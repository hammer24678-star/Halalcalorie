import re, os, sys

print("=== patch_android.py starting ===")

# build.gradle
g_path = 'android/app/build.gradle'
if not os.path.exists(g_path):
    print("ERROR: build.gradle not found")
    sys.exit(1)

g = open(g_path).read()
g = re.sub(r'applicationId\s+"[^"]+"', 'applicationId "com.halalcalorie.app"', g)
g = re.sub(r'minSdk\s+\d+', 'minSdk 21', g)
g = re.sub(r'minSdkVersion\s+\d+', 'minSdkVersion 21', g)
g = re.sub(r'targetSdk\s+\d+', 'targetSdk 34', g)
g = re.sub(r'targetSdkVersion\s+\d+', 'targetSdkVersion 34', g)
g = re.sub(r'compileSdk\s+\d+', 'compileSdk 34', g)
g = re.sub(r'compileSdkVersion\s+\d+', 'compileSdkVersion 34', g)
g = re.sub(r'versionCode\s+\d+', 'versionCode 1', g)
g = re.sub(r'versionName\s+"[^"]+"', 'versionName "1.0.0"', g)
open(g_path, 'w').write(g)
print("Patched build.gradle")

# AndroidManifest.xml
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

# strings.xml
s_path = 'android/app/src/main/res/values/strings.xml'
if os.path.exists(s_path):
    s = open(s_path).read()
    s = re.sub(r'<string name="app_name">[^<]*</string>', '<string name="app_name">HalalCalorie</string>', s)
    open(s_path, 'w').write(s)
    print("Patched strings.xml")

print("=== patch_android.py done ===")
