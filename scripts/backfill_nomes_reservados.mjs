/**
 * Backfill do indice de unicidade de nomes (`nomes_reservados`).
 *
 * As contas criadas antes do indice nao tem reserva. Sem este backfill, um
 * usuario novo consegue reservar o nome de um usuario antigo — a checagem
 * antiga (varredura da colecao `usuarios`) nao existe mais.
 *
 * Rode UMA VEZ por ambiente, antes de publicar a versao com a reserva:
 *   GOOGLE_APPLICATION_CREDENTIALS=caminho/para/service-account.json \
 *     node scripts/backfill_nomes_reservados.mjs --projeto ecojp-8b952
 *
 * Sem --aplicar o script so relata (dry run). Roda com privilegio de admin,
 * entao ignora as Rules: a protecao contra sobrescrever e a checagem explicita
 * de existencia abaixo.
 *
 * Colisoes: contas antigas podem ja compartilhar o mesmo slug ("Jose Silva" e
 * "jose silva"), porque a checagem antiga comparava so trim+lowercase e nao
 * era atomica. A reserva fica com a conta mais antiga e as demais sao
 * listadas no relatorio final para resolucao manual — o script nao renomeia
 * ninguem sozinho.
 */
import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const aplicar = args.includes('--aplicar');
const projectId = args[args.indexOf('--projeto') + 1];

if (!args.includes('--projeto') || !projectId) {
  console.error('Uso: node scripts/backfill_nomes_reservados.mjs --projeto <id> [--aplicar]');
  process.exit(1);
}

// Paridade com slugify() de lib/utils/texto.dart. Se um dos dois mudar, o
// outro precisa mudar junto: divergencia gera reserva com ID que o app nunca
// consulta, e a unicidade para de valer sem nenhum erro visivel.
const COM_ACENTO = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
const SEM_ACENTO = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';

function removerAcentos(texto) {
  return [...texto]
    .map((c) => {
      const i = COM_ACENTO.indexOf(c);
      return i === -1 ? c : SEM_ACENTO[i];
    })
    .join('');
}

// Paridade com sanitizarLinhaUnica() de lib/utils/texto.dart: o app gera o
// slug a partir do nome higienizado (UsuarioService.idDoNome). Sem isto, um
// nome com caractere invisível no meio geraria aqui um slug diferente do que
// o app consulta.
function removivel(c) {
  if (c < 0x20) return c !== 0x09 && c !== 0x0a;
  if (c === 0x7f) return true;
  if (c >= 0x80 && c <= 0x9f) return true;
  if (c >= 0x200b && c <= 0x200d) return true;
  if (c === 0xfeff) return true;
  if (c >= 0x202a && c <= 0x202e) return true;
  if (c >= 0x2066 && c <= 0x2069) return true;
  return false;
}

function sanitizarLinhaUnica(texto) {
  return [...texto]
    .filter((ch) => !removivel(ch.codePointAt(0)))
    .join('')
    .replace(/\s+/g, ' ')
    .trim();
}

function slugify(texto) {
  return removerAcentos(texto)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

initializeApp({
  projectId,
  credential: process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? cert(process.env.GOOGLE_APPLICATION_CREDENTIALS)
    : applicationDefault(),
});

const db = getFirestore();

const criadas = [];
const jaExistiam = [];
const colisoes = [];
const semSlug = [];

// 1. Lê todos os perfis, paginando por __name__ (um get() único estoura
//    memória e o deadline do Firestore numa base grande).
const PAGINA = 500;
const perfis = [];
let ultimo = null;
for (;;) {
  let q = db.collection('usuarios').orderBy('__name__').limit(PAGINA);
  if (ultimo) q = q.startAfter(ultimo);
  const snap = await q.get();
  if (snap.empty) break;
  for (const doc of snap.docs) {
    const nome = doc.get('nome');
    if (typeof nome === 'string') perfis.push({ uid: doc.id, nome });
  }
  ultimo = snap.docs[snap.docs.length - 1];
  if (snap.size < PAGINA) break;
}
const total = perfis.length;

// 2. Data de criação de cada conta no Auth. Na colisão o nome fica com a
//    conta MAIS ANTIGA — antes o laço seguia a ordem do UID (aleatória), ao
//    contrário do que este cabeçalho promete.
const auth = getAuth();
const criacao = new Map();
for (let i = 0; i < perfis.length; i += 100) {
  const lote = perfis.slice(i, i + 100).map((p) => ({ uid: p.uid }));
  const { users } = await auth.getUsers(lote);
  for (const u of users) criacao.set(u.uid, Date.parse(u.metadata.creationTime));
}
// Contas sem registro no Auth (apagadas) vão para o fim.
perfis.sort(
  (a, b) => (criacao.get(a.uid) ?? Infinity) - (criacao.get(b.uid) ?? Infinity),
);

// 3. Reserva em ordem. `reservadosAgora` simula as reservas desta execução:
//    no dry run nada é gravado, então sem ele duas contas antigas com o mesmo
//    slug passavam as duas como "a criar" e o relatório dizia 0 colisões.
const reservadosAgora = new Map();
for (const { uid, nome: nomeCru } of perfis) {
  const nome = sanitizarLinhaUnica(nomeCru);
  const slug = slugify(nome);
  if (!slug) {
    semSlug.push({ uid, nome: nomeCru });
    continue;
  }

  const donoNaExecucao = reservadosAgora.get(slug);
  if (donoNaExecucao) {
    colisoes.push({ slug, nome, dono: donoNaExecucao, perdeu: uid });
    continue;
  }

  const ref = db.collection('nomes_reservados').doc(slug);
  const atual = await ref.get();
  if (atual.exists) {
    if (atual.get('uid') === uid) jaExistiam.push({ uid, slug });
    else colisoes.push({ slug, nome, dono: atual.get('uid'), perdeu: uid });
    continue;
  }

  if (aplicar) {
    await ref.set({
      uid,
      nome: nome.slice(0, 40),
      criadoEm: FieldValue.serverTimestamp(),
    });
  }
  reservadosAgora.set(slug, uid);
  criadas.push({ uid, slug });
}

console.log(`\nPerfis lidos ......... ${total}`);
console.log(`Reservas ${aplicar ? 'criadas' : 'a criar'} ..... ${criadas.length}`);
console.log(`Ja reservadas ........ ${jaExistiam.length}`);
console.log(`Sem slug possivel .... ${semSlug.length}`);
console.log(`Colisoes ............. ${colisoes.length}`);

if (semSlug.length) {
  console.log('\nNomes sem letra/digito (o app passou a recusar; resolver manualmente):');
  for (const s of semSlug) console.log(`  ${s.uid}  ${JSON.stringify(s.nome)}`);
}

if (colisoes.length) {
  console.log('\nCOLISOES — o slug ficou com a conta listada em "dono";');
  console.log('as contas em "perdeu" seguem usando o nome sem reserva:');
  for (const c of colisoes) {
    console.log(`  ${c.slug}  dono=${c.dono}  perdeu=${c.perdeu}  (${c.nome})`);
  }
}

if (!aplicar) console.log('\nDry run. Rode de novo com --aplicar para gravar.');
