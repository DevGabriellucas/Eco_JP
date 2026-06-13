# Configuração de chaves (setup do projeto)

Por segurança, as chaves de API **não ficam no código versionado**. Cada
desenvolvedor configura as chaves localmente antes de rodar o app.

## 1. Google Maps (Android)

Edite o arquivo `android/local.properties` (ele é ignorado pelo Git) e adicione:

```
MAPS_API_KEY=sua_chave_do_google_maps
```

> ⚠️ **Nunca cole a chave real em arquivos versionados.**
> O `android/local.properties` deve ficar apenas na sua máquina.
> A chave deve ter **restrição de aplicativo Android** (SHA-1 + nome do pacote
> `com.example.eco_jp`) no Google Cloud Console.

## 1.1. Google Maps (Web / Chrome)

Para usar o mapa no Chrome, crie uma chave do Google Maps com restrição de
**HTTP referrer** no Google Cloud Console. Ela é diferente da chave Android.

Copie o exemplo:

```
copy web\maps_config.example.js web\maps_config.js
```

Depois edite `web/maps_config.js` e coloque a chave Web:

```
window.ECOJP_GOOGLE_MAPS_API_KEY = 'sua_chave_web_do_google_maps';
```

O arquivo `web/maps_config.js` é ignorado pelo Git e não deve ir para o GitHub.
Para desenvolvimento local, libere referrers como:

```
http://localhost:*
http://127.0.0.1:*
```

## 2. Cloudinary (upload de imagens)

O projeto já vem com o `cloud name` e o preset unsigned padrão do EcoJP.
Então, para desenvolvimento normal, `flutter run` já funciona.

Use `--dart-define` apenas se precisar trocar para outro Cloudinary:

```
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=seu_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=seu_upload_preset
```

Para gerar o APK usando outro Cloudinary:

```
flutter build apk --dart-define=CLOUDINARY_CLOUD_NAME=seu_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=seu_upload_preset
```

Trave também o preset `Eco_JP` no painel do Cloudinary:

- O preset deve ficar como **Unsigned**.
- Restrinja o tipo de arquivo para **image**.
- Defina uma pasta fixa, por exemplo `ecojp/denuncias`.
- Desative overwrite/sobrescrita.
- Defina tamanho máximo por imagem.
- Permita apenas formatos esperados, como `jpg`, `jpeg`, `png` e `webp`.
- Nunca use `API Secret` no app Flutter.

As regras do Firestore aceitam apenas URLs de imagem com o formato:

```
https://res.cloudinary.com/dmdghbgac/image/upload/...
```

## 3. Firebase

Para manter o GitHub público mais limpo, os arquivos gerados do Firebase ficam
ignorados no `.gitignore`:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `.firebaserc`

Cada desenvolvedor deve gerar esses arquivos localmente com o FlutterFire CLI:

```
flutterfire configure
```

Se algum desses arquivos já tiver sido commitado antes, remova apenas do
rastreamento do Git, mantendo o arquivo local:

```
git rm --cached lib/firebase_options.dart android/app/google-services.json
```

Depois disso, faça um commit com a remoção.
