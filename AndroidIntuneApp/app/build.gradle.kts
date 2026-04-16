plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// Rewrites Android/Java classes to call MAM-aware equivalents. Requires
// `com.microsoft.intune.mam.build.jar` on the root project's buildscript
// classpath — see the top-level build.gradle.kts.
apply(plugin = "com.microsoft.intune.mam")

android {
    namespace = "com.example.androidintuneapp"
    compileSdk {
        version = release(36)
    }

    defaultConfig {
        applicationId = "com.example.androidintuneapp"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // Placeholder consumed by the MSAL BrowserTabActivity intent-filter in
        // AndroidManifest.xml. The path segment must match the base64-url
        // encoded SHA-1 of the signing certificate used to sign the APK, and
        // must also match the `redirect_uri` in res/raw/msal_config.json.
        // Compute with: keytool -exportcert -alias <alias> -keystore <ks> | openssl sha1 -binary | openssl base64
        manifestPlaceholders["msalRedirectScheme"] = "msauth"
        manifestPlaceholders["msalRedirectHost"] = applicationId!!
        manifestPlaceholders["msalRedirectPath"] = "/cobDPoK66N9FqyxsbxRS/5q8zq8="
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
    }
}

repositories {
    // Intune App SDK AAR is distributed via GitHub, not Maven. Drop
    // `Microsoft.Intune.MAM.SDK.aar` into `app/libs/` to resolve this.
    flatDir {
        dirs("libs")
    }
}

// Optional: to tweak the MAM build-plugin (report/verify/incremental), use the
// Groovy-style named extension after the plugin is applied, e.g.:
//   (extensions.getByName("intunemam") as org.gradle.api.plugins.ExtensionAware)
// Defaults are fine for a hello-world app.

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)

    // Microsoft Authentication Library (interactive + silent AAD sign-in).
    implementation(libs.msal)

    // Intune App SDK. The AAR must live at app/libs/Microsoft.Intune.MAM.SDK.aar
    // (downloaded from https://github.com/microsoftconnect/ms-intune-app-sdk-android).
    // curl --ssl-no-revoke -L -o app\libs\Microsoft.Intune.MAM.SDK.aar https://github.com/microsoftconnect/ms-intune-app-sdk-android/raw/master/Microsoft.Intune.MAM.SDK.aar
    implementation(files("libs/Microsoft.Intune.MAM.SDK.aar"))

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}

// curl --ssl-no-revoke -L -o libs\com.microsoft.intune.mam.build.jar https://github.com/microsoftconnect/ms-intune-app-sdk-android/raw/master/GradlePlugin/com.microsoft.intune.mam.build.jar
