// TESTE 2 — Vazão de criação de denúncias e limite anti-spam
//
// Duas medições numa tacada:
//
//  1. Vazão e latência de criação, que exercita as 694 linhas de Rules
//     (isValidOcorrencia valida quinze campos por escrita). Diferente das
//     curtidas, cada denúncia é um documento novo — não há contenção, então
//     aqui esperamos que escale bem. O que interessa é a LATÊNCIA da
//     validação sob carga.
//
//  2. Prova empírica de que o limite anti-spam é só do cliente. O app impõe
//     30 segundos entre denúncias do mesmo usuário (RateLimiter em memória,
//     lib/services/rate_limiter.dart:14). Este cenário manda várias por
//     segundo com o mesmo usuário. Se passarem, o limite não existe no
//     servidor — que é o achado P1 da auditoria.
//
//   k6 run loadtest/k6/denuncias.js

import { check } from 'k6';
import { Counter, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';
import exec from 'k6/execution';
import { contexto, criarDocumento, novoId } from './lib/firestore.js';

const config = JSON.parse(open('../tokens.json'));
const ctx = contexto(config);
const usuarios = new SharedArray('usuarios', () => config.usuarios);

const criadas = new Counter('denuncias_criadas');
const rejeitadas = new Counter('denuncias_rejeitadas');
const spamAceito = new Counter('spam_aceito_pelo_servidor');
const latenciaRules = new Trend('validacao_rules_ms', true);

const CATEGORIAS = ['Lixo', 'Queimada', 'Buraco', 'Esgoto', 'Enchentes'];
const BAIRROS = [
  ['Tambaú', -7.1195, -34.8286],
  ['Manaíra', -7.1052, -34.8348],
  ['Bancários', -7.1408, -34.8461],
  ['Cristo Redentor', -7.1638, -34.8482],
  ['Mangabeira', -7.1725, -34.8329],
];

export const options = {
  scenarios: {
    // Vazão normal: usuários distintos criando denúncias.
    vazao: {
      executor: 'ramping-arrival-rate',
      startRate: 2,
      timeUnit: '1s',
      preAllocatedVUs: 40,
      maxVUs: 80,
      stages: [
        { target: 5, duration: '30s' },
        { target: 20, duration: '1m' },
        { target: 50, duration: '1m' },
      ],
      exec: 'criarDenuncia',
    },
    // Rajada de um único usuário — o que o RateLimiter deveria bloquear.
    rajadaDeSpam: {
      executor: 'constant-arrival-rate',
      rate: 5,
      timeUnit: '1s',
      duration: '30s',
      preAllocatedVUs: 10,
      startTime: '2m30s', // roda depois do cenário de vazão
      exec: 'spam',
    },
  },
  thresholds: {
    'validacao_rules_ms': ['p(95)<1500'],
    // Se este contador subir, o servidor aceitou spam que o app diz bloquear.
    'spam_aceito_pelo_servidor': [{ threshold: 'count<1', abortOnFail: false }],
  },
};

function payload(indice) {
  const [bairro, lat, lon] = BAIRROS[indice % BAIRROS.length];
  const categoria = CATEGORIAS[indice % CATEGORIAS.length];
  const foto = 'https://res.cloudinary.com/dmdghbgac/image/upload/v1/carga.jpg';
  return {
    titulo: `${categoria} acumulado em ${bairro}`,
    descricao:
      `Registro sintético gerado pelo teste de carga do EcoJP em ${bairro}. `
      + 'Não corresponde a uma ocorrência real e pode ser apagado.',
    localizacao: `${bairro}, João Pessoa - PB`,
    // Espalha os pontos para não empilhar marcadores no mesmo lugar do mapa.
    latitude: lat + (Math.random() - 0.5) * 0.01,
    longitude: lon + (Math.random() - 0.5) * 0.01,
    tipoLixo: categoria,
    status: 'Pendente',
    usuarioId: null, // preenchido por quem chama
    usuarioNome: null,
    usuarioFotoUrl: null,
    imagemUrl: foto,
    imagensUrls: [foto],
    anonima: false,
    likes: 0,
    dislikes: 0,
    comments: 0,
    shares: 0,
    likedBy: [],
    dislikedBy: [],
    fixada: false,
  };
}

function enviar(usuario, indice) {
  const dados = payload(indice);
  dados.usuarioId = usuario.uid;
  dados.usuarioNome = `Carga ${indice % usuarios.length}`;

  const inicio = Date.now();
  const resposta = criarDocumento(
    ctx, usuario.idToken, 'ocorrencias', novoId(), dados,
  );
  latenciaRules.add(Date.now() - inicio);

  if (resposta.status === 200) criadas.add(1);
  else rejeitadas.add(1);

  return resposta;
}

export function criarDenuncia() {
  const indice = exec.scenario.iterationInTest;
  const usuario = usuarios[indice % usuarios.length];
  const resposta = enviar(usuario, indice);

  check(resposta, {
    'denuncia criada': (r) => r.status === 200,
    'nao rejeitada pelas Rules': (r) => r.status !== 403,
  });
}

export function spam() {
  // Sempre o MESMO usuário, muito mais rápido que o intervalo de 30s do app.
  const usuario = usuarios[0];
  const resposta = enviar(usuario, exec.scenario.iterationInTest);

  if (resposta.status === 200) spamAceito.add(1);

  check(resposta, {
    'servidor barrou a rajada': (r) => r.status !== 200,
  });
}

export function handleSummary(dados) {
  const ok = dados.metrics.denuncias_criadas?.values?.count ?? 0;
  const nao = dados.metrics.denuncias_rejeitadas?.values?.count ?? 0;
  const spam = dados.metrics.spam_aceito_pelo_servidor?.values?.count ?? 0;
  const p95 = dados.metrics.validacao_rules_ms?.values?.['p(95)'];

  return {
    stdout: `
──────────────────────────────────────────────────────────────
 CRIAÇÃO DE DENÚNCIAS
──────────────────────────────────────────────────────────────
 Criadas ................... ${ok}
 Rejeitadas ................ ${nao}
 Latência p95 (Rules) ...... ${p95 ? p95.toFixed(0) + ' ms' : 'n/d'}

 ANTI-SPAM
 Rajadas aceitas ........... ${spam}
 ${spam > 0
   ? 'O servidor aceitou ' + spam + ' denuncias em rajada do mesmo usuario.\n'
     + ' O limite de 30s existe apenas no cliente (rate_limiter.dart:14) e\n'
     + ' e burlado por reinstalacao do app ou por requisicao direta.'
   : 'Nenhuma rajada passou — ha limite no servidor.'}
──────────────────────────────────────────────────────────────
`,
    'loadtest/resultados/denuncias.json': JSON.stringify(dados, null, 2),
  };
}
