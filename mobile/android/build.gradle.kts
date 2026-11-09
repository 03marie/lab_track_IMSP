allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Par défaut, Flutter/AGP demandent le NDK 28.2 (~1,2 Go) et les Build-Tools 36 : à télécharger.
// On impose à tous les modules (app et plugins) les versions déjà installées sur le PC.
subprojects {
    val imposerNdk = {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            ndkVersion = "27.0.12077973"
            buildToolsVersion = "35.0.0"
        }
    }
    // `:app` est déjà évalué (evaluationDependsOn ci-dessus) : afterEvaluate y est interdit.
    if (state.executed) imposerNdk() else afterEvaluate { imposerNdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
