import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/usuario_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/ocorrencia_service.dart';
import '../../services/usuario_service.dart';

class _C {
  static const bg         = Colors.white;
  static const text       = Color(0xFF1A1A1A);
  static const hint       = Color(0xFF8A8A8A);
  static const avatarBg   = Color(0xFF9E9E9E);
  static const border     = Color(0xFF1A1A1A);
  static const error      = Color(0xFFB00020);
}

class EditarPerfilPage extends StatefulWidget {
  final UsuarioModel perfilAtual;

  const EditarPerfilPage({super.key, required this.perfilAtual});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final _formKey           = GlobalKey<FormState>();
  final _nomeCtrl          = TextEditingController();
  final _bioCtrl           = TextEditingController();
  final _bairroCtrl        = TextEditingController();
  final _picker              = ImagePicker();
  final _cloudinaryService   = CloudinaryService();
  final _usuarioService      = UsuarioService();
  final _ocorrenciaService   = OcorrenciaService();

  XFile?    _novaFoto;
  Uint8List? _novaFotoBytes;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl.text   = widget.perfilAtual.nome;
    _bioCtrl.text    = widget.perfilAtual.bio;
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
      source: source, imageQuality: 80, maxWidth: 800,
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
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _C.text),
              title: const Text('Tirar foto'),
              onTap: () { Navigator.pop(context); _trocarFoto(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _C.text),
              title: const Text('Escolher da galeria'),
              onTap: () { Navigator.pop(context); _trocarFoto(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarSalvar() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Salvar alterações',
          style: TextStyle(fontWeight: FontWeight.w700, color: _C.text),
        ),
        content: const Text(
          'Tem certeza que deseja alterar o seu perfil?',
          style: TextStyle(color: _C.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _C.hint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.text,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      await _ocorrenciaService.atualizarPerfilNasOcorrencias(
        atualizado.uid,
        atualizado.nome,
        atualizado.fotoUrl,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado!')),
      );
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
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        foregroundColor: _C.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Editar perfil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _C.text),
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
            _input(
              controller: _bairroCtrl,
              hint: 'Seu bairro',
              maxLength: 40,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _confirmarSalvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.text,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarEditavel() {
    final temFotoNova = _novaFotoBytes != null;
    final temFotoAtual = widget.perfilAtual.fotoUrl != null &&
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
                    ? NetworkImage(widget.perfilAtual.fotoUrl!) as ImageProvider
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
              decoration: const BoxDecoration(
                color: _C.text,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _C.text,
        ),
      );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_salvando,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(color: _C.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.hint, fontSize: 14),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.border, width: 1.5),
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
