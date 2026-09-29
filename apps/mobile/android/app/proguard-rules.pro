# Firebase discovers its components by class name from AndroidManifest
# metadata (ComponentDiscoveryService), so R8 sees no code reference to the
# registrars and strips/renames them. Without them Firebase.initializeApp
# throws ("FirebaseCrashlytics component is not present") and the app never
# gets past main() — a black screen on every release install. Debug builds
# don't shrink, so this only ever shows up in a release build.
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar
-keep class com.google.firebase.components.** { *; }
-keep class com.google.firebase.crashlytics.CrashlyticsRegistrar { *; }
-keep class com.google.firebase.installations.** { *; }
-keep class com.google.firebase.provider.FirebaseInitProvider { *; }
-keep class com.google.firebase.ktx.** { *; }
-keep class com.google.firebase.analytics.connector.** { *; }
