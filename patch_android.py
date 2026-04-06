import os, re

ROOT = os.path.dirname(os.path.abspath(__file__))
ANDROID = os.path.join(ROOT, 'android')

# ── app/build.gradle (write from scratch) ───────────────────
app_gradle = os.path.join(ANDROID, 'app', 'build.gradle')
os.makedirs(os.path.dirname(app_gradle), exist_ok=True)
with open(app_gradle, 'w') as f:
    f.write("""plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "com.halalcalorie.app"
    compileSdk 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
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
            signingConfig signingConfigs.debug
            minifyEnabled false
            shrinkResources false
        }
    }
}

flutter {
    source "../.."
}
""")
print("Wrote app/build.gradle (compileSdk 34)")

# ── settings.gradle (kotlin 1.9.22) ─────────────────────────
settings = os.path.join(ANDROID, 'settings.gradle')
if os.path.exists(settings):
    content = open(settings).read()
    content = re.sub(
        r'id "org\.jetbrains\.kotlin\.android" version "[^"]*"',
        'id "org.jetbrains.kotlin.android" version "1.9.22"',
        content
    )
    open(settings, 'w').write(content)
    print("Patched settings.gradle: kotlin 1.9.22")

# ── AndroidManifest.xml ──────────────────────────────────────
manifest = os.path.join(ANDROID, 'app', 'src', 'main', 'AndroidManifest.xml')
if os.path.exists(manifest):
    content = open(manifest).read()
    perms = [
        'android.permission.INTERNET',
        'android.permission.CAMERA',
        'android.permission.ACTIVITY_RECOGNITION',
        'android.permission.BODY_SENSORS',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.WRITE_EXTERNAL_STORAGE',
    ]
    for p in perms:
        tag = f'<uses-permission android:name="{p}"/>'
        if tag not in content:
            content = content.replace(
                '<application', tag + '\n    <application', 1)
    open(manifest, 'w').write(content)
    print("Patched AndroidManifest.xml")

# ── strings.xml (app name) ───────────────────────────────────
strings_dir = os.path.join(ANDROID, 'app', 'src', 'main', 'res', 'values')
os.makedirs(strings_dir, exist_ok=True)
strings_file = os.path.join(strings_dir, 'strings.xml')
with open(strings_file, 'w') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n')
    f.write('<resources>\n')
    f.write('    <string name="app_name">HalalCalorie</string>\n')
    f.write('</resources>\n')
print("Wrote strings.xml")

print("patch_android.py done.")
