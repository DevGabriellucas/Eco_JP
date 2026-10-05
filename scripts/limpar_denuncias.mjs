/**
 * Apaga TODAS as denúncias e o que depende delas, para começar uma
 * demonstração com o feed, o mapa e as estatísticas vazios.
 *
 * Apaga:
 *   - ocorrencias/* com as subcoleções (comentarios, historico,
 *     compartilhamentos, dono);
 *   - denuncias_moderacao/* (reports de denúncias e comentários);
 *   - notificacoes/{uid}/items/* (curtidas, comentários e conquistas que
 *     apontam para denúncias que deixam de existir);
 *   - usuarios/{uid}/minhas_denuncias_anonimas/*.
 *
 * Mantém usuários, perfis, seguidores, nomes reservados, consentimentos e
 * papéis. As fotos e vídeos ficam no Cloudinary (o upload é unsigned, o
 * Admin SDK não alcança).
 *
 * NÃO TEM VOLTA. Sem --aplicar só conta o que seria apagado (dry run).
 *
 * Uso:
 *   GOOGLE_APPLICATION_CREDENTIALS=caminho/para/service-account.json \
 *     node scripts/limpar_denuncias.mjs --projeto ecojp-8b952 [--aplicar]
 */
import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const aplicar = args.includes('--aplicar');
const projectId = args[args.indexOf('--projeto') + 1];

if (!args.includes('--projeto') || !projectId) {
  console.error('Uso: node scripts/limpar_denuncias.mjs --projeto <id> [--aplicar]');
  process.exit(1);
}

initializeApp({
  projectId,
  credential: process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? cert(process.env.GOOGLE_APPLICATION_CREDENTIALS)
    : applicationDefault(),
});

const db = getFirestore();

// recursiveDelete leva junto as subcoleções de cada documento. O prefixo
// protege os collectionGroup de pegar uma coleção homônima em outro lugar.
async function limpar(consulta, rotulo, prefixo = '') {
  const docs = (await consulta.get()).docs.filter((d) =>
    d.ref.path.startsWith(prefixo),
  );
  if (aplicar) {
    await Promise.all(docs.map((d) => db.recursiveDelete(d.ref)));
  }
  console.log(`${rotulo}: ${docs.length} ${aplicar ? '(apagados)' : '(dry run)'}`);
}

console.log(`Projeto: ${projectId}\n`);
await limpar(db.collection('ocorrencias'), 'ocorrencias (com subcoleções)');
await limpar(db.collection('denuncias_moderacao'), 'denuncias_moderacao');
await limpar(db.collectionGroup('items'), 'notificacoes/*/items', 'notificacoes/');
await limpar(
  db.collectionGroup('minhas_denuncias_anonimas'),
  'usuarios/*/minhas_denuncias_anonimas',
  'usuarios/',
);
if (!aplicar) console.log('\nNada foi apagado. Rode de novo com --aplicar.');
