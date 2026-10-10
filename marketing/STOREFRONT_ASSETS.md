# TapLead storefront localization — 10 October 2026

Copy: `store-localizations.json` contains all 50 Apple storefront locales. The API's saved identifiers for newer languages include bn-BD, gu-IN, kn-IN, ml-IN, mr-IN, or-IN, pa-IN, sl-SI, ta-IN, te-IN and ur-PK. The renderer's folder names use the shorter translation keys.

Metadata was saved and read back successfully for all 50 locales in [GitHub workflow 38037913647](https://github.com/lanray07/TapLead/actions/runs/38037913647). `store-metadata-verification.json` records the saved localization IDs. The US name is **TapLead: Business Cards** because Apple reported that **TapLead** was already in use in that locale. Other storefront names remain TapLead. All descriptions include the standard Apple EULA and the GitHub privacy URL.

`scripts/localized-store-assets.cjs` composes translated captions around unchanged real native XCTest captures. Restore the `TapLead-Xcode-results` artifact from [38035209175](https://github.com/lanray07/TapLead/actions/runs/38035209175) into `artifacts/nfc-removal-xcode-38035209175`, including its screenshots manifest, then run the renderer with Node and Sharp on Windows. It uses installed Windows fonts for Pango shaping. It accepts an optional comma-separated list of translation keys.

Each locale has:

- Four Duo inner-size screenshots, 2007 × 2853.
- Four Duo outer-size design samples, 1398 × 2034.
- Four current iPhone screenshots, 1206 × 2622.
- One universal header/search PNG, 5244 × 2950.

The full export has 650 files. All dimensions, absence of alpha channels and SHA-256 hashes were verified. Provenance and hashes are in `localized-assets/manifest.json`; generated image files are ignored by Git to avoid repeatedly storing 172 MB of reproducible rasters. The local complete ZIP is `artifacts/TapLead-storefront-all-50-locales.zip`.

Native UI captures use the app's ten supported languages where available and real English fallback elsewhere. The four outer-size design samples use real English demo content. This does not claim a new Duo-adapted native layout or functioning paid purchases. Translations are agent-authored; independent native-speaker review is pending.

Uploading assets and saving metadata is separate from submitting App Review. No review submission is part of this marketing task; the outstanding Pro purchase acceptance work remains unresolved.

Apple references: [locale list](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations), [screenshot sizes](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [creative asset sizes](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications), [asset management](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets).
