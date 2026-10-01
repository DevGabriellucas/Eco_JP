/**
 * Backfill do campo `oculto` em ocorrencias e comentarios.
 *
 * As regras passaram a liberar consultas publicas so com
 * where('oculto', '==', false), e o Firestore nao devolve nessa consulta os
 * documentos que nao tem o campo. Sem este backfill, todas as denuncias e
 * comentarios criados antes da mudanca somem do feed, do mapa e das
 * estatisticas.
 *
 * Ordem de implantacao:
 *   1. publicar o app que grava `oculto: false` e filtra as consultas;
 *   2. publicar os indices (firebase deploy --only firestore:indexes);
 *   3. rodar este script com --aplicar;
 *   4. so entao publicar as regras (firebase deploy --only firestore:rules).
 *
 * Uso:
 *   GOOGLE_APPLICATION_CREDENTIALS=caminho/para/service-account.json \
 *     node scripts/backfill_oculto.mjs --projeto ecojp-8b952 [--aplicar]
 *
 * Sem --aplicar so relata (dry run). Nao altera documentos que ja tem o
 * campo — em especial, nao reexibe nada que a autoridade ocultou.
 */
import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const args = process.argv.slice(2);
const aplicar = args.includes('--aplicar');
const projectId = args[args.indexOf('--projeto') + 1];

if (!args.includes('--projeto') || !projectId) {
  console.error('Uso: node scripts/backfill_oculto.mjs --projeto <id> [--aplicar]');
  process.exit(1);
}

initializeApp({
  projectId,
  credential: process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? cert(process.env.GOOGLE_APPLICATION_CREDENTIALS)
    : applicationDefault(),
});

const db = getFirestore();
const LOTE = 400;

async function backfill(consulta, rotulo) {
  let pendentes = 0;
  let batch = db.batch();
  let noLote = 0;
  for (const doc of (await consulta.get()).docs) {
    if (Object.prototype.hasOwnProperty.call(doc.data(), 'oculto')) continue;
    pendentes++;
    if (!aplicar) continue;
    batch.update(doc.ref, { oculto: false });
    if (++noLote === LOTE) {
      await batch.commit();
      batch = db.batch();
      noLote = 0;
    }
  }
  if (aplicar && noLote > 0) await batch.commit();
  console.log(`${rotulo}: ${pendentes} sem o campo ${aplicar ? '(atualizados)' : '(dry run)'}`);
}

await backfill(db.collection('ocorrencias'), 'ocorrencias');
await backfill(db.collectionGroup('comentarios'), 'comentarios');
if (!aplicar) console.log('\nNada foi gravado. Rode de novo com --aplicar.');
