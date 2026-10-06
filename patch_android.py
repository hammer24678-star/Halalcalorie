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
    namespace "com.ihsanstudio.halalcalorie"
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
        applicationId "com.ihsanstudio.halalcalorie"
        minSdk 24
        targetSdk 36
        versionCode __VERSION_CODE__
        versionName "__VERSION_NAME__"
    }

    // PATCH_V40_16KB_PAGE_SIZE: keep native libs uncompressed + page-aligned in
    // the APK/AAB so Play's 16 KB check passes regardless of AGP's
    // minSdk-based default. minSdk 24 already implies this under
    // AGP 8.3+/9.x, but don't leave a Play-blocking check implicit.
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
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
        classpath 'com.android.tools.build:gradle:9.1.0'
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
distributionUrl=https\\://services.gradle.org/distributions/gradle-9.1.0-all.zip
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

kt_dir = "android/app/src/main/kotlin/com.ihsanstudio.halalcalorie"
os.makedirs(kt_dir, exist_ok=True)

# Remove wrong package directory flutter create generates
import shutil
wrong_dir = "android/app/src/main/kotlin/com/example"
if os.path.exists(wrong_dir):
    shutil.rmtree(wrong_dir)

with open(kt_dir + "/MainActivity.kt", "w") as f:
    f.write("package com.ihsanstudio.halalcalorie\n\n")
    f.write("import io.flutter.embedding.android.FlutterActivity\n\n")
    f.write("class MainActivity: FlutterActivity()\n")

print("MainActivity.kt written with correct package: com.ihsanstudio.halalcalorie")

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
        # Pedometer / health
        ('ACTIVITY_RECOGNITION',
         '    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />'),
        ('sensor.stepcounter',
         '    <uses-feature android:name="android.hardware.sensor.stepcounter" android:required="false" />'),
        # Notifications
        ('POST_NOTIFICATIONS',
         '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />'),
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

# ── Strip READ_MEDIA_IMAGES / READ_MEDIA_VIDEO merged in by plugins ────
# permission_handler bundles these in its own AAR manifest for every
# permission group it supports, regardless of whether Dart code actually
# requests them. Play flags this as invalid use of photo/video permissions
# since this app only does occasional one-shot photo picks via
# image_picker's system picker — it never needs broad media-library access.
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as f: manifest = f.read()
    changed = False

    if 'xmlns:tools=' not in manifest:
        manifest = manifest.replace(
            'xmlns:android="http://schemas.android.com/apk/res/android"',
            'xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools"',
            1
        )
        changed = True

    for perm in ['READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO']:
        full_name = f'android.permission.{perm}'
        if full_name not in manifest:
            line = f'    <uses-permission android:name="{full_name}" tools:node="remove" />'
            manifest = manifest.replace('<application', line + '\n    <application', 1)
            changed = True

    if changed:
        with open(manifest_path, 'w') as f: f.write(manifest)
        print('AndroidManifest: stripped READ_MEDIA_IMAGES/VIDEO via tools:node=remove')
    else:
        print('AndroidManifest: media-permission removal already present')

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


# PATCH_V58_NOTIF ─ make local notifications actually work on Android
# 1. a monochrome status-bar icon (the launcher icon renders as a white square)
_icon_xml = (
    '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    android:width="24dp" android:height="24dp"\n'
    '    android:viewportWidth="24" android:viewportHeight="24">\n'
    '    <path android:fillColor="#FFFFFFFF"\n'
    '        android:pathData="M21,12.79A9,9 0 1,1 11.21,3 7,7 0 0,0 21,12.79z"/>\n'
    '</vector>\n')
_drawable_dir = "android/app/src/main/res/drawable"
os.makedirs(_drawable_dir, exist_ok=True)
with open(_drawable_dir + "/ic_stat_halal.xml", "w", encoding="utf-8") as _f:
    _f.write(_icon_xml)
print("Notification icon written: drawable/ic_stat_halal.xml")

# 2. permissions + receivers (the plugin's own manifest declares them too; an
#    identical explicit declaration merges cleanly and removes any doubt)
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as _f: _m = _f.read()
    _changed = False
    for _perm in ("RECEIVE_BOOT_COMPLETED", "VIBRATE"):
        if "android.permission." + _perm not in _m:
            _m = _m.replace("<application",
                '    <uses-permission android:name="android.permission.' + _perm + '" />\n    <application', 1)
            _changed = True
    if "ScheduledNotificationReceiver" not in _m:
        _recv = (
            '    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
            '    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
            '        <intent-filter>\n'
            '            <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
            '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
            '            <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n'
            '            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
            '        </intent-filter>\n'
            '    </receiver>\n')
        _m = _m.replace("</application>", _recv + "    </application>", 1)
        _changed = True
    if _changed:
        with open(manifest_path, "w") as _f: _f.write(_m)
        print("AndroidManifest: notification permissions + receivers added")
    else:
        print("AndroidManifest: notification setup already present")


# PATCH_V59_STEPCARD ─ live step card: Kotlin sources, layouts, service, permissions
import shutil as _sh
_kt_dst = "android/app/src/main/kotlin/com.ihsanstudio.halalcalorie"
os.makedirs(_kt_dst, exist_ok=True)
if os.path.isdir("android_extra/kotlin"):
    for _n in os.listdir("android_extra/kotlin"):
        _sh.copy("android_extra/kotlin/" + _n, _kt_dst + "/" + _n)   # includes the new MainActivity.kt
    print("StepCard: Kotlin sources copied")
_lay_dst = "android/app/src/main/res/layout"
os.makedirs(_lay_dst, exist_ok=True)
if os.path.isdir("android_extra/res/layout"):
    for _n in os.listdir("android_extra/res/layout"):
        _sh.copy("android_extra/res/layout/" + _n, _lay_dst + "/" + _n)
    print("StepCard: layouts copied")
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as _f: _m = _f.read()
    _ch = False
    for _perm in ("FOREGROUND_SERVICE", "FOREGROUND_SERVICE_HEALTH"):
        if 'android.permission.' + _perm + '"' not in _m:
            _m = _m.replace("<application",
                '    <uses-permission android:name="android.permission.' + _perm + '" />\n    <application', 1)
            _ch = True
    if "StepCardService" not in _m:
        _svc = (
            '    <service android:name="com.ihsanstudio.halalcalorie.StepCardService" android:exported="false" android:foregroundServiceType="health" />\n'
            '    <receiver android:name="com.ihsanstudio.halalcalorie.StepCardBootReceiver" android:exported="true">\n'
            '        <intent-filter>\n'
            '            <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
            '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
            '        </intent-filter>\n'
            '    </receiver>\n')
        _m = _m.replace("</application>", _svc + "    </application>", 1)
        _ch = True
    if _ch:
        with open(manifest_path, "w") as _f: _f.write(_m)
        print("AndroidManifest: step card service + permissions added")
    else:
        print("AndroidManifest: step card already present")
