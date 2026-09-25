import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Um `<path>` de `ecohub_logo_strokes.svg` (o contorno de uma letra). Cada
/// `M` é um contorno percorrido pela caneta.
class EcoHubSignatureStroke {
  final String id;
  final List<List<Offset>> gestures;

  const EcoHubSignatureStroke({required this.id, required this.gestures});
}

/// Trajetória da escrita, lida de `assets/ecohub_logo_strokes.svg`.
///
/// Os dois SVGs são tratados como somente leitura: eles definem a geometria,
/// e toda a animação (ordem, progresso, tempo) é feita aqui em Dart. O SVG de
/// strokes usa o mesmo viewBox (805x310) de `ecohub_logo_draw.svg`.
class EcoHubSignature {
  static const viewBox = Size(805, 310);

  /// Área que a marca ocupa dentro do viewBox (o SVG oficial tem margens
  /// vazias dos lados).
  static const logoBounds = Rect.fromLTRB(106, 94, 706, 207);

  final List<EcoHubSignatureStroke> strokes;

  const EcoHubSignature(this.strokes);

  /// Aceita os comandos de polilinha (M, L, H, V, Z — absolutos e relativos),
  /// que são os usados pelo SVG de strokes.
  factory EcoHubSignature.parse(String svg) {
    final strokes = <EcoHubSignatureStroke>[];
    for (final tag in RegExp(r'<path\b[^>]*>').allMatches(svg)) {
      final element = tag[0]!;
      String? attr(String name) =>
          RegExp('\\b$name="([^"]*)"').firstMatch(element)?.group(1);

      final data = attr('d');
      if (data == null) continue;
      strokes.add(
        EcoHubSignatureStroke(
          id: attr('id') ?? 'path${strokes.length}',
          gestures: _parsePolyline(data),
        ),
      );
    }
    return EcoHubSignature(strokes);
  }

  static List<List<Offset>> _parsePolyline(String data) {
    final tokens = RegExp(r'[MmLlHhVvZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')
        .allMatches(data)
        .map((match) => match[0]!)
        .toList();
    final gestures = <List<Offset>>[];
    var current = Offset.zero;
    var command = 'M';
    var i = 0;
    double next() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      if (RegExp('[A-Za-z]').hasMatch(tokens[i])) command = tokens[i++];
      switch (command) {
        case 'M' || 'm':
          final point = Offset(next(), next());
          current = command == 'm' ? current + point : point;
          gestures.add([current]);
          // Pares seguintes a um M são tratados como L (regra do SVG).
          command = command == 'm' ? 'l' : 'L';
        case 'L' || 'l':
          final point = Offset(next(), next());
          current = command == 'l' ? current + point : point;
          gestures.last.add(current);
        case 'H' || 'h':
          final x = next();
          current = Offset(command == 'h' ? current.dx + x : x, current.dy);
          gestures.last.add(current);
        case 'V' || 'v':
          final y = next();
          current = Offset(current.dx, command == 'v' ? current.dy + y : y);
          gestures.last.add(current);
        case 'Z' || 'z':
          gestures.last.add(gestures.last.first);
          current = gestures.last.first;
        default:
          throw FormatException(
            'Comando "$command" não suportado na trajetória da assinatura',
          );
      }
    }
    return gestures;
  }
}

/// Um contorno na ordem de escrita, com a tinta acumulada ao longo dele.
class _InkLeg {
  final String strokeId;
  final Path path;
  final ui.PathMetric metric;

  /// Distâncias amostradas ao longo do contorno e a tinta total (pixels da
  /// logo revelados) acumulada até cada uma delas.
  final List<double> arcs;
  final List<double> inks;

  _InkLeg(this.strokeId, this.path, this.metric, this.arcs, this.inks);

  double get inkStart => inks.first;
  double get inkEnd => inks.last;

  /// Distância ao longo do contorno em que a tinta acumulada atinge [ink].
  double arcForInk(double ink) {
    if (ink >= inkEnd) return metric.length;
    var low = 0, high = inks.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (inks[mid] < ink) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == 0) return 0;
    final span = inks[low] - inks[low - 1];
    final t = span <= 0 ? 1.0 : (ink - inks[low - 1]) / span;
    return arcs[low - 1] + (arcs[low] - arcs[low - 1]) * t;
  }
}

/// Linha do tempo da escrita.
///
/// A caneta percorre os contornos do SVG de strokes e revela a logo oficial
/// num raio [penRadius] em volta de si. Como a caneta anda pela borda de cada
/// traço e o raio cobre a espessura dele, cada trecho aparece já inteiro, com
/// a cor e a espessura finais, e permanece na tela.
///
/// O tempo é medido em "tinta nova" (pixels da logo revelados pela primeira
/// vez), não em distância: trechos longos levam mais tempo, e a volta da
/// caneta pelo outro lado de um traço já escrito é instantânea. Isso mantém a
/// escrita contínua, sem pausas entre as letras.
@visibleForTesting
class EcoHubInkTimeline {
  static const penRadius = 7.0;

  /// A área revelada vai um pouco além de [penRadius] para incluir a borda
  /// suavizada (antialiasing) das letras: assim o último frame da escrita é
  /// idêntico à logo oficial.
  static const revealRadius = penRadius + 1.5;
  static const _sampleStep = 1.0;

  /// Ordem de escrita e ponto de partida de cada contorno. A geometria vem
  /// intacta do SVG; aqui só se escolhe por onde a caneta começa a percorrê-la.
  /// O "e" começa pela ponta do talo (entrada), segue pelo bojo, pela barra e
  /// pelo arco de cima (o desenho da folha); o contorno `leaf` completa a
  /// nervura.
  static const writingOrder = <(String, Offset?)>[
    ('e', Offset(106, 199)),
    ('leaf', null),
    ('c', Offset(317, 137)),
    ('o', null),
    ('h', null),
    ('u', null),
    ('b', null),
  ];

  final List<_InkLeg> _legs;
  final double totalInk;

  /// Fração dos pixels da logo que a escrita completa revela (deve ser 1).
  final double coverage;

  EcoHubInkTimeline._(this._legs, this.totalInk, this.coverage);

  /// [alpha] é o canal alfa da logo oficial rasterizada em 1 pixel por
  /// unidade do viewBox ([width] pixels por linha).
  factory EcoHubInkTimeline(
    EcoHubSignature signature, {
    required Uint8List alpha,
    required int width,
  }) {
    final height = alpha.length ~/ width;
    final revealed = Uint8List(alpha.length);
    var glyphPixels = 0;
    for (final value in alpha) {
      if (value > 127) glyphPixels++;
    }
    var revealedPixels = 0;

    int stamp(Offset center) {
      const r = penRadius;
      var count = 0;
      final minX = math.max(0, (center.dx - r).floor());
      final maxX = math.min(width - 1, (center.dx + r).ceil());
      final minY = math.max(0, (center.dy - r).floor());
      final maxY = math.min(height - 1, (center.dy + r).ceil());
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          final index = y * width + x;
          if (alpha[index] <= 127 || revealed[index] == 1) continue;
          final dx = x + .5 - center.dx, dy = y + .5 - center.dy;
          if (dx * dx + dy * dy > r * r) continue;
          revealed[index] = 1;
          count++;
        }
      }
      return count;
    }

    final legs = <_InkLeg>[];
    var ink = 0.0;
    for (final (id, start) in writingOrder) {
      final stroke = signature.strokes.firstWhere((stroke) => stroke.id == id);
      for (var g = 0; g < stroke.gestures.length; g++) {
        final points = g == 0 && start != null
            ? _startAt(stroke.gestures[g], start)
            : stroke.gestures[g];
        if (points.length < 2) continue;
        final path = Path()..addPolygon(points, false);
        final metric = path.computeMetrics().first;

        final arcs = <double>[0];
        final inks = <double>[ink];
        for (var s = 0.0;; s = math.min(s + _sampleStep, metric.length)) {
          final count = stamp(metric.getTangentForOffset(s)!.position);
          ink += count;
          revealedPixels += count;
          arcs.add(s);
          inks.add(ink);
          if (s >= metric.length) break;
        }
        legs.add(_InkLeg(id, path, metric, arcs, inks));
      }
    }
    return EcoHubInkTimeline._(
      legs,
      ink,
      glyphPixels == 0 ? 0 : revealedPixels / glyphPixels,
    );
  }

  /// Percorre o mesmo contorno fechado a partir do vértice mais próximo de
  /// [start], sem alterar nenhum ponto.
  static List<Offset> _startAt(List<Offset> points, Offset start) {
    if (points.length < 3 || points.first != points.last) return points;
    final ring = points.sublist(0, points.length - 1);
    var best = 0;
    for (var i = 1; i < ring.length; i++) {
      if ((ring[i] - start).distance < (ring[best] - start).distance) best = i;
    }
    return [...ring.sublist(best), ...ring.sublist(0, best), ring[best]];
  }

  /// Ordem em que os traços são escritos.
  List<String> get strokeOrder {
    final order = <String>[];
    for (final leg in _legs) {
      if (order.isEmpty || order.last != leg.strokeId) order.add(leg.strokeId);
    }
    return order;
  }

  /// Fração do tempo de escrita gasta em cada traço.
  Map<String, double> get timeShare {
    final share = <String, double>{};
    for (final leg in _legs) {
      share[leg.strokeId] =
          (share[leg.strokeId] ?? 0) + (leg.inkEnd - leg.inkStart) / totalInk;
    }
    return share;
  }

  /// Desenha em [canvas] o caminho já percorrido pela caneta em [progress].
  void _drawWritten(Canvas canvas, double progress, Paint pen) {
    final target = totalInk * progress;
    for (final leg in _legs) {
      if (leg.inkStart >= target) break;
      if (leg.inkEnd <= target) {
        canvas.drawPath(leg.path, pen);
      } else {
        canvas.drawPath(leg.metric.extractPath(0, leg.arcForInk(target)), pen);
      }
    }
  }
}

/// Velocidade constante com partida e chegada suaves (perfil trapezoidal).
class _PenCurve extends Curve {
  static const _easeIn = .06;
  static const _easeOut = .08;
  static const _cruise = 1 / (1 - _easeIn / 2 - _easeOut / 2);

  const _PenCurve();

  @override
  double transformInternal(double t) {
    if (t < _easeIn) return _cruise * t * t / (2 * _easeIn);
    if (t > 1 - _easeOut) {
      final remaining = 1 - t;
      return 1 - _cruise * remaining * remaining / (2 * _easeOut);
    }
    return _cruise * (_easeIn / 2 + t - _easeIn);
  }
}

/// Pinta só a parte da logo oficial que a caneta já escreveu. Com a escrita
/// completa, pinta a própria logo oficial (sem troca visível).
@visibleForTesting
class EcoHubLogoInkPainter extends CustomPainter {
  final ui.Picture logo;
  final EcoHubInkTimeline timeline;
  final Animation<double> progress;

  EcoHubLogoInkPainter({
    required this.logo,
    required this.timeline,
    required this.progress,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    if (value <= 0) return;

    const bounds = EcoHubSignature.logoBounds;
    const viewBox = EcoHubSignature.viewBox;
    canvas.save();
    canvas.scale(size.width / viewBox.width, size.height / viewBox.height);

    if (value >= 1) {
      canvas.drawPicture(logo);
    } else {
      final layer = bounds.inflate(EcoHubInkTimeline.revealRadius * 2);
      canvas.saveLayer(layer, Paint());
      timeline._drawWritten(
        canvas,
        value,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = EcoHubInkTimeline.revealRadius * 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.saveLayer(layer, Paint()..blendMode = BlendMode.srcIn);
      canvas.drawPicture(logo);
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EcoHubLogoInkPainter oldDelegate) =>
      oldDelegate.logo != logo ||
      oldDelegate.timeline != timeline ||
      oldDelegate.progress != progress;
}

/// A logo oficial (`ecohub_logo_draw.svg`) lida diretamente: grupos com
/// `fill` + `fill-rule` e paths de polilinha. É desenhada com as cores e
/// paths do próprio SVG, sem o custo de compilar o SVG num isolate — o que
/// atrasava a abertura do app em ~0,5 s.
@visibleForTesting
class EcoHubOfficialLogo {
  final List<(Color, Path, List<List<Offset>>)> shapes;

  const EcoHubOfficialLogo(this.shapes);

  /// Lança [FormatException] se o SVG usar algo além de grupos com
  /// preenchimento sólido e paths de polilinha.
  factory EcoHubOfficialLogo.parse(String svg) {
    final shapes = <(Color, Path, List<List<Offset>>)>[];
    final groups = RegExp(r'<g\b([^>]*)>(.*?)</g>', dotAll: true);
    for (final group in groups.allMatches(svg)) {
      String? attr(String name) =>
          RegExp('\\b$name="([^"]*)"').firstMatch(group[1]!)?.group(1);
      final fill = attr('fill') ?? '';
      final rgb = fill.length == 7 && fill.startsWith('#')
          ? int.tryParse(fill.substring(1), radix: 16)
          : null;
      if (rgb == null) throw FormatException('fill não suportado: "$fill"');
      final evenOdd = attr('fill-rule') == 'evenodd';

      for (final path in RegExp(r'<path\b[^>]*\bd="([^"]*)"').allMatches(group[2]!)) {
        final polygons = EcoHubSignature._parsePolyline(path[1]!);
        final shape = Path()
          ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
        for (final polygon in polygons) {
          shape.addPolygon(polygon, true);
        }
        shapes.add((Color(0xFF000000 | rgb), shape, polygons));
      }
    }
    if (shapes.isEmpty) throw const FormatException('nenhum path na logo');
    return EcoHubOfficialLogo(shapes);
  }

  ui.Picture record() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final (color, path, _) in shapes) {
      canvas.drawPath(path, Paint()..color = color);
    }
    return recorder.endRecording();
  }

  /// Máscara da logo (255 dentro, 0 fora) em 1 pixel por unidade do
  /// viewBox, por varredura de linhas com a regra par-ímpar.
  Uint8List mask(int width, int height) {
    final mask = Uint8List(width * height);
    final edges = <(Offset, Offset)>[
      for (final (_, _, polygons) in shapes)
        for (final polygon in polygons)
          for (var i = 0; i < polygon.length; i++)
            (polygon[i], polygon[(i + 1) % polygon.length]),
    ];
    for (var y = 0; y < height; y++) {
      final cy = y + .5;
      final xs = <double>[
        for (final (a, b) in edges)
          if ((a.dy > cy) != (b.dy > cy))
            a.dx + (cy - a.dy) * (b.dx - a.dx) / (b.dy - a.dy),
      ]..sort();
      for (var i = 0; i + 1 < xs.length; i += 2) {
        final from = math.max(0, (xs[i] - .5).ceil());
        final to = math.min(width - 1, (xs[i + 1] - .5).ceil() - 1);
        for (var x = from; x <= to; x++) {
          mask[y * width + x] = 255;
        }
      }
    }
    return mask;
  }
}

class _PreparedLogo {
  final ui.Picture picture;
  final EcoHubInkTimeline timeline;

  const _PreparedLogo(this.picture, this.timeline);
}

/// Logo EcoHub sendo escrita à mão: e (com a folha) → c → o → h → u → b.
///
/// Reutilizável em qualquer tela de carregamento: não depende de Firebase nem
/// de navegação. Escreve uma única vez; ao terminar, a logo completa fica na
/// tela e [onFinished] é chamado. Quem usa decide quando sair.
///
/// [width] é a largura do SVG inteiro (805x310, com as margens vazias).
class EcoHubLogoDrawing extends StatefulWidget {
  static const canvasWidth = 805.0;
  static const canvasHeight = 310.0;
  static const logoKey = ValueKey('ecohub-logo-drawing');
  static const _logoAsset = 'assets/ecohub_logo_draw.svg';
  static const _strokesAsset = 'assets/ecohub_logo_strokes.svg';

  /// Logo e trajetória já preparadas. Guardar o resultado (e não a Future)
  /// permite que qualquer uso seguinte comece a escrever no mesmo frame.
  static _PreparedLogo? _cached;
  static Future<void>? _loading;

  final double width;
  final Duration startDelay;
  final Duration duration;
  final VoidCallback? onStarted;

  /// A escrita chegou ao fim do "b".
  final VoidCallback? onFinished;

  const EcoHubLogoDrawing({
    super.key,
    required this.width,
    this.startDelay = const Duration(milliseconds: 300),
    this.duration = const Duration(milliseconds: 1400),
    this.onStarted,
    this.onFinished,
  });

  /// Prepara a logo e a trajetória com antecedência (opcional). O resultado
  /// fica em cache, então os usos seguintes começam a escrever imediatamente.
  static Future<void> precache() {
    if (_cached != null) return Future<void>.value();
    return _loading ??= _loadAssets()
        .then((logo) => _cached = logo)
        .whenComplete(() => _loading = null);
  }

  static Future<_PreparedLogo> _loadAssets() async {
    final (logoSvg, strokesSvg) = await (
      rootBundle.loadString(_logoAsset),
      rootBundle.loadString(_strokesAsset),
    ).wait;
    final signature = EcoHubSignature.parse(strokesSvg);
    final width = EcoHubSignature.viewBox.width.round();
    final height = EcoHubSignature.viewBox.height.round();

    ui.Picture picture;
    Uint8List alpha;
    try {
      final logo = EcoHubOfficialLogo.parse(logoSvg);
      picture = logo.record();
      alpha = logo.mask(width, height);
    } on FormatException catch (error) {
      // SVG com recursos que a leitura direta não cobre: usa o flutter_svg.
      debugPrint('Logo EcoHub via flutter_svg: $error');
      final info = await vg.loadPicture(const SvgAssetLoader(_logoAsset), null);
      final image = await info.picture.toImage(width, height);
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      picture = info.picture;
      alpha = Uint8List(width * height);
      for (var i = 0; i < alpha.length; i++) {
        alpha[i] = rgba!.getUint8(i * 4 + 3);
      }
    }

    final timeline = EcoHubInkTimeline(signature, alpha: alpha, width: width);
    return _PreparedLogo(picture, timeline);
  }

  @override
  State<EcoHubLogoDrawing> createState() => _EcoHubLogoDrawingState();
}

class _EcoHubLogoDrawingState extends State<EcoHubLogoDrawing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: const _PenCurve(),
  );

  // A espera inicial conta a partir do momento em que a tela aparece de fato
  // (primeiro frame desenhado), e o tempo de preparar a logo já faz parte dela.
  final _sinceVisible = Stopwatch();
  late final Future<void> _visible;
  Timer? _startTimer;

  _PreparedLogo? _logo = EcoHubLogoDrawing._cached;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    // O teto só protege casos em que o sinal de "frame desenhado" não chega
    // (ex.: testes sem engine); no aparelho ele chega em ~150 ms.
    _visible = WidgetsBinding.instance.waitUntilFirstFrameRasterized
        .timeout(const Duration(seconds: 1), onTimeout: () {})
        .then((_) => _sinceVisible.start());
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    if (_logo == null) {
      try {
        await EcoHubLogoDrawing.precache();
      } catch (error) {
        debugPrint('Falha ao carregar a logo animada da Eco Hub: $error');
      }
      if (!mounted) return;
      setState(() => _logo = EcoHubLogoDrawing._cached);
    }

    await _visible;
    if (!mounted) return;

    final remaining = widget.startDelay - _sinceVisible.elapsed;
    if (remaining > Duration.zero) {
      _startTimer = Timer(remaining, _begin);
    } else {
      _begin();
    }
  }

  void _begin() {
    if (!mounted || _started) return;
    _started = true;
    widget.onStarted?.call();

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_logo == null || reduceMotion) {
      _controller.value = 1;
      _finish();
      return;
    }
    unawaited(_controller.forward());
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    // Nunca avisa o pai no meio de um build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance
          .addPostFrameCallback((_) => widget.onFinished?.call());
    } else {
      widget.onFinished?.call();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = _logo;

    return SizedBox(
      width: widget.width,
      height: widget.width *
          EcoHubLogoDrawing.canvasHeight /
          EcoHubLogoDrawing.canvasWidth,
      child: logo == null
          ? null
          : CustomPaint(
              key: EcoHubLogoDrawing.logoKey,
              painter: EcoHubLogoInkPainter(
                logo: logo.picture,
                timeline: logo.timeline,
                progress: _progress,
              ),
            ),
    );
  }
}

class EcoHubLoading extends StatelessWidget {
  final double width;
  final VoidCallback? onStarted;
  final VoidCallback? onFinished;

  const EcoHubLoading({
    super.key,
    required this.width,
    this.onStarted,
    this.onFinished,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EcoHubLogoDrawing(
        width: width,
        onStarted: onStarted,
        onFinished: onFinished,
      ),
    );
  }
}
