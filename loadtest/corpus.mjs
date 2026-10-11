// Cria um acervo de denúncias no emulador para que as consultas agregadas
// (mapa, estatísticas, dados públicos) tenham 500 documentos reais para ler.
// Usa o Admin SDK em lotes — muito mais rápido que gerar pelo k6.
//
//   node loadtest/corpus.mjs
//
// Quantidade via LOADTEST_CORPUS (padrão 2000).

import admin from 'firebase-admin';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Emulador não detectado. Defina FIRESTORE_EMULATOR_HOST.');
  process.exit(1);
}

const PROJETO = process.env.LOADTEST_PROJECT_ID ?? 'ecojp-loadtest';
const TOTAL = Number(process.env.LOADTEST_CORPUS ?? 2000);

admin.initializeApp({ projectId: PROJETO });
const db = admin.firestore();

const CATEGORIAS = ['Lixo', 'Queimada', 'Buraco', 'Esgoto', 'Enchentes'];
const BAIRROS = [
  ['Tambaú', -7.1195, -34.8286], ['Manaíra', -7.1052, -34.8348],
  ['Bancários', -7.1408, -34.8461], ['Cristo Redentor', -7.1638, -34.8482],
  ['Mangabeira', -7.1725, -34.8329], ['Bessa', -7.0834, -34.8395],
];
const FOTO = 'https://res.cloudinary.com/dmdghbgac/image/upload/v1/carga.jpg';

console.log(`Criando ${TOTAL} denúncias sintéticas...`);
let criadas = 0;
for (let inicio = 0; inicio < TOTAL; inicio += 500) {
  const lote = db.batch();
  const fim = Math.min(inicio + 500, TOTAL);
  for (let i = inicio; i < fim; i++) {
    const [bairro, lat, lon] = BAIRROS[i % BAIRROS.length];
    const categoria = CATEGORIAS[i % CATEGORIAS.length];
    lote.set(db.collection('ocorrencias').doc(), {
      titulo: `${categoria} acumulado em ${bairro}`,
      descricao: `Registro sintético ${i} do acervo de teste de carga. Não é uma ocorrência real.`,
      localizacao: `${bairro}, João Pessoa - PB`,
      latitude: lat + (Math.random() - 0.5) * 0.01,
      longitude: lon + (Math.random() - 0.5) * 0.01,
      tipoLixo: categoria,
      status: 'Pendente',
      // Espalha as datas ao longo de 90 dias para o ordenamento ser realista.
      dataCriacao: admin.firestore.Timestamp.fromMillis(
        Date.now() - Math.floor(Math.random() * 90 * 86400000),
      ),
      usuarioId: null, usuarioNome: null, usuarioFotoUrl: null,
      imagemUrl: FOTO, imagensUrls: [FOTO], anonima: true,
      likes: 0, dislikes: 0, comments: 0, shares: 0,
      likedBy: [], dislikedBy: [], fixada: false, oculto: false,
    });
  }
  await lote.commit();
  criadas = fim;
  process.stdout.write(`  ${criadas}/${TOTAL}\r`);
}
console.log(`\nAcervo pronto: ${criadas} denúncias.`);
process.exit(0);
