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
// API compat (db.collection) usa FieldValue do namespace compat.
const firestore = require('firebase/compat/app').default.firestore.FieldValue;

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

  test('NAO cria ocorrencia com titulo em branco (so espacos)', async () => {
    // titulo '     ' passa no size() >= 3 mas deve falhar em naoEmBranco.
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('ocorrencias').add(
        ocorrenciaValida('alice', { titulo: '     ' }),
      ),
    );
  });

  test('NAO cria ocorrencia com descricao em branco (so espacos)', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('ocorrencias').add(
        ocorrenciaValida('alice', { descricao: '            ' }),
      ),
    );
  });
});

describe('denuncia anonima (dono/info no mesmo batch)', () => {
  const anonima = () =>
    ocorrenciaValida('x', {
      anonima: true,
      usuarioId: null,
      usuarioNome: null,
      usuarioFotoUrl: null,
    });

  // Mesmo formato do OcorrenciaRepository.cadastrarOcorrencia.
  function batchAnonimo(db, uid, id, { comDono = true, comPonteiro = true } = {}) {
    const ref = db.collection('ocorrencias').doc(id);
    const batch = db.batch();
    batch.set(ref, anonima());
    if (comDono) batch.set(ref.collection('dono').doc('info'), { usuarioId: uid });
    if (comPonteiro) {
      batch.set(
        db.collection('usuarios').doc(uid).collection('minhas_denuncias_anonimas').doc(id),
        {},
      );
    }
    return batch.commit();
  }

  // Denúncia anônima já publicada por alice.
  async function seedAnonimaDeAlice(id, { comDono = true } = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const ref = ctx.firestore().collection('ocorrencias').doc(id);
      await ref.set({ ...anonima(), dataCriacao: new Date() });
      if (comDono) await ref.collection('dono').doc('info').set({ usuarioId: 'alice' });
    });
  }

  test('cria denuncia + dono/info + ponteiro num unico batch', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(batchAnonimo(db, 'alice', 'd1'));
  });

  test('NAO cria denuncia anonima sem dono/info no mesmo batch', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      batchAnonimo(db, 'alice', 'd2', { comDono: false, comPonteiro: false }),
    );
  });

  test('NAO cria dono/info com o UID de outra pessoa', async () => {
    const db = verifiedContext(testEnv, 'alice');
    const ref = db.collection('ocorrencias').doc('d3');
    const batch = db.batch();
    batch.set(ref, anonima());
    batch.set(ref.collection('dono').doc('info'), { usuarioId: 'bob' });
    await assertFails(batch.commit());
  });

  test('terceiro NAO cria dono/info numa denuncia anonima ja existente sem dono', async () => {
    await seedAnonimaDeAlice('d4', { comDono: false });
    const db = verifiedContext(testEnv, 'mallory');
    await assertFails(
      db.collection('ocorrencias').doc('d4').collection('dono').doc('info')
        .set({ usuarioId: 'mallory' }),
    );
  });

  test('dono/{docId} so aceita o ID "info"', async () => {
    const db = verifiedContext(testEnv, 'alice');
    const ref = db.collection('ocorrencias').doc('d5');
    const batch = db.batch();
    batch.set(ref, anonima());
    batch.set(ref.collection('dono').doc('info'), { usuarioId: 'alice' });
    batch.set(ref.collection('dono').doc('outro'), { usuarioId: 'alice' });
    await assertFails(batch.commit());
  });

  test('NAO cria ponteiro em "minhas denuncias" para denuncia de outra pessoa', async () => {
    await seedAnonimaDeAlice('d6');
    const db = verifiedContext(testEnv, 'mallory');
    await assertFails(
      db.collection('usuarios').doc('mallory')
        .collection('minhas_denuncias_anonimas').doc('d6').set({}),
    );
  });

  // Mesmo formato do UsuarioService.excluirTodosDados.
  function batchExclusao(db, ids) {
    const batch = db.batch();
    for (const id of ids) {
      const ref = db.collection('ocorrencias').doc(id);
      batch.delete(ref);
      batch.delete(ref.collection('dono').doc('info'));
      batch.delete(db.collection('usuarios').doc('alice')
        .collection('minhas_denuncias_anonimas').doc(id));
    }
    return batch.commit();
  }

  test('exclusao de conta: lote de 6 denuncias anonimas passa', async () => {
    const ids = [...Array(6).keys()].map((i) => `ex${i}`);
    for (const id of ids) await seedAnonimaDeAlice(id);
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(batchExclusao(db, ids));
  });

  test('exclusao de conta: lote unico com 21 anonimas estoura o limite de get()', async () => {
    // Documenta por que excluirTodosDados divide as anônimas em lotes.
    const ids = [...Array(21).keys()].map((i) => `big${i}`);
    for (const id of ids) await seedAnonimaDeAlice(id);
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(batchExclusao(db, ids));
  });

  test('dono recria o proprio ponteiro para denuncia existente', async () => {
    await seedAnonimaDeAlice('d7');
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(
      db.collection('usuarios').doc('alice')
        .collection('minhas_denuncias_anonimas').doc('d7').set({}),
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

describe('comentarios', () => {
  async function seedOcorrencia() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection('ocorrencias')
        .doc('occC')
        .set(ocorrenciaValida('alice'));
      // Perfis: o nome do comentário precisa bater com usuarios/{uid}.nome.
      await ctx.firestore().collection('usuarios').doc('alice')
        .set({ nome: 'Alice', bio: '', bairro: '' });
      await ctx.firestore().collection('usuarios').doc('prefeitura')
        .set({ nome: 'Prefeitura', bio: '', bairro: '' });
      await ctx.firestore().collection('roles').doc('prefeitura')
        .set({ role: 'autoridade' });
    });
  }

  function comentar(uid, extra = {}) {
    return verifiedContext(testEnv, uid)
      .collection('ocorrencias').doc('occC').collection('comentarios')
      .add(comentarioValido(uid, extra));
  }

  function comentarioValido(uid, extra = {}) {
    return {
      texto: 'Comentario util e construtivo',
      userId: uid,
      userName: 'Alice',
      userPhotoUrl: null,
      dataCriacao: serverTimestamp(),
      parentId: null,
      likedBy: [],
      likes: 0,
      ...extra,
    };
  }

  test('cria comentario valido', async () => {
    await seedOcorrencia();
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(
      db
        .collection('ocorrencias')
        .doc('occC')
        .collection('comentarios')
        .add(comentarioValido('alice')),
    );
  });

  test('NAO cria comentario em branco (so espacos)', async () => {
    await seedOcorrencia();
    // texto '   ' passa no size() >= 1 mas deve falhar em naoEmBranco.
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db
        .collection('ocorrencias')
        .doc('occC')
        .collection('comentarios')
        .add(comentarioValido('alice', { texto: '   ' })),
    );
  });

  test('usuario comum NAO grava o selo de autoridade', async () => {
    await seedOcorrencia();
    await assertFails(comentar('alice', { autorAutoridade: true }));
  });

  test('autoridade grava o selo de autoridade', async () => {
    await seedOcorrencia();
    await assertSucceeds(
      comentar('prefeitura', { userName: 'Prefeitura', autorAutoridade: true }),
    );
  });

  test('NAO comenta com nome diferente do perfil (ex.: "Prefeitura")', async () => {
    await seedOcorrencia();
    await assertFails(comentar('alice', { userName: 'Prefeitura' }));
  });

  test('NAO comenta sem perfil (nome nao pode ser conferido)', async () => {
    await seedOcorrencia();
    await assertFails(comentar('semperfil', { userName: 'Alguem' }));
  });

  test('NAO comenta com foto hospedada fora do Cloudinary/Google', async () => {
    await seedOcorrencia();
    await assertFails(
      comentar('alice', { userPhotoUrl: 'https://evil.example/pixel.png' }),
    );
  });

  test('comenta com foto do Cloudinary do projeto ou do Google', async () => {
    await seedOcorrencia();
    await assertSucceeds(comentar('alice', {
      userPhotoUrl: 'https://res.cloudinary.com/dmdghbgac/image/upload/v1/a.jpg',
    }));
    await assertSucceeds(comentar('alice', {
      userPhotoUrl: 'https://lh3.googleusercontent.com/a/abc=s96-c',
    }));
  });
});

describe('nome publico na denuncia (usuarioNome)', () => {
  async function seedPerfil() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('usuarios').doc('alice')
        .set({ nome: 'Alice', bio: '', bairro: '' });
    });
  }

  test('denuncia com o nome do proprio perfil e aceita', async () => {
    await seedPerfil();
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(
      db.collection('ocorrencias').add(ocorrenciaValida('alice', { usuarioNome: 'Alice' })),
    );
  });

  test('NAO denuncia com nome de outra pessoa', async () => {
    await seedPerfil();
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('ocorrencias').add(ocorrenciaValida('alice', { usuarioNome: 'Prefeitura' })),
    );
  });

  test('propagacao do perfil em lote grande (30 denuncias) passa nas regras', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await f.collection('usuarios').doc('alice').set({ nome: 'Alice Nova', bio: '', bairro: '' });
      for (let i = 0; i < 30; i++) {
        await f.collection('ocorrencias').doc(`p${i}`)
          .set({ ...ocorrenciaValida('alice', { usuarioNome: 'Alice' }), dataCriacao: new Date() });
      }
    });
    const db = verifiedContext(testEnv, 'alice');
    const batch = db.batch();
    for (let i = 0; i < 30; i++) {
      batch.update(db.collection('ocorrencias').doc(`p${i}`), {
        usuarioNome: 'Alice Nova',
        usuarioFotoUrl: null,
      });
    }
    await assertSucceeds(batch.commit());
  });
});

describe('linha do tempo (auditoria)', () => {
  async function seed() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db
        .collection('ocorrencias')
        .doc('occH')
        .set(ocorrenciaValida('alice'));
      await db.collection('roles').doc('gov').set({ role: 'autoridade' });
      // `por` precisa ser o nome do perfil da autoridade.
      await db.collection('usuarios').doc('gov').set({ nome: 'Órgão X', bio: '', bairro: '' });
    });
  }

  function evento(extra = {}) {
    return { status: 'verificada', por: 'Órgão X', data: serverTimestamp(), ...extra };
  }

  test('autoridade registra evento de auditoria', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'gov');
    await assertSucceeds(
      db
        .collection('ocorrencias')
        .doc('occH')
        .collection('historico')
        .add(evento()),
    );
  });

  test('usuario comum NAO registra evento de auditoria', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(
      db
        .collection('ocorrencias')
        .doc('occH')
        .collection('historico')
        .add(evento()),
    );
  });

  test('evento com status invalido e rejeitado', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'gov');
    await assertFails(
      db
        .collection('ocorrencias')
        .doc('occH')
        .collection('historico')
        .add(evento({ status: 'qualquer_coisa' })),
    );
  });

  test('evento de auditoria e imutavel (sem update/delete)', async () => {
    await seed();
    let ref;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      ref = await ctx
        .firestore()
        .collection('ocorrencias')
        .doc('occH')
        .collection('historico')
        .add({ status: 'verificada', data: new Date() });
    });
    const db = verifiedContext(testEnv, 'gov');
    const doc = db
      .collection('ocorrencias')
      .doc('occH')
      .collection('historico')
      .doc(ref.id);
    await assertFails(doc.update({ status: 'resolvida' }));
    await assertFails(doc.delete());
  });

  test('evento com "por" diferente do nome do perfil e rejeitado', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'gov');
    await assertFails(
      db.collection('ocorrencias').doc('occH').collection('historico')
        .add(evento({ por: 'Prefeitura' })),
    );
  });
});

describe('ciclo oficial exige evento de auditoria no mesmo batch', () => {
  async function seed(extra = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.collection('ocorrencias').doc('occA')
        .set({ ...ocorrenciaValida('alice'), dataCriacao: new Date(), ...extra });
      await db.collection('roles').doc('gov').set({ role: 'autoridade' });
      await db.collection('usuarios').doc('gov').set({ nome: 'Semam', bio: '', bairro: '' });
    });
  }

  // Mesmo formato do OcorrenciaRepository: evento + ultimoEventoId.
  function acao(db, campos, status) {
    const ref = db.collection('ocorrencias').doc('occA');
    const ev = ref.collection('historico').doc();
    const batch = db.batch();
    batch.set(ev, { status, por: 'Semam', data: serverTimestamp() });
    batch.update(ref, { ...campos, ultimoEventoId: ev.id });
    return batch.commit();
  }

  test('verificar com evento e nome do perfil passa', async () => {
    await seed();
    await assertSucceeds(acao(verifiedContext(testEnv, 'gov'), {
      verificada: true, verificadaPor: 'gov', verificadaPorNome: 'Semam',
      verificadaEm: serverTimestamp(), statusOficial: null,
    }, 'verificada'));
  });

  test('NAO verifica sem o evento de auditoria', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'gov');
    await assertFails(db.collection('ocorrencias').doc('occA').update({
      verificada: true, verificadaPor: 'gov', verificadaPorNome: 'Semam',
      verificadaEm: serverTimestamp(), statusOficial: null,
    }));
  });

  test('NAO verifica com nome fixo diferente do perfil ("Autoridade")', async () => {
    await seed();
    await assertFails(acao(verifiedContext(testEnv, 'gov'), {
      verificada: true, verificadaPor: 'gov', verificadaPorNome: 'Autoridade',
      verificadaEm: serverTimestamp(), statusOficial: null,
    }, 'verificada'));
  });

  test('NAO encaminha com evento de outro status', async () => {
    await seed({ verificada: true });
    await assertFails(acao(verifiedContext(testEnv, 'gov'), {
      statusOficial: 'encaminhada', encaminhadaEm: serverTimestamp(),
    }, 'resolvida'));
  });

  test('reverter resolvida para encaminhada limpa resolvidaEm com evento "revertida"', async () => {
    await seed({ verificada: true, statusOficial: 'resolvida', resolvidaEm: new Date() });
    await assertSucceeds(acao(verifiedContext(testEnv, 'gov'), {
      statusOficial: 'encaminhada', resolvidaEm: null,
    }, 'revertida'));
  });

  test('NAO "reverte" para encaminhada mantendo resolvidaEm', async () => {
    await seed({ verificada: true, statusOficial: 'resolvida', resolvidaEm: new Date() });
    await assertFails(acao(verifiedContext(testEnv, 'gov'), {
      statusOficial: 'encaminhada',
    }, 'revertida'));
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

  test('NAO salva perfil com nome em branco (so espacos)', async () => {
    // nome '   ' passa no size() >= 1 mas deve falhar em naoEmBranco.
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('usuarios').doc('alice').set({
        nome: '   ',
        bio: '',
        bairro: '',
      }),
    );
  });
});

describe('reserva de nome (nomes_reservados)', () => {
  const reserva = (uid, nome = 'Alice') => ({
    uid,
    nome,
    criadoEm: serverTimestamp(),
  });

  test('usuario reserva um slug livre para si', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(
      db.collection('nomes_reservados').doc('alice').set(reserva('alice')),
    );
  });

  test('NAO reserva declarando outro dono', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('nomes_reservados').doc('bob').set(reserva('bob')),
    );
  });

  // Este e o teste que sustenta a atomicidade: a reserva nao usa transacao,
  // ela depende de `allow update: if false`. Um set() sobre um slug ja tomado
  // e avaliado como update e precisa falhar, senao dois cadastros simultaneos
  // com o mesmo nome passariam os dois.
  test('NAO sobrescreve slug ja reservado por outra conta', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection('nomes_reservados')
        .doc('alice')
        .set({ uid: 'alice', nome: 'Alice', criadoEm: new Date() });
    });
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(
      db.collection('nomes_reservados').doc('alice').set(reserva('bob')),
    );
  });

  test('NAO reserva com campos fora do formato', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('nomes_reservados').doc('alice').set({
        uid: 'alice',
        nome: 'Alice',
        criadoEm: serverTimestamp(),
        papel: 'autoridade',
      }),
    );
  });

  test('dono libera a propria reserva', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection('nomes_reservados')
        .doc('alice')
        .set({ uid: 'alice', nome: 'Alice', criadoEm: new Date() });
    });
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(
      db.collection('nomes_reservados').doc('alice').delete(),
    );
  });

  test('NAO libera reserva de outra conta', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection('nomes_reservados')
        .doc('alice')
        .set({ uid: 'alice', nome: 'Alice', criadoEm: new Date() });
    });
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(db.collection('nomes_reservados').doc('alice').delete());
  });
});

describe('notificacoes (autenticidade e deduplicacao)', () => {
  // occN de alice, curtida por bob; comentario cB1 de bob.
  async function seed() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await f.collection('usuarios').doc('bob').set({ nome: 'Bob', bio: '', bairro: '' });
      await f.collection('usuarios').doc('pref').set({ nome: 'Prefeitura', bio: '', bairro: '' });
      await f.collection('roles').doc('pref').set({ role: 'autoridade' });
      await f.collection('ocorrencias').doc('occN').set({
        ...ocorrenciaValida('alice'), dataCriacao: new Date(), likedBy: ['bob'], likes: 1,
      });
      await f.collection('ocorrencias').doc('occN').collection('comentarios').doc('cB1')
        .set({ texto: 'oi', userId: 'bob', userName: 'Bob', dataCriacao: new Date() });
    });
  }

  function notif(tipo, extra = {}) {
    return {
      tipo,
      deUsuarioNome: 'Bob',
      ocorrenciaId: 'occN',
      ocorrenciaTitulo: 'Buraco na rua',
      dataCriacao: serverTimestamp(),
      lida: false,
      ...extra,
    };
  }

  const inbox = (db) => db.collection('notificacoes').doc('alice').collection('items');

  test('curtida com ID deterministico de quem curtiu e aceita', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertSucceeds(inbox(db).doc('curtida_occN_bob').set(notif('curtida')));
  });

  test('segunda curtida com o mesmo ID e negada (deduplicacao)', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await inbox(db).doc('curtida_occN_bob').set(notif('curtida'));
    await assertFails(inbox(db).doc('curtida_occN_bob').set(notif('curtida')));
  });

  test('NAO notifica curtida com ID aleatorio', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(inbox(db).add(notif('curtida')));
  });

  test('NAO notifica curtida de quem nao curtiu', async () => {
    await seed();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('usuarios').doc('carol')
        .set({ nome: 'Carol', bio: '', bairro: '' });
    });
    const db = verifiedContext(testEnv, 'carol');
    await assertFails(
      inbox(db).doc('curtida_occN_carol').set(notif('curtida', { deUsuarioNome: 'Carol' })),
    );
  });

  test('NAO notifica com titulo diferente do da denuncia (phishing)', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(inbox(db).doc('curtida_occN_bob').set(
      notif('curtida', { ocorrenciaTitulo: 'Clique aqui: bit.ly/xyz' }),
    ));
  });

  test('NAO notifica com nome diferente do perfil', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(inbox(db).doc('curtida_occN_bob').set(
      notif('curtida', { deUsuarioNome: 'Prefeitura' }),
    ));
  });

  test('comentario: notifica com o ID do proprio comentario', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertSucceeds(inbox(db).doc('comentario_cB1').set(notif('comentario')));
  });

  test('comentario: NAO notifica comentario inexistente', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(inbox(db).doc('comentario_naoexiste').set(notif('comentario')));
  });

  test('usuario comum NAO envia notificacao de status oficial', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(inbox(db).add(notif('status_resolvida')));
  });

  test('autoridade envia notificacao de status oficial', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'pref');
    await assertSucceeds(
      inbox(db).add(notif('status_resolvida', { deUsuarioNome: 'Prefeitura' })),
    );
  });

  test('conquista: so com ID conquista_<slug>', async () => {
    const db = verifiedContext(testEnv, 'alice');
    const conquista = {
      tipo: 'conquista', deUsuarioNome: 'EcoJP', ocorrenciaId: '', ocorrenciaTitulo: '',
      conquistaTitulo: 'Primeira denuncia', dataCriacao: serverTimestamp(), lida: false,
    };
    await assertSucceeds(inbox(db).doc('conquista_primeira-denuncia').set(conquista));
    await assertFails(inbox(db).add(conquista));
  });
});

describe('usuarios/{uid}/meta', () => {
  const meta = (db, uid) =>
    db.collection('usuarios').doc(uid).collection('meta').doc('conquistasNotificadas');

  test('dono grava e le conquistasNotificadas', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(meta(db, 'alice').set({ items: ['Primeira denuncia'] }));
    await assertSucceeds(meta(db, 'alice').get());
  });

  test('NAO grava meta de outra pessoa', async () => {
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(meta(db, 'alice').set({ items: [] }));
  });

  test('NAO grava lista com mais de 50 itens', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(meta(db, 'alice').set({ items: [...Array(51).keys()].map(String) }));
  });
});

describe('conteudo ocultado pela moderacao', () => {
  async function seed() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await f.collection('roles').doc('pref').set({ role: 'autoridade' });
      const base = { ...ocorrenciaValida('alice'), dataCriacao: new Date() };
      await f.collection('ocorrencias').doc('visivel').set({ ...base, oculto: false });
      await f.collection('ocorrencias').doc('oculta').set({ ...base, oculto: true });
      // Documento criado antes do campo existir (antes do backfill).
      await f.collection('ocorrencias').doc('legado').set(base);
      await f.collection('ocorrencias').doc('visivel').collection('comentarios').doc('cOculto')
        .set({ texto: 'x', userId: 'bob', userName: 'Bob', oculto: true, dataCriacao: new Date() });
      await f.collection('ocorrencias').doc('visivel').collection('comentarios').doc('cOk')
        .set({ texto: 'y', userId: 'bob', userName: 'Bob', oculto: false, dataCriacao: new Date() });
    });
  }

  test('terceiro NAO le denuncia oculta por ID (deep link, perfil publico)', async () => {
    await seed();
    await assertFails(verifiedContext(testEnv, 'mallory').collection('ocorrencias').doc('oculta').get());
  });

  test('dono e autoridade leem a denuncia oculta', async () => {
    await seed();
    await assertSucceeds(verifiedContext(testEnv, 'alice').collection('ocorrencias').doc('oculta').get());
    await assertSucceeds(verifiedContext(testEnv, 'pref').collection('ocorrencias').doc('oculta').get());
  });

  test('documento legado sem o campo oculto continua legivel por ID', async () => {
    await seed();
    await assertSucceeds(verifiedContext(testEnv, 'mallory').collection('ocorrencias').doc('legado').get());
  });

  test('consulta sem filtro de oculto e negada para usuario comum', async () => {
    await seed();
    await assertFails(verifiedContext(testEnv, 'mallory').collection('ocorrencias').limit(10).get());
  });

  test('consulta com where oculto == false e permitida', async () => {
    await seed();
    const snap = await assertSucceeds(
      verifiedContext(testEnv, 'mallory').collection('ocorrencias')
        .where('oculto', '==', false).orderBy('dataCriacao', 'desc').limit(10).get(),
    );
    expect(snap.docs.map((d) => d.id)).toEqual(['visivel']);
  });

  test('dono lista as proprias denuncias (inclusive ocultas) pelo usuarioId', async () => {
    await seed();
    await assertSucceeds(
      verifiedContext(testEnv, 'alice').collection('ocorrencias').where('usuarioId', '==', 'alice').get(),
    );
  });

  test('autoridade consulta sem filtro (filas)', async () => {
    await seed();
    await assertSucceeds(verifiedContext(testEnv, 'pref').collection('ocorrencias').limit(10).get());
  });

  test('comentario oculto: terceiro nao le; consulta precisa do filtro', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'mallory');
    const com = db.collection('ocorrencias').doc('visivel').collection('comentarios');
    await assertFails(com.doc('cOculto').get());
    await assertFails(com.get());
    await assertSucceeds(com.where('oculto', '==', false).orderBy('dataCriacao').get());
  });

  test('NAO cria denuncia ja oculta', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(db.collection('ocorrencias').add(ocorrenciaValida('alice', { oculto: true })));
  });

  test('cria denuncia com oculto false', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(db.collection('ocorrencias').add(ocorrenciaValida('alice', { oculto: false })));
  });
});

describe('area de Joao Pessoa e bairro', () => {
  test('NAO cria denuncia fora de Joao Pessoa (Sao Paulo)', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(db.collection('ocorrencias').add(
      ocorrenciaValida('alice', { latitude: -23.55, longitude: -46.63 }),
    ));
  });

  test('NAO cria denuncia em Campina Grande (fora da area)', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(db.collection('ocorrencias').add(
      ocorrenciaValida('alice', { latitude: -7.23, longitude: -35.88 }),
    ));
  });

  test('cria denuncia com bairro estruturado', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertSucceeds(db.collection('ocorrencias').add(
      ocorrenciaValida('alice', { bairro: 'Manaíra' }),
    ));
  });

  test('NAO cria denuncia com bairro longo demais ou nao-texto', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(db.collection('ocorrencias').add(
      ocorrenciaValida('alice', { bairro: 'x'.repeat(61) }),
    ));
    await assertFails(db.collection('ocorrencias').add(
      ocorrenciaValida('alice', { bairro: 42 }),
    ));
  });
});

describe('contadores (compartilhamento, reacoes, comentario orfao)', () => {
  async function seed() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('ocorrencias').doc('occS')
        .set({ ...ocorrenciaValida('alice'), dataCriacao: new Date(), shares: 0 });
      await ctx.firestore().collection('usuarios').doc('bob')
        .set({ nome: 'Bob', bio: '', bairro: '' });
    });
  }

  function compartilhar(db, uid) {
    const ref = db.collection('ocorrencias').doc('occS');
    const batch = db.batch();
    batch.update(ref, { shares: firestore.increment(1) });
    batch.set(ref.collection('compartilhamentos').doc(uid), { uid, criadoEm: serverTimestamp() });
    return batch.commit();
  }

  function reagir(db, uid, likedBy) {
    const batch = db.batch();
    batch.update(db.collection('ocorrencias').doc('occS'), {
      likedBy, likes: likedBy.length, dislikedBy: [], dislikes: 0,
    });
    batch.set(db.collection('usuarios').doc(uid).collection('meta').doc('reacao'),
      { ultima: serverTimestamp() });
    return batch.commit();
  }

  test('compartilhar conta +1 com o registro do usuario', async () => {
    await seed();
    await assertSucceeds(compartilhar(verifiedContext(testEnv, 'bob'), 'bob'));
  });

  test('NAO compartilha duas vezes (contador nao infla)', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await compartilhar(db, 'bob');
    await assertFails(compartilhar(db, 'bob'));
  });

  test('NAO soma share sem o registro no mesmo batch', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(db.collection('ocorrencias').doc('occS').update({ shares: 1 }));
  });

  test('curtir com o carimbo de reacao passa', async () => {
    await seed();
    await assertSucceeds(reagir(verifiedContext(testEnv, 'bob'), 'bob', ['bob']));
  });

  test('NAO reage sem o carimbo de reacao', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(db.collection('ocorrencias').doc('occS')
      .update({ likedBy: ['bob'], likes: 1 }));
  });

  test('reacao em sequencia rapida (menos de 1 s) e negada', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await reagir(db, 'bob', ['bob']);
    await assertFails(reagir(db, 'bob', []));
  });

  test('NAO comenta em denuncia inexistente', async () => {
    await seed();
    const db = verifiedContext(testEnv, 'bob');
    await assertFails(db.collection('ocorrencias').doc('naoexiste').collection('comentarios').add({
      texto: 'oi', userId: 'bob', userName: 'Bob', userPhotoUrl: null,
      dataCriacao: serverTimestamp(), parentId: null, likedBy: [], likes: 0,
    }));
  });
});

describe('validacoes que faltavam (card 46)', () => {
  test('NAO cria denuncia com municipioId de outra cidade', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(db.collection('ocorrencias').add(
      ocorrenciaValida('alice', { municipioId: 'x'.repeat(5000) }),
    ));
    await assertSucceeds(db.collection('ocorrencias').add(
      ocorrenciaValida('alice', { municipioId: 'joao-pessoa' }),
    ));
  });

  test('NAO reserva nome com slug fora do formato', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(db.collection('nomes_reservados').doc('Fora Do Formato')
      .set({ uid: 'alice', nome: 'Fora do formato', criadoEm: serverTimestamp() }));
  });

  test('autoridade resolve denuncia de moderacao so com os campos de decisao', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('roles').doc('gov').set({ role: 'autoridade' });
      await ctx.firestore().collection('denuncias_moderacao').doc('m1').set({
        alvoTipo: 'ocorrencia', ocorrenciaId: 'o1', comentarioId: null,
        denuncianteId: 'bob', motivo: 'Spam', detalhe: null, status: 'pendente',
        criadoEm: new Date(),
      });
    });
    const ref = verifiedContext(testEnv, 'gov').collection('denuncias_moderacao').doc('m1');
    await assertFails(ref.update({ motivo: 'reescrito' }));
    await assertFails(ref.update({ status: 'qualquer', resolvidoPor: 'gov', resolvidoEm: serverTimestamp() }));
    await assertSucceeds(ref.update({ status: 'revisada', resolvidoPor: 'gov', resolvidoEm: serverTimestamp() }));
  });
});

describe('pares positivo/negativo que faltavam (card 40)', () => {
  test('seguir: cria os dois lados do vinculo; NAO segue em nome de outro', async () => {
    const db = verifiedContext(testEnv, 'alice');
    const batch = db.batch();
    batch.set(db.collection('usuarios').doc('alice').collection('seguindo').doc('bob'),
      { uid: 'bob', criadoEm: serverTimestamp() });
    batch.set(db.collection('usuarios').doc('bob').collection('seguidores').doc('alice'),
      { uid: 'alice', criadoEm: serverTimestamp() });
    await assertSucceeds(batch.commit());

    await assertFails(
      db.collection('usuarios').doc('carol').collection('seguindo').doc('bob')
        .set({ uid: 'bob', criadoEm: serverTimestamp() }),
    );
  });

  test('NAO segue a si mesmo', async () => {
    const db = verifiedContext(testEnv, 'alice');
    await assertFails(
      db.collection('usuarios').doc('alice').collection('seguindo').doc('alice')
        .set({ uid: 'alice', criadoEm: serverTimestamp() }),
    );
  });

  test('consentimento: registra o proprio com aceite explicito; NAO o de outro', async () => {
    const db = verifiedContext(testEnv, 'alice');
    const consentimento = {
      versao: '2026-10-01', aceiteTermos: true, aceitePrivacidade: true,
      aceitoEm: serverTimestamp(),
    };
    await assertSucceeds(db.collection('consentimentos').doc('alice').set(consentimento));
    await assertFails(db.collection('consentimentos').doc('bob').set(consentimento));
    await assertFails(db.collection('consentimentos').doc('alice')
      .set({ ...consentimento, aceiteTermos: false }));
  });

  test('denuncia de moderacao: cria valida; NAO em nome de outro', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('ocorrencias').doc('oM')
        .set({ ...ocorrenciaValida('alice'), dataCriacao: new Date() });
    });
    const db = verifiedContext(testEnv, 'bob');
    const denuncia = {
      alvoTipo: 'ocorrencia', ocorrenciaId: 'oM', comentarioId: null,
      denuncianteId: 'bob', motivo: 'Spam', detalhe: null, status: 'pendente',
      criadoEm: serverTimestamp(),
    };
    await assertSucceeds(db.collection('denuncias_moderacao').add(denuncia));
    await assertFails(db.collection('denuncias_moderacao').add({ ...denuncia, denuncianteId: 'carol' }));
    await assertFails(db.collection('denuncias_moderacao').doc('x').get());
  });
});

describe('selo de curtida da autoridade em comentario', () => {
  async function seed() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await f.collection('roles').doc('gov').set({ role: 'autoridade' });
      await f.collection('ocorrencias').doc('oc').set({ ...ocorrenciaValida('alice'), dataCriacao: new Date() });
      await f.collection('ocorrencias').doc('oc').collection('comentarios').doc('c1')
        .set({ texto: 'x', userId: 'bob', userName: 'Bob', likedBy: [], likes: 0, oculto: false, dataCriacao: new Date() });
    });
  }
  const com = (db) => db.collection('ocorrencias').doc('oc').collection('comentarios').doc('c1');

  test('autoridade curte e grava o selo', async () => {
    await seed();
    await assertSucceeds(com(verifiedContext(testEnv, 'gov'))
      .update({ likedBy: ['gov'], likes: 1, curtidoPorAutoridade: true }));
  });

  test('usuario comum NAO grava o selo', async () => {
    await seed();
    await assertFails(com(verifiedContext(testEnv, 'alice'))
      .update({ likedBy: ['alice'], likes: 1, curtidoPorAutoridade: true }));
  });

  test('usuario comum curte sem o selo', async () => {
    await seed();
    await assertSucceeds(com(verifiedContext(testEnv, 'alice'))
      .update({ likedBy: ['alice'], likes: 1 }));
  });
});
