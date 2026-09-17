plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de produção configurável via propriedades do Gradle (e.g.
// ~/.gradle/gradle.properties) ou variáveis de ambiente. Sem keystore de
// produção o build de release usa a assinatura de debug (desenvolvimento).
val keystoreFile = providers.gradleProperty("MENTALL_KEYSTORE_FILE").orNull
    ?: System.getenv("MENTALL_KEYSTORE_FILE")
val keystorePassword = providers.gradleProperty("MENTALL_KEYSTORE_PASSWORD").orNull
    ?: System.getenv("MENTALL_KEYSTORE_PASSWORD")
val keyAlias = providers.gradleProperty("MENTALL_KEY_ALIAS").orNull
    ?: System.getenv("MENTALL_KEY_ALIAS")
val keyPassword = providers.gradleProperty("MENTALL_KEY_PASSWORD").orNull
    ?: System.getenv("MENTALL_KEY_PASSWORD")
val hasReleaseSigning = !keystoreFile.isNullOrBlank()
    && !keystorePassword.isNullOrBlank()
    && !keyAlias.isNullOrBlank()
    && !keyPassword.isNullOrBlank()

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
                storeFile = file(keystoreFile!!)
                storePassword = keystorePassword
                keyAlias = keyAlias
                keyPassword = keyPassword
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
