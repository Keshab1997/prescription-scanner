import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// flutter-builder CI decodes ANDROID_KEYSTORE_BASE64 to android/app/upload-keystore.jks
// and writes storeFile=upload-keystore.jks. Local docs keep the same filename in android/.
val releaseKeystoreFile: File? =
    keystoreProperties.getProperty("storeFile")?.let { storeFileName ->
        listOf(file(storeFileName), rootProject.file(storeFileName))
            .firstOrNull { it.isFile }
            ?: file(storeFileName)
    }

android {
    namespace = "com.keshabstudios.prescriptionscanner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.keshabstudios.prescriptionscanner"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    // `flutter build appbundle --release` failed with:
    //   "Release app bundle failed to strip debug symbols from native libraries."
    // Root cause: debugSymbolLevel was "NONE", so AGP generated no .sym/.dbg
    // files and Flutter's post-build symbol check (libflutter.so.sym / .dbg
    // not present) failed. Restoring "SYMBOL_TABLE" (AGP default) generates the
    // symbol tables Flutter expects so the check passes. keepDebugSymbols keeps
    // them inside the bundled .so so Play Console can symbolicate native crashes.
    packaging {
        jniLibs {
            keepDebugSymbols += setOf("**/*.so")
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
            // Play/AAB uses upload keystore when android/key.properties exists.
            // Local `flutter run --release` still works with debug signing.
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
