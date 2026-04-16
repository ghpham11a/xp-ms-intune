# Intune App SDK — Build Plugin

Drop `com.microsoft.intune.mam.build.jar` from the Intune App SDK release in
this folder. The file is part of the SDK zip on
<https://github.com/microsoftconnect/ms-intune-app-sdk-android> (look under the
`GradlePlugin/` folder of the release).

The root `build.gradle.kts` pins the plugin onto the `buildscript` classpath so
`:app` can `apply(plugin = "com.microsoft.intune.mam")`.
