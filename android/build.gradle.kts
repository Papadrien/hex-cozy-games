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

val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
