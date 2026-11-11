# Building the Play Store release (Android App Bundle)

## 1. Application ID

The application ID is `com.distress.roadmanager` (`android/app/build.gradle.kts`): the id of the app that is already on Google Play and registered in Firebase. **It cannot be changed.** (The Kotlin package `com.thapar.roaddistress` is only the code's namespace.)

To upload an update to that Play app you must sign the bundle with that app's **upload key** (held by whoever created the Play app) and use a `versionCode` higher than the one already on Play (the number after `+` in `pubspec.yaml`).

## 2. Create the upload keystore (once)

Run this in a terminal, in a folder OUTSIDE the repository, and answer the prompts. Choose strong passwords.

```powershell
keytool -genkeypair -v -keystore road-inspection-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

* Back the `.jks` file and both passwords up somewhere safe (two places). With **Play App Signing** (the
  default for new apps) Google holds the real app-signing key and this is only your *upload* key, so a lost upload
  key can be reset through Play support - but it is slow, so keep the backup.
* Never commit it; `key.properties` and `*.jks` are git-ignored.

## 3. Point the build at it

Copy `android/key.properties.example` to `android/key.properties` and fill in the passwords and the path to the `.jks`.

## 4. Build

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://<your-railway-domain>
```

Output: `build/app/outputs/bundle/release/app-release.aab`. Without `key.properties` this command refuses to run,
so a debug-signed bundle can never be produced by accident. (`flutter build apk --release` still falls back to the
debug key, which is fine for installing on your own phone.)

## 5. Before uploading

* `versionCode` must increase with every upload: raise the number after the `+` in `pubspec.yaml` (`version: 1.0.0+2`).
* Firebase console: add the SHA-1 and SHA-256 fingerprints of the key you sign with (upload key, and the Play App Signing key from the
  Play Console) to the Android app, otherwise Google sign-in fails with `DEVELOPER_ERROR`. Print a keystore's fingerprints with
  `keytool -list -v -keystore <file>.jks -alias upload`.
* Play Console > App access: a dedicated Google test account that is on the Firestore `allowedUsers` list (role `inspector`); see `SECURITY.md`.
* Play Console > App content: privacy policy URL, Data safety form, and the account-deletion URL
  (the in-app "Delete account" button plus the web page in `docs/privacy/delete-account.html`).
