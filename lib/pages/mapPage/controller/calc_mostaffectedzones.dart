import 'package:eco_jp/models/ocorrencia_model.dart';

/// Calcula quais bairros concentram mais ocorrências a partir da string
/// livre de `localizacao` de cada denúncia.
class CalcMostAffectedZones {
  final List<OcorrenciaModel> listaOcorrencia;

  CalcMostAffectedZones(this.listaOcorrencia);

  /// Extrai o "bairro" de uma localização livre.
  ///
  /// Os endereços salvos seguem aproximadamente o formato
  /// "Rua, Bairro, Cidade" (3 partes), mas dependendo da fonte (Nominatim,
  /// ViaCEP, GPS ou digitação manual) podem vir com "Bairro, Cidade"
  /// (2 partes) ou apenas "Centro" (1 parte).
  ///
  /// Heurística: quando há rua + bairro + cidade (3+ partes), o bairro é a
  /// segunda parte; com 2 partes assume-se "Bairro, Cidade" e com 1 parte
  /// usa-se o que houver. Retorna `null` quando não há texto aproveitável.
  ///
  /// Partes formadas apenas por números (número da casa ou CEP, ex.: "Av X,
  /// 1200, Manaíra") são descartadas antes da heurística — senão o "bairro"
  /// acabaria sendo o número.
  static String? extrairBairro(String localizacao) {
    final partes = localizacao
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && !_apenasNumero.hasMatch(p))
        .toList();
    if (partes.isEmpty) return null;
    final indice = partes.length >= 3 ? 1 : 0;
    return partes[indice];
  }

  /// Casa partes que são só dígitos/pontuação de número (ex.: "1200",
  /// "58000-000", "nº 12").
  static final RegExp _apenasNumero = RegExp(r'^(nº|n°|n\.?)?\s*[\d.\s-]+$');

  Map<String, int> _contarPorBairro() {
    final contagem = <String, int>{};
    for (final ocorrencia in listaOcorrencia) {
      final bairro = extrairBairro(ocorrencia.localizacao);
      if (bairro == null) continue;
      contagem[bairro] = (contagem[bairro] ?? 0) + 1;
    }
    return contagem;
  }

  /// Ranking dos bairros com mais ocorrências, do maior para o menor.
  /// Empates são desfeitos por ordem alfabética (resultado estável).
  List<({String bairro, int quantidade})> zonasMaisAfetadas({int limite = 3}) {
    final contagem = _contarPorBairro();
    final ranking =
        contagem.entries
            .map((e) => (bairro: e.key, quantidade: e.value))
            .toList()
          ..sort((a, b) {
            final cmp = b.quantidade.compareTo(a.quantidade);
            return cmp != 0 ? cmp : a.bairro.compareTo(b.bairro);
          });
    return ranking.take(limite).toList();
  }

  ({String bairro, int quantidade}) bairroMaisFrequente() {
    final ranking = zonasMaisAfetadas(limite: 1);
    if (ranking.isEmpty) {
      return (bairro: 'Nenhum bairro encontrado', quantidade: 0);
    }
    return ranking.first;
  }
}
