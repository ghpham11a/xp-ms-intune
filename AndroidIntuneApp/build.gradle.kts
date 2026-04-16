// Top-level build file where you can add configuration options common to all sub-projects/modules.

// The Intune App SDK Gradle plugin must be on the classpath so `:app` can apply
// `com.microsoft.intune.mam`. Drop `com.microsoft.intune.mam.build.jar` from the
// SDK release (https://github.com/microsoftconnect/ms-intune-app-sdk-android) into
// `libs/` at the repo root (same folder as this file).
buildscript {
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath(libs.javassist)
        classpath(files("libs/com.microsoft.intune.mam.build.jar"))
    }
}

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
