plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Firma: la password arriva dalle variabili d'ambiente di GitHub Actions,
// così qualsiasi carattere speciale viene letto senza modifiche.
val ksPassword: String? = System.getenv("KEYSTORE_PASSWORD")
val ksAlias: String = System.getenv("KEY_ALIAS") ?: "becoach"
val ksFile = file("becoach.p12")
val canSign = ksPassword != null && ksFile.exists()

android {
    namespace = "com.dvdsalviato.becoach"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.dvdsalviato.becoach"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (canSign) {
                storeFile = ksFile
                storePassword = ksPassword
                keyAlias = ksAlias
                keyPassword = ksPassword
                storeType = "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (canSign)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
