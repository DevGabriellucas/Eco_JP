#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
//  Gera/atualiza as coordenadas dos bairros em assets/data/rotas_coleta.json
//  usando a Google Geocoding API. Roda UMA vez (precisa de internet); depois o
//  app lê o campo "coord" direto, sem depender de rede nem de chute.
//
//  PRÉ-REQUISITOS
//    • Node 18+ (usa o fetch nativo).
//    • A "Geocoding API" habilitada no Google Cloud Console, na mesma conta da
//      chave do mapa. (APIs e serviços → Biblioteca → Geocoding API → Ativar.)
//
//  COMO RODAR (na raiz do projeto, com internet):
//    node tools/geocode_bairros.mjs
//
//  A chave é lida automaticamente de android/local.properties (MAPS_API_KEY).
//  Para usar outra chave:  node tools/geocode_bairros.mjs --key=SUA_CHAVE
//
//  O script:
//    1. lê todos os bairros distintos do JSON;
//    2. geocoda cada um (tentando algumas variações de busca);
//    3. só aceita resultados DENTRO da caixa de João Pessoa;
//    4. grava "coord": { "lat": ..., "lng": ... } em cada bairro;
//    5. imprime um relatório com os que falharam (pra ajustar na mão).
// ─────────────────────────────────────────────────────────────────────────────

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const raiz = join(__dirname, '..');
const jsonPath = join(raiz, 'assets', 'data', 'rotas_coleta.json');

// Caixa (bounding box) aproximada de João Pessoa — a MESMA usada no app.
const JP = { latMin: -7.30, latMax: -6.95, lngMin: -35.0, lngMax: -34.75 };
const dentroDeJP = (lat, lng) =>
  lat >= JP.latMin && lat <= JP.latMax && lng >= JP.lngMin && lng <= JP.lngMax;

function lerChave() {
  const arg = process.argv.find((a) => a.startsWith('--key='));
  if (arg) return arg.slice('--key='.length).trim();
  if (process.env.MAPS_API_KEY) return process.env.MAPS_API_KEY.trim();
  if (process.env.GOOGLE_MAPS_API_KEY) return process.env.GOOGLE_MAPS_API_KEY.trim();
  try {
    const props = readFileSync(join(raiz, 'android', 'local.properties'), 'utf8');
    const m = props.match(/^\s*MAPS_API_KEY\s*=\s*(.+)\s*$/m);
    if (m) return m[1].trim();
  } catch {
    /* sem local.properties */
  }
  return null;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Tenta algumas variações de endereço até achar um resultado dentro de JP.
async function geocodar(nome, chave) {
  const semParenteses = nome.replace(/\s*\(.*?\)\s*/g, ' ').trim();
  const variacoes = [
    `${nome}, João Pessoa - PB, Brasil`,
    `${semParenteses}, João Pessoa - PB, Brasil`,
    `bairro ${semParenteses}, João Pessoa, Paraíba, Brasil`,
  ];

  for (const endereco of variacoes) {
    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.searchParams.set('address', endereco);
    url.searchParams.set(
      'components',
      'country:BR|administrative_area:PB|locality:João Pessoa',
    );
    url.searchParams.set('language', 'pt-BR');
    url.searchParams.set('region', 'br');
    url.searchParams.set('key', chave);

    let data;
    try {
      const res = await fetch(url);
      data = await res.json();
    } catch (e) {
      console.error(`  ! erro de rede em "${endereco}": ${e.message}`);
      continue;
    }

    if (data.status === 'REQUEST_DENIED' || data.status === 'INVALID_REQUEST') {
      throw new Error(
        `Google recusou a requisição (${data.status}): ${data.error_message || ''}\n` +
          `Verifique se a "Geocoding API" está habilitada e se a chave permite.`,
      );
    }
    if (data.status === 'OVER_QUERY_LIMIT') {
      throw new Error('OVER_QUERY_LIMIT: cota da API estourada. Tente mais tarde.');
    }

    for (const r of data.results || []) {
      const loc = r.geometry?.location;
      if (!loc) continue;
      if (dentroDeJP(loc.lat, loc.lng)) {
        return { lat: round(loc.lat), lng: round(loc.lng), via: endereco };
      }
    }
  }
  return null;
}

const round = (n) => Math.round(n * 1e5) / 1e5; // 5 casas (~1 m)

async function main() {
  const chave = lerChave();
  if (!chave) {
    console.error(
      'ERRO: chave não encontrada. Coloque MAPS_API_KEY em android/local.properties ' +
        'ou rode com --key=SUA_CHAVE.',
    );
    process.exit(1);
  }

  const json = JSON.parse(readFileSync(jsonPath, 'utf8'));

  // Coleta nomes distintos preservando referências a TODAS as entradas.
  const porNome = new Map(); // nome -> [bairroObj, ...]
  for (const grupo of json.grupos) {
    for (const b of grupo.bairros) {
      if (!porNome.has(b.nome)) porNome.set(b.nome, []);
      porNome.get(b.nome).push(b);
    }
  }

  console.log(`Geocodificando ${porNome.size} bairros distintos...\n`);

  const ok = [];
  const falharam = [];

  for (const [nome, entradas] of porNome) {
    const coord = await geocodar(nome, chave);
    if (coord) {
      for (const b of entradas) b.coord = { lat: coord.lat, lng: coord.lng };
      ok.push(nome);
      console.log(`  ✓ ${nome.padEnd(34)} (${coord.lat}, ${coord.lng})`);
    } else {
      falharam.push(nome);
      console.log(`  ✗ ${nome.padEnd(34)} — sem resultado dentro de João Pessoa`);
    }
    await sleep(120); // gentileza com a API
  }

  writeFileSync(jsonPath, JSON.stringify(json, null, 2) + '\n', 'utf8');

  console.log(`\nConcluído: ${ok.length} com coordenada, ${falharam.length} falharam.`);
  if (falharam.length) {
    console.log('\nBairros sem coordenada (ajuste "coord" na mão no JSON, se quiser):');
    for (const n of falharam) console.log(`  - ${n}`);
  }
  console.log(`\nArquivo atualizado: ${jsonPath}`);
  console.log('Confira no app e, se algum bairro ainda ficar torto, edite o "coord" dele no JSON.');
}

main().catch((e) => {
  console.error('\nFALHOU:', e.message);
  process.exit(1);
});
