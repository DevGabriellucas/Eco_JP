import 'package:eco_jp/models/ocorrencia_model.dart';

class CalcMostAffectedZones {
  final List<OcorrenciaModel> listaOcorrencia;

  CalcMostAffectedZones(this.listaOcorrencia);

  List<List<String>> _separarLocalizacaoEmLista() {
    return listaOcorrencia
        .map((ocorrencia) => ocorrencia.localizacao.split(', '))
        .toList();
  }

  List<String> _pegarListaDeBairros() {
    final listaLocalizacao = _separarLocalizacaoEmLista();
    final listaBairros = <String>[];

    for (final loc in listaLocalizacao) {
      if (loc.length >= 3) {
        listaBairros.add(loc[1].trim());
      }
    }

    return listaBairros;
  }

  ({String bairro, int quantidade}) bairroMaisFrequente() {
    final listaBairros = _pegarListaDeBairros();

    if (listaBairros.isEmpty) {
      return (bairro: 'Nenhum bairro encontrado', quantidade: 0);
    }

    final contagem = <String, int>{};

    for (final bairro in listaBairros) {
      contagem[bairro] = (contagem[bairro] ?? 0) + 1;
    }

    final resultado = contagem.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    return (bairro: resultado.key, quantidade: resultado.value);
  }
}
