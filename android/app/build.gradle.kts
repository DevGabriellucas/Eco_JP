import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave do Google Maps: nunca versionada. Procura, nesta ordem:
//   1. android/local.properties (dev local — arquivo gitignored)
//   2. variável de ambiente MAPS_API_KEY (CI/CD)
// Vazia é aceita para o build não quebrar em PRs de fork; nesse caso o mapa
// abre cinza em vez de falhar a compilação.
val mapsApiKey: String = run {
    val props = Properties()
    val localProps = rootProject.file("local.properties")
    if (localProps.exists()) {
        localProps.inputStream().use { props.load(it) }
    }
    // takeIf: uma linha `MAPS_API_KEY=` vazia no local.properties devolvia ""
    // (não null) e escondia a variável de ambiente.
    props.getProperty("MAPS_API_KEY")?.takeIf { it.isNotBlank() }
        ?: System.getenv("MAPS_API_KEY")?.takeIf { it.isNotBlank() }
        ?: ""
}

// Assinatura de release. As credenciais ficam em android/key.properties
// (gitignored, NUNCA versionado). Sem esse arquivo o build de release FALHA
// (ver o bloco taskGraph.whenReady no fim): antes ele caía em silêncio na
// chave de debug efêmera do runner, e cada tag gerava um APK com assinatura
// diferente — sem atualização por cima, login Google com ApiException 10 e
// App Check recusando. Para um release local de teste, assinado com a chave
// de debug, exporte ECOJP_PERMITIR_RELEASE_DEBUG=true.
val keystoreProperties = Properties().apply {
    val arquivo = rootProject.file("key.properties")
    if (arquivo.exists()) {
        arquivo.inputStream().use { load(it) }
    }
}
val temKeystoreDeRelease = keystoreProperties.getProperty("storeFile") != null
val permiteReleaseComDebug = System.getenv("ECOJP_PERMITIR_RELEASE_DEBUG") == "true"

android {
    namespace = "br.com.ecojp.app"
    compileSdk = 36
    ndkVersion = "30.0.16138531"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identificador definitivo e permanente na Play Store. Não pode mudar
        // depois da primeira publicação — trocá-lo cria um app novo, sem os
        // usuários e sem as avaliações do anterior.
        applicationId = "br.com.ecojp.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Substitui ${MAPS_API_KEY} no AndroidManifest.xml em tempo de build.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (temKeystoreDeRelease) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (temKeystoreDeRelease) {
                signingConfigs.getByName("release")
            } else {
                // Só chega a ser usado com ECOJP_PERMITIR_RELEASE_DEBUG=true;
                // sem isso o build é interrompido antes (ver abaixo).
                signingConfigs.getByName("debug")
            }
        }
    }

    lint {
        checkReleaseBuilds = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Interrompe qualquer tarefa de release sem a chave de upload. Checado só
// quando o grafo de tarefas está pronto, para não afetar builds de debug.
gradle.taskGraph.whenReady {
    val pedeRelease = allTasks.any { it.name.contains("Release") }
    if (pedeRelease && !temKeystoreDeRelease && !permiteReleaseComDebug) {
        throw GradleException(
            "Build de release sem android/key.properties. Configure a chave de " +
                "upload (ver .github/workflows/release.yml) ou, só para teste " +
                "local, exporte ECOJP_PERMITIR_RELEASE_DEBUG=true."
        )
    }
}
