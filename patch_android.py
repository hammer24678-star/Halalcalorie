import re, os, sys

print("=== patch_android.py starting ===")

# ── 1. Write app/build.gradle from scratch ───────────────────
# No regex — just overwrite with exact known-good content
build_gradle = """plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "com.halalcalorie.app"
    compileSdk 34

    defaultConfig {
        applicationId "com.halalcalorie.app"
        minSdk 26
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
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
"""

g_path = 'android/app/build.gradle'
if os.path.exists(g_path):
    open(g_path, 'w').write(build_gradle)
    print("Wrote app/build.gradle from scratch")
else:
    print(f"ERROR: {g_path} not found — flutter create may have failed")
    sys.exit(1)

# ── 2. Patch settings.gradle — bump Kotlin to 1.9.22 ────────
s_path = 'android/settings.gradle'
if os.path.exists(s_path):
    s = open(s_path).read()
    s = re.sub(
        r'id\s+"org\.jetbrains\.kotlin\.android"\s+version\s+"[^"]+"',
        'id "org.jetbrains.kotlin.android" version "1.9.22"',
        s
    )
    open(s_path, 'w').write(s)
    # Verify
    for line in open(s_path).read().split('\n'):
        if 'kotlin' in line.lower():
            print(f"  settings.gradle: {line.strip()}")
else:
    print("WARNING: settings.gradle not found")

# ── 3. AndroidManifest.xml ───────────────────────────────────
m_path = 'android/app/src/main/AndroidManifest.xml'
if os.path.exists(m_path):
    m = open(m_path).read()
    perms = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.CAMERA"/>',
        '<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>',
        '<uses-permission android:name="android.permission.BODY_SENSORS"/>',
        '<uses-permission android:name="android.permission.VIBRATE"/>',
    ]
    for p in perms:
        if p not in m:
            m = m.replace('<application', p + '\n    <application', 1)
    open(m_path, 'w').write(m)
    print("Patched AndroidManifest.xml")

# ── 4. strings.xml ───────────────────────────────────────────
s2 = 'android/app/src/main/res/values/strings.xml'
if os.path.exists(s2):
    c = open(s2).read()
    c = re.sub(r'<string name="app_name">[^<]*</string>',
               '<string name="app_name">HalalCalorie</string>', c)
    open(s2, 'w').write(c)
    print("Patched strings.xml")

print("=== patch_android.py done ===")
