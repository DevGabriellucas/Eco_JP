import 'package:eco_jp/services/usuario_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsuarioService.idDoNome (slug da reserva de nome)', () {
    test('ignora acento, caixa e pontuação', () {
      expect(UsuarioService.idDoNome('José Silva'), 'jose-silva');
      expect(UsuarioService.idDoNome('JOSE-SILVA'), 'jose-silva');
      expect(UsuarioService.idDoNome('  josé   silva '), 'jose-silva');
    });

    test('caractere invisível no meio não escapa da reserva', () {
      // Com um zero-width no meio, o nome exibe igual a "João Silva" depois
      // de higienizado; o slug tem que colidir com o da outra conta.
      expect(
        UsuarioService.idDoNome('Jo${String.fromCharCode(0x200B)}ão Silva'),
        UsuarioService.idDoNome('João Silva'),
      );
      expect(
        UsuarioService.idDoNome('${String.fromCharCode(0x202E)}João Silva'),
        UsuarioService.idDoNome('João Silva'),
      );
    });

    test('nome sem letra nem dígito não tem slug', () {
      expect(UsuarioService.idDoNome('---'), isNull);
      expect(UsuarioService.idDoNome(String.fromCharCode(0x200B)), isNull);
    });
  });
}
