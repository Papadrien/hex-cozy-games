# Rules
- When user asks to fix a build: always `git add`, `git commit`, and `git push` after applying fixes
- Run `flutter analyze` (not `dart analyze`) and `flutter test` after every code change

# Context
- Flutter 3.44.3 / Dart 3.12.2 / AGP 9.0.1 / Kotlin 2.3.20 / Gradle 9.1.0
- No Android SDK in this dev environment (`flutter build` will fail with "No Android SDK found")
- `flutter analyze` and `flutter test` work fine

# Fixed (séance en cours)
- `android/gradle.properties` : `android.newDsl=true` → `false` (Flutter Gradle plugin ne supporte pas AGP 9 new DSL)
- `android/gradle.properties` : `android.builtInKotlin=true` → `false` (KGP introuvable sur le classpath avec le mode built-in)
- Android SDK 36 installé (platform + build-tools)
- NDK 28.2.13676358 installé
- Licences Android acceptées

# Bloquant
- AAPT2 crash avec "Illegal instruction" sur ce CPU (environnement virtualisé incompatible avec les instructions CPU des binaires AAPT2 récents). Le build Android ne peut pas finaliser ici, mais `flutter analyze` et `flutter test` passent.
