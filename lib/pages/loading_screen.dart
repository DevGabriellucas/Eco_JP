import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/ecohub_logo_drawing.dart';

class LoadingScreen extends StatefulWidget {
  final Future<void> Function() load;
  final WidgetBuilder next;
  final WidgetBuilder error;

  const LoadingScreen({
    super.key,
    required this.load,
    required this.next,
    required this.error,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const _logoWidthFactor = .88;

  /// Largura da marca dentro do SVG (805 unidades de largura, com margens
  /// vazias dos lados): a largura desejada da marca na tela é convertida para
  /// a largura do SVG inteiro.
  static const _markWidthInCanvas = 600.0;
  static const _holdAfterSignature = Duration(milliseconds: 300);
  static const _crossfade = Duration(milliseconds: 800);

  bool _loadingFinished = false;
  bool _signatureFinished = false;
  bool _holdFinished = false;
  bool _failed = false;
  bool _isNavigating = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    // O carregamento real corre em paralelo e nunca bloqueia a animação.
    unawaited(_startAppInitialization());
  }

  Future<void> _startAppInitialization() async {
    var failed = false;
    try {
      await widget.load();
    } catch (error) {
      failed = true;
      debugPrint('Falha ao inicializar Eco Hub: $error');
    }
    if (!mounted) return;

    setState(() {
      _failed = failed;
      _loadingFinished = true;
    });
    unawaited(_tryNavigate());
  }

  void _onSignatureFinished() {
    if (!mounted || _signatureFinished) return;
    setState(() => _signatureFinished = true);
    // A logo fica completa e parada um instante antes da transição. Se o app
    // ainda estiver carregando, ela simplesmente continua assim (sem repetir
    // a escrita).
    _holdTimer = Timer(_holdAfterSignature, () {
      _holdFinished = true;
      unawaited(_tryNavigate());
    });
  }

  Future<void> _tryNavigate() async {
    if (!_loadingFinished ||
        !_signatureFinished ||
        !_holdFinished ||
        _isNavigating) {
      return;
    }
    _isNavigating = true;

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: _crossfade,
        reverseTransitionDuration: _crossfade,
        pageBuilder: (context, animation, secondaryAnimation) =>
            (_failed ? widget.error : widget.next)(context),
        // Crossfade: a próxima tela surge por cima da logo enquanto ela
        // ainda está visível, sem passar por uma tela verde vazia.
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markWidth = (MediaQuery.sizeOf(context).width * _logoWidthFactor)
        .clamp(0.0, 600.0);
    final canvasWidth =
        markWidth * EcoHubLogoDrawing.canvasWidth / _markWidthInCanvas;

    return Scaffold(
      backgroundColor: const Color(0xFF0A2E1A),
      body: SafeArea(
        child: Semantics(
          label: 'Carregando Eco Hub',
          liveRegion: true,
          // As margens vazias do SVG podem passar da largura da tela.
          child: OverflowBox(
            maxWidth: canvasWidth,
            child: EcoHubLogoDrawing(
              width: canvasWidth,
              onFinished: _onSignatureFinished,
            ),
          ),
        ),
      ),
    );
  }
}
