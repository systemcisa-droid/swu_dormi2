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
// 오래된 플러그인(syncfusion_flutter_pdfviewer 31, vibration/video_thumbnail 33)이 하드코딩한
// compileSdk가 최신 androidx 의존성의 최소 요구(34)보다 낮아 checkDebugAarMetadata에서 실패한다.
// 라이브러리 모듈에 한해 앱과 같은 compileSdk로 끌어올린다 (targetSdk/minSdk는 변경하지 않음).
// 아래 evaluationDependsOn(":app")이 :app을 즉시 평가하므로 반드시 그보다 먼저 등록해야 한다.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { android ->
            if ((android.compileSdk ?: 0) < 34) {
                android.compileSdk = 36
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
