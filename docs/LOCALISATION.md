# Localisation

`Localizable.xcstrings` contains English source strings and explicit review queues for Spanish, French, German, Italian, Portuguese, Dutch, Japanese, Korean and Simplified Chinese. Non-English values currently fall back to English and are marked `new`; they are **not** finished translations. Do not declare these languages as fully supported in the App Store until reviewed.

Run `python scripts/localize.py` after UI changes. The extractor gathers common SwiftUI literals plus domain enums; Xcode string extraction is the authoritative final check, especially for interpolated/plural strings and labels in custom components. Domain/user content uses verbatim text. Locale-aware native formatters display dates and counts. System navigation and leading/trailing alignments support future RTL work.

To request machine drafts through an approved developer translation gateway:

```powershell
$env:TRANSLATION_GATEWAY_URL = 'https://your-approved-service/translate'
# Load TRANSLATION_GATEWAY_TOKEN from a secret manager.
python scripts/localize.py --draft es
```

The gateway receives `{source, target, strings}` and returns `{translations: {sourceString: translatedString}}`. Only source UI text is submitted. Drafts are stored as `needs_review`; a native-speaking reviewer marks approved entries `translated` in Xcode. No user card, lead or note content is translated. Run `python scripts/localize.py --check` in release CI; it fails while review queues remain.

The widget needs its own resource membership because it is a separate bundle. `scripts/prepare-assets.py` copies the catalogue into the widget resource folder; rerun it after extraction. Before release, improve this to a build resource-generation phase to avoid stale copies.

Test every advertised locale with accessibility text sizes, long names, multiline biographies, 320–440 point widths, VoiceOver and reduced motion. Capture actual simulator screenshots and inspect truncation. Public web pages currently use English; add a validated language negotiation/catalogue layer before advertising full international web support.
