# TapLead

**Tap. Connect. Convert.** A native iOS digital card and networking CRM, with a runnable public-profile and lead-capture service.

## What is here

- SwiftUI app targeting iOS 17+, with onboarding, local/demo exploration, profile editing, public-field controls, local photos, themes, section and social ordering, QR sharing and event mode.
- Connections inbox with five statuses, search, tags, editable notes, timeline, follow-ups, local notifications, reviewed on-device speech transcription and a voice-command review screen.
- Durable offline lead outbox with idempotent API writes and retry on connectivity/foreground changes.
- Core NFC tag write plus read-back verification, capability checks and QR fallback.
- Small, medium and large QR widgets and four App Intents. Widgets contain no lead details.
- Email authentication, Keychain session storage, server-verified Apple identity tokens, nonce challenges and encrypted Apple refresh credentials for deletion/revocation.
- SQLite-backed HTTPS-ready service with private owner routes, consented public lead forms, vCards, measured events, data export and account deletion.
- Consent-gated AI gateway contract with evidence checks and reviewable drafts. No AI vendor secrets or automatic sending in the app.
- StoreKit purchase/restore adapter with server JWS verification, account binding, signed renewal/revocation notifications and Free/Pro limits; signed Wallet-pass client architecture. Purchase UI is deliberately disabled pending release configuration/verification.
- English string catalogue and nine additional locale review queues; extraction and optional approved-gateway draft workflow.

**This is an implementation baseline, not a verified production release.** The iOS sources have been syntax checked on Windows; SwiftUI, entitlements, hardware and UI tests require Xcode on a Mac. See [release status](docs/RELEASE.md) for the exact remaining work. No App Store Connect record has been changed.

## Run the service on Windows

Use Node 24 or newer. From the project root:

```powershell
cd backend
npm ci
Copy-Item .env.example .env
npm test
npm start
```

The development service binds to `127.0.0.1:8787`. Its SQLite database is ignored by Git. HTTP is for loopback development only; the native app requires an HTTPS API base URL.

For the labelled recipient-profile demo, from the root:

```powershell
node scripts/preview-demo.mjs
$env:DATABASE_PATH = "$PWD/backend/data/preview.sqlite"
node backend/src/server.js
```

Open `http://localhost:8787/p/00000000-0000-4000-8000-000000000002`. This seed has no real account credentials and must never be used in production. The preview is a real public-profile page, not a native iOS simulator.

## Build the iOS app on a Mac

1. Install Xcode and XcodeGen from their official distributions.
2. Run `xcodegen generate` from the root, then open `TapLead.xcodeproj`.
3. Select your Apple development team. Replace sample app/group identifiers consistently in `project.yml`, `AppStore.swift` and the widget provider. Register Sign in with Apple, NFC and the App Group.
4. Set `TapLeadAPIURL`, `TapLeadPrivacyURL` and `TapLeadTermsURL` in `project.yml` to real HTTPS URLs and regenerate. The empty API setting deliberately prevents accidental publication to an invented domain.
5. Run the TapLead scheme on an iPhone simulator. Use `--demo` as a launch argument for sample connections. NFC and speech availability require device testing.
6. Run `TapLeadUITests`; capture screenshot attachments at real target simulator resolutions before creating App Store compositions.

```sh
swift test
xcodebuild -project TapLead.xcodeproj -scheme TapLead \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

Choose a simulator that actually exists in `xcrun simctl list devices available`; the example device name is not a guarantee of an installed runtime.

## Checks performed here

Five Swift domain tests pass, including UTF-8 vCard folding, privacy and persistence. Twelve backend tests pass, including consent, owner isolation, idempotent writes, request limiting, measured events, cascading account deletion and subscription expiry/account/replay logic. `npm audit --omit=dev` reports zero known dependency vulnerabilities at build time. All native Swift files pass parser checks; this does **not** establish iOS compilation or UI correctness.

```powershell
swift test --scratch-path C:\Users\User\.codex\taplead-build
python scripts/localize.py
cd backend
npm test
```

The scratch-path example avoids a Windows Swift build issue encountered with a workspace path containing spaces. On another machine use an appropriate writable path.

## Operational documents

- [Release status and verification](docs/RELEASE.md)
- [Architecture and deployment](docs/ARCHITECTURE.md)
- [AI contract](docs/AI.md)
- [Wallet signing setup](docs/WALLET.md)
- [Localisation workflow](docs/LOCALISATION.md)
- [App Store copy and screenshot plan](marketing/APP_STORE.md)

No credentials are included. Do not commit `.env`, Apple signing keys, database contents or exported contact data.
