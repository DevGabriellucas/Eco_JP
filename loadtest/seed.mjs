// Semeia o ambiente de teste de carga: cria usuários com e-mail verificado,
// pega um idToken para cada um e cria a denúncia-alvo do teste de contenção.
//
// Roda contra os EMULADORES. Recusa rodar contra o Firebase real a menos que
// LOADTEST_ALLOW_REAL=1 esteja definido — teste de carga em produção gera
// custo real e polui as denúncias da demonstração.
//
//   npm run loadtest:seed
//
// Saída: loadtest/tokens.json (ignorado pelo git).

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';

const AQUI = dirname(fileURLToPath(import.meta.url));

const PROJETO = process.env.LOADTEST_PROJECT_ID ?? 'ecojp-loadtest';
const QTD_USUARIOS = Number(process.env.LOADTEST_USERS ?? 50);
const SENHA = 'LoadTest!2026';

const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const fsHost = process.env.FIRESTORE_EMULATOR_HOST;

if ((!authHost || !fsHost) && process.env.LOADTEST_ALLOW_REAL !== '1') {
  console.error(`
  Emuladores não detectados.

  Este script recusa rodar contra o Firebase real por padrão: um teste de
  carga em produção é faturado por leitura/escrita e mistura dados falsos
  com denúncias reais.

  Suba os emuladores primeiro:

      npm run emulator

  e rode o seed em outro terminal:

      npm run loadtest:seed

  Para apontar mesmo assim para um projeto Firebase de verdade (use um
  projeto de teste separado, nunca ecojp-8b952), defina LOADTEST_ALLOW_REAL=1.
`);
  process.exit(1);
}

admin.initializeApp({ projectId: PROJETO });
const auth = admin.auth();
const db = admin.firestore();

// O emulador de Auth aceita qualquer apiKey; o Firebase real exige a chave web.
const apiKey = process.env.LOADTEST_API_KEY ?? 'emulador-nao-valida-a-chave';
const identityBase = authHost
  ? `http://${authHost}/identitytoolkit.googleapis.com/v1`
  : 'https://identitytoolkit.googleapis.com/v1';

async function criarUsuario(indice) {
  const email = `carga${indice}@ecojp.test`;
  let registro;
  try {
    registro = await auth.createUser({
      email,
      password: SENHA,
      displayName: `Carga ${indice}`,
      emailVerified: true, // as Rules exigem emailVerificado() para postar
    });
  } catch (erro) {
    if (erro.code !== 'auth/email-already-exists') throw erro;
    registro = await auth.getUserByEmail(email);
    await auth.updateUser(registro.uid, { password: SENHA, emailVerified: true });
  }

  const resposta = await fetch(
    `${identityBase}/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: SENHA, returnSecureToken: true }),
    },
  );
  if (!resposta.ok) {
    throw new Error(`login falhou para ${email}: ${await resposta.text()}`);
  }
  const { idToken } = await resposta.json();
  // Perfil com o nome que os scripts enviam ("Carga N"): as Rules exigem que
  // o nome público da denúncia seja o `nome` do perfil.
  await db.collection('usuarios').doc(registro.uid)
    .set({ nome: `Carga ${indice}`, bio: '', bairro: '' });
  return { uid: registro.uid, email, idToken };
}

// Denúncia-alvo do teste de contenção: todas as curtidas do k6 caem neste
// documento, que é exatamente o cenário "denúncia viralizada".
async function criarAlvo(donoUid) {
  const ref = db.collection('ocorrencias').doc('alvo-teste-de-carga');
  await ref.set({
    titulo: 'Descarte irregular na Avenida Epitácio Pessoa',
    descricao:
      'Denúncia sintética criada pelo teste de carga. Serve de alvo único '
      + 'para medir contenção de escrita em curtidas. Pode ser apagada.',
    localizacao: 'Avenida Epitácio Pessoa, Tambaú, João Pessoa',
    latitude: -7.1195,
    longitude: -34.8286,
    tipoLixo: 'Lixo',
    status: 'Pendente',
    dataCriacao: admin.firestore.FieldValue.serverTimestamp(),
    usuarioId: donoUid,
    usuarioNome: 'Carga 0',
    usuarioFotoUrl: null,
    imagemUrl: 'https://res.cloudinary.com/dmdghbgac/image/upload/v1/carga.jpg',
    imagensUrls: ['https://res.cloudinary.com/dmdghbgac/image/upload/v1/carga.jpg'],
    anonima: false,
    likes: 0,
    dislikes: 0,
    comments: 0,
    shares: 0,
    likedBy: [],
    dislikedBy: [],
    fixada: false,
    oculto: false,
  });
  return ref.id;
}

console.log(`Semeando ${QTD_USUARIOS} usuários no projeto "${PROJETO}"...`);
const usuarios = [];
for (let i = 0; i < QTD_USUARIOS; i++) {
  usuarios.push(await criarUsuario(i));
  if ((i + 1) % 10 === 0) console.log(`  ${i + 1}/${QTD_USUARIOS}`);
}

const alvoId = await criarAlvo(usuarios[0].uid);
console.log(`Denúncia-alvo criada: ocorrencias/${alvoId}`);

const destino = join(AQUI, 'tokens.json');
mkdirSync(dirname(destino), { recursive: true });
writeFileSync(
  destino,
  JSON.stringify(
    {
      projeto: PROJETO,
      emulador: Boolean(fsHost),
      baseFirestore: fsHost
        ? `http://${fsHost}/v1/projects/${PROJETO}/databases/(default)/documents`
        : `https://firestore.googleapis.com/v1/projects/${PROJETO}/databases/(default)/documents`,
      alvoId,
      geradoEm: new Date().toISOString(),
      usuarios,
    },
    null,
    2,
  ),
);

console.log(`
Pronto. ${usuarios.length} tokens em loadtest/tokens.json

  ATENÇÃO: idToken do Firebase expira em 1 hora. Rode o seed de novo antes
  de cada bateria de testes longa.

Próximo passo:
  k6 run loadtest/k6/curtidas.js
`);
process.exit(0);
