pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdk = properties.getProperty("flutter.sdk")
            require(flutterSdk != null) { "flutter.sdk not set in local.properties" }
            flutterSdk
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        val preferOfficialRepositories = System.getenv("GITHUB_ACTIONS") == "true"
        maven { url = uri("$flutterSdkPath/bin/cache/artifacts/engine") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        if (preferOfficialRepositories) {
            google()
            mavenCentral()
            gradlePluginPortal()
        }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        if (!preferOfficialRepositories) {
            google()
            mavenCentral()
            gradlePluginPortal()
        }
    }
}

dependencyResolutionManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdk = properties.getProperty("flutter.sdk")
            require(flutterSdk != null) { "flutter.sdk not set in local.properties" }
            flutterSdk
        }
    // Keep subprojects on the same repository set.
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        val preferOfficialRepositories = System.getenv("GITHUB_ACTIONS") == "true"
        maven { url = uri("$flutterSdkPath/bin/cache/artifacts/engine") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        if (preferOfficialRepositories) {
            google()
            mavenCentral()
        }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        if (!preferOfficialRepositories) {
            google()
            mavenCentral()
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
