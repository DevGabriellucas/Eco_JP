/**
 * Testes das regras de seguranca do Firestore do EcoJP.
 *
 * Rodam contra o emulador do Firestore com @firebase/rules-unit-testing.
 * Execute com: npm test  (dentro de test/firestore_rules/), que sobe o
 * emulador automaticamente via `firebase emulators:exec`.
 *
 * Cobrem os controles de seguranca mais criticos identificados na analise:
 *   - Leitura exige autenticacao (nada e publico sem login).
 *   - Escrita de conteudo exige e-mail verificado.
 *   - Denuncia anonima nao grava o UID real no documento publico (S2).
 *   - Papel de autoridade nao pode ser autoconcedido pelo app (roles/).
 *   - Moderacao (ocultar) e status oficial so pela autoridade.
 *   - Usuario so edita o proprio perfil / consentimento.
 */
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { setLogLevel, serverTimestamp } = require('firebase/firestore');

const PROJECT_ID = 'ecojp-rules-test';
let testEnv;

// Silencia o ruido de erros esperados de permission-denied nos logs.
setLogLevel('error');

// Contextos de usuario reutilizados nos testes.
function verifiedContext(env, uid) {
  return env.authenticatedContext(uid, { email_verified: true }).firestore();
}
function unverifiedContext(env, uid) {
  return env.authenticatedContext(uid, { email_verified: false }).firestore();
}

// Documento de ocorrencia valido (nao-anonimo) para um dado autor.
function ocorrenciaValida(uid, extra = {}) {
  const img =
    'https://res.cloudinary.com/dmdghbgac/image/upload/v1/foto.jpg';
  return {
    titulo: 'Buraco na rua',
    descricao: 'Buraco grande e perigoso na via principal.',
    localizacao: 'Rua das Flores, Centro',
    latitude: -7.11,
    longitude: -34.86,
    tipoLixo: 'Buraco',
    status: 'Pendente',
    // A regra exige dataCriacao == request.time (timestamp do servidor).
    dataCriacao: serverTimestamp(),
    usuarioId: uid,
    imagemUrl: img,
    imagensUrls: [img],
    anonima: false,
    likes: 0,
    dislikes: 0,
    comments: 0,
    likedBy: [],
    dislikedBy: [],
    fixada: false,
    ...extra,
  };
}

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../firestore.rules'),
        'utf8',
      ),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('ocorrencias', () => {
  test('usuario nao autenticado NAO le ocorrencias', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(db.collection('ocorrencias').doc('x').get());
  });

  test('usuario autenticado le ocorrencias', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(db.collection('ocorrencias').doc('x').get());
  });

  test('cria ocorrencia valida com e-mail verificado', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(
      db.collection('ocorrencias').add(ocorrenciaValida('alice')),
    );
  });

  test('NAO cria ocorrencia sem e-mail verificado', async () => {
    const db = unverifiedContext(testEnv, 'bob');
    await assertFails(
      db.collection('ocorrencias').add(ocorrenciaValida('bob')),
    );
  });

  test('NAO cria ocorrencia forjando outro autor (usuarioId != uid)', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('ocorrencias').add(ocorrenciaValida('mallory')),
    );
  });

  test('denuncia anonima NAO pode gravar usuarioId no documento publico (S2)', async () => {
    const db = verifiedContext(testEnv, 'alice');
    // anonima=true exige usuarioId==null; gravar o UID real deve falhar.
    await assertFails(
      db
        .collection('ocorrencias')
        .add(ocorrenciaValida('alice', { anonima: true })),
    );
  });

  test('denuncia anonima valida (usuarioId null) e aceita', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(
      db.collection('ocorrencias').add(
        ocorrenciaValida('alice', {
          anonima: true,
          usuarioId: null,
          usuarioNome: null,
          usuarioFotoUrl: null,
        }),
      ),
    );
  });

  test('NAO cria ocorrencia com coordenada (0,0) invalida', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db
        .collection('ocorrencias')
        .add(ocorrenciaValida('alice', { latitude: 0, longitude: 0 })),
    );
  });

  test('NAO cria ocorrencia com imagem fora do Cloudinary do projeto', async () => {
    const db = verifiedContext(testEnv, 'alice');
    const badImg = 'https://evil.com/foto.jpg';
    await assertFails(
      db.collection('ocorrencias').add(
        ocorrenciaValida('alice', {
          imagemUrl: badImg,
          imagensUrls: [badImg],
        }),
      ),
    );
  });
});

describe('moderacao e papeis', () => {
  // Semeia uma ocorrencia de alice diretamente (sem passar pelas regras).
  async function seedOcorrencia() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection('ocorrencias')
        .doc('occ1')
        .set(ocorrenciaValida('alice'));
    });
  }

  test('usuario comum NAO consegue ocultar (moderar) uma ocorrencia', async () => {
    await seedOcorrencia();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(
      db.collection('ocorrencias').doc('occ1').update({ oculto: true }),
    );
  });

  test('usuario NAO consegue autoconceder papel de autoridade (roles/)', async () => {
    const db = verifiedContext(testEnv, 'mallory');
    await assertFails(
      db.collection('roles').doc('mallory').set({ role: 'autoridade' }),
    );
  });

  test('autoridade consegue ocultar uma ocorrencia (moderacao)', async () => {
    await seedOcorrencia();
    // Concede o papel via caminho privilegiado (simula o Console Admin).
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection('roles')
        .doc('gov')
        .set({ role: 'autoridade' });
    });
    const db = verifiedContext(testEnv, 'gov');
    await assertSucceeds(
      db.collection('ocorrencias').doc('occ1').update({ oculto: true }),
    );
  });

  test('usuario comum NAO altera status oficial', async () => {
    await seedOcorrencia();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(
      db
        .collection('ocorrencias')
        .doc('occ1')
        .update({ statusOficial: 'resolvida' }),
    );
  });
});

describe('perfis de usuario', () => {
  test('usuario edita o proprio perfil', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(
      db.collection('usuarios').doc('alice').set({
        nome: 'Alice',
        bio: 'Cidada engajada',
        bairro: 'Centro',
      }),
    );
  });

  test('usuario NAO edita o perfil de outro', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('usuarios').doc('bob').set({
        nome: 'Bob falsificado',
        bio: '',
        bairro: '',
      }),
    );
  });
});
