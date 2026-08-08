# ─────────────────────────────────────────────────────────────
# WorkManager / Room
#
# Fix crash release : "Unable to get provider
# androidx.startup.InitializationProvider" ->
# NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
#
# Cause : le SDK AdMob initialise WorkManager très tôt (avant
# Application.onCreate, via androidx.startup) et instancie
# WorkDatabase_Impl par réflexion en cherchant son constructeur
# sans argument. Flutter active R8 par défaut sur les builds
# release (même sans minifyEnabled explicite dans build.gradle.kts),
# et sans ces règles, R8 strippe/renomme ce constructeur car il ne
# détecte pas l'appel réflectif interne à WorkManager.
# ─────────────────────────────────────────────────────────────
-keep class androidx.work.impl.WorkDatabase
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keep class androidx.work.impl.model.** { *; }
-keep class androidx.work.impl.background.systemjob.SystemJobService
-dontwarn androidx.work.**
