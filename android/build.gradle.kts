allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ═══════════════════════════════════════════════════════════════
// إصلاح AGP 8.x مع إضافات Flutter القديمة
// (namespace + Java 17) — بدون kotlinOptions المهجورة
// ═══════════════════════════════════════════════════════════════
subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            // ─── 1. Java 17 على كل الإضافات ───
            try {
                val compileOptions = androidExt.javaClass
                    .getMethod("getCompileOptions")
                    .invoke(androidExt)
                if (compileOptions != null) {
                    compileOptions.javaClass
                        .getMethod("setSourceCompatibility", JavaVersion::class.java)
                        .invoke(compileOptions, JavaVersion.VERSION_17)
                    compileOptions.javaClass
                        .getMethod("setTargetCompatibility", JavaVersion::class.java)
                        .invoke(compileOptions, JavaVersion.VERSION_17)
                }
            } catch (_: Exception) { /* تجاهل */ }

            // ─── 2. namespace patch ───
            try {
                val getNs = androidExt.javaClass.getMethod("getNamespace")
                val currentNs = getNs.invoke(androidExt) as? String
                if (currentNs.isNullOrBlank()) {
                    val setNs = androidExt.javaClass.getMethod(
                        "setNamespace",
                        String::class.java
                    )
                    val packageName = "com.patched." +
                        project.name.replace("-", "_").replace(".", "_")
                    setNs.invoke(androidExt, packageName)
                    logger.lifecycle(
                        "✅ Namespace patched for ${project.name}: $packageName"
                    )
                }
            } catch (_: NoSuchMethodException) {
            } catch (e: Exception) {
                logger.lifecycle(
                    "⚠️ Namespace patch failed for ${project.name}: ${e.message}"
                )
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
