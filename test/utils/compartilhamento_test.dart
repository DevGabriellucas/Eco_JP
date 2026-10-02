import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/utils/compartilhamento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OcorrenciaModel ocorrencia({String titulo = 'Lixo na calçada'}) =>
      OcorrenciaModel(
        id: 'abc123',
        titulo: titulo,
        descricao: 'Sacos rasgados desde segunda.',
        localizacao: 'Rua X, Torre, João Pessoa',
        latitude: -7.12,
        longitude: -34.86,
        tipoLixo: 'Lixo',
        imagensUrls: const ['https://res.cloudinary.com/x/foto.jpg'],
      );

  test('texto em português com acentos, local, mapa, foto e link do app', () {
    final texto = textoCompartilhamento(ocorrencia());

    expect(texto, startsWith('Denúncia no EcoJP'));
    expect(texto, contains('Lixo na calçada'));
    expect(texto, contains('Local: Rua X, Torre, João Pessoa'));
    expect(texto, contains('Sacos rasgados desde segunda.'));
    expect(texto, contains('Ver no mapa: https://www.google.com/maps/search/'));
    expect(texto, contains('Foto: https://res.cloudinary.com/x/foto.jpg'));
    expect(texto, contains('ecojp://ocorrencia/abc123'));
    // Sem as grafias antigas sem acento.
    expect(texto, isNot(contains('Denuncia ')));
    expect(texto, isNot(contains('Endereco')));
  });

  test('título vazio vira "Sem título"', () {
    expect(textoCompartilhamento(ocorrencia(titulo: '  ')),
        contains('Sem título'));
  });
}
