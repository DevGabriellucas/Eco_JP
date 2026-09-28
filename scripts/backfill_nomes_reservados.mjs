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

// Pagina por __name__ em vez de ler tudo de uma vez: numa base grande, um
// get() unico estoura memoria e o deadline do Firestore.
const PAGINA = 500;
let ultimo = null;
let total = 0;

for (;;) {
  let q = db.collection('usuarios').orderBy('__name__').limit(PAGINA);
  if (ultimo) q = q.startAfter(ultimo);
  const snap = await q.get();
  if (snap.empty) break;

  for (const doc of snap.docs) {
    total += 1;
    const nome = doc.get('nome');
    if (typeof nome !== 'string') continue;

    const slug = slugify(nome);
    if (!slug) {
      semSlug.push({ uid: doc.id, nome });
      continue;
    }

    const ref = db.collection('nomes_reservados').doc(slug);
    const atual = await ref.get();

    if (atual.exists) {
      if (atual.get('uid') === doc.id) jaExistiam.push({ uid: doc.id, slug });
      else colisoes.push({ slug, nome, dono: atual.get('uid'), perdeu: doc.id });
      continue;
    }

    if (aplicar) {
      await ref.set({
        uid: doc.id,
        nome: nome.trim().slice(0, 40),
        criadoEm: FieldValue.serverTimestamp(),
      });
    }
    criadas.push({ uid: doc.id, slug });
  }

  ultimo = snap.docs[snap.docs.length - 1];
  if (snap.size < PAGINA) break;
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
