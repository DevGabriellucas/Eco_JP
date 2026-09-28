// TESTE 1 — Contenção de escrita em curtidas
//
// Mede o achado principal da auditoria: curtidas são gravadas como arrays
// dentro do próprio documento da denúncia (OcorrenciaRepository._toggleReacao),
// então todas as curtidas de uma mesma denúncia disputam UM documento. O
// Firestore sustenta ~1 escrita por segundo por documento; acima disso as
// transações começam a abortar.
//
// Este é o cenário "denúncia viralizada pelo Esgoteio".
//
//   k6 run loadtest/k6/curtidas.js
//
// Leitura do resultado: acompanhe `curtidas_conflito`. Enquanto a taxa de
// chegada está baixa ela fica perto de zero; a partir de ~1 curtida/segundo
// ela sobe e não volta. O ponto em que sobe é o teto da arquitetura atual.

import { check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';
import exec from 'k6/execution';
import {
  contexto,
  iniciarTransacao,
  lerNaTransacao,
  commitTransacao,
  campos,
} from './lib/firestore.js';

const config = JSON.parse(open('../tokens.json'));
const ctx = contexto(config);

const usuarios = new SharedArray('usuarios', () => config.usuarios);

const curtidasOk = new Counter('curtidas_ok');
const curtidasConflito = new Counter('curtidas_conflito');
const taxaConflito = new Rate('curtidas_conflito_taxa');
const latencia = new Trend('curtida_duracao_ms', true);

export const options = {
  scenarios: {
    // Sobe a taxa de curtidas por segundo de forma controlada. É a taxa de
    // CHEGADA que importa aqui, não o número de usuários simultâneos: o que
    // satura o documento é escrita por segundo.
    viralizacao: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 100,
      stages: [
        { target: 1, duration: '30s' },   // linha de base: 1 curtida/s
        { target: 5, duration: '1m' },    // engajamento normal
        { target: 15, duration: '1m' },   // publicação em destaque
        { target: 40, duration: '1m' },   // divulgação em massa
        { target: 40, duration: '30s' },  // sustenta o pico
      ],
    },
  },
  thresholds: {
    // Este limite FALHA de propósito na arquitetura atual — é a evidência.
    // Depois de mover as reações para subcoleção + increment, ele passa.
    curtidas_conflito_taxa: [{ threshold: 'rate<0.01', abortOnFail: false }],
  },
};

export default function () {
  // Cada iteração usa um usuário diferente: a regra isValidReactionUpdate()
  // só aceita que o usuário adicione ou remova o PRÓPRIO uid.
  const usuario = usuarios[exec.scenario.iterationInTest % usuarios.length];
  const caminho = ctx.caminhoDoc('ocorrencias', config.alvoId);
  const inicio = Date.now();

  const transacao = iniciarTransacao(ctx, usuario.idToken);
  if (!transacao) {
    curtidasConflito.add(1);
    taxaConflito.add(true);
    return;
  }

  const atual = lerNaTransacao(ctx, usuario.idToken, caminho, transacao);
  if (!atual) {
    curtidasConflito.add(1);
    taxaConflito.add(true);
    return;
  }

  // Mesma lógica de _toggleReacao: quem já curtiu, descurte. Isso deixa o
  // pool de usuários ciclar indefinidamente em vez de esgotar na primeira
  // curtida de cada um.
  const curtidoPor = atual.likedBy ?? [];
  const jaCurtiu = curtidoPor.indexOf(usuario.uid) !== -1;
  const novaLista = jaCurtiu
    ? curtidoPor.filter((uid) => uid !== usuario.uid)
    : curtidoPor.concat([usuario.uid]);

  const resposta = commitTransacao(ctx, usuario.idToken, transacao, [
    {
      update: {
        name: caminho,
        fields: campos({ likedBy: novaLista, likes: novaLista.length }),
      },
      updateMask: { fieldPaths: ['likedBy', 'likes'] },
    },
  ]);

  latencia.add(Date.now() - inicio);

  const conflito = resposta.status === 409 || resposta.status === 429
    || (resposta.status >= 500 && resposta.status < 600);

  if (resposta.status === 200) {
    curtidasOk.add(1);
    taxaConflito.add(false);
  } else {
    curtidasConflito.add(1);
    taxaConflito.add(true);
  }

  check(resposta, {
    'curtida aceita': (r) => r.status === 200,
    'nao foi rejeitada pelas Rules': (r) => r.status !== 403,
  }, { conflito: String(conflito) });
}

export function handleSummary(dados) {
  const ok = dados.metrics.curtidas_ok?.values?.count ?? 0;
  const falha = dados.metrics.curtidas_conflito?.values?.count ?? 0;
  const total = ok + falha;
  const pct = total ? ((falha / total) * 100).toFixed(1) : '0.0';

  return {
    stdout: `
──────────────────────────────────────────────────────────────
 CONTENÇÃO DE CURTIDAS — denúncia ${config.alvoId}
──────────────────────────────────────────────────────────────
 Curtidas aceitas .......... ${ok}
 Curtidas em conflito ...... ${falha}  (${pct}%)
 Total de tentativas ....... ${total}

 Conflito acima de poucos por cento significa que o documento
 saturou: as transações estão disputando a mesma denúncia.
 Correção: mover reações para ocorrencias/{id}/reacoes/{uid}
 e manter o total com FieldValue.increment.
──────────────────────────────────────────────────────────────
`,
    'loadtest/resultados/curtidas.json': JSON.stringify(dados, null, 2),
  };
}
