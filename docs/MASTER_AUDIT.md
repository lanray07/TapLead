# Master prompt acceptance audit

Audited 4 October 2026 against all 40 sections of the supplied master prompt, source, existing test evidence and saved App Store configuration. **Not ready for submission.** Build 1012 is an uploaded baseline, not acceptance evidence for unfinished production features.

The complete section-by-section checklist is [MASTER_REQUIREMENTS.json](MASTER_REQUIREMENTS.json). Each section includes its current status and remaining work. `verified` requires acceptance evidence, not merely a screen or source file. `partial` includes features whose source exists but whose live/device behaviour has not been validated. `blocked` identifies unavailable production dependencies. Wallet is conditional because the prompt explicitly permits documented architecture while signing configuration is unavailable. Its button and claims remain absent. Teams architecture is required; a full enterprise product is not required for initial release.

Run `python scripts/check-release-readiness.py`. The [GitHub submission-readiness workflow](../.github/workflows/release-readiness.yml) runs the same check and fails while any requirement remains partial/blocked. Archive/TestFlight workflows may still produce development candidates. This check does not itself submit to Apple or prevent a person from using App Store Connect; submission must be held until it passes with reviewed evidence for the exact build.

First resolve deployment/authentication, secure public media and real subscriptions; implement the missing customisation, QR exports, mode presets, immediate actions and analytics; configure/evaluate optional AI; review translations; run the complete device/accessibility/offline/receipt acceptance walkthrough; replace theme-heavy screenshots with the required feature story and finish keyword research. Reconcile privacy/policies with actual deployed processing before publishing App Privacy. A new build must include and test these changes.

Free hosting was requested. Creating a separate project still awaits the required connected-organisation selection; the existing Supabase project belongs to another application's data. AI, translation and Apple authentication configuration are separate dependencies and must not be claimed to work simply because hosting is free.

See [release evidence and device walkthrough](RELEASE.md), [Wallet exception](WALLET.md), [AI contract](AI.md), and [localisation workflow](LOCALISATION.md). Checklist status changes must record concrete test or review evidence. Do not mark a requirement verified to silence the workflow.
