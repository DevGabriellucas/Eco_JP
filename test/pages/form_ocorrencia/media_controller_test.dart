import 'dart:typed_data';

import 'package:eco_jp/pages/form_ocorrencia/controllers/media_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

// Preenche um slot de foto diretamente (sem o picker de plataforma), para
// exercitar a lógica pura de slots/seleção do MediaController.
void _preencherSlot(MediaController c, int slot) {
  c.imagens[slot] = XFile('foto_$slot.jpg');
  c.imagensBytes[slot] = Uint8List.fromList([slot]);
}

void main() {
  late MediaController controller;

  setUp(() => controller = MediaController());
  tearDown(() => controller.dispose());

  group('totalFotos e proximoSlotVazio', () {
    test('começa vazio', () {
      expect(controller.totalFotos, 0);
      expect(controller.proximoSlotVazio(), 0);
      expect(controller.fotosAnexadas(), isEmpty);
    });

    test('conta apenas slots preenchidos', () {
      _preencherSlot(controller, 0);
      _preencherSlot(controller, 2);
      expect(controller.totalFotos, 2);
      expect(controller.proximoSlotVazio(), 1); // slot do meio ainda livre
    });

    test('proximoSlotVazio devolve null quando cheio', () {
      for (var i = 0; i < 3; i++) {
        _preencherSlot(controller, i);
      }
      expect(controller.proximoSlotVazio(), isNull);
    });
  });

  group('fotosAnexadas', () {
    test('preserva ordem de slot e associa bytes ao slot de origem', () {
      _preencherSlot(controller, 2);
      _preencherSlot(controller, 0);
      final anexadas = controller.fotosAnexadas();
      expect(anexadas.map((a) => a.slot), [0, 2]);
      expect(anexadas.first.bytes, controller.imagensBytes[0]);
    });
  });

  group('removerFoto', () {
    test('limpa o slot e notifica', () {
      _preencherSlot(controller, 0);
      var notificacoes = 0;
      controller.addListener(() => notificacoes++);

      controller.removerFoto(0);

      expect(controller.imagens[0], isNull);
      expect(controller.imagensBytes[0], isNull);
      expect(controller.totalFotos, 0);
      expect(notificacoes, 1);
    });

    test('ao remover a foto ativa, salta para outra foto existente', () {
      _preencherSlot(controller, 0);
      _preencherSlot(controller, 2);
      controller.selecionarFotoAtiva(2);

      controller.removerFoto(2);

      expect(controller.fotoAtivaIdx, 0); // caiu na foto restante
    });

    test('ao remover a foto ativa sem outras, volta ao índice 0', () {
      _preencherSlot(controller, 1);
      controller.selecionarFotoAtiva(1);

      controller.removerFoto(1);

      expect(controller.fotoAtivaIdx, 0);
    });
  });

  group('selecionarFotoAtiva', () {
    test('atualiza o índice e notifica', () {
      var notificacoes = 0;
      controller.addListener(() => notificacoes++);

      controller.selecionarFotoAtiva(2);

      expect(controller.fotoAtivaIdx, 2);
      expect(notificacoes, 1);
    });
  });
}
