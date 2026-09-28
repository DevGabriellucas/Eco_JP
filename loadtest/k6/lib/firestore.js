// Helpers da API REST do Firestore para os cenários do k6.
//
// O app usa o SDK do Firebase (gRPC). O k6 fala HTTP, então aqui usamos a API
// REST equivalente. Para escrita o comportamento é o mesmo — mesmas Rules,
// mesma contenção por documento. Para LEITURA há uma diferença importante
// registrada no README: REST não tem snapshot listener.

import http from 'k6/http';

// ── Codificação de valores ────────────────────────────────────────────────
// O Firestore REST exige valores tipados: {stringValue}, {integerValue}, etc.
// Inteiro vai como string no JSON — é assim que a API espera.

export function valor(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v)
      ? { integerValue: String(v) }
      : { doubleValue: v };
  }
  if (Array.isArray(v)) {
    return { arrayValue: { values: v.map(valor) } };
  }
  return { stringValue: String(v) };
}

export function campos(objeto) {
  const saida = {};
  for (const [chave, v] of Object.entries(objeto)) saida[chave] = valor(v);
  return saida;
}

export function leValor(v) {
  if (!v) return null;
  if ('nullValue' in v) return null;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(leValor);
  return v.stringValue;
}

export function leCampos(fields) {
  const saida = {};
  for (const [chave, v] of Object.entries(fields ?? {})) saida[chave] = leValor(v);
  return saida;
}

// ── Contexto ──────────────────────────────────────────────────────────────

export function contexto(config) {
  // Os métodos de banco (:commit, :beginTransaction, :batchGet) e o de
  // consulta (:runQuery) pendem todos do mesmo caminho .../documents, então
  // base e raiz coincidem. Ficam separados só para o código dizer qual é qual.
  const base = config.baseFirestore;
  return {
    base,
    raiz: base,
    projeto: config.projeto,
    caminhoDoc: (colecao, id) =>
      `projects/${config.projeto}/databases/(default)/documents/${colecao}/${id}`,
  };
}

export function cabecalhos(idToken) {
  return {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${idToken}`,
    },
  };
}

// ── Transação (o que o app faz ao curtir) ─────────────────────────────────
// beginTransaction → batchGet → commit. É este ciclo que entra em conflito
// quando duas pessoas curtem a mesma denúncia ao mesmo tempo.

export function iniciarTransacao(ctx, idToken) {
  const resposta = http.post(
    `${ctx.raiz}:beginTransaction`,
    '{}',
    { ...cabecalhos(idToken), tags: { fase: 'beginTransaction' } },
  );
  if (resposta.status !== 200) return null;
  return resposta.json('transaction');
}

export function lerNaTransacao(ctx, idToken, caminho, transacao) {
  const resposta = http.post(
    `${ctx.raiz}:batchGet`,
    JSON.stringify({ documents: [caminho], transaction: transacao }),
    { ...cabecalhos(idToken), tags: { fase: 'batchGet' } },
  );
  if (resposta.status !== 200) return null;
  // batchGet devolve um array de resultados, um por documento pedido.
  const corpo = resposta.json();
  const primeiro = Array.isArray(corpo) ? corpo[0] : corpo;
  if (!primeiro || !primeiro.found) return null;
  return leCampos(primeiro.found.fields);
}

export function commitTransacao(ctx, idToken, transacao, writes) {
  return http.post(
    `${ctx.raiz}:commit`,
    JSON.stringify({ transaction: transacao, writes }),
    { ...cabecalhos(idToken), tags: { fase: 'commit' } },
  );
}

// ── Escrita direta ────────────────────────────────────────────────────────

// Cria documento com carimbo de tempo do servidor. As Rules exigem
// `dataCriacao == request.time`, então o valor NÃO pode vir do cliente —
// tem que ser o transform REQUEST_TIME, que o Firestore resolve no commit.
export function criarDocumento(ctx, idToken, colecao, id, dados) {
  const write = {
    update: {
      name: ctx.caminhoDoc(colecao, id),
      fields: campos(dados),
    },
    updateTransforms: [
      { fieldPath: 'dataCriacao', setToServerValue: 'REQUEST_TIME' },
    ],
    currentDocument: { exists: false },
  };
  return http.post(
    `${ctx.raiz}:commit`,
    JSON.stringify({ writes: [write] }),
    { ...cabecalhos(idToken), tags: { fase: 'criar' } },
  );
}

export function consultar(ctx, idToken, query) {
  return http.post(
    `${ctx.base}:runQuery`,
    JSON.stringify({ structuredQuery: query }),
    { ...cabecalhos(idToken), tags: { fase: 'runQuery' } },
  );
}

// Id no formato do Firestore (20 caracteres alfanuméricos).
const ALFABETO = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
export function novoId() {
  let id = '';
  for (let i = 0; i < 20; i++) {
    id += ALFABETO[Math.floor(Math.random() * ALFABETO.length)];
  }
  return id;
}
