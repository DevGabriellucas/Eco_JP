// TESTE 4 — Pico de usuários simultâneos
//
// Diferente dos outros três, aqui cada usuário virtual imita uma PESSOA: ele
// abre uma tela, para para ler, decide o que fazer, para de novo. É o `sleep`
// que faz a diferença — sem ele, um VU do k6 vale por centenas de pessoas,
// porque dispara ações sem pausa nenhuma.
//
// Com tempo de leitura, 450 VUs são 450 pessoas com o app aberto ao mesmo
// tempo. É esse o número que responde "quantos usuários simultâneos aguenta".
//
// Referência: 15.000 usuários por dia (cenário estadual do dossiê) produzem
// um pico simultâneo de 150 a 450 pessoas, usando a faixa usual de 1% a 3%
// da base diária. O teste vai até 450 e além, para achar a margem.
//
//   k6 run loadtest/k6/pico.js

import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';
import exec from 'k6/execution';
import { contexto, consultar, curtirComRetentativa, FILTRO_VISIVEIS } from './lib/firestore.js';

const config = JSON.parse(open('../tokens.json'));
const ctx = contexto(config);
const usuarios = new SharedArray('usuarios', () => config.usuarios);

const sessoes = new Counter('sessoes_completas');
const erros = new Rate('erros');
const docs = new Counter('documentos_lidos');
// Curtidas que esgotaram as tentativas por disputa do documento. Ficam fora
// de `erros`, que mede indisponibilidade.
const conflitos = new Counter('curtidas_em_disputa');
const tFeed = new Trend('abrir_feed_ms', true);
const tMapa = new Trend('abrir_mapa_ms', true);

// Mesmo tamanho de página do app (_pageSize em home_page.dart).
const PAGINA_FEED = 10;
const TETO_AGREGADO = 500;

export const options = {
  scenarios: {
    pico: {
      executor: 'ramping-vus',
      startVUs: 25,
      stages: [
        { target: 50, duration: '30s' },   // manhã tranquila
        { target: 150, duration: '45s' },  // pico de 15 mil/dia, estimativa baixa
        { target: 300, duration: '45s' },  // pico de 15 mil/dia, estimativa alta
        { target: 450, duration: '45s' },  // 3% da base — pico pessimista
        { target: 450, duration: '60s' },  // sustenta, é aqui que se mede
        { target: 0, duration: '15s' },
      ],
      gracefulRampDown: '15s',
    },
  },
  thresholds: {
    erros: ['rate<0.01'],
    abrir_feed_ms: ['p(95)<3000'],
    abrir_mapa_ms: ['p(95)<8000'],
  },
};

function contarDocs(resposta) {
  if (resposta.status !== 200) return 0;
  const corpo = resposta.json();
  return Array.isArray(corpo) ? corpo.filter((l) => l.document).length : 0;
}

export default function () {
  const usuario = usuarios[exec.vu.idInTest % usuarios.length];

  // ── Abre o app: feed ────────────────────────────────────────────────────
  let t0 = Date.now();
  const feed = consultar(ctx, usuario.idToken, {
    from: [{ collectionId: 'ocorrencias' }],
    where: FILTRO_VISIVEIS,
    orderBy: [{ field: { fieldPath: 'dataCriacao' }, direction: 'DESCENDING' }],
    limit: PAGINA_FEED,
  });
  tFeed.add(Date.now() - t0);
  docs.add(contarDocs(feed));
  erros.add(feed.status !== 200);
  check(feed, { 'feed abriu': (r) => r.status === 200 });

  sleep(3 + Math.random() * 4); // lê o feed

  // ── 60% abrem o mapa ────────────────────────────────────────────────────
  if (Math.random() < 0.6) {
    t0 = Date.now();
    const mapa = consultar(ctx, usuario.idToken, {
      from: [{ collectionId: 'ocorrencias' }],
      where: FILTRO_VISIVEIS,
      orderBy: [{ field: { fieldPath: 'dataCriacao' }, direction: 'DESCENDING' }],
      limit: TETO_AGREGADO,
    });
    tMapa.add(Date.now() - t0);
    docs.add(contarDocs(mapa));
    erros.add(mapa.status !== 200);
    check(mapa, { 'mapa abriu': (r) => r.status === 200 });

    sleep(4 + Math.random() * 5); // examina o mapa
  }

  // ── 30% curtem alguma coisa ─────────────────────────────────────────────
  if (Math.random() < 0.3) {
    const caminho = ctx.caminhoDoc('ocorrencias', config.alvoId);
    const resultado = curtirComRetentativa(ctx, usuario, caminho);
    // Disputa pelo documento não é indisponibilidade: conta à parte.
    if (resultado === 'conflito') conflitos.add(1);
    else erros.add(resultado !== 'ok');
    sleep(2 + Math.random() * 3);
  }

  sessoes.add(1);
}

export function handleSummary(dados) {
  const m = dados.metrics;
  const s = m.sessoes_completas?.values?.count ?? 0;
  // vus (medido), não vus_max (o teto configurado no cenário).
  const vus = m.vus?.values?.max ?? 0;
  const nConflitos = m.curtidas_em_disputa?.values?.count ?? 0;
  const taxaErro = (m.erros?.values?.rate ?? 0) * 100;
  const feedP95 = m.abrir_feed_ms?.values?.['p(95)'];
  const mapaP95 = m.abrir_mapa_ms?.values?.['p(95)'];
  const lidos = m.documentos_lidos?.values?.count ?? 0;

  return {
    stdout: `
──────────────────────────────────────────────────────────────
 PICO DE USUÁRIOS SIMULTÂNEOS
──────────────────────────────────────────────────────────────
 Pessoas simultâneas (pico) . ${vus}
 Sessões completas .......... ${s}
 Documentos lidos ........... ${lidos.toLocaleString('pt-BR')}
 Taxa de erro ............... ${taxaErro.toFixed(2)}%
 Curtidas em disputa ........ ${nConflitos}

 Abrir o feed ............... p95 ${feedP95 ? feedP95.toFixed(0) + ' ms' : 'n/d'}
 Abrir o mapa ............... p95 ${mapaP95 ? mapaP95.toFixed(0) + ' ms' : 'n/d'}

 Cada usuário virtual tem tempo de leitura entre as ações, então
 o número acima são pessoas de verdade, não requisições por
 segundo disfarçadas.
──────────────────────────────────────────────────────────────
`,
    'loadtest/resultados/pico.json': JSON.stringify(dados, null, 2),
  };
}
