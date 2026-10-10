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
// إصلاح AGP 8.x مع إضافات Flutter القديمة (on_audio_query_android, إلخ)
// ═══════════════════════════════════════════════════════════════
subprojects {
    afterEvaluate {
        // ─── 1. فرض Java 17 على كل الإضافات ───
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                // compileOptions
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

            // ─── 2. namespace patch للـ plugins القديمة ───
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

        // ─── 3. إجبار Kotlin jvmTarget = 17 على كل المشاريع الفرعية ───
        try {
            project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
                .configureEach {
                    kotlinOptions {
                        jvmTarget = "17"
                    }
                }
        } catch (_: Exception) {
            // إذا لم تكن الإضافة تستخدم Kotlin، نتجاهل
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
