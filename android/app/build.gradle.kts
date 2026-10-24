plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de produção configurável via propriedades do Gradle (e.g.
// ~/.gradle/gradle.properties) ou variáveis de ambiente. Sem keystore de
// produção o build de release usa a assinatura de debug (desenvolvimento).
// Nomes diferentes das propriedades do SigningConfig para não haver
// shadowing na atribuição (ex.: `keyAlias = keyAlias` resolvia para o campo
// vazio do próprio SigningConfig e o bundle saía com alias nulo).
val mentallKeystoreFile = providers.gradleProperty("MENTALL_KEYSTORE_FILE").orNull
    ?: System.getenv("MENTALL_KEYSTORE_FILE")
val mentallKeystorePassword = providers.gradleProperty("MENTALL_KEYSTORE_PASSWORD").orNull
    ?: System.getenv("MENTALL_KEYSTORE_PASSWORD")
val mentallKeyAlias = providers.gradleProperty("MENTALL_KEY_ALIAS").orNull
    ?: System.getenv("MENTALL_KEY_ALIAS")
val mentallKeyPassword = providers.gradleProperty("MENTALL_KEY_PASSWORD").orNull
    ?: System.getenv("MENTALL_KEY_PASSWORD")
val hasReleaseSigning = !mentallKeystoreFile.isNullOrBlank()
    && !mentallKeystorePassword.isNullOrBlank()
    && !mentallKeyAlias.isNullOrBlank()
    && !mentallKeyPassword.isNullOrBlank()

android {
    namespace = "com.mentall.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mentall.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = File(mentallKeystoreFile!!)
                storePassword = mentallKeystorePassword
                keyAlias = mentallKeyAlias
                keyPassword = mentallKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Sem keystore de produção: assinatura de debug para dev.
                signingConfigs.getByName("debug")
            }
        }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
