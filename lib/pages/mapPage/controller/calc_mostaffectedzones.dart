import 'package:eco_jp/models/ocorrencia_model.dart';
import 'package:eco_jp/utils/texto.dart';

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
    final bairro = partes[indice];
    // Formato do Google Places ("Rua, João Pessoa - PB, Brasil") e o texto de
    // falha do geocode antigo caíam aqui como se fossem bairro.
    return _naoEhBairro(bairro) ? null : bairro;
  }

  /// Pedaços de endereço que nunca são bairro: a própria cidade (no formato
  /// do Google Places o "bairro" virava "João Pessoa - PB"), a UF, o país e
  /// o texto de falha do geocode reverso antigo.
  static bool _naoEhBairro(String parte) {
    final n = _normalizar(parte);
    return n.startsWith('joao pessoa') ||
        n == 'pb' ||
        n == 'paraiba' ||
        n == 'brasil' ||
        n == 'endereco nao encontrado';
  }

  /// Chave de agrupamento: sem acento, minúsculas e espaços simples —
  /// "Manaíra", "manaira" e "MANAÍRA " contam juntos.
  static String _normalizar(String s) =>
      removerAcentos(s).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Bairro da denúncia: o campo estruturado gravado na criação ou, em
  /// denúncias antigas, a heurística sobre o texto do endereço.
  static String? bairroDe(OcorrenciaModel o) {
    final estruturado = o.bairro?.trim();
    if (estruturado != null &&
        estruturado.isNotEmpty &&
        !_naoEhBairro(estruturado)) {
      return estruturado;
    }
    return extrairBairro(o.localizacao);
  }

  /// Casa partes que são só dígitos/pontuação de número (ex.: "1200",
  /// "58000-000", "nº 12").
  static final RegExp _apenasNumero = RegExp(r'^(nº|n°|n\.?)?\s*[\d.\s-]+$');

  Map<String, int> _contarPorBairro() {
    final contagem = <String, int>{};
    // Primeira grafia vista de cada bairro, para exibir com acento e caixa.
    final exibicao = <String, String>{};
    for (final ocorrencia in listaOcorrencia) {
      final bairro = bairroDe(ocorrencia);
      if (bairro == null) continue;
      final chave = _normalizar(bairro);
      exibicao.putIfAbsent(chave, () => bairro);
      contagem[chave] = (contagem[chave] ?? 0) + 1;
    }
    return {
      for (final e in contagem.entries) exibicao[e.key]!: e.value,
    };
  }

  /// Ranking dos bairros com mais ocorrências, do maior para o menor.
  /// Empates são desfeitos por ordem alfabética (resultado estável).
  List<({String bairro, int quantidade})> zonasMaisAfetadas({int limite = 3}) {
    final contagem = _contarPorBairro();
    final ranking = contagem.entries
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
