# App Store assets and saved draft metadata

The screenshot layouts in `assets/01-card-*`, `02-connections-*` and `03-today-*` embed genuine pixels from the successful native simulator run [37195819458](https://github.com/lanray07/TapLead/actions/runs/37195819458). The SVG sources remain editable. PNG exports use 1242 × 2688 and 1320 × 2868 dimensions. Both sets have been uploaded to App Store Connect in card, connections, Today order.

`04-insights-*` is an internal draft only and was not uploaded: the captured native screen correctly reports that the production insights service is unavailable. No invented activity or completed feature is shown.

## Subscription promotional images

`assets/pro-monthly-promotion.png` and `assets/pro-annual-promotion.png` are opaque 1024 × 1024 exports made with the built-in image generation tool. They were uploaded to the respective subscription Image fields. They are abstract artwork, not app screenshots.

Prompt set:

- Monthly: premium dark charcoal-purple and violet TapLead Pro artwork, two floating overlapping abstract contact cards with luminous edges and a connective arc; exact headline “TapLead Pro”; no prices, feature claims, fabricated UI, Apple logos or people.
- Annual: matching premium charcoal-purple and violet artwork, three translucent contact cards forming an upward fan over a luminous orbit; exact text “TapLead Pro” and “Annual”; no prices, feature claims, fabricated UI, Apple logos or people.

Original generated files remain in Codex generated-image storage; the project exports are saved here.

## App Store Connect draft

- App: TapLead, 6818982306, English (U.K.). Subtitle: Business Cards & Connections.
- Categories: Business / Productivity. Calculated age rating: 4+ with regional equivalents. User-generated content declared; no feed/chat, advertising, gambling or mature content.
- Subscription group: TapLead Pro, 22439298, localized English (U.K.). Both products are level 1.
- Monthly: `com.taplead.pro.monthly`, Apple ID 6818996322, one month, draft UK base price £4.99 with Apple regional equivalents.
- Annual: `com.taplead.pro.yearly`, Apple ID 6818996808, one year upfront, saved draft UK base price £39.99 with Apple regional equivalents.
- Both descriptions: “Up to 20 cards and 10,000 synced leads.” No introductory trial. Review notes disclose the current purchase configuration blocker.
- Both products have saved availability in 175 current territories, future territory auto-add disabled and individual App Store purchase options; multiseat and family sharing are off.
- Free app pricing and availability in 175 territories are saved. The support URL points to the repository support guide. Ten privacy categories and purposes are saved as unpublished drafts.
- `assets/pro-review-current-configuration.png` is the untouched native Pro screen from successful [run 37197524412](https://github.com/lanray07/TapLead/actions/runs/37197524412). It visibly shows purchases unavailable and is only a draft review asset; replace it after production configuration and Sandbox verification.
- Privacy and terms pages use public GitHub URLs under `docs/PRIVACY.md` and `docs/TERMS.md`; these URLs are wired into app configuration and GitHub archive variables.
- No final review submission has been made. Content-rights declaration, production policy reconciliation, release-service configuration, signing repair, enabled-paywall review screenshots and Apple Sandbox verification still require completion.
