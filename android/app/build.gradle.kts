nsplugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("...") // ✅ Firebase için şart
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "..." // 🔹 kendi package name’in
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            storeFile = file("kandas.keystore")
            storePassword = "KEYSTORE_PASSWORD"
            keyAlias = "kandas"
            keyPassword = "KEY_PASSWORD"
        }
    }

    defaultConfig {
        applicationId = "com.example.kandas" // 🔹 Firebase ve Play Console ile aynı olmalı
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        getByName("release") {
            // ✅ Kod ve kaynak küçültme kapalı (hata önleyici)
            isMinifyEnabled = false
            isShrinkResources = false

            // 🔹 Proguard ayarları
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // 🔹 Release keystore ile imzalama
            signingConfig = signingConfigs.getByName("release")
        }

        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false

            // 🔹 Debug build de aynı keystore ile imzalansın (Firebase SHA sorunu çözülür)
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // ✅ Java17 + coreLibraryDesugaring aktif (bildirim eklentisi için şart)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        viewBinding = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔹 AndroidX
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-ktx:1.9.0")

    // 🔹 Firebase
    implementation("com.google.firebase:firebase-auth:22.3.1")
    implementation("com.google.firebase:firebase-firestore:25.0.0")
    implementation("com.google.firebase:firebase-analytics:22.0.2")
    implementation("com.google.android.gms:play-services-auth:21.0.0")

    // ✅ Flutter Local Notifications fix
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // 🔹 Test
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}