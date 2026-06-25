import re as _vre

# -- Read version from pubspec.yaml (single source of truth) --
with open("pubspec.yaml", encoding="utf-8") as _f:
    _pubspec_src = _f.read()
_vm = _vre.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$",
                   _pubspec_src, _vre.MULTILINE)
if not _vm:
    raise SystemExit("ERROR: couldn't find version: X.Y.Z+N in pubspec.yaml")
VERSION_NAME = _vm.group(1)
VERSION_CODE = int(_vm.group(2))
print(f"Read from pubspec.yaml -> versionName={VERSION_NAME} versionCode={VERSION_CODE}")

APP_BUILD_GRADLE = """plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "com.halalcalorie.app"
    compileSdk 36
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
        coreLibraryDesugaringEnabled true
    }

    kotlinOptions {
        jvmTarget = '11'
    }

    defaultConfig {
        applicationId "com.halalcalorie.app"
        minSdk 24
        targetSdk 36
        versionCode __VERSION_CODE__
        versionName "__VERSION_NAME__"
    }

    signingConfigs {
        release {
            storeFile file(System.getenv("KEYSTORE_PATH") ?: "keystore.jks")
            storePassword System.getenv("STORE_PASSWORD") ?: ""
            keyAlias     System.getenv("KEY_ALIAS")       ?: ""
            keyPassword  System.getenv("KEY_PASSWORD")    ?: ""
        }
    }

    buildTypes {
        release {
            shrinkResources false
            minifyEnabled false
            signingConfig signingConfigs.release
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.0.21"
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
"""
APP_BUILD_GRADLE = (APP_BUILD_GRADLE
    .replace("__VERSION_CODE__", str(VERSION_CODE))
    .replace("__VERSION_NAME__", VERSION_NAME))

PROJECT_BUILD_GRADLE = """buildscript {
    ext.kotlin_version = '2.0.21'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.5.2'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.21"
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
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.13-all.zip
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

# ── App launcher icon ──────────────────────────────────────
icon_sizes = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

# Simple green circle with crescent as placeholder icon
# Replace assets/logo.png with your real logo before building
import shutil, os
for folder in icon_sizes:
    path = f"android/app/src/main/res/{folder}"
    os.makedirs(path, exist_ok=True)
    # Copy logo.png as launcher icon
    if os.path.exists("assets/logo.png"):
        shutil.copy("assets/logo.png", f"{path}/ic_launcher.png")

print("Launcher icons written")

# ── Patch AndroidManifest — step counter permissions ──────────
manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as f: manifest = f.read()
    needed = [
        # Core
        ('android.permission.INTERNET',
         '    <uses-permission android:name="android.permission.INTERNET" />'),
        ('CAMERA',
         '    <uses-permission android:name="android.permission.CAMERA" />'),
        # Media (Android 13+)
        ('READ_MEDIA_IMAGES',
         '    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />'),
        # Pedometer / health
        ('ACTIVITY_RECOGNITION',
         '    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />'),
        ('sensor.stepcounter',
         '    <uses-feature android:name="android.hardware.sensor.stepcounter" android:required="false" />'),
        # Notifications
        ('POST_NOTIFICATIONS',
         '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />'),
        # Foreground service (workout timer)
        ('FOREGROUND_SERVICE"',
         '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />'),
        ('FOREGROUND_SERVICE_HEALTH',
         '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_HEALTH" />'),
    ]
    inserted = False
    for marker, line in needed:
        if marker not in manifest:
            manifest = manifest.replace('<application', line + '\n    <application', 1)
            inserted = True
    if inserted:
        with open(manifest_path, 'w') as f: f.write(manifest)
        print('AndroidManifest: foreground service permissions added')
    else:
        print('AndroidManifest: all permissions already present')
else:
    print("WARNING: AndroidManifest.xml not found — run after flutter create")

# ── Kotlin version upgrade (required by purchases_flutter v8) ─────────
# flutter create generates settings.gradle with kotlin 1.7.21
# purchases_flutter v8 stdlib is compiled with 1.9.0 → version mismatch
import re as _re
settings_gradle = 'android/settings.gradle'
if os.path.exists(settings_gradle):
    sg = open(settings_gradle).read()
    sg_new = _re.sub(
        r'(id\s+"org\.jetbrains\.kotlin\.android"\s+version\s+")[^"]+(")',
        r'\g<1>1.9.0\2',
        sg
    )
    if sg_new != sg:
        open(settings_gradle, 'w').write(sg_new)
        print("settings.gradle: Kotlin upgraded to 1.9.0")
    else:
        print("settings.gradle: Kotlin already 1.9.0 or key line not found")
else:
    print("WARNING: android/settings.gradle not found — Kotlin not patched")
