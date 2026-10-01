// TESTE 3 — Custo de leitura do feed e das telas agregadas
//
// RESSALVA IMPORTANTE, leia antes de tirar conclusão:
//
// O app não lê o Firestore por requisição avulsa — ele abre snapshot
// listeners (`.snapshots()`), que ficam pendurados e recebem cada alteração
// dos documentos observados. O k6 fala REST, que não tem listener. Ou seja:
// este teste mede a leitura INICIAL de cada tela, mas NÃO reproduz a
// amplificação de leitura descrita na auditoria (a que faz o app estourar a
// cota gratuita com ~50 usuários por dia).
//
// O que ele mede bem: quantos documentos cada tela baixa ao abrir, e quanto
// isso demora. Que já é o suficiente para dimensionar custo por sessão.
//
//   k6 run loadtest/k6/feed.js

import { check } from 'k6';
import { Counter, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';
import exec from 'k6/execution';
import { contexto, consultar, FILTRO_VISIVEIS } from './lib/firestore.js';

const config = JSON.parse(open('../tokens.json'));
const ctx = contexto(config);
const usuarios = new SharedArray('usuarios', () => config.usuarios);

const docsLidos = new Counter('documentos_lidos');
const latenciaFeed = new Trend('feed_ms', true);
const latenciaAgregado = new Trend('tela_agregada_ms', true);

// Espelham o código: home_page usa _pageSize; mapa, estatísticas e dados
// públicos usam OcorrenciaRepository.tetoAgregado.
// Mesmo tamanho de página do app (_pageSize em home_page.dart).
const PAGINA_FEED = 10;
const TETO_AGREGADO = 500;

export const options = {
  scenarios: {
    sessoes: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { target: 10, duration: '30s' },
        { target: 40, duration: '1m' },
        { target: 40, duration: '30s' },
      ],
    },
  },
  thresholds: {
    'feed_ms': ['p(95)<2000'],
    'tela_agregada_ms': ['p(95)<5000'],
  },
};

function contarDocs(resposta) {
  if (resposta.status !== 200) return 0;
  const corpo = resposta.json();
  if (!Array.isArray(corpo)) return 0;
  // runQuery devolve um elemento por documento; o último pode vir só com
  // metadados de leitura, sem `document`.
  return corpo.filter((linha) => linha.document).length;
}

export default function () {
  const usuario = usuarios[exec.vu.idInTest % usuarios.length];

  // ── Abertura do feed ────────────────────────────────────────────────────
  let inicio = Date.now();
  const feed = consultar(ctx, usuario.idToken, {
    from: [{ collectionId: 'ocorrencias' }],
    where: FILTRO_VISIVEIS,
    orderBy: [{ field: { fieldPath: 'dataCriacao' }, direction: 'DESCENDING' }],
    limit: PAGINA_FEED,
  });
  latenciaFeed.add(Date.now() - inicio);
  docsLidos.add(contarDocs(feed));
  check(feed, { 'feed carregou': (r) => r.status === 200 });

  // ── Abertura do mapa / estatísticas / dados públicos ────────────────────
  // Três telas do app fazem exatamente esta consulta de 500 documentos.
  inicio = Date.now();
  const agregado = consultar(ctx, usuario.idToken, {
    from: [{ collectionId: 'ocorrencias' }],
    where: FILTRO_VISIVEIS,
    orderBy: [{ field: { fieldPath: 'dataCriacao' }, direction: 'DESCENDING' }],
    limit: TETO_AGREGADO,
  });
  latenciaAgregado.add(Date.now() - inicio);
  docsLidos.add(contarDocs(agregado));
  check(agregado, { 'tela agregada carregou': (r) => r.status === 200 });
}

export function handleSummary(dados) {
  const docs = dados.metrics.documentos_lidos?.values?.count ?? 0;
  const iteracoes = dados.metrics.iterations?.values?.count ?? 1;
  const porSessao = (docs / iteracoes).toFixed(0);
  // US$ 0,06 por 100 mil leituras, câmbio de referência R$ 5,50.
  const custoMilSessoes = ((porSessao * 1000 / 100000) * 0.06 * 5.5).toFixed(2);

  return {
    stdout: `
──────────────────────────────────────────────────────────────
 LEITURA POR SESSÃO
──────────────────────────────────────────────────────────────
 Documentos lidos .......... ${docs}
 Sessões simuladas ......... ${iteracoes}
 Leituras por sessão ....... ${porSessao}

 A mil sessões, isso custa cerca de R$ ${custoMilSessoes} em Firestore.

 Lembre: o app usa snapshot listeners, que continuam faturando a
 cada alteração dos documentos observados. O número acima é o
 PISO da leitura de uma sessão, não o total.
──────────────────────────────────────────────────────────────
`,
    'loadtest/resultados/feed.json': JSON.stringify(dados, null, 2),
  };
}
