import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/repositories/ocorrencia_repository.dart';
import '../features/denuncias/providers/denuncia_providers.dart';
import '../features/denuncias/providers/geocoding_provider.dart';
import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/classificacao_ia_service.dart';
import '../services/cloudinary_service.dart';
import '../services/geolocation/geocoding_service.dart';
import '../services/rate_limiter.dart';
import '../services/usuario_service.dart';
import '../theme/app_theme.dart';
import '../utils/imagem_privacidade.dart';

// ─── Paleta ────────────────────────────────────────────────────────────────

class _C {
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
  final _enderecoCtrl = TextEditingController();
  final _enderecoFocus = FocusNode();
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _cloudinaryService = CloudinaryService();
  final _picker = ImagePicker();

  OcorrenciaRepository get _ocorrenciaRepository =>
      ref.read(ocorrenciaRepositoryProvider);
  GeocodingService get _geo => ref.read(geocodingServiceProvider);

  // Até 3 fotos
  final List<XFile?> _imagens = List.filled(3, null, growable: false);
  final List<Uint8List?> _imagensBytes = List.filled(3, null, growable: false);

  // Vídeo opcional (até 30s)
  XFile? _video;
  Uint8List? _videoBytes;
  // Controlador só para exibir o primeiro quadro do vídeo como preview.
  VideoPlayerController? _videoController;

  final _classificacaoService = ClassificacaoIaService();
  String? _categoria;
  bool _anonima = false;
  bool _sugerindoCategoria = false;
  double? _latitude;
  double? _longitude;

  bool _loadingLoc = false;
  bool _enviando = false;
  bool _enviado = false;
  String? _statusEnvio;
  int _uploadAtual = 0;
  int _uploadTotal = 0;
  int _fotoAtivaIdx = 0; // qual foto aparece na área principal

  // Autocomplete
  List<EnderecoSugestao> _sugestoes = [];
  bool _buscandoSug = false;
  bool _mostrarSug = false;
  Timer? _debounce;

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

  int get _totalFotos => _imagensBytes.where((b) => b != null).length;

  @override
  void initState() {
    super.initState();
    // FocusNode usado apenas para unfocus() ao selecionar sugestão.
    // O TapRegion no widget cuida de fechar o dropdown.
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    _enderecoCtrl.dispose();
    _enderecoFocus.dispose();
    _debounce?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  // ── Fotos ────────────────────────────────────────────────────────────────

  // Limites de tamanho aplicados no cliente — independentes de qualquer
  // configuração no painel do Cloudinary (defesa em profundidade).
  static const _maxFotoBytes = 8 * 1024 * 1024; // 8 MB
  static const _maxVideoBytes = 50 * 1024 * 1024; // 50 MB

  Future<void> _selecionarImagem(int slot, ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (!mounted || img == null) return;
    final bytesOriginais = await img.readAsBytes();
    if (!mounted) return;
    // Remove EXIF (inclui GPS embutido na foto) antes de qualquer outra
    // validação — sem isso, a localização exata poderia vazar mesmo em
    // denúncia marcada como anônima.
    final bytes = await removerMetadadosImagem(bytesOriginais);
    if (!mounted) return;
    if (bytes.length > _maxFotoBytes) {
      _snack('Foto muito grande (máx. 8 MB). Tente outra.', error: true);
      return;
    }
    setState(() {
      _imagens[slot] = img;
      _imagensBytes[slot] = bytes;
      _fotoAtivaIdx = slot; // mostra a foto recém adicionada
    });
  }

  int? _proximoSlotVazio() {
    for (int i = 0; i < 3; i++) {
      if (_imagens[i] == null) return i;
    }
    return null;
  }

  void _adicionarFoto() {
    final slot = _proximoSlotVazio();
    if (slot != null) _abrirPicker(slot);
  }

  void _removerFoto(int slot) {
    setState(() {
      _imagens[slot] = null;
      _imagensBytes[slot] = null;
      if (_fotoAtivaIdx == slot) {
        final prox = List.generate(
          3,
          (i) => i,
        ).firstWhere((i) => i != slot && _imagens[i] != null, orElse: () => 0);
        _fotoAtivaIdx = prox;
      }
    });
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
    final video = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    if (!mounted || video == null) return;
    final bytes = await video.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxVideoBytes) {
      _snack('Vídeo muito grande (máx. 50 MB). Tente outro.', error: true);
      return;
    }
    setState(() {
      _video = video;
      _videoBytes = bytes;
    });
    await _prepararPreviewVideo(video);
  }

  void _removerVideo() {
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _video = null;
      _videoBytes = null;
    });
  }

  // Prepara um controlador só para exibir o primeiro quadro como preview no
  // formulário; a reprodução em si acontece em tela cheia (_VisualizadorVideo).
  Future<void> _prepararPreviewVideo(XFile video) async {
    await _videoController?.dispose();
    final controller = VideoPlayerController.file(File(video.path));
    _videoController = controller;
    try {
      await controller.initialize();
      // Se o widget saiu de tela ou o usuário já trocou/removeu o vídeo,
      // descartamos silenciosamente (o novo controlador cuida do resto).
      if (!mounted || _videoController != controller) return;
      setState(() {});
    } catch (e) {
      debugPrint('Preview de vídeo indisponível: $e');
    }
  }

  void _abrirVisualizadorVideo() {
    final video = _video;
    if (video == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _VisualizadorVideo(path: video.path, titulo: video.name),
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

  void _onEnderecoChanged(String v) {
    if (_mostrarSug || _latitude != null || _longitude != null) {
      setState(() {
        _mostrarSug = false;
        _latitude = null;
        _longitude = null;
      });
    }
    _debounce?.cancel();
    final texto = v.trim();
    // Autocomplete com 2+ caracteres (CEP, bairro, rua): mais rápido e útil
    if (texto.length < 2) {
      setState(() => _sugestoes = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_geo.pareceCep(texto)) {
        _buscarPorCep(texto);
      } else {
        _buscarSugestoes(texto);
      }
    });
  }

  Future<void> _buscarSugestoes(String q) async {
    setState(() => _buscandoSug = true);
    try {
      final list = await _geo.autocomplete(q);
      if (!mounted) return;
      setState(() {
        _sugestoes = list;
        _mostrarSug = list.isNotEmpty;
      });
    } finally {
      if (mounted) setState(() => _buscandoSug = false);
    }
  }

  // Busca um endereço pelo CEP (ViaCEP) e resolve as coordenadas no Nominatim.
  Future<void> _buscarPorCep(String cep) async {
    final list = await _geo.buscarPorCep(cep);
    if (!mounted) return;
    setState(() {
      _sugestoes = list;
      _mostrarSug = list.isNotEmpty;
    });
  }

  void _selecionarSugestao(EnderecoSugestao s) {
    _enderecoCtrl.text = s.descricao;
    setState(() {
      _latitude = s.lat;
      _longitude = s.lon;
      _sugestoes = [];
      _mostrarSug = false;
    });
    _enderecoFocus.unfocus();
  }

  Future<void> _usarLocalizacaoAtual() async {
    setState(() => _loadingLoc = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Ative o GPS do dispositivo.', error: true);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _snack('Permissão negada.', error: true);
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _snack('Permissão bloqueada nas configurações.', error: true);
        return;
      }
      if (!mounted) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      final addr = await _geo.reverseGeocode(pos.latitude, pos.longitude);
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _enderecoCtrl.text = addr;
        _mostrarSug = false;
      });
    } catch (e) {
      debugPrint('Localização: $e');
      _snack('Erro ao obter localização.', error: true);
    } finally {
      if (mounted) setState(() => _loadingLoc = false);
    }
  }

  // ── Envio ────────────────────────────────────────────────────────────────

  bool _coordenadaValida(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return false;
    return lat != 0 && lon != 0;
  }

  Future<void> _confirmarEnvio() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalFotos == 0) {
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
              style: TextStyle(fontSize: 13, color: _C.hint),
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
                    '$_totalFotos foto${_totalFotos == 1 ? '' : 's'}',
                  ),
                  _resumoItem('Vídeo', _video != null ? 'Anexado' : 'Nenhum'),
                  _resumoItem('Categoria', _categoria ?? '-'),
                  _resumoItem('Título', _tituloCtrl.text.trim()),
                  _resumoItem(
                    'Descrição',
                    _truncate(_descricaoCtrl.text.trim(), 70),
                  ),
                  _resumoItem(
                    'Local',
                    _truncate(_enderecoCtrl.text.trim(), 60),
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
      _uploadTotal = _totalFotos;
    });
    try {
      // Se o usuário digitou o endereço sem escolher uma sugestão, ainda não
      // temos coordenadas — resolvemos agora para o pin aparecer no mapa.
      var lat = _latitude;
      var lon = _longitude;
      if (lat == null || lon == null) {
        final coord = await _geo.geocodificar(_enderecoCtrl.text.trim());
        if (!mounted) return;
        lat = coord?.$1;
        lon = coord?.$2;
      }

      if (!_coordenadaValida(lat, lon)) {
        _snack(
          'Não foi possível localizar esse endereço. Escolha uma sugestão ou use sua localização atual.',
          error: true,
        );
        return;
      }

      final urls = <String>[];

      for (int i = 0; i < 3; i++) {
        final img = _imagens[i];
        final bytes = _imagensBytes[i];
        if (img != null && bytes != null) {
          if (mounted) {
            setState(() {
              _statusEnvio =
                  'Enviando foto ${urls.length + 1} de $_uploadTotal...';
            });
          }
          final url = await _cloudinaryService.uploadImage(
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
      if (_video != null && _videoBytes != null) {
        if (mounted) setState(() => _statusEnvio = 'Enviando vídeo...');
        videoUrl = await _cloudinaryService.uploadVideo(
          bytes: _videoBytes!,
          fileName: _video!.name,
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
        localizacao: _enderecoCtrl.text.trim(),
        latitude: lat!,
        longitude: lon!,
        tipoLixo: categoria,
        usuarioId: uid,
        videoUrl: videoUrl,
        usuarioNome: _anonima
            ? null
            : (perfil?.nome.trim().isNotEmpty == true
                  ? perfil!.nome
                  : (_authService.currentUser?.displayName ??
                        _authService.currentUser?.email?.split('@').first)),
        usuarioFotoUrl: _anonima
            ? null
            : (perfil?.fotoUrl ?? _authService.currentUser?.photoURL),
        imagemUrl: urls.isNotEmpty ? urls.first : null,
        imagensUrls: urls,
        anonima: _anonima,
      );

      await _ocorrenciaRepository.cadastrarOcorrencia(ocorrencia);
      if (!mounted) return;

      setState(() {
        _enviado = true;
        _statusEnvio = 'Denúncia enviada.';
      });
      _snack('Ocorrência registrada com sucesso!');
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
        backgroundColor: error ? _C.error : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.surface,
      appBar: AppBar(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            _fotoSection(),
            const SizedBox(height: 16),
            _videoSection(),
            const SizedBox(height: 20),
            _categoriaSection(),
            const SizedBox(height: 16),
            _tituloSection(),
            const SizedBox(height: 16),
            _descricaoSection(),
            const SizedBox(height: 16),
            _localizacaoSection(),
            const SizedBox(height: 12),
            _botaoLocalizacao(),
            const SizedBox(height: 16),
            _anonimaSection(),
            if (_enviando) ...[const SizedBox(height: 16), _envioStatus()],
            const SizedBox(height: 24),
            _botaoEnviar(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ── Seção fotos ───────────────────────────────────────────────────────────

  Widget _fotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mainPhotoArea(),
        if (_totalFotos > 0) ...[const SizedBox(height: 8), _thumbnailStrip()],
        const SizedBox(height: 6),
        Text(
          '$_totalFotos/3 foto${_totalFotos == 1 ? '' : 's'} selecionada${_totalFotos == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 11, color: _C.hint),
        ),
      ],
    );
  }

  // ── Seção vídeo (opcional) ───────────────────────────────────────────────

  Widget _videoSection() {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('VÍDEO (OPCIONAL)'),
        if (_video == null)
          GestureDetector(
            onTap: _enviando ? null : _abrirPickerVideo,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: pal.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: pal.border),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_outlined, color: _C.hint, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Adicionar vídeo (até 30s)',
                    style: TextStyle(
                      fontSize: 13,
                      color: _C.hint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
    final controller = _videoController;
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
                    _video?.name ?? 'Vídeo',
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
                    onTap: _enviando ? null : _removerVideo,
                    child: const Icon(Icons.close, size: 18, color: _C.hint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainPhotoArea() {
    final pal = context.pal;
    final bytes = _totalFotos > 0 ? _imagensBytes[_fotoAtivaIdx] : null;
    return GestureDetector(
      onTap: _enviando
          ? null
          : bytes == null
          ? _adicionarFoto
          : () => _abrirVisualizadorFotos(_fotoAtivaIdx),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: bytes == null
            ? CustomPaint(
                foregroundPainter: _DashedPainter(color: pal.border, radius: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: pal.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 40, color: _C.hint),
                      SizedBox(height: 8),
                      Text(
                        'Tirar Foto',
                        style: TextStyle(
                          fontSize: 14,
                          color: _C.hint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toque para adicionar uma imagem',
                        style: TextStyle(fontSize: 12, color: _C.hint),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: pal.surfaceAlt,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        child: Image.memory(
                          bytes,
                          key: ValueKey<int>(_fotoAtivaIdx),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Ampliar',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _fotoAcaoBtn(
                          icon: Icons.swap_horiz,
                          label: 'Trocar foto',
                          onTap: _enviando
                              ? null
                              : () => _abrirPicker(_fotoAtivaIdx),
                        ),
                        const SizedBox(width: 8),
                        _fotoAcaoBtn(
                          icon: Icons.close,
                          label: 'Remover foto',
                          onTap: _enviando
                              ? null
                              : () => _removerFoto(_fotoAtivaIdx),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _thumbnailStrip() {
    final pal = context.pal;
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          if (_imagens[i] != null)
            GestureDetector(
              onTap: () => setState(() => _fotoAtivaIdx = i),
              child: Container(
                width: 52,
                height: 52,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _fotoAtivaIdx == i ? pal.ink : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(_imagensBytes[i]!, fit: BoxFit.cover),
                ),
              ),
            ),
        if (_totalFotos < 3)
          Semantics(
            button: true,
            label: 'Adicionar foto',
            child: GestureDetector(
              onTap: _enviando ? null : _adicionarFoto,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: pal.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: pal.border),
                ),
                child: const Icon(Icons.add, color: _C.hint, size: 22),
              ),
            ),
          ),
      ],
    );
  }

  // Botão circular sobre a foto (trocar / remover).
  Widget _fotoAcaoBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppColors.ink),
        ),
      ),
    );
  }

  // Abre o visualizador em tela cheia com todas as fotos anexadas, começando
  // na foto tocada. Permite dar zoom (InteractiveViewer) e navegar entre elas.
  void _abrirVisualizadorFotos(int slotInicial) {
    final fotos = <Uint8List>[];
    final slots = <int>[];
    for (int i = 0; i < 3; i++) {
      final b = _imagensBytes[i];
      if (b != null) {
        fotos.add(b);
        slots.add(i);
      }
    }
    if (fotos.isEmpty) return;
    final inicial = slots.indexOf(slotInicial).clamp(0, fotos.length - 1);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _VisualizadorFotos(fotos: fotos, indiceInicial: inicial),
      ),
    );
  }

  // ── Seção categoria ───────────────────────────────────────────────────────

  Future<void> _sugerirCategoriaIA() async {
    final titulo = _tituloCtrl.text.trim();
    final descricao = _descricaoCtrl.text.trim();
    if (titulo.isEmpty && descricao.isEmpty) {
      _snack('Preencha título ou descrição antes de pedir sugestão.');
      return;
    }
    setState(() => _sugerindoCategoria = true);
    final categoria = await _classificacaoService.sugerirCategoria(
      titulo: titulo,
      descricao: descricao,
    );
    if (!mounted) return;
    setState(() => _sugerindoCategoria = false);
    if (categoria != null) {
      setState(() => _categoria = categoria);
    } else {
      _snack('Não foi possível sugerir agora. Selecione manualmente.');
    }
  }

  Widget _categoriaSection() {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label('CATEGORIA'),
            TextButton.icon(
              onPressed: (_enviando || _sugerindoCategoria)
                  ? null
                  : _sugerirCategoriaIA,
              icon: _sugerindoCategoria
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: const Text(
                'Sugerir com IA',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: pal.ink,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
              ),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: _categoria,
          decoration: _dec(''),
          dropdownColor: pal.surface,
          style: TextStyle(color: pal.ink, fontSize: 14),
          icon: Icon(Icons.add, color: pal.ink, size: 20),
          hint: Text(
            'Selecione categoria',
            style: TextStyle(color: pal.hint, fontSize: 14),
          ),
          items: _categorias
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: _enviando ? null : (v) => setState(() => _categoria = v),
          validator: (v) => v == null ? 'Selecione uma categoria' : null,
        ),
      ],
    );
  }

  // ── Seção título ──────────────────────────────────────────────────────────

  Widget _tituloSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('TÍTULO'),
        TextFormField(
          controller: _tituloCtrl,
          enabled: !_enviando,
          maxLength: 80,
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
        if (_enderecoFocus.hasFocus) _enderecoFocus.unfocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('LOCALIZAÇÃO'),
          TextFormField(
            controller: _enderecoCtrl,
            focusNode: _enderecoFocus,
            enabled: !_enviando,
            style: TextStyle(color: pal.ink, fontSize: 14),
            onChanged: _onEnderecoChanged,
            decoration: _dec('Pesquise localização').copyWith(
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.location_on_outlined,
                  color: pal.ink,
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: _buscandoSug
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
                  : Icon(Icons.search, color: pal.ink, size: 20),
            ),
            validator: (v) =>
                (v?.trim() ?? '').isEmpty ? 'Informe a localização' : null,
          ),
          if (_mostrarSug && _sugestoes.isNotEmpty) _sugestoesDropdown(),
          _localizacaoStatus(),
        ],
      ),
    );
  }

  Widget _localizacaoStatus() {
    final texto = _enderecoCtrl.text.trim();
    if (texto.isEmpty) return const SizedBox.shrink();

    final confirmada = _coordenadaValida(_latitude, _longitude);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            confirmada ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: confirmada ? context.pal.primary : _C.hint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              confirmada
                  ? 'Localização confirmada para o mapa.'
                  : 'As coordenadas serão validadas antes do envio.',
              style: TextStyle(
                fontSize: 12,
                color: confirmada ? context.pal.primary : _C.hint,
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
        children: _sugestoes.asMap().entries.map((e) {
          final isLast = e.key == _sugestoes.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: () => _selecionarSugestao(e.value),
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
                        color: _C.hint,
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_loadingLoc || _enviando) ? null : _usarLocalizacaoAtual,
        style: OutlinedButton.styleFrom(
          foregroundColor: pal.ink,
          side: BorderSide(color: pal.ink),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: _loadingLoc
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: pal.ink,
                ),
              )
            : const Icon(Icons.my_location, size: 18),
        label: Text(
          _loadingLoc ? 'Obtendo localização...' : 'Usar localização atual',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: pal.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _anonima,
        onChanged: _enviando ? null : (v) => setState(() => _anonima = v),
        activeThumbColor: pal.ink,
        title: const Text(
          'Denunciar anonimamente',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Seu nome e foto não aparecem para ninguém, nem para o órgão responsável.',
          style: TextStyle(fontSize: 12, color: _C.hint),
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
          backgroundColor: pal.ink,
          disabledBackgroundColor: _C.disabled,
          foregroundColor: pal.surface,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        icon: _enviando
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: pal.surface,
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
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: context.pal.ink,
      ),
    ),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint.isNotEmpty ? hint : null,
    hintStyle: const TextStyle(color: _C.hint, fontSize: 14),
    filled: false,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: context.pal.ink),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: context.pal.ink, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _C.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _C.error, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  Widget _pill() => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: _C.hint,
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
                color: _C.hint,
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

// ─── Sugestão de endereço (descrição + coordenadas) ─────────────────────────

// ─── Dashed border painter ─────────────────────────────────────────────────

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
          Radius.circular(radius),
        ),
      );

    final dashed = Path();
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        dashed.addPath(m.extractPath(d, d + 5), Offset.zero);
        d += 9;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color || old.radius != radius;
}

// ─── Visualizador de fotos em tela cheia ────────────────────────────────────

class _VisualizadorFotos extends StatefulWidget {
  final List<Uint8List> fotos;
  final int indiceInicial;

  const _VisualizadorFotos({required this.fotos, required this.indiceInicial});

  @override
  State<_VisualizadorFotos> createState() => _VisualizadorFotosState();
}

class _VisualizadorFotosState extends State<_VisualizadorFotos> {
  late final PageController _pageCtrl;
  late int _atual;

  @override
  void initState() {
    super.initState();
    _atual = widget.indiceInicial;
    _pageCtrl = PageController(initialPage: widget.indiceInicial);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.fotos.length > 1
            ? Text(
                '${_atual + 1} / ${widget.fotos.length}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.fotos.length,
        onPageChanged: (i) => setState(() => _atual = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.memory(widget.fotos[i], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ─── Visualizador de vídeo em tela cheia ────────────────────────────────────

class _VisualizadorVideo extends StatefulWidget {
  final String path;
  final String titulo;

  const _VisualizadorVideo({required this.path, required this.titulo});

  @override
  State<_VisualizadorVideo> createState() => _VisualizadorVideoState();
}

class _VisualizadorVideoState extends State<_VisualizadorVideo> {
  VideoPlayerController? _ctrl;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final ctrl = VideoPlayerController.file(File(widget.path));
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setLooping(true);
      await ctrl.play();
      setState(() {});
    } catch (e) {
      debugPrint('Não foi possível reproduzir o vídeo: $e');
      if (mounted) setState(() => _erro = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _alternarPlayPause() {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        unawaited(ctrl.pause());
      } else {
        unawaited(ctrl.play());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final Widget body;
    if (_erro) {
      body = const Text(
        'Não foi possível reproduzir o vídeo.',
        style: TextStyle(color: Colors.white70),
      );
    } else if (ctrl == null || !ctrl.value.isInitialized) {
      body = const CircularProgressIndicator(color: Colors.white);
    } else {
      body = GestureDetector(
        onTap: _alternarPlayPause,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: VideoPlayer(ctrl),
            ),
            if (!ctrl.value.isPlaying)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                ctrl,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.titulo,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(child: body),
    );
  }
}
