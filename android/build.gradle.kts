allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// توجيه مخرجات البناء إلى مجلد أبعد لتقليل عمق المسارات
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ═══════════════════════════════════════════════════════════════
// إصلاح توافق AGP 8.x مع إضافات Flutter القديمة
// بعض الحزم (مثل on_audio_query_android 1.1.0) لم تُحدّث build.gradle
// لتتضمن namespace، مما يسبب فشل البناء مع AGP 8+
// هذا الـ hook يضيف namespace تلقائيًا لأي إضافة تفتقده
// ═══════════════════════════════════════════════════════════════
subprojects {
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
            ?: return@afterEvaluate

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
            // إضافة قديمة جدًا لا تدعم namespace — نتجاهل
        } catch (e: Exception) {
            logger.lifecycle(
                "⚠️ Namespace patch failed for ${project.name}: ${e.message}"
            )
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
