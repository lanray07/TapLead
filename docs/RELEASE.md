# Release status

The [40-section master acceptance audit](MASTER_AUDIT.md) is the submission gate. Its current result is blocked; build upload alone does not satisfy the master prompt.

## Verified in GitHub Xcode

[Run 37204032293](https://github.com/lanray07/TapLead/actions/runs/37204032293) passed app/widget compilation and all 25 tests: seven shared Swift, twelve backend and six native UI tests. Seven additional genuine card-style screenshot compositions were exported and uploaded, bringing both iPhone size sets to ten. The saved order was verified after reloading App Store Connect. See the [premium sample gallery](../marketing/PREMIUM_SAMPLES.md).

[Run 37202219579](https://github.com/lanray07/TapLead/actions/runs/37202219579) passed app/widget compilation, seven shared Swift tests, twelve backend tests and five native UI tests. The card editor supports Photo, Logo or None, imports from Photos or Files, and all four corner positions. Native UI coverage verifies logo import, bottom-right placement, persistence after restart and removal; shared tests cover legacy card decoding and saved image preferences. [Native card capture](../marketing/assets/card-corner-logo-native.png) shows the imported logo. Images remain local to the iPhone; public media hosting is still unconfigured.

[Run 37197524412](https://github.com/lanray07/TapLead/actions/runs/37197524412) also passed app/widget compilation, four simulator UI tests, five shared Swift tests and twelve backend tests. It includes an authentic Pro capture with purchases disabled pending configuration. Metadata, screenshots, subscription artwork/products/pricing, free download price and unpublished privacy drafts are prepared; see [saved store draft](../marketing/APP_STORE.md).

[GitHub run 37195819458](https://github.com/lanray07/TapLead/actions/runs/37195819458) successfully compiled the iOS app and widget with Apple SDKs, passed all three native simulator UI tests, and exported four native screen captures plus the XCTest result bundle. Five shared Swift tests and twelve backend tests also passed. Signing and real-device behavior require separate validation.

The distribution signing gap is resolved. `group.com.TapLead.app.shared` was registered and assigned to both `com.TapLead.app` and `com.TapLead.app.widget` in the Apple Developer portal. [Run 37205854958](https://github.com/lanray07/TapLead/actions/runs/37205854958) successfully exported, verified and uploaded build 1012 (version 1.0.0) to App Store Connect. Apple processed it and the build was selected and saved on version 1.0.0. Verification covers app/widget signatures, identifiers, matching build numbers, App Group, current NFC `TAG` entitlement and Apple sign-in. The workflow uses Xcode 26.6 and checks for an iOS SDK version of at least 26. The previous upload attempt identified the obsolete NFC `NDEF` entitlement, which was corrected. An earlier experimental export omitted capabilities and is not a release deliverable.

Submission remains incomplete. The selected build has no production API URL and purchases are disabled. Free Supabase hosting was requested; the connected organisation's new-project price was confirmed as zero per month. Organisation selection is pending before creating a separate TapLead project; the existing project contains another application's data. Privacy publication must reflect the deployed service and its actual processors/retention. Apple free/paid agreements, banking, tax forms and listed compliance statuses are active.

## Verified on this Windows machine

- Shared Swift domain module compiles; five XCTest cases pass.
- Backend service runs; twelve tests pass and production dependency audit reports no known vulnerabilities. Subscription tests cover disabled-purchase denial, account binding, expiry and revocation replay; they do not substitute for real Apple-signed receipt tests.
- All app and widget source files pass Swift syntax parsing. This is not Apple SDK type checking.
- The actual recipient web profile was viewed in the in-app browser. A consented demo form submission returned a success page and was persisted in the preview database.
- Source strings are extracted. Review status remains open for all nine non-English locales.

## Implemented, needs Mac/device validation

SwiftUI onboarding and five tabs, card editor and local images, reordered links/sections, eight theme choices, public/private detail controls, stable source URLs and QR image sharing, event screen, lead creation/inbox/search/statuses/tags/timeline, offline note persistence and lead outbox, text/voice note review, command/date review, AI review interface, follow-up notifications, NFC write/read-back, widgets, App Intents, Keychain storage and data export.

The NFC and speech implementations use documented Apple APIs with capability checks. Neither has been exercised on an iPhone here. Voice transcription requires supported on-device recognition; unsupported locales/devices get a text fallback. Commands preselect a connection/date and require explicit action confirmation. Ambiguous names and date interpretation need usability tests.

## Release blockers and remaining implementation

| Area | Required work |
| --- | --- |
| iOS build | App/widget compilation, 25 automated tests and distribution signature/capability verification passed in GitHub. Build 1012 is processed and attached to 1.0.0. Add the production service configuration and complete real-device tests. |
| Apple credentials | Distribution app/widget identifiers and App Group/NFC/sign-in entitlements are configured. Configure backend Apple code exchange and token revocation; verify credential-revocation handling. |
| Hosting | Deploy HTTPS service, set real profile domain/policy URLs, configure persistence, backups, migrations, monitoring and distributed abuse protection. |
| Authentication | Email ownership verification, password recovery, session management and account-linking UX. Apple sign-in configuration is required before enabling it. |
| Subscriptions | Signed transaction verification/account binding/renewal-revocation routes and Free/Pro server limits are implemented. Configure Apple roots/products/notifications, test real Sandbox receipts and add delivery reconciliation/grace-period policy. Purchase actions are disabled by default. |
| Card themes | Verify native contrast, custom-accent use and all eight theme layouts. Full typography/background/CTA customization is incomplete. |
| Public media | Secure upload pipeline, image type/size validation, metadata removal and storage policy. Current profile photo/logo remain local and are not uploaded. |
| Personas/modes | Demo and verified-Pro persona creation/publication paths exist. Test cloud Pro limits and add explicit Sales/Recruiting/Event presets and company branding locks. |
| Wallet | Build and deploy certificate-backed signing/update service, wire the client action, device test. No Wallet claim is published. |
| AI | Configure approved provider gateway, publish processing terms, evaluate extraction/drafts and add quota/billing rules. |
| Widgets/Spotlight | Large-widget aggregate recent-connection/due-follow-up counts are now implemented in source, with calendar-day boundary coverage. New Xcode compilation and widget privacy/size tests, plus Spotlight public-card index verification, remain. Build 1012 does not include this change. |
| Advanced QR | Printable exports, QR-on-image compositions and configurable branded QR assets are incomplete. Native QR image/link sharing exists. |
| Teams | Future organization/member/role architecture documented; no Teams admin/product implementation. |
| Localisation | Human-reviewed translations, plural/interpolation extraction, translated public pages and locale/accessibility UI tests. |
| App Store | Screenshots and two Pro promotional images uploaded; metadata/pricing saved. GitHub privacy/terms URLs configured. Complete production reconciliation of policies/privacy drafts, enabled-paywall screenshots and TestFlight testing. |

## Minimum acceptance walkthrough

1. Create a local card. Confirm edits survive relaunch and private fields do not appear in the generated vCard.
2. Sign in, publish, scan from a second phone without TapLead installed, download a vCard and submit a consented lead. Pull to sync the native inbox.
3. Disable internet, add/edit/delete native leads, relaunch, reconnect and check idempotent sync. Confirm demo data cannot upload into a real account.
4. Record, edit and save a voice note. Deny permissions, try unsupported language/hardware, interrupt recording and cancel. Confirm raw audio is not retained.
5. Review a voice command with an ambiguous name/date and confirm the chosen action. A command alone must not create a reminder or send a message.
6. Schedule, reschedule, complete and delete follow-ups; check notification permission denial and no lead identity on a locked phone.
7. Write/read/test a supported NFC tag; test locked/small/multiple tags and a device without NFC writing.
8. Check VoiceOver, Dynamic Type, dark mode, adequate contrast/tap targets, reduced motion, long content and keyboard dismissal.
9. Export and delete an account. Confirm public URL disappears, sessions expire, Apple grants revoke, synced data cascades and backup retention is disclosed.

Sources consulted: [Core NFC](https://developer.apple.com/documentation/corenfc), [Speech authorization](https://developer.apple.com/documentation/speech/sfspeechrecognizer/requestauthorization(_:)), [Apple token revocation](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [App Store Server Library](https://github.com/apple/app-store-server-library-node).
