import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../utils/imagem_privacidade.dart';

/// Estado e lógica das mídias de uma denúncia: até 3 fotos e um vídeo opcional.
///
/// Não conhece `BuildContext` nem UI — mutações são publicadas via
/// [notifyListeners], e falhas de validação (arquivo grande) voltam como
/// mensagem de erro para a página exibir. As dependências são injetáveis por
/// construtor para permitir testes unitários.
class MediaController extends ChangeNotifier {
  MediaController({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // Limites de tamanho aplicados no cliente — independentes de qualquer
  // configuração no painel do Cloudinary (defesa em profundidade).
  static const maxFotoBytes = 8 * 1024 * 1024; // 8 MB
  static const maxVideoBytes = 50 * 1024 * 1024; // 50 MB

  // Até 3 fotos.
  final List<XFile?> imagens = List.filled(3, null, growable: false);
  final List<Uint8List?> imagensBytes = List.filled(3, null, growable: false);
  int fotoAtivaIdx = 0; // qual foto aparece na área principal

  // Vídeo opcional (até 30s).
  XFile? video;
  Uint8List? videoBytes;
  // Controlador só para exibir o primeiro quadro do vídeo como preview.
  VideoPlayerController? videoController;

  bool _disposed = false;

  int get totalFotos => imagensBytes.where((b) => b != null).length;

  int? proximoSlotVazio() {
    for (int i = 0; i < 3; i++) {
      if (imagens[i] == null) return i;
    }
    return null;
  }

  /// Seleciona uma foto para o [slot]. Retorna uma mensagem de erro para exibir
  /// (arquivo grande) ou `null` em caso de sucesso ou cancelamento.
  Future<String?> selecionarImagem(int slot, ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (_disposed || img == null) return null;
    final bytesOriginais = await img.readAsBytes();
    if (_disposed) return null;
    // Remove EXIF (inclui GPS embutido na foto) antes de qualquer outra
    // validação — sem isso, a localização exata poderia vazar mesmo em
    // denúncia marcada como anônima.
    final bytes = await removerMetadadosImagem(bytesOriginais);
    if (_disposed) return null;
    if (bytes.length > maxFotoBytes) {
      return 'Foto muito grande (máx. 8 MB). Tente outra.';
    }
    imagens[slot] = img;
    imagensBytes[slot] = bytes;
    fotoAtivaIdx = slot; // mostra a foto recém adicionada
    notifyListeners();
    return null;
  }

  void selecionarFotoAtiva(int slot) {
    fotoAtivaIdx = slot;
    notifyListeners();
  }

  void removerFoto(int slot) {
    imagens[slot] = null;
    imagensBytes[slot] = null;
    if (fotoAtivaIdx == slot) {
      final prox = List.generate(
        3,
        (i) => i,
      ).firstWhere((i) => i != slot && imagens[i] != null, orElse: () => 0);
      fotoAtivaIdx = prox;
    }
    notifyListeners();
  }

  /// Fotos anexadas (em ordem de slot) junto do índice do slot de origem.
  List<({int slot, Uint8List bytes})> fotosAnexadas() {
    final res = <({int slot, Uint8List bytes})>[];
    for (int i = 0; i < 3; i++) {
      final b = imagensBytes[i];
      if (b != null) res.add((slot: i, bytes: b));
    }
    return res;
  }

  /// Seleciona o vídeo opcional. Retorna mensagem de erro (arquivo grande) ou
  /// `null` em caso de sucesso ou cancelamento.
  Future<String?> selecionarVideo(ImageSource source) async {
    final v = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    if (_disposed || v == null) return null;
    final bytes = await v.readAsBytes();
    if (_disposed) return null;
    if (bytes.length > maxVideoBytes) {
      return 'Vídeo muito grande (máx. 50 MB). Tente outro.';
    }
    video = v;
    videoBytes = bytes;
    notifyListeners();
    await _prepararPreviewVideo(v);
    return null;
  }

  void removerVideo() {
    videoController?.dispose();
    videoController = null;
    video = null;
    videoBytes = null;
    notifyListeners();
  }

  // Prepara um controlador só para exibir o primeiro quadro como preview no
  // formulário; a reprodução em si acontece em tela cheia (VisualizadorVideo).
  Future<void> _prepararPreviewVideo(XFile v) async {
    await videoController?.dispose();
    final controller = VideoPlayerController.file(File(v.path));
    videoController = controller;
    try {
      await controller.initialize();
      // Se o controller foi descartado ou o usuário já trocou/removeu o vídeo,
      // descartamos silenciosamente (o novo controlador cuida do resto).
      if (_disposed || videoController != controller) return;
      notifyListeners();
    } catch (e) {
      debugPrint('Preview de vídeo indisponível: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    videoController?.dispose();
    super.dispose();
  }
}
