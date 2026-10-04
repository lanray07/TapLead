# TapLead privacy policy

Last updated: 4 October 2026.

TapLead helps you create a digital business card, organise professional connections and keep meeting notes. This policy describes the current implementation maintained in the [TapLead repository](https://github.com/lanray07/TapLead). Live account services and purchases remain unavailable until their production configuration and verification are complete. Optional on-device AI requires iOS 26, an available Apple Intelligence model, Pro access and your explicit action consent; physical-device evaluation remains pending for release.

## Information and its use

- **Local cards and connections:** The app stores the profile details, connection details, tags, notes, statuses and follow-up dates you enter on your iPhone. Demo connections are labelled sample data and are not uploaded to an account.

- **Account and synchronisation, when configured:** Signing in uses your email and account identifier, or the identifier supplied by Sign in with Apple. The account service stores password hashes rather than plaintext passwords, sessions, your card details and synced connections/notes. This data provides authentication, publication, synchronisation and account management.

- **Contact details:** Cards and connections can contain names, email addresses, phone numbers, addresses, company/role information, websites and social links. Only the card fields you select for publication are included in public profiles and contact downloads. Published information can be accessed and copied by recipients of your link.

- **Subscriptions, when enabled:** Apple handles payment details. TapLead uses verified transaction identifiers, product identifiers, expiry/revocation status and your account identifier to provide subscription access. TapLead does not receive your payment card number.

- **Profile activity:** If a card owner enables activity collection, the service records the card identifier, event type, link source and timestamp for profile views, contact downloads, link clicks and submissions. These records belong to the card owner's account. The current event database does not store a visitor identity or device advertising identifier. Counts do not identify unique visitors or prove that a contact was saved.

TapLead's current implementation has no advertising SDK or third-party advertising tracking and does not sell user data.

## Photos, microphone, speech and NFC

Photos/logos are stored locally while you edit. When you publish through a configured account service, TapLead uploads only the selected photo or logo; unselected images remain on the iPhone. The service validates and re-encodes PNG/JPEG images, strips embedded metadata and stores the result with your card. The selected image is public while the card is published. Choosing None or making the card private stops public image delivery; account/card deletion removes the associated stored image. Cloud image publication has been deployed and tested; production account configuration and backup retention remain pending for the next release. Microphone and speech permissions are requested for notes you choose to record. Recognition requires supported on-device speech processing; raw audio is not retained or uploaded by TapLead. You can review and edit the resulting text before saving; saved text notes can be synchronised with an account service when configured. NFC reads/writes are used for the public profile link, after you choose the action.

## Optional AI

Optional Smart Notes and follow-up drafts use Apple’s Foundation Models on the iPhone when its model is available for the device and language. TapLead does not send the chosen notes or contact name to an external AI processor in this path. You must opt in and choose an action; results are reviewed before saving or sharing. An optional external gateway remains disabled and is not called by the native AI screen. Any future external processor requires an updated consent flow and policy before activation.

## Sharing and external services

The account API and database are hosted by Supabase, with TapLead's database in the London region. GitHub Pages hosts the public-profile page and account-link page; the published profile fields are retrieved from the Supabase API when a recipient opens a shared link. These providers process network requests to deliver their services. TapLead's API also stores one-way source-IP hashes in rate-limit buckets for abuse prevention; buckets expire within an hour and are pruned during subsequent requests. Production email delivery is awaiting configuration; its provider and retention must be included here before public account signup launches.

Information you publish or deliberately share goes to the recipients you choose. A connection form submits the entered information to the relevant card owner's account after consent. Private notes are not part of the public card or vCard. Apple provides App Store billing and optional Apple authentication. External website, social and booking links open services with their own privacy policies. GitHub hosts these policy/support pages and any public support issues; GitHub's own privacy practices apply to visits and issue submissions.

No production hosting provider or AI processor is configured in this repository's current release configuration. Provider details and any infrastructure logging/backup practices must be disclosed before live account services open to users.

## Retention and deletion

Local card and connection data remains in the app's storage until edited, deleted or the app's data is removed. **Settings → Export my data** creates a file you can choose to share; protect exported files because they can include contact details and private notes. Copies you export or share are outside the app's control.

The implemented account database keeps account data while the account exists; it has no automatic expiry for cards, connections, notes or profile events. **Settings → Delete account**, available when signed in, removes the account and associated cards, leads, activity, sessions and entitlement records from that database after successful processing. The app clears its local account snapshot. Apple sign-in accounts require successful grant revocation; a failed deletion is reported rather than presented as complete. Deleting an account does not cancel an Apple subscription; cancel separately in your Apple subscription settings.

Public links stop serving a card after successful unpublication/deletion, but previously downloaded or shared copies cannot be recalled. Production backup retention and any legally required retention have not been configured; these must be specified before the live service launches. iPhone backups and files stored outside TapLead are managed through your device or storage provider.

## Your choices

You can edit your card's public fields, unpublish a card, turn off its activity collection, edit/delete connections, export your local data and delete an authenticated account. You can revoke microphone/speech permissions in iPhone Settings. These controls affect future actions; deleting previously collected account information requires the applicable deletion controls. Optional AI consent is scoped to the selected action.

## Questions and changes

For general privacy questions, [open a TapLead issue](https://github.com/lanray07/TapLead/issues/new) or consult the [support guide](https://github.com/lanray07/TapLead/blob/main/docs/SUPPORT.md). GitHub issues are public: do not include passwords, private contacts, recordings, identity documents or other sensitive information. Use the authenticated app's controls for account export/deletion. If you need a private support route, request one without posting the private information.

Changes to data practices will be reflected on this page. The date above identifies the current notice.

