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

    // Pre-create stub typedefs.txt so syncLibJars configuration validation passes
    // (extractAnnotations is disabled to avoid downloading large lint tool jars)
    listOf(
        "intermediates/annotations_typedef_file/debug/extractDebugAnnotations/typedefs.txt",
        "intermediates/annotations_typedef_file/release/extractReleaseAnnotations/typedefs.txt"
    ).forEach { relPath ->
        val f = File(newSubprojectBuildDir.asFile, relPath)
        f.parentFile.mkdirs()
        if (!f.exists()) f.createNewFile()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Force all Kotlin stdlib deps to match the compiler (2.3.10)
subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("2.3.10")
            }
        }
    }
    // Disable annotation extraction tasks — avoids downloading large lint tool jars
    tasks.configureEach {
        if (name.startsWith("extract") && name.endsWith("Annotations")) {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
