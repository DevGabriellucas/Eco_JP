import { strict as assert } from 'node:assert';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { serverTimestamp } from 'firebase/firestore';

// Testes das regras do Firestore (firestore.rules), rodando contra o
// emulador local — não tocam o projeto Firebase real. Cobrem as garantias
// de segurança que a auditoria manual confirmou: negação por padrão, roles
// não-autopromovíveis, proteção do denunciante anônimo, e a moderação
// implementada nesta sessão.

let testEnv;

const CIDADAO_UID = 'cidadao-1';
const OUTRO_CIDADAO_UID = 'cidadao-2';
const AUTORIDADE_UID = 'autoridade-1';

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'ecojp-rules-test',
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// Contexto autenticado com e-mail verificado (a maioria das escritas exige).
function comoUsuario(uid) {
  return testEnv
    .authenticatedContext(uid, { email_verified: true })
    .firestore();
}

function semLogin() {
  return testEnv.unauthenticatedContext().firestore();
}

async function concederAutoridade(uid) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`roles/${uid}`).set({ role: 'autoridade' });
  });
}

const IMAGEM_VALIDA =
  'https://res.cloudinary.com/dmdghbgac/image/upload/x.jpg';

async function criarOcorrencia(uid, overrides = {}) {
  const id = `oc-${uid}-${Date.now()}-${Math.random()}`;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc(`ocorrencias/${id}`)
      .set({
        titulo: 'Buraco na rua',
        descricao: 'Buraco grande na esquina, risco pra pedestres',
        localizacao: 'Rua Exemplo, 123',
        latitude: -7.115,
        longitude: -34.86,
        tipoLixo: 'Buraco',
        status: 'Pendente',
        dataCriacao: serverTimestamp(),
        usuarioId: uid,
        usuarioNome: 'Fulano',
        usuarioFotoUrl: null,
        imagemUrl: IMAGEM_VALIDA,
        imagensUrls: [IMAGEM_VALIDA],
        anonima: false,
        likes: 0,
        dislikes: 0,
        comments: 0,
        likedBy: [],
        dislikedBy: [],
        fixada: false,
        ...overrides,
      });
  });
  return id;
}

// ── Negação por padrão ──────────────────────────────────────────────────────

describe('Negação por padrão', () => {
  it('coleção desconhecida nega leitura e escrita', async () => {
    const db = comoUsuario(CIDADAO_UID);
    await assertFails(db.doc('coisa_qualquer/doc1').get());
    await assertFails(db.doc('coisa_qualquer/doc1').set({ a: 1 }));
  });

  it('usuário deslogado não lê ocorrências', async () => {
    const id = await criarOcorrencia(CIDADAO_UID);
    const db = semLogin();
    await assertFails(db.doc(`ocorrencias/${id}`).get());
  });
});

// ── Roles não-autopromovíveis ────────────────────────────────────────────────

describe('Papel de autoridade', () => {
  it('cidadão não consegue se autoconceder o papel autoridade', async () => {
    const db = comoUsuario(CIDADAO_UID);
    await assertFails(
      db.doc(`roles/${CIDADAO_UID}`).set({ role: 'autoridade' }),
    );
  });

  it('cidadão lê o próprio papel (inexistente) mas não o de outro usuário', async () => {
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(db.doc(`roles/${CIDADAO_UID}`).get());
    await assertFails(db.doc(`roles/${OUTRO_CIDADAO_UID}`).get());
  });

  it('cidadão comum não pode verificar uma denúncia', async () => {
    const id = await criarOcorrencia(CIDADAO_UID);
    const db = comoUsuario(OUTRO_CIDADAO_UID);
    await assertFails(
      db.doc(`ocorrencias/${id}`).update({
        verificada: true,
        verificadaPor: OUTRO_CIDADAO_UID,
        verificadaPorNome: 'Fulano',
        verificadaEm: serverTimestamp(),
        statusOficial: null,
      }),
    );
  });

  it('autoridade pode verificar uma denúncia', async () => {
    const id = await criarOcorrencia(CIDADAO_UID);
    await concederAutoridade(AUTORIDADE_UID);
    const db = comoUsuario(AUTORIDADE_UID);
    await assertSucceeds(
      db.doc(`ocorrencias/${id}`).update({
        verificada: true,
        verificadaPor: AUTORIDADE_UID,
        verificadaPorNome: 'Autoridade Um',
        verificadaEm: serverTimestamp(),
        statusOficial: null,
      }),
    );
  });
});

// ── Proteção do denunciante anônimo ─────────────────────────────────────────

describe('Denúncia anônima', () => {
  it('nega criar denúncia anônima com nome/foto preenchidos', async () => {
    const db = comoUsuario(CIDADAO_UID);
    await assertFails(
      db.doc(`ocorrencias/oc-anon-${Date.now()}`).set({
        titulo: 'Lixo acumulado',
        descricao: 'Descarte irregular na calçada da esquina',
        localizacao: 'Rua Exemplo, 456',
        latitude: -7.115,
        longitude: -34.86,
        tipoLixo: 'Lixo',
        status: 'Pendente',
        dataCriacao: serverTimestamp(),
        usuarioId: CIDADAO_UID,
        usuarioNome: 'Fulano', // não pode ir junto com anonima: true
        usuarioFotoUrl: null,
        anonima: true,
        likes: 0,
        dislikes: 0,
        comments: 0,
        likedBy: [],
        dislikedBy: [],
        fixada: false,
      }),
    );
  });

  it('nega criar denúncia anônima com usuarioId preenchido (S2)', async () => {
    const db = comoUsuario(CIDADAO_UID);
    await assertFails(
      db.doc(`ocorrencias/oc-anon-uid-${Date.now()}`).set({
        titulo: 'Lixo acumulado',
        descricao: 'Descarte irregular na calçada da esquina',
        localizacao: 'Rua Exemplo, 456',
        latitude: -7.115,
        longitude: -34.86,
        tipoLixo: 'Lixo',
        status: 'Pendente',
        dataCriacao: serverTimestamp(),
        usuarioId: CIDADAO_UID, // deveria ser null quando anonima==true
        usuarioNome: null,
        usuarioFotoUrl: null,
        imagemUrl: IMAGEM_VALIDA,
        imagensUrls: [IMAGEM_VALIDA],
        anonima: true,
        likes: 0,
        dislikes: 0,
        comments: 0,
        likedBy: [],
        dislikedBy: [],
        fixada: false,
      }),
    );
  });

  it('permite criar denúncia anônima com usuarioId null (S2)', async () => {
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(
      db.doc(`ocorrencias/oc-anon-ok-${Date.now()}`).set({
        titulo: 'Lixo acumulado',
        descricao: 'Descarte irregular na calçada da esquina',
        localizacao: 'Rua Exemplo, 456',
        latitude: -7.115,
        longitude: -34.86,
        tipoLixo: 'Lixo',
        status: 'Pendente',
        dataCriacao: serverTimestamp(),
        usuarioId: null,
        usuarioNome: null,
        usuarioFotoUrl: null,
        imagemUrl: IMAGEM_VALIDA,
        imagensUrls: [IMAGEM_VALIDA],
        anonima: true,
        likes: 0,
        dislikes: 0,
        comments: 0,
        likedBy: [],
        dislikedBy: [],
        fixada: false,
      }),
    );
  });
});

// ── S2: subcoleção privada dono/info ────────────────────────────────────────

describe('S2 — dono/info (privacidade do denunciante anônimo)', () => {
  async function criarOcorrenciaAnonima(uid) {
    const id = `oc-anon-${uid}-${Date.now()}-${Math.random()}`;
    const db = comoUsuario(uid);
    await assertSucceeds(
      db.doc(`ocorrencias/${id}`).set({
        titulo: 'Buraco na rua',
        descricao: 'Buraco grande na esquina, risco pra pedestres',
        localizacao: 'Rua Exemplo, 123',
        latitude: -7.115,
        longitude: -34.86,
        tipoLixo: 'Buraco',
        status: 'Pendente',
        dataCriacao: serverTimestamp(),
        usuarioId: null,
        usuarioNome: null,
        usuarioFotoUrl: null,
        imagemUrl: IMAGEM_VALIDA,
        imagensUrls: [IMAGEM_VALIDA],
        anonima: true,
        likes: 0,
        dislikes: 0,
        comments: 0,
        likedBy: [],
        dislikedBy: [],
        fixada: false,
      }),
    );
    return id;
  }

  it('dono consegue criar a subcoleção dono/info na própria denúncia anônima', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(
      db.doc(`ocorrencias/${id}/dono/info`).set({ usuarioId: CIDADAO_UID }),
    );
  });

  it('outro usuário não sobrescreve dono/info já gravado pelo dono real', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(
      db.doc(`ocorrencias/${id}/dono/info`).set({ usuarioId: CIDADAO_UID }),
    );
    const dbAtacante = comoUsuario(OUTRO_CIDADAO_UID);
    await assertFails(
      dbAtacante
        .doc(`ocorrencias/${id}/dono/info`)
        .set({ usuarioId: OUTRO_CIDADAO_UID }),
    );
  });

  it('outro usuário não lê dono/info de denúncia anônima alheia', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`ocorrencias/${id}/dono/info`)
        .set({ usuarioId: CIDADAO_UID });
    });
    const db = comoUsuario(OUTRO_CIDADAO_UID);
    await assertFails(db.doc(`ocorrencias/${id}/dono/info`).get());
  });

  it('o próprio dono lê dono/info da própria denúncia anônima', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`ocorrencias/${id}/dono/info`)
        .set({ usuarioId: CIDADAO_UID });
    });
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(db.doc(`ocorrencias/${id}/dono/info`).get());
  });

  it('autoridade lê dono/info de qualquer denúncia anônima', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`ocorrencias/${id}/dono/info`)
        .set({ usuarioId: CIDADAO_UID });
    });
    await concederAutoridade(AUTORIDADE_UID);
    const db = comoUsuario(AUTORIDADE_UID);
    await assertSucceeds(db.doc(`ocorrencias/${id}/dono/info`).get());
  });

  it('dono edita título/descrição da própria denúncia anônima (isOwner via subcoleção)', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`ocorrencias/${id}/dono/info`)
        .set({ usuarioId: CIDADAO_UID });
    });
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(
      db.doc(`ocorrencias/${id}`).update({
        titulo: 'Buraco enorme',
        descricao: 'Atualizado: piorou depois da chuva',
      }),
    );
  });

  it('outro usuário não edita denúncia anônima alheia mesmo sem ver o dono', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`ocorrencias/${id}/dono/info`)
        .set({ usuarioId: CIDADAO_UID });
    });
    const db = comoUsuario(OUTRO_CIDADAO_UID);
    await assertFails(
      db.doc(`ocorrencias/${id}`).update({
        titulo: 'Tentativa de editar',
        descricao: 'Não deveria funcionar de jeito nenhum',
      }),
    );
  });

  it('dono apaga dono/info e o ponteiro em minhas_denuncias_anonimas ao excluir', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`ocorrencias/${id}/dono/info`)
        .set({ usuarioId: CIDADAO_UID });
      await ctx
        .firestore()
        .doc(`usuarios/${CIDADAO_UID}/minhas_denuncias_anonimas/${id}`)
        .set({});
    });
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(db.doc(`ocorrencias/${id}/dono/info`).delete());
    await assertSucceeds(
      db
        .doc(`usuarios/${CIDADAO_UID}/minhas_denuncias_anonimas/${id}`)
        .delete(),
    );
  });
});

// ── S2: ponteiro minhas_denuncias_anonimas ──────────────────────────────────

describe('S2 — minhas_denuncias_anonimas (perfil encontra as próprias)', () => {
  async function criarOcorrenciaAnonima(uid) {
    const id = `oc-anon-ptr-${uid}-${Date.now()}-${Math.random()}`;
    const db = comoUsuario(uid);
    await db.doc(`ocorrencias/${id}`).set({
      titulo: 'Esgoto a céu aberto',
      descricao: 'Esgoto vazando na calçada há dias',
      localizacao: 'Rua Exemplo, 789',
      latitude: -7.115,
      longitude: -34.86,
      tipoLixo: 'Esgoto',
      status: 'Pendente',
      dataCriacao: serverTimestamp(),
      usuarioId: null,
      usuarioNome: null,
      usuarioFotoUrl: null,
      imagemUrl: IMAGEM_VALIDA,
      imagensUrls: [IMAGEM_VALIDA],
      anonima: true,
      likes: 0,
      dislikes: 0,
      comments: 0,
      likedBy: [],
      dislikedBy: [],
      fixada: false,
    });
    return id;
  }

  it('dono grava o ponteiro da própria denúncia anônima', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(
      db.doc(`usuarios/${CIDADAO_UID}/minhas_denuncias_anonimas/${id}`).set({}),
    );
  });

  it('não é possível gravar ponteiro apontando para denúncia não-anônima', async () => {
    const idNaoAnonima = await criarOcorrencia(CIDADAO_UID);
    const db = comoUsuario(CIDADAO_UID);
    await assertFails(
      db
        .doc(`usuarios/${CIDADAO_UID}/minhas_denuncias_anonimas/${idNaoAnonima}`)
        .set({}),
    );
  });

  it('outro usuário não lê os ponteiros de denúncias anônimas alheias', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`usuarios/${CIDADAO_UID}/minhas_denuncias_anonimas/${id}`)
        .set({});
    });
    const db = comoUsuario(OUTRO_CIDADAO_UID);
    await assertFails(
      db.doc(`usuarios/${CIDADAO_UID}/minhas_denuncias_anonimas/${id}`).get(),
    );
  });

  it('o próprio dono lê seus ponteiros de denúncias anônimas', async () => {
    const id = await criarOcorrenciaAnonima(CIDADAO_UID);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`usuarios/${CIDADAO_UID}/minhas_denuncias_anonimas/${id}`)
        .set({});
    });
    const db = comoUsuario(CIDADAO_UID);
    await assertSucceeds(
      db.doc(`usuarios/${CIDADAO_UID}/minhas_denuncias_anonimas/${id}`).get(),
    );
  });
});

// ── Reações (like/dislike) ──────────────────────────────────────────────────

describe('Reações (curtir/descurtir)', () => {
  it('usuário só adiciona o próprio UID em likedBy', async () => {
    const id = await criarOcorrencia(CIDADAO_UID);
    const db = comoUsuario(OUTRO_CIDADAO_UID);
    await assertFails(
      db.doc(`ocorrencias/${id}`).update({
        likedBy: ['uid-forjado'],
        likes: 1,
      }),
    );
  });

  it('usuário adiciona o próprio UID em likedBy corretamente', async () => {
    const id = await criarOcorrencia(CIDADAO_UID);
    const db = comoUsuario(OUTRO_CIDADAO_UID);
    await assertSucceeds(
      db.doc(`ocorrencias/${id}`).update({
        likedBy: [OUTRO_CIDADAO_UID],
        likes: 1,
      }),
    );
  });
});

// ── Moderação (implementada nesta sessão) ───────────────────────────────────

describe('Moderação de conteúdo', () => {
  async function criarDenunciaModeracao(ocorrenciaId, denuncianteId) {
    const db = comoUsuario(denuncianteId);
    const ref = db.collection('denuncias_moderacao').doc();
    await assertSucceeds(
      ref.set({
        alvoTipo: 'ocorrencia',
        ocorrenciaId,
        comentarioId: null,
        denuncianteId,
        motivo: 'Conteúdo ofensivo',
        detalhe: null,
        status: 'pendente',
        criadoEm: serverTimestamp(),
      }),
    );
    return ref.id;
  }

  it('qualquer usuário logado pode denunciar conteúdo abusivo', async () => {
    const ocId = await criarOcorrencia(CIDADAO_UID);
    await criarDenunciaModeracao(ocId, OUTRO_CIDADAO_UID);
  });

  it('cidadão comum não lê a fila de denúncias de moderação', async () => {
    const ocId = await criarOcorrencia(CIDADAO_UID);
    const denunciaId = await criarDenunciaModeracao(ocId, OUTRO_CIDADAO_UID);
    const db = comoUsuario(OUTRO_CIDADAO_UID);
    await assertFails(db.doc(`denuncias_moderacao/${denunciaId}`).get());
  });

  it('autoridade lê e resolve uma denúncia de moderação', async () => {
    const ocId = await criarOcorrencia(CIDADAO_UID);
    const denunciaId = await criarDenunciaModeracao(ocId, OUTRO_CIDADAO_UID);
    await concederAutoridade(AUTORIDADE_UID);
    const db = comoUsuario(AUTORIDADE_UID);
    await assertSucceeds(db.doc(`denuncias_moderacao/${denunciaId}`).get());
    await assertSucceeds(
      db.doc(`denuncias_moderacao/${denunciaId}`).update({
        status: 'revisada',
        resolvidoPor: AUTORIDADE_UID,
        resolvidoEm: serverTimestamp(),
      }),
    );
  });

  it('cidadão comum não consegue ocultar uma ocorrência denunciada', async () => {
    const ocId = await criarOcorrencia(CIDADAO_UID);
    const db = comoUsuario(OUTRO_CIDADAO_UID);
    await assertFails(db.doc(`ocorrencias/${ocId}`).update({ oculto: true }));
  });

  it('autoridade consegue ocultar uma ocorrência denunciada', async () => {
    const ocId = await criarOcorrencia(CIDADAO_UID);
    await concederAutoridade(AUTORIDADE_UID);
    const db = comoUsuario(AUTORIDADE_UID);
    await assertSucceeds(
      db.doc(`ocorrencias/${ocId}`).update({ oculto: true }),
    );
  });
});

// Sanidade: garante que as funções auxiliares acima realmente rodaram (evita
// um describe vazio passar silenciosamente se algo estiver mal configurado).
describe('Sanidade do ambiente de teste', () => {
  it('consegue criar e ler uma ocorrência própria', async () => {
    const id = await criarOcorrencia(CIDADAO_UID);
    const db = comoUsuario(CIDADAO_UID);
    const snap = await assertSucceeds(db.doc(`ocorrencias/${id}`).get());
    assert.equal(snap.data().usuarioId, CIDADAO_UID);
  });
});
