# Code review do projeto EcoJP

**Data:** 30/09/2026
**Branch revisada:** `Develop` (commit `0015db7`)
**Escopo:** o repositório inteiro, fora os arquivos gerados ou de terceiros (`build/`, `.dart_tool/`, `node_modules/`)

## Como a revisão foi feita

A revisão foi feita em três etapas:

1. **Último commit (`0015db7`):** a suíte de teste de carga em `loadtest/` e o CI na `Develop`.
2. **Diff `main...HEAD`:** tudo o que a `Develop` tem a mais que a `main` (exclusão de conta, reserva de nome, App Check, troca do ID do app, script de backfill).
3. **Projeto inteiro, dividido em cinco áreas revisadas em paralelo:**
   - núcleo do app: `main.dart`, `core/`, `data/`, `models/`, `features/`, `services/`, `utils/`
   - telas de conta: login, cadastro, verificação de e-mail, perfil, termos, notificações e widgets compartilhados
   - telas principais: feed, formulário de denúncia, mapa, detalhe, estatísticas, filas de moderação e verificação
   - Firestore: regras, índices e testes das regras, conferidos contra o que o app lê e grava
   - plataforma e CI: Android, iOS, web, `pubspec`, workflows do GitHub, scripts, testes Dart e documentação

Os achados vêm da **leitura do código**. Nenhum teste foi executado e o emulador do Firestore não foi usado. Nove dos achados de gravidade alta foram conferidos diretamente no código-fonte e se confirmaram:
- EXIF (inclusive nas fontes do pacote `image` 4.9.1)
- `dono/info`
- selo de autoridade
- token de e-mail
- textos em inglês
- campo `status`
- `assets/data/`
- deployment target do iOS
- intent-filter do Android

Os números de linha se referem ao commit `0015db7` e podem mudar com as correções.

Cada item deste documento também está como cartão na lista **Sprint 1** do quadro EcoJP no Trello.

## Resumo

| Gravidade | Quantidade | Temas principais |
|---|---|---|
| Alta | 13 | privacidade (GPS nas fotos, denúncia anônima), segurança das regras, fluxos quebrados (cadastro, e-mail, exclusão de conta), release e iOS |
| Média | 29 | moderação, custo no Firestore/Cloudinary, LGPD, deep links, auditoria, CI, teste de carga |
| Baixa | 7 | robustez, acessibilidade, documentação, limpeza |

Achados que apareceram em mais de uma área foram unidos num item só.

## Ordem sugerida de correção

1. **Privacidade:** A1, A2, A3 e M2. São os que expõem pessoas.
2. **Fluxos básicos:** A4 a A10 e M1.
3. **Release:** A11 a A13. Tudo antes de ligar a imposição do App Check.
4. **Custo e estabilidade:** M9, M10, M11, M12, M13.
5. **Política de privacidade e documentação:** M19 a M22 e B1, alinhadas com o que o código faz.

---

## Gravidade alta

### A1. A limpeza de EXIF não remove o GPS das fotos (nem os metadados do vídeo)

**Etiquetas:** LGPD · Bloqueador

**Problema:** a "limpeza" de EXIF não remove nada. No pacote `image` 4.9.1, o decode de JPEG copia o EXIF inteiro (`_jpeg_quantize_io.dart:224`, `ExifData.from(jpeg.exif)`), e o `encodeJpg` grava de volta (`jpeg_encoder.dart:61`, `_writeExif`), incluindo o GPS. O comentário "decodeImage já não preserva EXIF" está errado. Com isso, uma denúncia anônima com foto de celular publica as coordenadas de onde a foto foi tirada. Se foi em casa, identifica o denunciante.

**Onde:**
- `lib/utils/imagem_privacidade.dart:26-29`
- `lib/pages/form_ocorrencia/controllers/media_controller.dart:58-61`
- o vídeo sobe sem limpeza em `media_controller.dart:104-115`
- o teste `test/utils/imagem_privacidade_test.dart:28-44` se pula sozinho (`markTestSkipped`), e o da linha 19 usa uma imagem sem EXIF, então passa mesmo que a função não faça nada

**Correção:**
- `imagem.exif = img.ExifData()` antes do `encodeJpg`, aplicando `bakeOrientation` antes
- se o decode falhar, recusar a foto em vez de enviar o original
- teste com um JPEG real com GPS como fixture, sem skip
- transformação no Cloudinary que remove metadados, como defesa extra
- tratar os metadados do vídeo (MP4 de câmera costuma ter o átomo de localização `©xyz`)

### A2. Qualquer usuário pode se tornar dono de uma denúncia anônima

**Etiquetas:** Bloqueador

**Problema:** a ocorrência, o `dono/info` e o ponteiro em `minhas_denuncias_anonimas` são gravados em três escritas separadas. A regra aceita o primeiro usuário verificado que gravar `dono/info`. Isso permite dois cenários:
- **Ataque:** um script escuta o feed e grava `dono/info` com o próprio UID antes do dono real. A partir daí, edita ou apaga a denúncia de outra pessoa.
- **Falha comum:** se a rede cair entre as escritas, a denúncia fica sem dono. Ninguém consegue editá-la, ela não aparece em "Minhas denúncias", não é apagada na exclusão de conta, e o reenvio gera duplicata.

**Onde:**
- `lib/data/repositories/ocorrencia_repository.dart:63-80`
- `firestore.rules:584-588` (create de `dono`)
- `firestore.rules:609-611` (o ponteiro aceita a denúncia de outra pessoa)
- `firestore.rules:578` (aceita qualquer `docId`)

**Correção:**
- gerar o ID com `_ocorrenciasRef.doc()` e gravar as três escritas num único `WriteBatch`
- nas regras, usar `getAfter`/`existsAfter` e restringir a `docId == 'info'`
- em `isValidOcorrencia`, quando `anonima == true`, exigir `dono/info` no mesmo batch
- criar o teste de regra "terceiro NÃO cria dono/info"

### A3. Selo de autoridade e nome/foto forjáveis

**Etiquetas:** Bloqueador

**Problema:** a regra aceita `autorAutoridade: true` de qualquer conta verificada, e `userName`, `usuarioNome` e as URLs de foto são texto livre. Isso permite:
- comentar como "Prefeitura de João Pessoa" com o selo azul oficial
- publicar com o nome reservado de outra pessoa
- usar uma URL de foto num servidor próprio, que registra o IP de quem abre o feed

**Onde:**
- `firestore.rules:384`, `:375-377`, `:94-105`
- `firestore.rules:98-100` (`isOptionalPublicPhoto`)
- `lib/widgets/occurrence_comments_sheet.dart:154`
- `lib/models/comentario_model.dart:52-53`

**Correção:**
- `(!('autorAutoridade' in data) || data.autorAutoridade == false || isAutoridade())`
- exigir que o nome seja igual a `get(/usuarios/$(uid)).data.nome`, ou resolver o nome na leitura
- aceitar só URLs de `res.cloudinary.com/dmdghbgac/` e `lh3.googleusercontent.com`

### A4. O token não é renovado depois da confirmação do e-mail

**Problema:** `recarregarEVerificarEmail` só faz `user.reload()`, que não renova o ID token. As regras leem `request.auth.token.email_verified`. Depois de confirmar o e-mail, a pessoa não consegue denunciar, comentar nem curtir por até 1 hora (permission-denied). As fotos já enviadas ficam órfãs no Cloudinary.

**Onde:**
- `lib/services/auth_service.dart:210-219`
- `lib/pages/verificacao_email_page.dart:84-92`

**Correção:** quando `emailVerified == true`, chamar `await user.getIdToken(true)` antes de devolver true ou invalidar o provider. Testar em aparelho real.

### A5. Cadastro com nome já em uso (ou longo demais) falha sem mensagem

**Problema:** logo que a conta é criada, o redirect troca `/cadastro` por `/verificacao-email`, e a página é desmontada antes de `reservarNome` terminar. A conta é apagada em silêncio e nenhuma mensagem aparece. O e-mail de verificação ainda chega, para uma conta que já não existe.

Além disso, um nome com mais de 40 caracteres é negado pela regra e reportado como "nome já em uso". O campo de nome do cadastro não tem `maxLength`.

**Onde:** `lib/pages/cadastro_page.dart:160-172`

**Correção:**
- reservar o nome antes de o redirect agir (flag "cadastro em andamento"), ou levar o erro para um provider global
- só enviar o e-mail de verificação depois que a reserva der certo
- `maxLength: 40` e uma mensagem específica para cada caso

### A6. Login com Google publica o prefixo do e-mail como nome

**Etiquetas:** LGPD

**Problema:** o login com Google não cria `usuarios/{uid}` nem reserva nome. A tela usa um `UsuarioModel` provisório com o prefixo do e-mail como nome, e esse objeto vai para "Editar perfil". Isso causa dois problemas:
- ao salvar só a bio, o prefixo vira o nome público e é propagado para todas as denúncias da pessoa
- abrir a edição antes de o perfil carregar apaga foto, bio e bairro e libera o nome antigo

**Onde:**
- `lib/pages/perfil/perfil_page.dart:70-74, 187-188, 379`
- `lib/pages/perfil/editar_perfil_page.dart:168-193`
- `lib/pages/form_ocorrencia_page.dart:437`
- `lib/widgets/occurrence_comments_sheet.dart:196`

**Correção:**
- não abrir a edição enquanto o perfil não carregou
- nunca usar o e-mail como nome de fallback
- criar o perfil e a reserva de nome no primeiro login com Google (por exemplo, no gate de consentimento)

### A7. A exclusão de conta falha ou deixa o usuário logado sem perfil

**Etiquetas:** LGPD

**Problemas:**
1. `excluirTodosDados` apaga `nomes_reservados/{slug}` sem checar se o documento existe e se é do usuário. A regra nega, e o batch, que também leva perfil e consentimento, falha. Afeta todas as contas criadas antes do commit `a3d1db4`. Arquivo: `lib/services/usuario_service.dart:189-192`.
2. Com 21 ou mais denúncias anônimas, o batch passa do limite de 20 `exists()`/`get()` das regras e nunca é gravado. Arquivo: `usuario_service.dart:148`.
3. Os dados são apagados antes da reautenticação. Quem entra com Google não tem senha, e o usuário fica logado em `/home` sem perfil. Arquivo: `lib/pages/perfil/configuracoes_conta_page.dart:203`.

**Correção:**
- ler a reserva e só apagar se `exists && uid == uid`
- apagar as denúncias anônimas em lotes de até cerca de 20
- reautenticar (Google ou senha) **antes** de apagar qualquer dado

### A8. O campo `status` é sempre "Pendente", e filtros e gráfico de status não funcionam

**Problema:** as regras só aceitam `status == 'Pendente'` na criação, e nenhuma regra de update muda esse campo. O chip "Resolvido" do feed e do mapa volta sempre vazio, e a pizza de status da autoridade mostra 100% pendente.

**Onde:**
- `firestore.rules:174`
- `lib/pages/estatisticas_page.dart:275, 311-315`
- `lib/pages/home_page.dart:481-483`
- `lib/pages/mapPage/controller/map_controller.dart:181-184`

**Correção:** derivar o status de `verificada` + `statusOficial` nesses três pontos (já existe `EstagioOficial` em `occurrence_types.dart`) e parar de usar `status`.

### A9. `assets/data/` não está no pubspec (o cronograma de coleta fica vazio)

**Problema:** `assets/data/rotas_coleta.json` não está declarado em `flutter: assets:`. Em qualquer build, o `rootBundle.loadString` lança exceção, o `catch (_)` engole o erro, e o cronograma de coleta aparece vazio sem aviso.

**Onde:**
- `pubspec.yaml:53-54`
- `lib/services/rota_coleta_service.dart:25`
- `lib/pages/dados_publicos_page.dart:54-56`

**Correção:**
- adicionar `- assets/data/`
- mostrar o erro em vez de engoli-lo
- criar um teste que chame `RotaColetaService().carregarRotas()`

### A10. "Traçar rota" falha no Android 11+ (faltam `<queries>`)

**Problema:** sem `<queries>` de VIEW para `https` e `geo`, a visibilidade de pacotes (targetSdk 36) faz `canLaunchUrl` retornar false. O botão de rota sempre diz que não foi possível abrir um app de mapas.

**Onde:**
- `android/app/src/main/AndroidManifest.xml:56-61`
- `lib/utils/navegacao_externa.dart:23-30`

**Correção:** declarar os `<intent>` de VIEW para `https` e `geo`, ou chamar `launchUrl` direto dentro de try/catch.

### A11. O release sai assinado com uma chave de debug aleatória

**Etiquetas:** Bloqueador · Tarefa no Console

**Problema:** nenhum workflow cria `key.properties`, e o Gradle cai sem avisar na chave de debug efêmera do runner. Cada tag gera um APK com assinatura diferente. Com isso:
- quem tem a versão anterior não consegue atualizar
- o login com Google dá `ApiException 10`
- o App Check (Play Integrity) recusa o app

**Onde:**
- `android/app/build.gradle.kts:76-82`
- `.github/workflows/release.yml:45-53`
- `.github/workflows/ci.yml:86-94`

**Correção:**
- injetar o `.jks` e as senhas por secrets no `release.yml`
- lançar `GradleException` em task de release sem `key.properties`
- cadastrar os SHA-1 e SHA-256 da chave de upload e do Play App Signing no Firebase e no App Check

### A12. iOS: deployment target 15.0 e `NSMicrophoneUsageDescription`

**Etiquetas:** Apresentação

**Problemas:**
- `IPHONEOS_DEPLOYMENT_TARGET = 13.0`, mas `firebase_core` 4.14.0 e `firebase_app_check` 0.4.7 exigem 15.0. O `pod install` (ou o SwiftPM) falha e nenhum build iOS sai. Arquivo: `ios/Runner.xcodeproj/project.pbxproj:353, 479, 530`.
- Falta `NSMicrophoneUsageDescription`. Gravar vídeo pela câmera (`form_ocorrencia_page.dart:192`) derruba o app, e a Apple rejeita na revisão. Arquivo: `ios/Runner/Info.plist`.

**Correção:**
- subir o target para 15.0 no projeto e no Podfile
- adicionar a descrição de uso do microfone em português

### A13. App Check: registrar `br.com.ecojp.app`, provedor web e App Attest antes de impor

**Etiquetas:** Bloqueador · Tarefa no Console

**Problema:** hoje, ligar a imposição bloqueia tudo:
- o app ainda está registrado no Firebase como `com.example` (`lib/firebase_options.dart:66`)
- não há `providerWeb` (reCAPTCHA) (`lib/main.dart:248`)
- o iOS usa App Attest em release, mas não há `Runner.entitlements` nem a capability
- o Crashlytics não existe no web nem no Windows e derruba a inicialização (`lib/main.dart:62-72`)

**Correção:**
- registrar os apps com o novo ID e rodar `flutterfire configure`
- adicionar o provedor web e a capability App Attest
- proteger o Crashlytics por plataforma
- só então ligar a imposição no Console

---

## Gravidade média

### M1. Troca de nome: o antigo é liberado cedo demais e o slug vem do texto cru

**Problemas:**
- `trocarNome` move a reserva antes do upload da foto e do `salvarPerfil`. Se um dos dois falhar, o nome antigo já foi liberado e outra conta pode registrá-lo. Arquivo: `lib/pages/perfil/editar_perfil_page.dart:168`.
- O slug é gerado do texto cru, mas o nome salvo é o sanitizado. Com um caractere invisível, dá para registrar um "João Silva" idêntico ao de outro usuário. Arquivo: `lib/services/usuario_service.dart:238`.

**Correção:**
- trocar a reserva por último, ou revertê-la em caso de falha
- gerar o slug a partir de `sanitizarLinhaUnica(nome)`

### M2. O conteúdo ocultado pela moderação continua legível

**Etiquetas:** LGPD

**Problema:** `oculto` só é filtrado no feed e no mapa. As regras deixam qualquer usuário logado ler, e o conteúdo continua visível no perfil público, em deep links antigos e em notificações.

**Onde:**
- `firestore.rules:515, 554`
- `lib/pages/perfil/perfil_publico_page.dart:64-67`
- `lib/pages/ocorrencia_deep_link_page.dart:52-56`
- `lib/pages/notificacoes_page.dart:42-59`

**Correção:**
- gravar `oculto: false` na criação
- ler só com `oculto == false || isOwner() || isAutoridade()`
- consultar com `where('oculto', isEqualTo: false)` (precisa de um índice `oculto` + `dataCriacao`)
- mostrar "conteúdo removido" nas telas

### M3. O autor pode reescrever a denúncia depois de verificada

**Problema:** o ramo de update do dono (título e descrição) não olha `verificada` nem `statusOficial`. O selo "Verificada por <órgão>" continua atestando um texto que o órgão nunca viu.

**Onde:** `firestore.rules:520-523`

**Correção:** exigir `verificada == false && statusOficial == null` para editar, ou zerar a verificação na edição.

### M4. Notificações de status forjáveis e sem deduplicação

**Problema:** a regra não exige `isAutoridade()` para os tipos `status_*`, e `deUsuarioNome` e `ocorrenciaTitulo` são texto livre. Qualquer usuário pode mandar uma "resolução oficial" falsa, com texto de phishing, para o autor de qualquer denúncia, e em loop.

**Onde:** `firestore.rules:433-462, 673-677`

**Correção:**
- exigir `isAutoridade()` para `status_*`
- exigir `ocorrenciaTitulo` igual ao título real da denúncia
- ligar o nome ao perfil
- usar ID determinístico para deduplicar (por exemplo, `curtida_{ocorrenciaId}_{uid}`)

### M5. Falta regra para `usuarios/{uid}/meta` (as notificações de conquista nunca saem)

**Problema:** não há regra para `usuarios/{uid}/meta/conquistasNotificadas`. O catch-all nega, o `catch` engole o erro e nenhuma notificação de conquista é criada. A função ainda roda a cada rebuild do perfil, e leitura negada também é cobrada.

**Onde:**
- `lib/pages/perfil/perfil_page.dart:83-130, 195`
- `firestore.rules:720-722`

**Correção:**
- `match /meta/{docId}` só para o dono, validando `items` (lista com até 50 itens)
- tirar a checagem do `build`
- usar ID determinístico por conquista para não duplicar

### M6. Excluir um comentário com respostas de outras pessoas sempre falha

**Etiquetas:** LGPD

**Problema:** o cliente apaga o comentário e todas as respostas num único batch, mas a regra só deixa cada autor apagar o próprio comentário. Basta uma resposta de outra pessoa para dar permission-denied, e o comentário fica para sempre.

**Onde:**
- `lib/data/repositories/comentario_repository.dart:142-160`
- `firestore.rules:556`

**Correção:** apagar só o próprio comentário (a interface trata a raiz ausente como "comentário removido"), ou permitir apagar as respostas quando o comentário pai do autenticado for apagado no mesmo batch.

### M7. O deep link `ecojp://` não abre no Android e perde o destino na partida a frio

**Problemas:**
- o `AndroidManifest.xml` não tem intent-filter para `ecojp` (o iOS tem)
- na partida a frio, o `push` acontece com o router em `/splash` e o redirect descarta o destino; sem login, o destino também se perde
- `app_router.dart:70` faz `state.extra!` e quebra se a rota do perfil público abrir sem `extra`
- o deep linking nativo do Flutter não foi desligado, o que conflita com o `app_links`

**Onde:**
- `android/app/src/main/AndroidManifest.xml:40-43`
- `lib/core/deep_link.dart:59-76`
- `lib/core/router/app_router.dart:70, 103-127`

**Correção:**
- intent-filter com `scheme="ecojp"`
- guardar o link pendente num provider e navegar quando o redirect liberar `/home`
- considerar App Links / Universal Links em `https://`

### M8. Crash ao tocar de novo na aba Dados ou Feed (`hasClients`)

**Problema:** `_scrollController.offset` é lido sem checar `hasClients`. Para cidadãos, a aba Dados nunca recebe o controller. No Feed, os estados de carregamento, erro e vazio também não recebem. Tocar de novo na aba gera um `StateError`, registrado como crash fatal no Crashlytics.

**Onde:** `lib/pages/home_shell.dart:79, 99, 117`

**Correção:** `if (c.hasClients && c.offset > 0)` nos três ramos.

### M9. Streams criadas dentro do `build` (a busca fecha o teclado, a lista volta ao topo)

**Etiquetas:** Qualidade e testes

**Problema:** cada `build` cria uma stream nova, e o `StreamBuilder` volta a `waiting` e mostra o spinner. Na prática:
- na busca das filas, o teclado fecha a cada letra
- nos comentários, a lista volta ao topo a cada interação
- em Estatísticas, cada rebuild abre outro listener de 500 documentos

**Onde:**
- `lib/pages/fila_verificacao_page.dart:104-108`
- `lib/pages/fila_moderacao_page.dart:63-67`
- `lib/pages/estatisticas_page.dart:242-249`
- `lib/widgets/occurrence_comments_sheet.dart:453-456`
- `lib/pages/notificacoes_page.dart:109`
- `lib/pages/perfil/perfil_page.dart:185, 191`
- `lib/pages/home_shell.dart:226`
- `lib/pages/detalhe_ocorrencia_page.dart:485-488, 1433-1434`

**Correção:** criar as streams no `initState` (`late final`) ou em providers, como `dados_publicos_page.dart:31` já faz, e checar `hasData` antes de `waiting`.

### M10. Feed: a paginação relê tudo e os listeners de "último comentário" vazam

**Etiquetas:** Servidor e escala

**Problemas:**
- Cada "carregar mais" recria o listener com `limit(N+10)` e relê tudo, então o custo cresce de forma quadrática. Além disso, `_loadingMore` volta a false cedo demais e, com rede lenta ou offline, aparece um "fim do feed" falso. Arquivo: `lib/pages/home_page.dart:207-214, 879-888`.
- `.asBroadcastStream()` sem `onCancel` faz cada card já exibido deixar um listener vivo, até depois do logout. Arquivo: `lib/pages/home_page.dart:150-175`.

**Correção:**
- paginar com `startAfterDocument` + `get()`, mantendo listener só na primeira página
- guardar e cancelar as subscriptions, ou usar `asBroadcastStream(onCancel: (s) => s.cancel())`

### M11. Mapa, estatísticas, dados públicos e PDF limitados às 500 denúncias mais recentes

**Etiquetas:** Servidor e escala

**Problema:** tudo sai de `listarOcorrenciasLimitadas(500)`, com listener vivo. As consequências:
- passando de 500 denúncias, o período "Tudo", o PDF oficial, as taxas, os tempos médios, o Panorama e o mapa de calor ficam errados sem aviso
- os dados públicos também contam as denúncias ocultas
- cada usuário com a aba aberta lê 500 documentos, e cada curtida cobra uma leitura por cliente

**Onde:**
- `lib/pages/estatisticas_page.dart:243-245`
- `lib/pages/dados_publicos_page.dart:40-42, 217-221`
- `lib/pages/mapPage/controller/map_controller.dart:113-114`
- `lib/services/relatorio_service.dart:28, 84`

**Correção:**
- usar `count()` com filtros ou um documento agregado de estatísticas
- carregar o mapa por viewport/geohash com `get()`
- rotular o recorte de verdade
- filtrar `oculto`

### M12. Contadores infláveis: `shares` e curtidas em loop, e comentário em denúncia inexistente

**Etiquetas:** Servidor e escala

**Problema:** `shares` aceita +1 sem limite, curtir e descurtir em loop é válido, e o comentário não confere se a ocorrência existe. Um script numa única conta verificada gera milhões de leituras por dia nos listeners do feed.

Além disso, `isOwner()` é avaliado antes de `affectedKeys()` e cobra uma leitura extra em cada curtida de denúncia anônima.

**Onde:** `firestore.rules:291-295, 534, 555` e `:520, :527`

**Correção:**
- trocar `shares` por uma subcoleção `compartilhamentos/{uid}` só com create
- criar rate limit por usuário (`meta/rate` + `getAfter`)
- exigir `exists(ocorrencia)` em `isValidComment`
- reordenar as condições

### M13. O detalhe baixa o vídeo inteiro só por abrir a tela

**Etiquetas:** Servidor e escala

**Problema:** `VideoPlayerController.networkUrl(...).initialize()` roda no `initState` com a URL original, de até 50 MB. Cada visualização consome banda do Cloudinary, mesmo sem apertar play.

**Onde:** `lib/pages/detalhe_ocorrencia_page.dart:849-857`

**Correção:**
- mostrar uma thumbnail (`so_0`) e só inicializar o player ao tocar
- usar uma URL transformada (`q_auto`, resolução menor)

### M14. Envio de denúncia: rate limit depois do upload, duplicatas e mídia órfã

**Problema:** até 3 fotos de 8 MB e 1 vídeo de 50 MB sobem antes do `checarERegistrar`. Se a rede cair no `add`, o reenvio sobe tudo de novo, estoura o rate limit e deixa mídia órfã. Na denúncia anônima, uma falha depois do `add` gera uma duplicata sem dono.

**Onde:** `lib/pages/form_ocorrencia_page.dart:384-456`

**Correção:**
- checar o rate limit antes dos uploads e só registrar depois de gravar
- gerar o ID antes e usar `WriteBatch` (ver A2)
- tratar erro depois do `add` como "enviada"

### M15. Não há geofence de João Pessoa, nem no cliente nem nas regras

**Problema:** a única validação é lat/lon diferente de 0. `geocodificar("Centro")` pega o primeiro "Centro" do Brasil, e pelo GPS alguém fora da cidade publica direto. Isso polui o mapa, o mapa de calor e as estatísticas.

**Onde:**
- `lib/pages/form_ocorrencia_page.dart:374`
- `lib/pages/form_ocorrencia/controllers/location_controller.dart:40-44, 159-165`
- `firestore.rules:67-75`

**Correção:**
- bounding box do município (por exemplo, lat -7.30..-6.95, lon -35.00..-34.75) em `coordenadaValida` e nas regras
- no geocoding, acrescentar ", João Pessoa - PB" e `viewbox` com `bounded=1`

### M16. O ranking de bairros é calculado errado

**Problema:** a heurística "a segunda parte do endereço é o bairro" falha de várias formas:
- no formato do Google Places, o "bairro" vira "João Pessoa - PB"
- números de casa geram chaves diferentes
- "Manaíra" e "Manaira" contam separado
- "Endereço não encontrado" vira um bairro

**Onde:**
- `lib/pages/mapPage/controller/calc_mostaffectedzones.dart:24-33`
- `lib/pages/form_ocorrencia/controllers/location_controller.dart:138-142`

**Correção:**
- gravar `bairro` como campo estruturado na criação (o Nominatim e o ViaCEP já devolvem)
- normalizar acentos e caixa
- tratar a falha do reverse geocode como erro

### M17. Auditoria da autoridade: reversão falsa, nome fixo e registros sem garantia

**Problemas:**
- "Reverter para encaminhada" chama o fluxo de encaminhar: grava um novo `encaminhadaEm`, cria o evento imutável "encaminhada" e notifica o cidadão. O `resolvidaEm` continua entrando nas métricas. Arquivos: `lib/pages/detalhe_ocorrencia_page.dart:151-177, 1242-1246` e `lib/pages/estatisticas_page.dart:167-170`.
- A fila de verificação grava o nome fixo `'Autoridade'`, não notifica o cidadão e não tem trava contra toque duplo, o que gera eventos duplicados. Arquivo: `lib/pages/fila_verificacao_page.dart:31-38, 612-615`.
- As regras não exigem o evento em `historico`, o campo `por` é livre e o update de `denuncias_moderacao` não valida campos. Arquivo: `firestore.rules:300-314, 567-570, 690`.

**Correção:**
- criar uma ação de reversão separada, com evento "revertida" e sem notificação
- nas métricas, só contar `resolvidaEm` quando `statusOficial == resolvida`
- usar o nome do perfil e travar o botão durante o processamento
- exigir `existsAfter` do evento e validar `resolvidoPor == uid`

### M18. Fila de moderação: o spinner vaza para o próximo item

**Problema:** `_processando` só volta a false no erro, e os itens não têm `key`. Depois de "Manter" no item 0, o State é reaproveitado pelo próximo relatório, que fica com spinner eterno e sem botões.

**Onde:** `lib/pages/fila_moderacao_page.dart:95-98, 419-434`

**Correção:** `key: ValueKey(d.id)` no `_ItemModeracao` e resetar `_processando` num `finally`.

### M19. A política de privacidade e o consentimento contradizem o app

**Etiquetas:** LGPD · Documentação

**Problemas:**
- A política não cita o Firebase Analytics (`setUserId(uid)` + evento com o parâmetro `anonima`, em `lib/services/analytics_service.dart:15, 42`), o Crashlytics, o Nominatim/OSM, o ViaCEP, o Google Places nem o login com Google. Arquivo: `lib/pages/legal/documentos_legais.dart:13-58`.
- A tela de consentimento promete "seu nome e foto não aparecem para ninguém", mas a autoridade pode ler o autor (`dono/info`). Arquivo: `lib/pages/legal/consentimento_page.dart:106-111`.
- A autoridade lê `dono/info` sem nenhum registro de quem consultou. Arquivo: `firestore.rules:579-580`.
- A tela de consentimento não tem "Não concordo / sair".
- O consentimento falha aberto quando não há rede. Arquivo: `lib/services/consent_service.dart:26-29`.

**Correção:**
- listar os operadores na política e subir `kVersaoDocumentosLegais`
- corrigir o texto sobre anonimato
- adicionar o botão de sair
- manter o usuário no gate quando não houver dado de consentimento
- avaliar uma Cloud Function com log para a leitura de `dono/info`

### M20. "Exportar meus dados" omite as denúncias anônimas

**Etiquetas:** LGPD

**Problema:** a exportação usa `listarPorUsuario(uid)`, que filtra por `usuarioId`, e as denúncias anônimas não têm esse campo. Além disso, `.snapshots().first` pode vir do cache local, incompleto.

**Onde:** `lib/pages/perfil/configuracoes_conta_page.dart:70-72`

**Correção:** usar `listarMinhasDenuncias(uid)` e ler com `Source.server`.

### M21. A exclusão não apaga a mídia no Cloudinary nem as subcoleções

**Etiquetas:** LGPD · Depende de functions/

**Problema:** a política diz que as denúncias são apagadas, mas fotos e vídeos ficam no Cloudinary (o upload é não assinado e não há caminho de exclusão). `comentarios` e `historico` ficam órfãos, com nome e foto de terceiros, e as URLs (ainda com GPS, ver A1) continuam públicas.

**Onde:**
- `lib/data/repositories/ocorrencia_repository.dart:406-428`
- `lib/services/usuario_service.dart:131-199`

**Correção:**
- guardar o `public_id` e apagar a mídia por Cloud Function ou backend assinado
- apagar as subcoleções em cascata
- até lá, corrigir o texto da política

### M22. Anonimato: o autor se expõe ao comentar e o GPS exato é publicado

**Etiquetas:** LGPD

**Problemas:**
- O comentário sempre grava nome e foto. Quem denunciou anonimamente e comenta na própria denúncia fica identificado. Arquivo: `lib/widgets/occurrence_comments_sheet.dart:140-152`.
- Com "usar localização atual", a latitude/longitude exata do denunciante anônimo fica legível para qualquer usuário. Arquivos: `lib/pages/form_ocorrencia_page.dart:426-428` e `location_controller.dart:140-141`.

**Correção:**
- detectar o dono pelos ponteiros e comentar como "Autor da denúncia", ou pelo menos avisar antes de enviar
- nas denúncias anônimas, arredondar ou aplicar jitter de 50 a 100 m, ou permitir ajustar o pino

### M23. O painel de comentários voltou para o inglês

**Problema:** o commit `b5c3bb0` traduziu as strings do painel para o inglês ("Comments", "Reply", "No comments yet", "Report comment"...). Combinadas com `mensagemErro`, saem frases misturadas como "Não foi possível edit the comment."

**Onde:** `lib/widgets/occurrence_comments_sheet.dart`, linhas 130, 183-184, 241, 314, 327, 366, 376, 390, 434, 693, 764, 1011 e 1051

**Correção:** voltar as strings para pt-BR.

### M24. Workflow de release: rodar testes, tirar a versão da tag e fixar as actions

**Etiquetas:** Qualidade e testes

**Problemas:**
- o `release.yml` não roda analyze nem testes e não depende do CI, então qualquer tag publica
- toda release sai como `1.0.0+1` (sem `--build-name`/`--build-number`)
- as actions de terceiros não estão fixadas por SHA (`softprops/action-gh-release@v2`, que tem `contents: write`), o Flutter usa `channel: stable` sem versão e o `npm install -g firebase-tools` não tem versão (`ci.yml:55`)
- o `dart format` não bloqueia (`ci.yml:24`), e o `ci.yml` não tem bloco `permissions:`

**Correção:**
- fazer o release depender do job de qualidade
- tirar a versão da tag
- fixar as actions por SHA e as versões do Flutter e do firebase-tools

### M25. Restringir a chave do Maps e separar uma chave de servidor

**Etiquetas:** Tarefa no Console

**Problema:** `tools/geocode_bairros.mjs` usa a mesma `MAPS_API_KEY` do Android para chamar a Geocoding REST. Uma chave restrita a apps Android seria recusada nessa chamada, então, se o script funciona, a chave não tem restrição. Ela vai embutida nos APKs publicados, e qualquer pessoa pode extraí-la e gastar Geocoding e Places na conta do projeto.

Além disso, uma linha `MAPS_API_KEY=` vazia no `local.properties` retorna `""` e faz a variável de ambiente ser ignorada (`android/app/build.gradle.kts:20-22`).

**Onde:**
- `tools/geocode_bairros.mjs:39-47`
- `.github/workflows/ci.yml:89-94`
- `.github/workflows/release.yml:49-53`

**Correção:**
- a chave do Android restrita por pacote + SHA-1 e só para o Maps SDK
- uma chave de servidor separada, restrita por IP e API
- conferir as restrições no Console
- no Gradle, usar `takeIf { it.isNotBlank() }`

### M26. iOS: o login com Google não está configurado

**Etiquetas:** Apresentação · Tarefa no Console

**Problema:** não há `GIDClientID`, nem o esquema `REVERSED_CLIENT_ID`, nem `GoogleService-Info.plist`, e `GoogleSignIn()` é chamado sem `clientId`. No iOS, "Entrar com Google" dá erro.

**Onde:**
- `lib/services/auth_service.dart:100`
- `ios/Runner/Info.plist`

**Correção:** registrar o app iOS `br.com.ecojp.app` no Firebase e adicionar o `GIDClientID` e o esquema invertido no plist.

### M27. Testes das regras: `firestore-tests/` não testa nada e faltam casos

**Etiquetas:** Qualidade e testes

**Problemas:**
- `firestore-tests/*.test.js` (rodado por `npm test` via `jest.config.js:3`) nunca carrega as regras nem o emulador. Só compara literais JS, então não consegue falhar.
- A suíte real (`test/firestore_rules`) não cobre:
  - reações, `shares` e notificações
  - `dono/info` e `minhas_denuncias_anonimas`
  - edição e exclusão pelo dono
  - comentários e `autorAutoridade`
  - seguir e deixar de seguir, consentimentos
  - `denuncias_moderacao` e `meta`
  - os caminhos positivos da autoridade
- Há testes negativos sem par positivo (`test/firestore_rules/firestore.rules.test.js:228-237`), que continuam verdes mesmo se a regra passar a negar tudo.

**Correção:**
- apagar `firestore-tests/` ou apontar a raiz para `test/firestore_rules`
- criar um par positivo/negativo por ramo de regra, começando pelos itens de gravidade alta

### M28. Teste de carga (`loadtest/`): as métricas não medem o que dizem

**Etiquetas:** Servidor e escala

**Problemas:**
1. Toda resposta diferente de 200 conta como "conflito", incluindo 401 de token vencido e 403 das regras (`k6/curtidas.js:111`).
2. O teste usa transação REST pessimista com uma única tentativa; o app usa transação otimista com até 5 (`curtidas.js:87`).
3. A transação aberta nunca sofre rollback (`k6/lib/firestore.js:90`).
4. `PAGINA_FEED = 20`, mas o app usa 10 (`feed.js:33`, `pico.js:35`).
5. As métricas de vazão e de spam são somadas, e os "17,2/s" foram calculados com 180 s em vez de 150 s (`denuncias.js:119`).
6. `erros` mistura disputa pelo documento com indisponibilidade (`pico.js:115`).
7. "Pessoas simultâneas" vem de `vus_max` (o valor configurado), não de `vus` (`pico.js:127`).
8. A pasta `loadtest/resultados/` não é criada, e o JSON bruto se perde.
9. `corpus.mjs` e `pico.js` não têm script npm nem aparecem no README.
10. Há lógica duplicada entre os scripts.

**Correção:** corrigir os itens 1 a 4 e rodar de novo antes de usar os números do `RESULTADOS.md`.

### M29. Script de backfill de nomes: ordena por UID e o dry-run não vê colisões

**Etiquetas:** Tarefa no Console

**Problema:** o cabeçalho diz que, numa colisão, o nome fica com a conta mais antiga, mas o loop ordena por `__name__` (o UID, que é aleatório). O dry-run não detecta colisão entre duas contas antigas e reporta 0.

**Onde:** `scripts/backfill_nomes_reservados.mjs:77`

**Correção:**
- ordenar pela data de criação (`metadata.creationTime` do Auth)
- simular as colisões no dry-run antes do `--aplicar`

---

## Gravidade baixa

### B1. A documentação contradiz o código (README, ROADMAP, ADR)

**Etiquetas:** Documentação

- README, ROADMAP e `.github/actions/flutter-setup/action.yml` dizem que `firebase_options.dart` está no gitignore, mas ele está versionado. Por isso o passo "Gerar FirebaseOptions de CI" é código morto, e o plugin gms não é aplicado.
- O ROADMAP diz que existe sugestão de categoria com Gemini (`:77-79`, `:117-120`), mas o recurso não existe no código.
- `ROADMAP.md:50` diz que a imposição do App Check está ativa, mas ainda não está.
- Problemas no README:
  - cita a licença MIT, mas não existe `LICENSE`
  - cita `docs/DOCUMENTACAO_TECNICA.md` e `CONFIGURACAO.md`, que não existem
  - diz "Android SDK 21+", mas o `minSdk` é 26
  - usa o placeholder `github.com/username/eco-jp`
  - marca o App Check como "✅ + iOS"
- O ADR (`docs/adr/0001...md:93`) diz que o CI não existe, e a linha 10 cita FCM, que não está no pubspec.

### B2. Notificações sem limite, e "marcar como lidas" falha acima de 500

**Etiquetas:** Servidor e escala

- `contarNaoLidas` é um listener sem limite. `marcarTodasComoLidas` usa um único batch, que falha acima de 500 documentos, e o erro é engolido. Arquivo: `lib/services/notificacao_service.dart:72-91`.
- `marcarTodasComoLidas` roda no `initState`, e o destaque de "não lida" some em 1 segundo. `_abrirDenuncia` não tem `catch`, então offline vira crash "fatal". Conquistas mostram a seta mas não navegam. Arquivo: `lib/pages/notificacoes_page.dart:27-31, 41-62`.

**Correção:**
- contar com `count()` (ou mostrar "99+")
- dividir em lotes de 500
- marcar como lidas ao sair da tela
- adicionar `catch` com SnackBar

### B3. Localização: faltam timeouts no GPS e no geocoding

- O mapa não tem try/catch nem timeout e fica num spinner eterno em ambiente fechado. Arquivo: `lib/pages/mapPage/widgets/mapdisplay.dart:39-56`.
- "Usar localização atual" pode travar e, ao terminar, sobrescrever o endereço que a pessoa digitou. Arquivo: `location_controller.dart:133-142`.
- `reverseGeocode` não tem timeout nem User-Agent. Arquivo: `lib/services/geolocation/geocoding_service.dart:209`.
- O autocomplete via Nominatim viola a política de uso do OSM. Arquivo: `geocoding_service.dart:41-62, 94-109`.
- Com a permissão negada para sempre, o app abre a tela de GPS em vez da de permissões. Arquivo: `lib/services/geolocation/geolocation_service.dart:37-47`.

**Correção:**
- `timeLimit` ou `getLastKnownPosition`, com câmera padrão em João Pessoa
- `.timeout` e User-Agent no geocoding
- outro provedor para o autocomplete
- `openAppSettings()` para a permissão

### B4. Validações que faltam nas regras

- `municipioId` não tem validação de tipo nem de tamanho (`firestore.rules:167`)
- `comments` fica congelado em 0 (`:195`)
- contas não verificadas podem reservar nomes em massa, e o slug não é validado (`:660-666`)
- `dono/{docId}` aceita qualquer ID (`:578`)
- o update de `denuncias_moderacao` não valida campos

### B5. Pequenos bugs de telas e serviços

**Etiquetas:** Qualidade e testes

- `carregarPerfil` está fora do `try`, e offline o painel da autoridade fica num spinner eterno (`lib/pages/detalhe_ocorrencia_page.dart:114-119, 158-166`)
- há uma corrida no `dispose` do controller do mapa (`map_controller.dart:102-131`)
- `listarMinhasDenuncias` não tem `onError`, o que gera crash fatal no logout (`lib/data/repositories/ocorrencia_repository.dart:225-253`)
- no login, "Logar" não fica desabilitado durante o login com Google, e o diálogo de recuperar senha fecha no erro (`lib/pages/login_page.dart:145-160, 344`)
- o medidor de senha contradiz a validação (`lib/pages/cadastro_page.dart:106` vs `:582`)
- a edição de denúncia não valida os limites das regras (`lib/widgets/ocorrencia_actions.dart:207-222, 240`)
- controllers de diálogo são descartados logo após o `pop` (`occurrence_comments_sheet.dart:301`, `ocorrencia_actions.dart:291-292`)
- o e-mail de verificação é reenviado a cada abertura da tela (`lib/pages/verificacao_email_page.dart:34, 50-54, 158`)
- o selo "❤️ by authority" só aparece para a própria autoridade (`occurrence_comments_sheet.dart:681`)
- "Última denúncia" mostra a denúncia atual (`lib/widgets/occurrence_card.dart:1521-1525`)
- o Analytics recebe um parâmetro `bool` (`lib/services/analytics_service.dart:15`)
- o PDF perde "—", "•" e emojis por causa da fonte Type1 (`lib/services/relatorio_service.dart`)

### B6. Acessibilidade: áreas de toque e rótulos

**Etiquetas:** Apresentação

- os checkboxes de aceite têm 24 dp e o texto ao lado não marca a caixa (`lib/pages/cadastro_page.dart:215-243`, `lib/pages/legal/consentimento_page.dart:132-167`)
- a seta de voltar é um `GestureDetector` com SVG, sem rótulo (`login_page.dart:262`, `cadastro_page.dart:320`)
- o menu "…" dos comentários tem 24×24 (`occurrence_comments_sheet.dart:773-776`)

**Correção:**
- usar `CheckboxListTile`
- trocar a seta por `IconButton(tooltip: 'Voltar')`
- aumentar a área de toque para 48 dp

### B7. Limpeza: dependências sem uso e sobras do template

**Etiquetas:** Qualidade e testes

- remover `google_generative_ai` e `geocoding`, que não são usados
- planejar a atualização de `geolocator ^9`, `go_router ^12` e `google_sign_in ^6`
- sobras de `com.example` e do template do Flutter:
  - `.github/actions/flutter-setup/action.yml:52, 126, 135`
  - `macos/Runner/Configs/AppInfo.xcconfig`
  - `linux/CMakeLists.txt:10`
  - `windows/runner/Runner.rc`
  - `web/index.html` e `web/manifest.json` ("A new Flutter project")
- o web não carrega o script do Maps JS, então a aba Mapa quebra na web
- faltam testes para `ocorrenciaIdFromUri`, para a reserva de nome no Dart e para a exclusão de conta
- o `_FakeAnalytics` com `noSuchMethod` esconde o bug do parâmetro `bool` do Analytics

---

## O que foi verificado sem encontrar problema

- Não há chave do Maps nem keystore versionados, nem no histórico dos manifests, do plist, do `index.html` e do Gradle. O prefixo `AIza` só aparece em `firebase_options.dart`.
- `key.properties`, `*.jks`, `local.properties`, `Maps.xcconfig`, `loadtest/tokens.json` e `loadtest/resultados/` estão no `.gitignore`.
- As permissões do Android estão adequadas (internet e localização).
- O bundle ID e o `applicationId` estão corretos (`br.com.ecojp.app`).
- O R8 não precisa de regras extras: Firebase e Maps trazem regras próprias.
- Todas as queries compostas do cliente têm índice em `firestore.indexes.json`.
- Nenhuma ação de moderação ou verificação é protegida só pela interface: todas exigem `isAutoridade()` nas regras.
