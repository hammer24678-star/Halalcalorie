import re, os, sys

print("=== patch_android.py starting ===")

# 1. settings.gradle — new Flutter 3.22 style, Kotlin version lives here
s_path = 'android/settings.gradle'
if os.path.exists(s_path):
    s = open(s_path).read()
    print("settings.gradle kotlin line:")
    for line in s.split('\n'):
        if 'kotlin' in line.lower():
            print(f"  {line.strip()}")
    # Bump kotlin android plugin to 1.9.22
    s = re.sub(
        r'id\s+"org\.jetbrains\.kotlin\.android"\s+version\s+"[^"]+"',
        'id "org.jetbrains.kotlin.android" version "1.9.22"',
        s
    )
    open(s_path, 'w').write(s)
    print("Patched settings.gradle: kotlin 1.9.22")
else:
    print("settings.gradle not found - skipping")

# 2. app/build.gradle
g_path = 'android/app/build.gradle'
if not os.path.exists(g_path):
    print("ERROR: app/build.gradle not found")
    sys.exit(1)

g = open(g_path).read()
g = re.sub(r'applicationId\s+"[^"]+"', 'applicationId "com.halalcalorie.app"', g)
g = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 21', g)
g = re.sub(r'minSdk\s+flutter\.minSdkVersion', 'minSdk 21', g)
g = re.sub(r'minSdkVersion\s+\d+', 'minSdkVersion 21', g)
g = re.sub(r'minSdk\s+\d+', 'minSdk 21', g)
g = re.sub(r'targetSdkVersion\s+flutter\.targetSdkVersion', 'targetSdkVersion 35', g)
g = re.sub(r'targetSdk\s+flutter\.targetSdkVersion', 'targetSdk 35', g)
g = re.sub(r'targetSdkVersion\s+\d+', 'targetSdkVersion 35', g)
g = re.sub(r'targetSdk\s+\d+', 'targetSdk 35', g)
g = re.sub(r'compileSdkVersion\s+flutter\.compileSdkVersion', 'compileSdkVersion 35', g)
g = re.sub(r'compileSdk\s+flutter\.compileSdkVersion', 'compileSdk 35', g)
g = re.sub(r'compileSdkVersion\s+\d+', 'compileSdkVersion 35', g)
g = re.sub(r'compileSdk\s+\d+', 'compileSdk 35', g)
g = re.sub(r'versionCode\s+\d+', 'versionCode 1', g)
g = re.sub(r'versionName\s+"[^"]+"', 'versionName "1.0.0"', g)
open(g_path, 'w').write(g)
print("Patched app/build.gradle")

for line in open(g_path).read().split('\n'):
    if any(x in line for x in ['minSdk', 'targetSdk', 'compileSdk', 'applicationId']):
        print(f"  {line.strip()}")

# 3. AndroidManifest.xml
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

# 4. strings.xml
s_path2 = 'android/app/src/main/res/values/strings.xml'
if os.path.exists(s_path2):
    s2 = open(s_path2).read()
    s2 = re.sub(r'<string name="app_name">[^<]*</string>', '<string name="app_name">HalalCalorie</string>', s2)
    open(s_path2, 'w').write(s2)
    print("Patched strings.xml")

print("=== patch_android.py done ===")
