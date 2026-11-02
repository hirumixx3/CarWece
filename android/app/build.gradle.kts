import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) propertiesFile.inputStream().use { load(it) }
}
fun signingValue(environment: String, property: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: releaseKeyProperties.getProperty(property)?.takeIf { it.isNotBlank() }

android {
    namespace = "com.hirumisu.carwece"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hirumisu.carwece"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("production") {
            signingValue("ANDROID_KEYSTORE_PATH", "storeFile")?.let {
                storeFile = rootProject.file(it)
            }
            storePassword = signingValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
            keyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias") ?: "hirumi"
            keyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")
        }
    }
    androidResources {
        noCompress += "m4a"
        noCompress += "mp4"
    }
    buildTypes {
        release {
            // No fallback to a debug or public development signing key.
            signingConfig = signingConfigs.getByName("production")
        }
    }
}

flutter {
    source = "../.."
}

// This test decodes the actual Dart StandardMethodCodec payload, including all
// mesh buffers, then calls the same validator that MainActivity calls before EGL.
dependencies {
    testImplementation("junit:junit:4.13.2")
}
val exportGraphicsWire by tasks.registering(Exec::class) {
    group = "verification"
    description = "Export real Dart graphics packets before Kotlin contract tests"
    workingDir = rootProject.file("..")
    val localProperties = Properties().apply {
        rootProject.file("local.properties").inputStream().use { load(it) }
    }
    val flutterSdk = requireNotNull(localProperties.getProperty("flutter.sdk"))
    val executable = if (System.getProperty("os.name").startsWith("Windows")) "flutter.bat" else "flutter"
    commandLine("$flutterSdk/bin/$executable", "test", "--no-pub", "--concurrency=1",
        "--dart-define=EXPORT_GRAPHICS_WIRE=true",
        "test/graphics_channel_test.dart", "test/battle_graphics_channel_test.dart")
    inputs.files(rootProject.fileTree("../lib") { include("**/*.dart") },
        rootProject.fileTree("../assets/shaders"),
        rootProject.file("../test/graphics_channel_test.dart"),
        rootProject.file("../test/battle_graphics_channel_test.dart"),
        rootProject.file("../pubspec.lock"))
    outputs.files(rootProject.file("../build/graphics_bridge/create.bin"),
        rootProject.file("../build/graphics_bridge/battle.bin"))
}

tasks.withType<Test>().configureEach {
    dependsOn(exportGraphicsWire)
    systemProperty("carwece.graphicsWire", rootProject.file("../build/graphics_bridge/create.bin").absolutePath)
    systemProperty("carwece.battleWire", rootProject.file("../build/graphics_bridge/battle.bin").absolutePath)
}
