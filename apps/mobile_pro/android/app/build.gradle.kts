import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.eastlakestudio.castnow.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.eastlakestudio.castnow.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24//flutter.minSdkVersion
        targetSdk = 34//flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystoreFile = project.rootProject.file("key.properties")
            if (keystoreFile.exists()) {
                val props = Properties()
                props.load(FileInputStream(keystoreFile))

                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            } else {
                // Fallback or log warning if key.properties is missing
                // For now, if missing, we might default to debug or leave empty which fails build
                println("Note: apps/mobile/android/key.properties not found. Release build will not be signed with upload key.")
            }
        }
    }

    buildTypes {
        release {
            // Use the release signing config we just created
            // If key.properties is missing, this might fail or produce unsigned APK depending on config
            // Better to check if we successfully configured it, but simpler to just assign it.
            // If the properties aren't loaded, storeFile will be null and it will fail, which is good.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // 自定义 APK 输出文件名逻辑
    applicationVariants.all {
        val variant = this
        variant.outputs.map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                val versionName = project.findProperty("flutter.versionName") as? String 
                    ?: variant.versionName 
                    ?: "1.0.0"
                
                val buildType = variant.buildType.name
                
                val newName = if (buildType == "release") {
                    "CastNow_v${versionName}.apk"
                } else {
                    "CastNow_v${versionName}_${buildType}.apk"
                }
                
                output.outputFileName = newName
            }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 修复 Kotlin 和 Android 核心库缺失的关键依赖
    implementation(kotlin("stdlib"))
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
