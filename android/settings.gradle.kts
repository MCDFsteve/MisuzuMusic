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
        // 解决 gradlePluginPortal TLS 握手/网络受限导致的依赖下载失败，优先走可访问的镜像
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // Flutter engine 本地/镜像仓库，确保能解析 flutter_embedding_* 等构件
        maven { url = uri("$flutterSdkPath/bin/cache/artifacts/engine") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        google()
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
    // 强制全局使用这里声明的仓库，避免子工程自行回落到无法访问的默认仓库
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("$flutterSdkPath/bin/cache/artifacts/engine") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        google()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
