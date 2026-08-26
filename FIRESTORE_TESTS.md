# Testes das Regras de Firestore - EcoJP

Este documento explica como configurar e rodar os testes das regras de Firestore.

## 📋 Pré-requisitos

- Node.js 16+ instalado
- Firebase CLI instalado (`npm install -g firebase-tools`)
- Projeto Firebase configurado (`firebase login`)

## 🚀 Instalação

1. **Instalar dependências:**
```bash
npm install
```

## 🧪 Rodando os Testes

### Opção 1: Rodar testes com emulador local

1. **Iniciar o emulador do Firestore:**
```bash
firebase emulators:start
```

2. **Em outro terminal, rodar os testes:**
```bash
npm test
```

### Opção 2: Rodar testes em modo watch (desenvolvimento)

```bash
npm run test:watch
```

## 📝 Estrutura dos Testes

Os testes estão organizados em arquivos separados por entidade:

- **`firestore-tests/ocorrencia.test.js`** - Testes de criação e validação de denúncias
  - Validação de campos (título, descrição, localização)
  - Validação de coordenadas geográficas
  - Validação de categorias
  - Proteção de denunciante anônimo
  - Autenticação e email verificado

- **`firestore-tests/comentarios.test.js`** - Testes de comentários e respostas
  - Validação de comentários
  - Replies (respostas) a comentários
  - Proteção de acesso

## ✅ Casos de Teste Cobertos

### Ocorrências

- ✅ Rejeita título com menos de 3 caracteres
- ✅ Rejeita descrição com menos de 10 caracteres
- ✅ Rejeita categoria inválida
- ✅ Rejeita coordenadas (0,0)
- ✅ Rejeita coordenadas fora dos limites (lat: -90 a 90, lon: -180 a 180)
- ✅ Rejeita criação sem email verificado
- ✅ Rejeita criação sem autenticação
- ✅ Proteção de denunciante anônimo (sem usuarioId)
- ✅ Proteção de denunciante anônimo (sem nome)

### Comentários

- ✅ Rejeita comentário sem email verificado
- ✅ Rejeita comentário sem autenticação
- ✅ Rejeita comentário vazio ou apenas espaços
- ✅ Permite respostas com parentId válido

## 🔧 Adicionando Novos Testes

1. Crie um arquivo `.test.js` na pasta `firestore-tests/`
2. Use o padrão do Jest:

```javascript
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'ecojp-8b952',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe('Minha Suite de Testes', () => {
  test('meu teste', async () => {
    const db = testEnv.authenticatedContext('user1', {
      email_verified: true,
    }).firestore();

    await assertSucceeds(db.collection('ocorrencias').add({
      // dados...
    }));
  });
});
```

## 📊 Resultado Esperado

Quando tudo estiver correto, você verá:

```
PASS  firestore-tests/ocorrencia.test.js
  Ocorrências - Validação de Campos
    ✓ rejeita ocorrência com título muito curto (<3 caracteres)
    ✓ rejeita ocorrência com descrição muito curta (<10 caracteres)
    ...
  Ocorrências - Autenticação
    ✓ rejeita criação sem email verificado
    ...

PASS  firestore-tests/comentarios.test.js
  Comentários - Validação Básica
    ✓ rejeita comentário sem email verificado
    ...

Test Suites: 2 passed, 2 total
Tests:       15 passed, 15 total
```

## 🐛 Troubleshooting

### Erro: "Cannot find module '@firebase/rules-unit-testing'"

**Solução:** Execute `npm install` novamente para garantir que todas as dependências estão instaladas.

### Erro: "ECONNREFUSED - Connection refused"

**Solução:** Certifique-se de que o emulador do Firestore está rodando:
```bash
firebase emulators:start
```

### Erro: "projectId 'ecojp-8b952' not found"

**Solução:** O projeto deve estar configurado. Verifique:
```bash
firebase projects:list
firebase use ecojp-8b952
```

## 📚 Referências

- [Firebase Emulator Suite Documentation](https://firebase.google.com/docs/emulator-suite)
- [Firestore Security Rules Testing](https://firebase.google.com/docs/firestore/security/test-rules)
- [Jest Documentation](https://jestjs.io/)
