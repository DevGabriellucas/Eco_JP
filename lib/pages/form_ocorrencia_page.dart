import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/repositories/ocorrencia_repository.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../features/denuncias/providers/geocoding_provider.dart';
import '../models/occurrence_types.dart';
import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/rate_limiter.dart';
import '../services/usuario_service.dart';
import '../theme/app_theme.dart';
import '../utils/cloudinary_image.dart';
import 'mapPage/map_style.dart';
import 'form_ocorrencia/controllers/location_controller.dart';
import 'form_ocorrencia/controllers/media_controller.dart';
import 'form_ocorrencia/widgets/dashed_border_painter.dart';
import 'form_ocorrencia/widgets/visualizador_fotos.dart';
import 'form_ocorrencia/widgets/visualizador_video.dart';

// ─── Paleta ────────────────────────────────────────────────────────────────

class _Cores {
  // Cinza-médio (dica) e vermelho de erro — ok nos dois temas. Os neutros
  // (texto/fundo/borda/superfície) vêm de `context.pal`.
  static const hint = AppColors.hint;
  static const error = AppColors.danger;
  static const disabled = AppColors.hint;
}

// ─── Page ──────────────────────────────────────────────────────────────────

class FormOcorrenciaPage extends ConsumerStatefulWidget {
  const FormOcorrenciaPage({super.key});

  @override
  ConsumerState<FormOcorrenciaPage> createState() => _FormOcorrenciaPageState();
}

class _FormOcorrenciaPageState extends ConsumerState<FormOcorrenciaPage> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _cloudinaryService = CloudinaryService();

  // Estado e lógica de mídia (fotos + vídeo) e de localização vivem em
  // controllers próprios; a página escuta ambos e reconstrói.
  late final MediaController _media;
  late final LocationController _location;

  OcorrenciaRepository get _ocorrenciaRepository =>
      ref.read(ocorrenciaRepositoryProvider);

  String? _categoria;
  bool _anonima = false;

  bool _enviando = false;
  bool _enviado = false;
  String? _statusEnvio;
  int _uploadAtual = 0;
  int _uploadTotal = 0;

  // Sobrevivem entre tentativas de envio. O ID é gerado uma vez: se a
  // tentativa anterior chegou ao servidor, a nova não duplica a denúncia. As
  // URLs evitam subir de novo a mesma mídia (e deixar órfãos no Cloudinary);
  // a chave é a própria lista de bytes, que muda se o usuário trocar o arquivo.
  String? _idOcorrencia;
  final Map<Uint8List, String> _urlsEnviadas = Map.identity();

  /// 3 casas decimais ≈ 110 m em João Pessoa.
  static double _arredondarCoordenada(double v) =>
      (v * 1000).roundToDouble() / 1000;

  static const _categorias = [
    'Lixo',
    'Queimada',
    'Buraco',
    'Árvores caídas',
    'Enchentes',
    'Esgoto',
    'Falta iluminação',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();
    _media = MediaController();
    _location = LocationController(geo: ref.read(geocodingServiceProvider));
    _media.addListener(_onControllerChange);
    _location.addListener(_onControllerChange);
  }

  // Reconstrói a página inteira a cada mudança nos controllers — mesma
  // granularidade de rebuild que o antigo setState monolítico.
  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _media.removeListener(_onControllerChange);
    _location.removeListener(_onControllerChange);
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    _media.dispose();
    _location.dispose();
    super.dispose();
  }

  // ── Fotos ────────────────────────────────────────────────────────────────

  Future<void> _selecionarImagem(int slot, ImageSource source) async {
    final err = await _media.selecionarImagem(slot, source);
    if (err != null) _snack(err, error: true);
  }

  void _adicionarFoto() {
    final slot = _media.proximoSlotVazio();
    if (slot != null) _abrirPicker(slot);
  }

  void _abrirPicker(int slot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.pal.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _pill(),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: context.pal.ink),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(context);
                _selecionarImagem(slot, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: context.pal.ink,
              ),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(context);
                _selecionarImagem(slot, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Vídeo ────────────────────────────────────────────────────────────────

  Future<void> _selecionarVideo(ImageSource source) async {
    final err = await _media.selecionarVideo(source);
    if (err != null) _snack(err, error: true);
  }

  void _abrirVisualizadorVideo() {
    final video = _media.video;
    if (video == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VisualizadorVideo(path: video.path, titulo: video.name),
      ),
    );
  }

  void _abrirPickerVideo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.pal.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _pill(),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.videocam_outlined, color: context.pal.ink),
              title: const Text('Gravar vídeo'),
              onTap: () {
                Navigator.pop(context);
                _selecionarVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.video_library_outlined,
                color: context.pal.ink,
              ),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(context);
                _selecionarVideo(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Localização ──────────────────────────────────────────────────────────

  Future<void> _usarLocalizacaoAtual() async {
    final err = await _location.usarLocalizacaoAtual();
    // Com a posição confirmada a mensagem é só um aviso, não um erro.
    if (err != null) {
      _snack(err, error: !_location.coordenadasConfirmadas);
    }
  }

  // ── Envio ────────────────────────────────────────────────────────────────

  Future<void> _confirmarEnvio() async {
    if (!_formKey.currentState!.validate()) return;
    if (_media.totalFotos == 0) {
      _snack('Adicione pelo menos uma foto.', error: true);
      return;
    }
    if (_authService.currentUser == null) {
      _snack('Faça login para registrar uma ocorrência.', error: true);
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pal.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: _buildModalConfirmacao,
    );

    if (ok == true) await _enviar();
  }

  Widget _buildModalConfirmacao(BuildContext ctx) {
    final pal = ctx.pal;
    final totalFotos = _media.totalFotos;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _pill()),
            const SizedBox(height: 20),
            const Text(
              'Confirmar denúncia?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Revise os dados antes de enviar.',
              style: TextStyle(fontSize: 13, color: _Cores.hint),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _resumoItem(
                    'Fotos',
                    '$totalFotos foto${totalFotos == 1 ? '' : 's'}',
                  ),
                  _resumoItem(
                    'Vídeo',
                    _media.video != null ? 'Anexado' : 'Nenhum',
                  ),
                  _resumoItem('Categoria', _categoria ?? '-'),
                  _resumoItem('Título', _tituloCtrl.text.trim()),
                  _resumoItem(
                    'Descrição',
                    _truncate(_descricaoCtrl.text.trim(), 70),
                  ),
                  _resumoItem(
                    'Local',
                    _truncate(_location.endereco, 60),
                  ),
                  _resumoItem(
                    'Identidade',
                    _anonima ? 'Anônima' : 'Visível',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: pal.ink,
                      side: BorderSide(color: pal.ink),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pal.ink,
                      foregroundColor: pal.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviar() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _snack('Sessão expirada. Faça login novamente.', error: true);
      return;
    }

    final categoria = _categoria;
    if (categoria == null) {
      _snack('Selecione uma categoria.', error: true);
      return;
    }

    setState(() {
      _enviando = true;
      _statusEnvio = 'Validando localização...';
      _uploadAtual = 0;
      _uploadTotal = _media.totalFotos;
    });
    try {
      // Se o usuário digitou o endereço sem escolher uma sugestão, ainda não
      // temos coordenadas — o controller resolve agora para o pin no mapa.
      final (lat, lon) = await _location.resolverCoordenadas();
      if (!mounted) return;

      if (!LocationController.coordenadaValida(lat, lon)) {
        _snack(
          'Não foi possível localizar esse endereço. Escolha uma sugestão ou use sua localização atual.',
          error: true,
        );
        return;
      }

      // Antes dos uploads: um envio recusado pelo limite depois de subir as
      // fotos deixaria a mídia órfã no Cloudinary.
      _ocorrenciaRepository.verificarLimiteDenuncia();
      final id = _idOcorrencia ??= _ocorrenciaRepository.novoIdOcorrencia();

      final urls = <String>[];

      for (int i = 0; i < 3; i++) {
        final img = _media.imagens[i];
        final bytes = _media.imagensBytes[i];
        if (img != null && bytes != null) {
          if (mounted) {
            setState(() {
              _statusEnvio =
                  'Enviando foto ${urls.length + 1} de $_uploadTotal...';
            });
          }
          final url =
              _urlsEnviadas[bytes] ??= await _cloudinaryService.uploadImage(
            bytes: bytes,
            fileName: img.name,
          );
          urls.add(url);
          if (mounted) {
            setState(() {
              _uploadAtual = urls.length;
            });
          }
          if (!mounted) return;
        }
      }

      String? videoUrl;
      if (_media.video != null && _media.videoBytes != null) {
        if (mounted) setState(() => _statusEnvio = 'Enviando vídeo...');
        videoUrl = _urlsEnviadas[_media.videoBytes!] ??=
            await _cloudinaryService.uploadVideo(
          bytes: _media.videoBytes!,
          fileName: _media.video!.name,
        );
        if (!mounted) return;
      }

      setState(() => _statusEnvio = 'Salvando denúncia...');
      final perfil = await _usuarioService.carregarPerfil(uid);
      if (!mounted) return;

      final ocorrencia = OcorrenciaModel(
        id: '',
        titulo: _tituloCtrl.text.trim(),
        descricao: _descricaoCtrl.text.trim(),
        // Anônima: endereço do GPS sem o número e coordenadas arredondadas
        // (~100 m). Com "usar localização atual", a posição exata do
        // denunciante ficava legível para qualquer usuário e podia
        // identificá-lo (a casa dele, por exemplo).
        localizacao: _location.enderecoPublico(anonima: _anonima),
        latitude: _anonima ? _arredondarCoordenada(lat!) : lat!,
        longitude: _anonima ? _arredondarCoordenada(lon!) : lon!,
        bairro: _location.bairro,
        tipoLixo: categoria,
        usuarioId: uid,
        videoUrl: videoUrl,
        // As regras exigem que o nome público seja o `nome` do perfil. Nunca
        // cair no prefixo do e-mail: ele viraria dado público da pessoa.
        usuarioNome: _anonima || perfil == null || perfil.nome.trim().isEmpty
            ? null
            : perfil.nome,
        usuarioFotoUrl: _anonima
            ? null
            : fotoPublicaPermitida(
                perfil?.fotoUrl ?? _authService.currentUser?.photoURL,
              ),
        imagemUrl: urls.isNotEmpty ? urls.first : null,
        imagensUrls: urls,
        anonima: _anonima,
      );

      final confirmada = await _ocorrenciaRepository.cadastrarOcorrencia(
        ocorrencia,
        id: id,
      );
      if (!mounted) return;

      setState(() {
        _enviado = true;
        _statusEnvio = 'Denúncia enviada.';
      });
      _snack(
        confirmada
            ? 'Ocorrência registrada com sucesso!'
            : 'Sem conexão: a denúncia foi salva e será publicada quando a internet voltar.',
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Envio error: $e');
      final String msg;
      if (e is RateLimitException) {
        msg = 'Aguarde ${e.segundosRestantes}s antes de enviar outra denúncia.';
      } else if (e is CloudinaryConfigException) {
        msg = 'Cloudinary não configurado: ${e.message}';
      } else if (e is CloudinaryUploadException) {
        msg = 'Erro no upload da foto: ${e.message}';
      } else {
        final s = e.toString();
        msg = s.length > 160 ? s.substring(0, 160) : s;
      }
      _snack(msg, error: true);
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
          if (!_enviado) {
            _statusEnvio = null;
            _uploadAtual = 0;
            _uploadTotal = 0;
          }
        });
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _Cores.error : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: pal.background,
      appBar: AppBar(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nova denúncia',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: pal.ink,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: pal.border, height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            _fotoSection(),
            const SizedBox(height: 24),
            _videoSection(),
            const SizedBox(height: 24),
            _categoriaSection(),
            const SizedBox(height: 24),
            _tituloSection(),
            const SizedBox(height: 24),
            _descricaoSection(),
            const SizedBox(height: 24),
            _localizacaoSection(),
            const SizedBox(height: 8),
            _botaoLocalizacao(),
            if (_location.coordenadasConfirmadas) ...[
              const SizedBox(height: 12),
              _mapaMiniatura(),
              const SizedBox(height: 8),
              _localizacaoStatus(),
            ],
            const SizedBox(height: 24),
            _anonimaSection(),
            if (_enviando) ...[const SizedBox(height: 16), _envioStatus()],
          ],
        ),
      ),
      bottomNavigationBar: _rodapeEnvio(),
    );
  }

  // ── Seção fotos ───────────────────────────────────────────────────────────

  Widget _fotoSection() {
    final totalFotos = _media.totalFotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('FOTOS'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$totalFotos de 3',
                style: TextStyle(
                  color: context.pal.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [for (var i = 0; i < 3; i++) _fotoSlot(i)],
        ),
        const SizedBox(height: 8),
        Text(
          'Adicione pelo menos uma foto. Metadados e GPS da imagem são removidos antes do envio.',
          style: TextStyle(fontSize: 11, height: 1.4, color: context.pal.muted),
        ),
      ],
    );
  }

  Widget _fotoSlot(int index) {
    final pal = context.pal;
    final bytes = _media.imagensBytes[index];
    final temFoto = bytes != null;
    final selecionada = _media.fotoAtivaIdx == index && temFoto;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
        child: GestureDetector(
          onTap: _enviando
              ? null
              : temFoto
                  ? () {
                      _media.selecionarFotoAtiva(index);
                      _abrirVisualizadorFotos(index);
                    }
                  : () => _abrirPicker(index),
          child: SizedBox(
            height: 100,
            child: temFoto
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selecionada ? pal.primary : pal.border,
                        width: selecionada ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(bytes!, fit: BoxFit.cover),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _enviando
                                  ? null
                                  : () => _media.removerFoto(index),
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomPaint(
                    foregroundPainter: DashedBorderPainter(
                      color: pal.border,
                      radius: 10,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: pal.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: index == _media.proximoSlotVazio()
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_camera_outlined,
                                  size: 20,
                                  color: pal.primary,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Adicionar foto',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: pal.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Icon(Icons.add, color: pal.muted, size: 22),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Seção vídeo (opcional) ───────────────────────────────────────────────

  Widget _videoSection() {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('VÍDEO (OPCIONAL)'),
        if (_media.video == null)
          GestureDetector(
            onTap: _enviando ? null : _abrirPickerVideo,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: pal.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: pal.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.videocam_outlined, color: pal.muted, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adicionar vídeo',
                          style: TextStyle(
                            fontSize: 13,
                            color: pal.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Até 30 segundos',
                          style: TextStyle(fontSize: 11, color: pal.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: pal.muted),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          )
        else
          _videoPreviewCard(),
      ],
    );
  }

  // Card de preview do vídeo: mostra o primeiro quadro (quando o controlador
  // fica pronto) com um botão de play; tocar abre a reprodução em tela cheia.
  Widget _videoPreviewCard() {
    final pal = context.pal;
    final controller = _media.videoController;
    final Widget media;
    if (controller != null && controller.value.isInitialized) {
      media = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    } else {
      media = const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _enviando ? null : _abrirVisualizadorVideo,
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  media,
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.videocam, color: pal.ink, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _media.video?.name ?? 'Vídeo',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: pal.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Remover vídeo',
                  child: GestureDetector(
                    onTap: _enviando ? null : _media.removerVideo,
                    child:
                        const Icon(Icons.close, size: 18, color: _Cores.hint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Abre o visualizador em tela cheia com todas as fotos anexadas, começando
  // na foto tocada. Permite dar zoom (InteractiveViewer) e navegar entre elas.
  void _abrirVisualizadorFotos(int slotInicial) {
    final anexadas = _media.fotosAnexadas();
    if (anexadas.isEmpty) return;
    final fotos = [for (final a in anexadas) a.bytes];
    final slots = [for (final a in anexadas) a.slot];
    final inicial = slots.indexOf(slotInicial).clamp(0, fotos.length - 1);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VisualizadorFotos(fotos: fotos, indiceInicial: inicial),
      ),
    );
  }

  // ── Seção categoria ───────────────────────────────────────────────────────

  Widget _categoriaSection() {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('CATEGORIA'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categorias.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.96,
          ),
          itemBuilder: (context, index) {
            final categoria = _categorias[index];
            final selecionada = _categoria == categoria;
            return Semantics(
              button: true,
              selected: selecionada,
              label: categoria,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _enviando
                      ? null
                      : () => setState(() => _categoria = categoria),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selecionada
                          ? pal.primary.withValues(alpha: 0.1)
                          : pal.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selecionada ? pal.primary : pal.border,
                        width: selecionada ? 1.5 : 1,
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          OccurrenceTypeParser.fromString(categoria).icon,
                          color: selecionada ? pal.primary : pal.muted,
                          size: 18,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _nomeCategoria(categoria),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selecionada ? pal.primary : pal.ink,
                            fontSize: 10.5,
                            height: 1.1,
                            fontWeight:
                                selecionada ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _nomeCategoria(String categoria) =>
      categoria == 'Falta iluminação' ? 'Iluminação' : categoria;

  // ── Seção título ──────────────────────────────────────────────────────────

  Widget _tituloSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelRow(
          'TÍTULO',
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _tituloCtrl,
            builder: (context, value, _) => Text(
              '${value.text.length}/80',
              style: TextStyle(fontSize: 11, color: context.pal.muted),
            ),
          ),
        ),
        TextFormField(
          controller: _tituloCtrl,
          enabled: !_enviando,
          maxLength: 80,
          minLines: 1,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: context.pal.ink, fontSize: 14),
          decoration: _dec('Digite o título').copyWith(counterText: ''),
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) return 'Título obrigatório';
            if (s.length > 80) return 'Máximo 80 caracteres';
            return null;
          },
        ),
      ],
    );
  }

  // ── Seção descrição ───────────────────────────────────────────────────────

  Widget _descricaoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('DESCRIÇÃO'),
        TextFormField(
          controller: _descricaoCtrl,
          enabled: !_enviando,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          style: TextStyle(color: context.pal.ink, fontSize: 14),
          decoration: _dec(
            'Descreva o problema ...',
          ).copyWith(alignLabelWithHint: true),
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) return 'Descrição obrigatória';
            if (s.length < 10) return 'Mínimo 10 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _descricaoCtrl,
          builder: (context, value, _) {
            final valido = value.text.trim().length >= 10;
            return Row(
              children: [
                Icon(
                  valido ? Icons.check : Icons.info_outline,
                  size: 14,
                  color: valido ? context.pal.primary : context.pal.hint,
                ),
                const SizedBox(width: 6),
                Text(
                  valido
                      ? 'Mínimo de 10 caracteres atingido'
                      : 'Mínimo de 10 caracteres',
                  style: TextStyle(
                    fontSize: 11,
                    color: valido ? context.pal.muted : context.pal.hint,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Seção localização + autocomplete ─────────────────────────────────────

  Widget _localizacaoSection() {
    final pal = context.pal;
    return TapRegion(
      onTapOutside: (_) {
        // Só fecha o teclado ao tocar fora. As sugestões continuam visíveis
        // para o usuário poder lê-las e tocá-las depois de tirar o foco — elas
        // são limpas ao escolher uma sugestão ou ao reeditar o endereço.
        _location.aoTocarFora();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('LOCALIZAÇÃO'),
          TextFormField(
            controller: _location.enderecoCtrl,
            focusNode: _location.enderecoFocus,
            enabled: !_enviando,
            style: TextStyle(color: pal.ink, fontSize: 14),
            onChanged: _location.onEnderecoChanged,
            decoration: _dec('Pesquise localização').copyWith(
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.search,
                  color: pal.muted,
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              // Com texto no campo vira um "x" que limpa tudo de uma vez:
              // antes era preciso apagar o endereço letra por letra.
              suffixIcon: _location.buscandoSug
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pal.ink,
                        ),
                      ),
                    )
                  : ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _location.enderecoCtrl,
                      builder: (context, valor, _) => valor.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Limpar localização',
                              icon: Icon(Icons.close, color: pal.ink, size: 20),
                              onPressed:
                                  _enviando ? null : _location.limparEndereco,
                            ),
                    ),
            ),
            validator: (v) =>
                (v?.trim() ?? '').isEmpty ? 'Informe a localização' : null,
          ),
          if (_location.mostrarSug && _location.sugestoes.isNotEmpty)
            _sugestoesDropdown(),
        ],
      ),
    );
  }

  Widget _localizacaoStatus() {
    final texto = _location.endereco;
    if (texto.isEmpty) return const SizedBox.shrink();

    final confirmada = _location.coordenadasConfirmadas;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            confirmada ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: confirmada ? context.pal.primary : _Cores.hint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              confirmada
                  ? 'Localização confirmada para o mapa.'
                  : 'As coordenadas serão validadas antes do envio.',
              style: TextStyle(
                fontSize: 12,
                color: confirmada ? context.pal.primary : _Cores.hint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sugestoesDropdown() {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border.all(color: pal.ink),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _location.sugestoes.asMap().entries.map((e) {
          final isLast = e.key == _location.sugestoes.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: () => _location.selecionarSugestao(e.value),
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(8))
                    : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: _Cores.hint,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value.descricao,
                          style: TextStyle(fontSize: 13, color: pal.ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: pal.border, indent: 40),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _botaoLocalizacao() {
    final pal = context.pal;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed:
            (_location.loadingLoc || _enviando) ? null : _usarLocalizacaoAtual,
        style: TextButton.styleFrom(
          foregroundColor: pal.primary,
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: const Size(0, 40),
          alignment: Alignment.centerLeft,
        ),
        icon: _location.loadingLoc
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: pal.primary,
                ),
              )
            : const Icon(Icons.my_location_outlined, size: 18),
        label: Text(
          _location.loadingLoc
              ? 'Obtendo localização...'
              : 'Usar localização atual',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _mapaMiniatura() {
    final pal = context.pal;
    final lat = _location.latitude;
    final lon = _location.longitude;
    if (lat == null || lon == null) return const SizedBox.shrink();
    final tipo = OccurrenceTypeParser.fromString(_categoria ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final position = LatLng(lat, lon);

    return Container(
      height: 140,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: IgnorePointer(
        child: GoogleMap(
          key: ValueKey('localizacao-$lat-$lon'),
          initialCameraPosition: CameraPosition(target: position, zoom: 15),
          markers: {
            Marker(
              markerId: const MarkerId('nova-denuncia'),
              position: position,
              icon: BitmapDescriptor.defaultMarkerWithHue(tipo.markerHue),
            ),
          },
          style: isDark ? kEstiloMapaEscuro : null,
          compassEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          rotateGesturesEnabled: false,
          scrollGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: false,
        ),
      ),
    );
  }

  Widget _envioStatus() {
    final pal = context.pal;
    final progress = _uploadTotal == 0 ? null : _uploadAtual / _uploadTotal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusEnvio ?? 'Enviando denúncia...',
                  style: TextStyle(
                    color: pal.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress.clamp(0, 1).toDouble(),
                backgroundColor: pal.border,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _anonimaSection() {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: pal.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.visibility_off_outlined,
              color: pal.muted,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Denunciar anonimamente',
                  style: TextStyle(
                    color: pal.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Seu nome e sua foto não aparecem na publicação.',
                  style: TextStyle(
                    color: pal.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: _anonima,
            onChanged: _enviando ? null : (v) => setState(() => _anonima = v),
            activeColor: pal.primary,
          ),
        ],
      ),
    );
  }

  Widget _rodapeEnvio() {
    final pal = context.pal;
    return Container(
      color: pal.surface,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: pal.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 16,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ProgressDotsPainter(color: pal.primary),
                ),
              ),
              const SizedBox(height: 8),
              _botaoEnviar(),
              const SizedBox(height: 8),
              Text(
                'Você revisa tudo antes de publicar.',
                style: TextStyle(fontSize: 11, color: pal.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoEnviar() {
    final pal = context.pal;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_enviando || _enviado) ? null : _confirmarEnvio,
        style: ElevatedButton.styleFrom(
          backgroundColor: pal.primary,
          disabledBackgroundColor: pal.muted,
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0E1311)
              : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        icon: _enviando
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0E1311)
                      : Colors.white,
                ),
              )
            : const Icon(Icons.send_outlined, size: 20),
        label: Text(
          _enviado ? 'Enviado!' : 'Enviar denúncia',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: context.pal.muted,
          ),
        ),
      );

  Widget _labelRow(String label, Widget trailing) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: context.pal.muted,
              ),
            ),
            trailing,
          ],
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint.isNotEmpty ? hint : null,
        hintStyle: TextStyle(color: context.pal.muted, fontSize: 14),
        filled: true,
        fillColor: context.pal.surfaceAlt,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.pal.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.pal.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _Cores.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _Cores.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _pill() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: _Cores.hint,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _resumoItem(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _Cores.hint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: context.pal.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}

class _ProgressDotsPainter extends CustomPainter {
  const _ProgressDotsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final dottedPaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    for (double x = 3; x <= size.width - 3; x += 5) {
      canvas.drawCircle(Offset(x, centerY), 1, dottedPaint);
    }

    final milestones = <double>[3, size.width / 2, size.width - 3];
    final completedPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(milestones.first, centerY), 3, completedPaint);
    canvas.drawCircle(Offset(milestones.last, centerY), 3, completedPaint);
    canvas.drawCircle(
      Offset(milestones[1], centerY),
      4,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressDotsPainter oldDelegate) =>
      oldDelegate.color != color;
}
