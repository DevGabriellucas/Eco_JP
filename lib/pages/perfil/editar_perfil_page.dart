import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/ocorrencia_repository.dart';
import '../../features/denuncias/providers/denuncia_providers.dart';
import '../../models/usuario_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/usuario_service.dart';
import '../../utils/cloudinary_image.dart';
import '../../utils/imagem_cacheada.dart';
import '../../theme/app_theme.dart';

class _C {
  // Cinza do avatar e vermelho de erro — iguais nos dois temas. Os neutros
  // (fundo/texto/borda/dica) vêm de `context.pal`.
  static const avatarBg = Color(0xFF9E9E9E);
  static const error = Color(0xFFB00020);
}

class EditarPerfilPage extends ConsumerStatefulWidget {
  final UsuarioModel perfilAtual;

  const EditarPerfilPage({super.key, required this.perfilAtual});

  @override
  ConsumerState<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends ConsumerState<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _cloudinaryService = CloudinaryService();
  final _usuarioService = UsuarioService();

  OcorrenciaRepository get _ocorrenciaRepository =>
      ref.read(ocorrenciaRepositoryProvider);

  XFile? _novaFoto;
  Uint8List? _novaFotoBytes;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl.text = widget.perfilAtual.nome;
    _bioCtrl.text = widget.perfilAtual.bio;
    _bairroCtrl.text = widget.perfilAtual.bairro;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _bioCtrl.dispose();
    _bairroCtrl.dispose();
    super.dispose();
  }

  Future<void> _trocarFoto(ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (!mounted || img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _novaFoto = img;
      _novaFotoBytes = bytes;
    });
  }

  void _opcoesFoto() {
    final pal = context.pal;
    showModalBottomSheet(
      context: context,
      backgroundColor: pal.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: pal.ink),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(context);
                _trocarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: pal.ink),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(context);
                _trocarFoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarSalvar() async {
    if (!_formKey.currentState!.validate()) return;

    final pal = context.pal;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Salvar alterações',
          style: TextStyle(fontWeight: FontWeight.w700, color: pal.ink),
        ),
        content: Text(
          'Tem certeza que deseja alterar o seu perfil?',
          style: TextStyle(color: pal.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: pal.hint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: pal.ink,
              foregroundColor: pal.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmar == true) await _salvar();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      String? fotoUrl = widget.perfilAtual.fotoUrl;

      if (_novaFotoBytes != null && _novaFoto != null) {
        fotoUrl = await _cloudinaryService.uploadImage(
          bytes: _novaFotoBytes!,
          fileName: _novaFoto!.name,
        );
      }

      final atualizado = widget.perfilAtual.copyWith(
        nome: _nomeCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        bairro: _bairroCtrl.text.trim(),
        fotoUrl: fotoUrl,
      );

      await _usuarioService.salvarPerfil(atualizado);
      await _ocorrenciaRepository.atualizarPerfilNasOcorrencias(
        atualizado.uid,
        atualizado.nome,
        atualizado.fotoUrl,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil atualizado!')));
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Erro ao salvar perfil: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: _C.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.surface,
      appBar: AppBar(
        backgroundColor: pal.surface,
        foregroundColor: pal.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          'Editar perfil',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: pal.ink,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(child: _avatarEditavel()),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _salvando ? null : _opcoesFoto,
                child: const Text('Alterar foto'),
              ),
            ),
            const SizedBox(height: 16),
            _label('Nome'),
            const SizedBox(height: 8),
            _input(
              controller: _nomeCtrl,
              hint: 'Seu nome',
              maxLength: 40,
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Informe seu nome' : null,
            ),
            const SizedBox(height: 16),
            _label('Biografia'),
            const SizedBox(height: 8),
            _input(
              controller: _bioCtrl,
              hint: 'Fale um pouco sobre você',
              maxLines: 3,
              maxLength: 150,
            ),
            const SizedBox(height: 16),
            _label('Bairro'),
            const SizedBox(height: 8),
            _input(controller: _bairroCtrl, hint: 'Seu bairro', maxLength: 40),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _confirmarSalvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pal.ink,
                  foregroundColor: pal.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _salvando
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pal.surface,
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarEditavel() {
    final pal = context.pal;
    final temFotoNova = _novaFotoBytes != null;
    final temFotoAtual =
        widget.perfilAtual.fotoUrl != null &&
        widget.perfilAtual.fotoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: _salvando ? null : _opcoesFoto,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: _C.avatarBg,
            backgroundImage: temFotoNova
                ? MemoryImage(_novaFotoBytes!)
                : temFotoAtual
                ? imagemCacheada(
                    cloudinaryAvatar(widget.perfilAtual.fotoUrl!, radius: 52),
                  )
                : null,
            child: (!temFotoNova && !temFotoAtual)
                ? Text(
                    widget.perfilAtual.iniciais,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A4A4A),
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: pal.ink, shape: BoxShape.circle),
              child: Icon(Icons.camera_alt, size: 16, color: pal.surface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: context.pal.ink,
    ),
  );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final pal = context.pal;
    return TextFormField(
      controller: controller,
      enabled: !_salvando,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: TextStyle(color: pal.ink, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: pal.hint, fontSize: 14),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: pal.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: pal.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.error, width: 1.5),
        ),
      ),
    );
  }
}
