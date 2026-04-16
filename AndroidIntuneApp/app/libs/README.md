# Intune App SDK — Android Archive

Drop `Microsoft.Intune.MAM.SDK.aar` from the Intune App SDK release in this
folder. Download from <https://github.com/microsoftconnect/ms-intune-app-sdk-android>
(the AAR is in the root of the release, alongside the GradlePlugin folder).

The `app/build.gradle.kts` adds this folder as a `flatDir` repository and
declares `implementation(files("libs/Microsoft.Intune.MAM.SDK.aar"))`.
