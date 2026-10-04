# TapLead keyword and positioning research

Research date: 4 October 2026. Primary sources: Apple's current metadata guidance and three US App Store publisher listings. This is qualitative search-intent and competitor-language research; no search-volume, keyword-difficulty or ranking estimate is claimed. Research does not authorize copying competitor content or assets.

| Listing | Observed positioning | Implication for TapLead |
| --- | --- | --- |
| [Blinq](https://apps.apple.com/us/app/blinq-digital-business-card/id1324102258) | Digital business card identity, QR/link/NFC sharing, notes and follow-up | Digital card/sharing terms describe the category; post-meeting follow-up must be demonstrated to distinguish TapLead. |
| [HiHello](https://apps.apple.com/us/app/hihello-digital-business-card/id1378114205) | Digital business cards, contact management and event capture | Contact, networking and conference intent fit TapLead. Paper-card scanner terms do not: TapLead has no such scanner. |
| [Popl](https://apps.apple.com/us/app/popl-ai-lead-capture/id1503939262) | Event lead capture, badge scanning and business cards | Lead capture is relevant after production deployment. Badge scanner, universal scanning and enterprise CRM integrations would misrepresent TapLead. |

Inference: start with the recognisable digital business card category, then explain remembering a conversation and choosing the next action. Treat QR/NFC as sharing methods, not the entire value proposition. Do not imply that sharing alone automatically reveals a visitor's identity.

The [Apple product-page guidance](https://developer.apple.com/app-store/product-page/) permits a subtitle of up to 30 characters, promotional text of up to 170 characters and keywords up to 100 characters. The [App Store Connect field reference](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) specifies a 100-byte keyword field; use ASCII and satisfy both limits. Apple says to avoid irrelevant terms, competing app names, duplicate words and keyword stuffing. Promotional text is not a keyword-ranking field.

Candidate final metadata, pending feature acceptance:

- Name: **TapLead** (7 characters), matching the master prompt and current saved title.
- Subtitle: **Digital Business Card & NFC** (27 ASCII characters), the prompt's preferred candidate. Use only after real NFC publication/write/read-back tests pass. Existing **Business Cards & Connections** is 28 characters and remains the conservative saved draft.
- If keeping the existing subtitle, candidate keywords: `digital,QR,NFC,networking,contact,lead,capture,CRM,followup,reminder,conference,vCard` (85 ASCII bytes). Each term maps to the intended accepted product; remove NFC, lead capture or CRM if its production acceptance fails.
- If choosing the digital-card/NFC subtitle, avoid repeating its terms in keywords: `QR,networking,contact,lead,capture,CRM,followup,reminder,conference,vCard` (73 ASCII bytes).
- Description opening: **The digital business card built for what happens after you meet.** Follow with the actual live sharing, consented capture, reviewed notes and follow-up behaviour. Describe optional AI only after its provider and review flow pass acceptance.

Do not use Wallet, badge scanning, automated sending, Salesforce/HubSpot integration, team administration or competitor names as discoverability claims for this release. Do not publish aspirational metadata against build 1012. Reconcile the final choice with the exact production build, then observe genuine App Store impressions/conversion after launch before drawing performance conclusions.
