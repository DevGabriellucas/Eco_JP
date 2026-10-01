# Sprint 1 — resumo da execução (01/10/2026)

Os 49 cards da lista "Sprint 1" do Trello (origem: `docs/Code-review.md`) foram tratados na branch `Develop`. **Nada foi commitado** e **nenhum card foi movido no Trello**; as duas coisas esperam a sua revisão.

## Verificação
- `flutter analyze`: sem issues
- `flutter test`: 180 testes passando (eram 155)
- Regras do Firestore no emulador: 99 testes passando (eram 30)
- `dart format lib test` aplicado (o CI agora bloqueia formatação)
- Gradle (`gradlew help`) compila

## Ordem de implantação (importante)
1. Publicar o app novo (grava `oculto: false`, filtra as consultas, usa o carimbo de reação etc.).
2. `firebase deploy --only firestore:indexes` (novos índices: `oculto + dataCriacao` e o grupo `compartilhamentos.uid`).
3. `npm run backfill:oculto -- --projeto ecojp-8b952` (dry run) e depois com `--aplicar`. Sem isso, as denúncias e comentários antigos somem do feed.
4. Só então `firebase deploy --only firestore:rules`.
5. Opcional: `npm run backfill:nomes -- --projeto ecojp-8b952` (agora ordena pela conta mais antiga e detecta colisões no dry run).

As regras novas são incompatíveis com versões antigas do app (consultas sem filtro de `oculto`, reação sem carimbo, nome livre). Publique o app antes e espere a adoção.

## Pendências manuais (Console / contas)
- **Assinatura (card 11):** criar os secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD` no GitHub; cadastrar SHA-1/SHA-256 da chave de upload e do Play App Signing no Firebase e no App Check. **Atenção:** `flutter build apk --release` local agora falha sem `android/key.properties`; para teste local use `ECOJP_PERMITIR_RELEASE_DEBUG=true`.
- **App Check (card 13):** registrar br.com.ecojp.app (Android, iOS e web) no Firebase, rodar `flutterfire configure`, criar a chave reCAPTCHA v3 e passar `--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=...` no build web, ligar App Attest no App ID da Apple. Só depois ligar a imposição.
- **iOS / Google (card 39):** `GIDClientID` e o esquema `REVERSED_CLIENT_ID` no `Info.plist` (vêm do `GoogleService-Info.plist`).
- **Chave do Maps (card 38):** restringir a chave Android por pacote + SHA-1; criar chave de servidor separada para `tools/geocode_bairros.mjs`; criar chave web restrita por domínio e trocar `SUA_CHAVE_WEB` em `web/index.html`.
- **Cloudinary (card 1/34):** adicionar transformação de remoção de metadados no upload preset; a exclusão da mídia junto com a conta depende de uma Cloud Function (a política agora diz isso).
- **Política (card 32):** a versão subiu para 2026-10-01, então todos vão ver o consentimento de novo. Ainda precisa de revisão jurídica e do e-mail do DPO.

## O que mudou, por área
- **Privacidade/LGPD:** EXIF/GPS removido de verdade das fotos (inclusive a de perfil) e metadados do vídeo neutralizados; denúncia anônima nasce num único batch com `dono/info` (regra impede "sequestro"); coordenadas da anônima arredondadas (~100 m); aviso ao autor anônimo antes de comentar; conteúdo ocultado só para dono e autoridade; exportação inclui as anônimas; exclusão reautentica antes, apaga em lotes e não falha por reserva de nome; Analytics sem o parâmetro `anonima`.
- **Regras:** nome público = nome do perfil; foto só do Cloudinary/Google; selo de autoridade só pela autoridade; notificações com ID determinístico e ligadas a ação real; status só pela autoridade com evento de auditoria obrigatório; compartilhamento uma vez por usuário; intervalo mínimo entre reações; geofence de João Pessoa; `meta`, `bairro`, `municipioId`, `nomes_reservados` e `denuncias_moderacao` validados.
- **Cadastro/login:** nome em uso mostra mensagem (o redirect espera o cadastro terminar); e-mail de verificação só depois da reserva; token renovado após confirmar o e-mail; login Google cria perfil com nome reservado (nunca o prefixo do e-mail); troca de nome libera o antigo só depois de salvar.
- **Funcionalidades:** status derivado do ciclo oficial (filtros e pizza funcionam); cronograma de coleta carrega; "traçar rota" no Android 11+; deep link `ecojp://` no Android e com destino pendente até o login; feed paginado com `get()`; vídeo só baixa ao tocar; reverter status é uma ação própria; fila de moderação sem spinner herdado; painel de comentários em português e com "Comentário removido"; bairro estruturado no ranking.
- **CI/build:** release exige a chave de upload, roda análise/testes e versiona pela tag; actions fixadas por SHA; Flutter 3.47.2 e firebase-tools 15.28.2 fixados; iOS 15.0, descrição de microfone e entitlement de App Attest.
- **Limpeza/docs:** `firestore-tests/` (não testava nada) removido e `npm test` aponta para a suíte real; loadtest corrigido (classificação de erros, retentativas, rollback, página de 10, filtro `oculto`); README/ROADMAP/ADR alinhados ao código; dependências `google_generative_ai` e `geocoding` removidas; sobras do template trocadas.

## Ressalvas
- Card 24: as telas e o PDF agora avisam quando o recorte de 500 foi atingido e mostram o total real (`count()`), mas o mapa por viewport/geohash não foi feito (só o rótulo).
- Card 35: o comentário do autor anônimo continua mostrando nome e foto; agora há um aviso antes. Comentar "como Autor da denúncia" exigiria mudar o modelo de comentário.
- `COMSPEC` desta máquina aponta para `C:\msys64\ucrt64\bin`: é isso que quebra o `flutter.bat` ("Acesso negado") e o `firebase emulators:exec`. Vale corrigir nas variáveis de ambiente do Windows.
