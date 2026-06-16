import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/pages/mapPage/controller/calc_mostaffectedzones.dart';
import 'package:flutter_test/flutter_test.dart';

OcorrenciaModel _ocorrencia(String localizacao) => OcorrenciaModel(
  id: 'x',
  titulo: 't',
  descricao: 'd',
  localizacao: localizacao,
  latitude: -7.1,
  longitude: -34.84,
  tipoLixo: 'Lixo',
);

void main() {
  group('CalcMostAffectedZones.extrairBairro', () {
    test('endereço "Rua, Bairro, Cidade" usa a segunda parte', () {
      expect(
        CalcMostAffectedZones.extrairBairro('Rua A, Manaíra, João Pessoa'),
        'Manaíra',
      );
    });

    test('endereço "Bairro, Cidade" usa a primeira parte', () {
      expect(
        CalcMostAffectedZones.extrairBairro('Bessa, João Pessoa'),
        'Bessa',
      );
    });

    test('localização com uma única parte é aproveitada', () {
      expect(CalcMostAffectedZones.extrairBairro('Centro'), 'Centro');
    });

    test('partes vazias e espaços são ignorados', () {
      expect(CalcMostAffectedZones.extrairBairro('  , Tambaú ,  '), 'Tambaú');
    });

    test('número da casa entre rua e bairro é ignorado', () {
      // Regressão: "Av X, 1200, Manaíra, JP" pegava "1200" como bairro.
      expect(
        CalcMostAffectedZones.extrairBairro(
          'Av Epitácio Pessoa, 1200, Manaíra, João Pessoa',
        ),
        'Manaíra',
      );
    });

    test('CEP entre as partes é ignorado', () {
      expect(
        CalcMostAffectedZones.extrairBairro(
          'Rua A, 58000-000, Bessa, João Pessoa',
        ),
        'Bessa',
      );
    });

    test('string vazia retorna null', () {
      expect(CalcMostAffectedZones.extrairBairro('   '), isNull);
    });
  });

  group('CalcMostAffectedZones.zonasMaisAfetadas', () {
    test('conta denúncias de 2 e 3 partes no mesmo bairro', () {
      // Regressão: antes, endereços com menos de 3 partes eram descartados.
      final calc = CalcMostAffectedZones([
        _ocorrencia('Rua A, Manaíra, João Pessoa'),
        _ocorrencia('Manaíra, João Pessoa'),
        _ocorrencia('Rua B, Bessa, João Pessoa'),
      ]);

      final ranking = calc.zonasMaisAfetadas();

      expect(ranking.first.bairro, 'Manaíra');
      expect(ranking.first.quantidade, 2);
    });

    test('respeita o limite e ordena do maior para o menor', () {
      final calc = CalcMostAffectedZones([
        _ocorrencia('Rua, Bessa, JP'),
        _ocorrencia('Rua, Bessa, JP'),
        _ocorrencia('Rua, Bessa, JP'),
        _ocorrencia('Rua, Manaíra, JP'),
        _ocorrencia('Rua, Manaíra, JP'),
        _ocorrencia('Rua, Tambaú, JP'),
        _ocorrencia('Rua, Cabo Branco, JP'),
      ]);

      final ranking = calc.zonasMaisAfetadas(limite: 3);

      expect(ranking.length, 3);
      expect(ranking[0], (bairro: 'Bessa', quantidade: 3));
      expect(ranking[1], (bairro: 'Manaíra', quantidade: 2));
    });

    test('lista vazia produz ranking vazio', () {
      expect(CalcMostAffectedZones([]).zonasMaisAfetadas(), isEmpty);
    });
  });

  group('CalcMostAffectedZones.bairroMaisFrequente', () {
    test('sem dados retorna rótulo padrão', () {
      final resultado = CalcMostAffectedZones([]).bairroMaisFrequente();
      expect(resultado.bairro, 'Nenhum bairro encontrado');
      expect(resultado.quantidade, 0);
    });
  });
}
