buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Plugin Firebase — appliqué de façon conditionnelle dans
        // android/app/build.gradle.kts uniquement si google-services.json
        // est présent (voir story 1.1 : Firebase optionnel tant que le
        // projet n'est pas encore créé / le secret CI pas encore fourni).
        classpath("com.google.gms:google-services:4.4.4")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// On utilise le build directory par défaut (android/build/) au lieu de
// rediriger vers ../build/ pour éviter les problèmes de résolution de
// chemin sur CI.

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
