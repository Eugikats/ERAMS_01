allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// agora_rtc_engine's android/build.gradle reads rootProject.ext.compileSdkVersion
// (via safeExtGet), falling back to a hardcoded 31 if unset — too low for its own
// transitive androidx deps (need 33+). Setting it here on rootProject.extra is
// visible to that Groovy safeExtGet() lookup since both share the same
// ExtraPropertiesExtension instance.
rootProject.extra["compileSdkVersion"] = 36

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
