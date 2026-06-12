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

## 2. Cloudinary (upload de imagens)

Passe as variáveis ao rodar ou compilar:

```
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=seu_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=seu_upload_preset
```

Para gerar o APK:

```
flutter build apk --dart-define=CLOUDINARY_CLOUD_NAME=seu_cloud_name --dart-define=CLOUDINARY_UPLOAD_PRESET=seu_upload_preset
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
