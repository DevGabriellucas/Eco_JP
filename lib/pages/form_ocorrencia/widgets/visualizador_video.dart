import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../theme/app_theme.dart';

/// Reprodução de vídeo em tela cheia: inicializa, faz loop e alterna
/// play/pause ao toque; mostra estado de erro se o vídeo não puder abrir.
class VisualizadorVideo extends StatefulWidget {
  final String path;
  final String titulo;

  const VisualizadorVideo({
    super.key,
    required this.path,
    required this.titulo,
  });

  @override
  State<VisualizadorVideo> createState() => _VisualizadorVideoState();
}

class _VisualizadorVideoState extends State<VisualizadorVideo> {
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
