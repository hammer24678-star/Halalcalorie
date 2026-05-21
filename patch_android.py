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
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.0"
}
"""

PROJECT_BUILD_GRADLE = """buildscript {
    ext.kotlin_version = '1.9.0'
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.4.2'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0"
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
    step_perms = (
        '    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />\n'
        '    <uses-permission android:name="android.hardware.sensor.stepcounter" />\n'
        '    <uses-feature android:name="android.hardware.sensor.stepcounter" android:required="false" />\n'
    )
    if "ACTIVITY_RECOGNITION" not in manifest:
        manifest = manifest.replace("<application", step_perms + "    <application", 1)
        with open(manifest_path, "w") as f: f.write(manifest)
        print("AndroidManifest: step counter permissions added")
    else:
        print("AndroidManifest: permissions already present")
else:
    print("WARNING: AndroidManifest.xml not found — run after flutter create")

# ── Kotlin version upgrade (required by purchases_flutter v8) ─────────
# flutter create generates settings.gradle with kotlin 1.7.21
# purchases_flutter v8 stdlib is compiled with 1.9.0 → version mismatch
settings_gradle = 'android/settings.gradle'
if os.path.exists(settings_gradle):
    sg = open(settings_gradle).read()
    sg_new = re.sub(
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
