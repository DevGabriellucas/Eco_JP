import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/ocorrencia_model.dart';
import '../services/auth_service.dart';
import '../services/cloudinary_service.dart';
import '../services/ocorrencia_service.dart';
import '../services/usuario_service.dart';
import '../theme/app_theme.dart';

// ─── Paleta ────────────────────────────────────────────────────────────────

class _C {
  static const primary = AppColors.ink;
  static const bg = AppColors.surface;
  static const hint = AppColors.hint;
  static const error = AppColors.danger;
  static const disabled = AppColors.hint;
  static const slotBg = Color(0xFFF8F8F8);
  static const slotBorder = Color(0xFFBBBBBB);
  static const divider = AppColors.border;
}

// ─── Page ──────────────────────────────────────────────────────────────────

class FormOcorrenciaPage extends StatefulWidget {
  const FormOcorrenciaPage({super.key});

  @override
  State<FormOcorrenciaPage> createState() => _FormOcorrenciaPageState();
}

class _FormOcorrenciaPageState extends State<FormOcorrenciaPage> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _enderecoFocus = FocusNode();
  final _authService = AuthService();
  final _usuarioService = UsuarioService();
  final _cloudinaryService = CloudinaryService();
  final _ocorrenciaService = OcorrenciaService();
  final _picker = ImagePicker();

  // Até 3 fotos
  final List<XFile?> _imagens = List.filled(3, null, growable: false);
  final List<Uint8List?> _imagensBytes = List.filled(3, null, growable: false);

  String? _categoria;
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
  List<_EnderecoSugestao> _sugestoes = [];
  bool _buscandoSug = false;
  bool _mostrarSug = false;
  Timer? _debounce;

  // Passe a key via: flutter run --dart-define=GOOGLE_MAPS_API_KEY=SUA_KEY
  static const _googleKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

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
    super.dispose();
  }

  // ── Fotos ────────────────────────────────────────────────────────────────

  Future<void> _selecionarImagem(int slot, ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (!mounted || img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
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
      backgroundColor: _C.bg,
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
              leading: const Icon(Icons.camera_alt_outlined, color: _C.primary),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(context);
                _selecionarImagem(slot, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: _C.primary,
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
    if (texto.length < 3) {
      setState(() => _sugestoes = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_pareceCep(texto)) {
        _buscarPorCep(texto);
      } else {
        _buscarSugestoes(texto);
      }
    });
  }

  // Detecta se o texto digitado é um CEP (8 dígitos, com ou sem hífen).
  bool _pareceCep(String texto) {
    return RegExp(r'^\d{5}-?\d{3}$').hasMatch(texto.trim());
  }

  Future<void> _buscarSugestoes(String q) async {
    setState(() => _buscandoSug = true);
    try {
      _googleKey.isNotEmpty
          ? await _buscarGooglePlaces(q)
          : await _buscarNominatim(q);
    } finally {
      if (mounted) setState(() => _buscandoSug = false);
    }
  }

  Future<void> _buscarGooglePlaces(String q) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': '$q, João Pessoa',
          'components': 'country:br',
          'location': '-7.1153,-34.8641',
          'radius': '50000',
          'language': 'pt-BR',
          'key': _googleKey,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // O autocomplete do Google não retorna lat/lon (só a descrição);
      // as coordenadas são resolvidas por geocodificação ao enviar.
      final list = (data['predictions'] as List<dynamic>? ?? [])
          .take(8)
          .map((p) => p['description']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .map((desc) => _EnderecoSugestao(descricao: desc))
          .toList();
      setState(() {
        _sugestoes = list;
        _mostrarSug = list.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Google Places: $e');
      await _buscarNominatim(q);
    }
  }

  Future<void> _buscarNominatim(String q) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$q, João Pessoa',
        'countrycodes': 'br',
        'limit': '15',
        'format': 'jsonv2',
        'accept-language': 'pt-BR',
        'addressdetails': '1',
        // bounding box de João Pessoa para priorizar resultados locais
        'viewbox': '-34.98,-6.97,-34.78,-7.29',
        'bounded': '0',
      });
      final res = await http
          .get(uri, headers: {'User-Agent': 'EcoJP/1.0'})
          .timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;

      final data = jsonDecode(res.body) as List<dynamic>;
      final seen = <String>{};
      final list = <_EnderecoSugestao>[];
      for (final raw in data) {
        final item = raw as Map<String, dynamic>;
        final desc = _formatarEnderecoNominatim(item);
        if (desc.isEmpty || !seen.add(desc)) continue;
        list.add(
          _EnderecoSugestao(
            descricao: desc,
            lat: double.tryParse(item['lat']?.toString() ?? ''),
            lon: double.tryParse(item['lon']?.toString() ?? ''),
          ),
        );
        if (list.length >= 8) break;
      }

      setState(() {
        _sugestoes = list;
        _mostrarSug = list.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Nominatim: $e');
    }
  }

  // Busca um endereço pelo CEP (ViaCEP) e resolve as coordenadas no Nominatim.
  Future<void> _buscarPorCep(String cepRaw) async {
    final cep = cepRaw.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;
    try {
      final res = await http
          .get(Uri.https('viacep.com.br', '/ws/$cep/json/'))
          .timeout(const Duration(seconds: 8));
      if (!mounted || res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['erro'] == true || data['erro'] == 'true') {
        setState(() {
          _sugestoes = [];
          _mostrarSug = false;
        });
        return;
      }

      final logradouro = data['logradouro']?.toString() ?? '';
      final bairro = data['bairro']?.toString() ?? '';
      final cidade = data['localidade']?.toString() ?? '';
      final uf = data['uf']?.toString() ?? '';

      final desc = [
        logradouro,
        bairro,
        cidade,
      ].where((s) => s.isNotEmpty).join(', ');
      final descricao = desc.isEmpty ? '$cidade - $uf' : desc;

      // Resolve lat/lon do endereço retornado pelo CEP.
      final coord = await _geocodificar('$descricao, $uf');
      if (!mounted) return;

      setState(() {
        _sugestoes = [
          _EnderecoSugestao(
            descricao: descricao,
            lat: coord?.$1,
            lon: coord?.$2,
          ),
        ];
        _mostrarSug = true;
      });
    } catch (e) {
      debugPrint('ViaCEP: $e');
    }
  }

  // Geocodifica um endereço em texto para coordenadas (lat, lon).
  Future<(double, double)?> _geocodificar(String endereco) async {
    if (endereco.trim().isEmpty) return null;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': endereco,
        'countrycodes': 'br',
        'limit': '1',
        'format': 'jsonv2',
        'accept-language': 'pt-BR',
      });
      final res = await http
          .get(uri, headers: {'User-Agent': 'EcoJP/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as List<dynamic>;
      if (data.isEmpty) return null;
      final item = data.first as Map<String, dynamic>;
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');
      if (lat == null || lon == null) return null;
      return (lat, lon);
    } catch (e) {
      debugPrint('Geocodificar: $e');
      return null;
    }
  }

  String _formatarEnderecoNominatim(Map<String, dynamic> item) {
    final addr = item['address'] as Map<String, dynamic>?;
    if (addr == null) {
      final display = item['display_name']?.toString() ?? '';
      return display.split(',').take(3).join(',').trim();
    }

    final road =
        addr['road']?.toString() ??
        addr['pedestrian']?.toString() ??
        addr['footway']?.toString() ??
        addr['path']?.toString() ??
        '';
    final bairro =
        addr['neighbourhood']?.toString() ??
        addr['suburb']?.toString() ??
        addr['quarter']?.toString() ??
        addr['city_district']?.toString() ??
        '';
    final cidade =
        addr['city']?.toString() ??
        addr['town']?.toString() ??
        addr['municipality']?.toString() ??
        '';

    final parts = <String>[];
    if (road.isNotEmpty) parts.add(road);
    if (bairro.isNotEmpty) parts.add(bairro);
    if (cidade.isNotEmpty && cidade != road) parts.add(cidade);

    if (parts.isEmpty) {
      final display = item['display_name']?.toString() ?? '';
      return display.split(',').take(2).join(',').trim();
    }
    return parts.join(', ');
  }

  void _selecionarSugestao(_EnderecoSugestao s) {
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      final addr = await _reverseGeocode(pos.latitude, pos.longitude);
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

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
        ].where((s) => s != null && s.trim().isNotEmpty).take(3).join(', ');
        if (parts.isNotEmpty) return parts;
      }
    } catch (_) {}

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'addressdetails': '1',
        'accept-language': 'pt-BR',
      });
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'];
        if (addr is Map<String, dynamic>) {
          final parts =
              [
                    addr['road'],
                    addr['neighbourhood'],
                    addr['suburb'],
                    addr['city'],
                  ]
                  .where((s) => s is String && s.trim().isNotEmpty)
                  .take(3)
                  .map((s) => s.toString())
                  .join(', ');
          if (parts.isNotEmpty) return parts;
        }
      }
    } catch (_) {}

    return 'Endereço não encontrado';
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
      backgroundColor: _C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: _buildModalConfirmacao,
    );

    if (ok == true) await _enviar();
  }

  Widget _buildModalConfirmacao(BuildContext ctx) {
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
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _resumoItem(
                    'Fotos',
                    '$_totalFotos foto${_totalFotos == 1 ? '' : 's'}',
                  ),
                  _resumoItem('Categoria', _categoria ?? '-'),
                  _resumoItem('Título', _tituloCtrl.text.trim()),
                  _resumoItem(
                    'Descrição',
                    _truncate(_descricaoCtrl.text.trim(), 70),
                  ),
                  _resumoItem(
                    'Local',
                    _truncate(_enderecoCtrl.text.trim(), 60),
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
                      foregroundColor: _C.primary,
                      side: const BorderSide(color: _C.primary),
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
                      backgroundColor: _C.primary,
                      foregroundColor: _C.bg,
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
        final coord = await _geocodificar(_enderecoCtrl.text.trim());
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
        usuarioNome: perfil?.nome.trim().isNotEmpty == true
            ? perfil!.nome
            : (_authService.currentUser?.displayName ??
                  _authService.currentUser?.email?.split('@').first),
        usuarioFotoUrl: perfil?.fotoUrl ?? _authService.currentUser?.photoURL,
        imagemUrl: urls.isNotEmpty ? urls.first : null,
        imagensUrls: urls,
      );

      await _ocorrenciaService.cadastrarOcorrencia(ocorrencia);
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
      if (e is CloudinaryConfigException) {
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
        backgroundColor: error ? _C.error : _C.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        foregroundColor: _C.primary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nova denúncia',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _C.primary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _C.divider, height: 1),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            _fotoSection(),
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

  Widget _mainPhotoArea() {
    final bytes = _totalFotos > 0 ? _imagensBytes[_fotoAtivaIdx] : null;
    return GestureDetector(
      onTap: _enviando
          ? null
          : bytes == null
          ? _adicionarFoto
          : () => _abrirPicker(_fotoAtivaIdx),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: bytes == null
            ? CustomPaint(
                foregroundPainter: _DashedPainter(
                  color: _C.slotBorder,
                  radius: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.slotBg,
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
                      color: _C.slotBg,
                      child: Image.memory(
                        bytes,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _enviando
                          ? null
                          : () => _removerFoto(_fotoAtivaIdx),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: _C.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _thumbnailStrip() {
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
                    color: _fotoAtivaIdx == i ? _C.primary : Colors.transparent,
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
          GestureDetector(
            onTap: _enviando ? null : _adicionarFoto,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _C.slotBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _C.slotBorder),
              ),
              child: const Icon(Icons.add, color: _C.hint, size: 22),
            ),
          ),
      ],
    );
  }

  // ── Seção categoria ───────────────────────────────────────────────────────

  Widget _categoriaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('CATEGORIA'),
        DropdownButtonFormField<String>(
          initialValue: _categoria,
          decoration: _dec(''),
          dropdownColor: _C.bg,
          style: const TextStyle(color: _C.primary, fontSize: 14),
          icon: const Icon(Icons.add, color: _C.primary, size: 20),
          hint: const Text(
            'Selecione categoria',
            style: TextStyle(color: _C.hint, fontSize: 14),
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
          style: const TextStyle(color: _C.primary, fontSize: 14),
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
          style: const TextStyle(color: _C.primary, fontSize: 14),
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
    return TapRegion(
      onTapOutside: (_) {
        _enderecoFocus.unfocus();
        if (_mostrarSug) {
          setState(() {
            _sugestoes = [];
            _mostrarSug = false;
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('LOCALIZAÇÃO'),
          TextFormField(
            controller: _enderecoCtrl,
            focusNode: _enderecoFocus,
            enabled: !_enviando,
            style: const TextStyle(color: _C.primary, fontSize: 14),
            onChanged: _onEnderecoChanged,
            decoration: _dec('Pesquise localização').copyWith(
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.location_on_outlined,
                  color: _C.primary,
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: _buscandoSug
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _C.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.search, color: _C.primary, size: 20),
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
            color: confirmada ? AppColors.primary : _C.hint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              confirmada
                  ? 'Localização confirmada para o mapa.'
                  : 'As coordenadas serão validadas antes do envio.',
              style: TextStyle(
                fontSize: 12,
                color: confirmada ? AppColors.primary : _C.hint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sugestoesDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: _C.bg,
        border: Border.all(color: _C.primary),
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: _C.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: _C.divider, indent: 40),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _botaoLocalizacao() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_loadingLoc || _enviando) ? null : _usarLocalizacaoAtual,
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.primary,
          side: const BorderSide(color: _C.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: _loadingLoc
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _C.primary,
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
                  style: const TextStyle(
                    color: AppColors.ink,
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
                backgroundColor: AppColors.border,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _botaoEnviar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_enviando || _enviado) ? null : _confirmarEnvio,
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.primary,
          disabledBackgroundColor: _C.disabled,
          foregroundColor: _C.bg,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        icon: _enviando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
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
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: _C.primary,
      ),
    ),
  );

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint.isNotEmpty ? hint : null,
    hintStyle: const TextStyle(color: _C.hint, fontSize: 14),
    filled: false,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _C.primary),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _C.primary, width: 1.5),
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
              style: const TextStyle(
                fontSize: 13,
                color: _C.primary,
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

class _EnderecoSugestao {
  final String descricao;
  final double? lat;
  final double? lon;

  const _EnderecoSugestao({required this.descricao, this.lat, this.lon});
}

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
