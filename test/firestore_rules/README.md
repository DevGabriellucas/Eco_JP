# Testes das regras de segurança do Firestore

Valida `firestore.rules` contra o emulador do Firestore usando
`@firebase/rules-unit-testing`.

## Pré-requisitos

- Node.js + npm
- Firebase CLI (`firebase --version`)
- Java (o emulador do Firestore roda na JVM)

## Rodar

```bash
cd test/firestore_rules
npm install        # só na primeira vez
npm test
```

O comando `npm test` sobe o emulador do Firestore, executa o Jest e derruba o
emulador automaticamente (via `firebase emulators:exec`).

## O que é coberto

- Leitura de ocorrências exige autenticação
- Criação de conteúdo exige e-mail verificado
- Não é possível forjar o autor de uma denúncia
- Denúncia anônima não grava o UID real no documento público (S2)
- Coordenada (0,0) e imagens fora do Cloudinary do projeto são rejeitadas
- Moderação (ocultar) e status oficial só pela autoridade
- Papel de `autoridade` não pode ser autoconcedido pelo app
- Usuário só edita o próprio perfil

## Observação

As regras exigem `dataCriacao == request.time`, então os testes usam
`serverTimestamp()` (não `new Date()`) ao criar documentos.
