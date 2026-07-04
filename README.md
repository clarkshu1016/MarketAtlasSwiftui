# MarketAtlas iOS

SwiftUI stock market app with AI chat, company screener, price history, and favorites.

---

## CI/CD — Auto Debug Build → Firebase App Distribution

Every push to `main` automatically:
1. Increments the build number (total git commit count)
2. Builds a Debug IPA (Ad Hoc signed)
3. Uploads to Firebase App Distribution for testers

### One-Time Setup

#### 1. Apple Developer Portal

1. Go to [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles
2. **Certificates** → Create an **Apple Distribution** certificate
   - Export as `.p12` with a password
   - Base64 encode: `base64 -i ~/Downloads/cert.p12 | pbcopy`
3. **Devices** → Register any test devices (UDID required for Ad Hoc)
4. **Provisioning Profiles** → Create an **Ad Hoc** profile
   - App ID: `com.appdevgpt.marketatlas1`
   - Certificate: select your Distribution cert
   - Devices: select registered test devices
   - Name: `MarketAtlas AdHoc`
   - Download, then base64 encode: `base64 -i ~/Downloads/MarketAtlas_AdHoc.mobileprovision | pbcopy`

#### 2. Firebase Console

1. [console.firebase.google.com](https://console.firebase.google.com) → your project
2. **Project Settings** → Your Apps → copy the **App ID** (format: `1:XXXXXXXXXX:ios:XXXX`)
3. **Project Settings** → Service Accounts → **Generate new private key** → download JSON
   - Copy contents: `cat ~/Downloads/<file>.json | pbcopy`

#### 3. GitHub Secrets

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → add all 6:

| Secret Name | Value |
|---|---|
| `APPLE_P12_BASE64` | Base64 of your `.p12` certificate |
| `APPLE_P12_PASSWORD` | Password used when exporting the `.p12` |
| `PROVISIONING_PROFILE_BASE64` | Base64 of `MarketAtlas_AdHoc.mobileprovision` |
| `PROVISIONING_PROFILE_NAME` | `MarketAtlas AdHoc` |
| `FIREBASE_APP_ID` | App ID from Firebase console |
| `FIREBASE_SERVICE_ACCOUNT` | Full JSON content of the service account key |

#### 4. Xcode Project Signing

In Xcode:
1. Click the `MarketAtlas` project → `MarketAtlas` **target** → **Signing & Capabilities**
2. Uncheck **"Automatically manage signing"**
3. Set **Team** → `AY6Y6KCP7Y`
4. Set **Provisioning Profile** → `MarketAtlas AdHoc`
5. Cmd+S — commit the resulting `project.pbxproj` change

> This configures Manual signing for the main app target only.
> SPM dependencies (Firebase, GoogleSignIn, etc.) are unaffected.

---

### How It Works

```
Push to main
    │
    ├─ Set build number = git commit count
    ├─ Install Distribution certificate into keychain
    ├─ Install Ad Hoc provisioning profile
    ├─ xcodebuild archive (Debug, generic/platform=iOS)
    ├─ xcodebuild exportArchive → .ipa (Ad Hoc)
    └─ Upload to Firebase App Distribution (testers group)
```

**Build number** auto-increments on every push — no manual changes needed.
**Release builds** are unaffected — this workflow only runs for Debug.

### Files

| File | Purpose |
|---|---|
| `.github/workflows/debug-distribute.yml` | GitHub Actions workflow |
| `ExportOptionsDebug.plist` | Ad Hoc export options (method, team, provisioning profile) |

---

## Local Development

Requirements:
- Xcode 16+
- iOS 17+ deployment target
- Swift Package dependencies resolve automatically on first open

### Backend

The app connects to a FastAPI backend at `https://marketatlas.appdevgpt.com`.

For local development, update `APIService.swift` base URL to `http://127.0.0.1:8000`.

---

## Tech Stack

- **SwiftUI** + `@Observable` (iOS 17+)
- **Firebase** (Analytics, Crashlytics)
- **Google Sign-In**
- **RevenueCat** (Pro subscriptions)
- **SFSpeechRecognizer** (voice input in chat)
- **AVSpeechSynthesizer** (TTS in chat)
