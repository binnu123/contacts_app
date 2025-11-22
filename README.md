# Contact Backup App

Simple Flutter app that exports phone contacts to a JSON file and allows sharing the backup.

## How to use
1. Commit & push these files to GitHub (you already cloned and will push).
2. The GitHub Actions workflow will run and build an APK. After the run succeeds, download the `app-release` artifact from the Actions run.
3. Install the APK on your Android device and grant Contacts permission.

## Optional: Signing
To produce signed APKs, create a Java keystore locally and add these GitHub Secrets:
- ANDROID_KEYSTORE_BASE64 (base64 of .jks)
- KEYSTORE_PASSWORD
- KEY_ALIAS
- KEY_PASSWORD

The workflow will use them to sign the build.
