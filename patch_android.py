APP_BUILD_GRADLE = """plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "com.halalcalorie.app"
    compileSdk 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = '11'
    }

    defaultConfig {
        applicationId "com.halalcalorie.app"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            shrinkResources false
            minifyEnabled false
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.7.21"
}
"""

PROJECT_BUILD_GRADLE = """buildscript {
    ext.kotlin_version = '1.7.21'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.4.2'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
"""

GRADLE_WRAPPER = """distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-7.6.3-all.zip
"""

with open('android/app/build.gradle', 'w') as f:
    f.write(APP_BUILD_GRADLE)
print("Wrote android/app/build.gradle")

with open('android/build.gradle', 'w') as f:
    f.write(PROJECT_BUILD_GRADLE)
print("Wrote android/build.gradle")

with open('android/gradle/wrapper/gradle-wrapper.properties', 'w') as f:
    f.write(GRADLE_WRAPPER)
print("Wrote gradle-wrapper.properties")

print("Patch complete.")

# ── Fix MainActivity package mismatch ─────────────────────
import os

kt_dir = "android/app/src/main/kotlin/com/halalcalorie/app"
os.makedirs(kt_dir, exist_ok=True)

# Remove wrong package directory flutter create generates
import shutil
wrong_dir = "android/app/src/main/kotlin/com/example"
if os.path.exists(wrong_dir):
    shutil.rmtree(wrong_dir)

with open(kt_dir + "/MainActivity.kt", "w") as f:
    f.write("package com.halalcalorie.app\n\n")
    f.write("import io.flutter.embedding.android.FlutterActivity\n\n")
    f.write("class MainActivity: FlutterActivity()\n")

print("MainActivity.kt written with correct package: com.halalcalorie.app")
