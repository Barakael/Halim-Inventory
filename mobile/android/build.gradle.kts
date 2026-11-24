allprojects {
    repositories {
        // Local copy of the Flutter arm64 release engine. Google Storage
        // downloads of this jar time out on this network.
        val engineMirror = File("${System.getProperty("user.home")}/.gradle/flutter-engine-mirror")
        if (engineMirror.isDirectory) {
            maven { url = uri(engineMirror) }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
