import 'package:flutter_test/flutter_test.dart';

import 'package:eco_jp/models/ocorrencia_model.dart';

void main() {
  test('OcorrenciaModel converte dados para Map', () {
    final ocorrencia = OcorrenciaModel(
      id: 'ocorrencia-1',
      titulo: 'Lixo acumulado',
      descricao: 'Descarte irregular na rua',
      localizacao: 'Centro',
      latitude: -7.1159,
      longitude: -34.8628,
      tipoLixo: 'Entulho',
      usuarioId: 'usuario-1',
      imagemUrl: 'https://example.com/foto.jpg',
    );

    final map = ocorrencia.toMap();

    expect(map['titulo'], 'Lixo acumulado');
    expect(map['descricao'], 'Descarte irregular na rua');
    expect(map['localizacao'], 'Centro');
    expect(map['latitude'], -7.1159);
    expect(map['longitude'], -34.8628);
    expect(map['tipoLixo'], 'Entulho');
    expect(map['status'], 'Pendente');
    expect(map['usuarioId'], 'usuario-1');
    expect(map['imagemUrl'], 'https://example.com/foto.jpg');
  });
}
