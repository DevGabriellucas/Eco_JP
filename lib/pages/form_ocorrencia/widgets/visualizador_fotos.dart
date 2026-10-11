import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Visualizador de fotos em tela cheia: navega entre as imagens anexadas
/// (PageView) e permite zoom (InteractiveViewer), começando na foto tocada.
class VisualizadorFotos extends StatefulWidget {
  final List<Uint8List> fotos;
  final int indiceInicial;

  const VisualizadorFotos({
    super.key,
    required this.fotos,
    required this.indiceInicial,
  });

  @override
  State<VisualizadorFotos> createState() => _VisualizadorFotosState();
}

class _VisualizadorFotosState extends State<VisualizadorFotos> {
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
