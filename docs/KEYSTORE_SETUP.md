# HalalCalorie — Android Keystore Setup

## Step 1: Generate keystore (run once on your phone/PC)

```bash
keytool -genkey -v \
  -keystore halalcalorie.keystore \
  -alias halalcalorie \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=HalalCalorie, OU=Mobile, O=HalalCalorie, L=Cairo, S=Cairo, C=EG"
```

You will be asked for:
- Keystore password (save this somewhere safe)
- Key password (can be same as keystore password)

## Step 2: Upload to Codemagic

1. Go to Codemagic → your app → Environment variables
2. Upload halalcalorie.keystore as a FILE variable named: CM_KEYSTORE
3. Add these text variables:
   - CM_KEYSTORE_PASSWORD = your_keystore_password
   - CM_KEY_PASSWORD      = your_key_password
   - CM_KEY_ALIAS         = halalcalorie

## Step 3: NEVER commit the keystore to GitHub!
Add to .gitignore:
```
*.keystore
*.jks
key.properties
```

## Step 4: Backup the keystore!
- Google Play ties your app to this keystore FOREVER
- If you lose it, you CANNOT update your app on Play Store
- Save copies in: Google Drive, email to yourself, USB drive

## applicationId: com.halalcalorie.app
## Key alias: halalcalorie
