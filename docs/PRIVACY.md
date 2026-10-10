# TapLead privacy policy

Last updated: 4 October 2026.

TapLead helps you create a digital business card, organise professional connections and keep meeting notes. This policy describes the implementation maintained in the [TapLead repository](https://github.com/lanray07/TapLead). The cloud service is deployed on Supabase. Account entry uses native Sign in with Apple; local guest mode keeps your working data on your iPhone. Subscription purchases remain disabled during release verification. Optional on-device AI requires iOS 26, an available Apple Intelligence model, Pro access and your explicit action consent.

## Information and its use

- **Local cards and connections:** The app stores the profile details, connection details, tags, notes, statuses and follow-up dates you enter on your iPhone. Demo connections are labelled sample data and are not uploaded to an account.

- **Account and synchronisation:** Account entry uses Sign in with Apple or local guest mode. Email/password login is disabled. For Apple accounts, the account service stores the Apple account identifier, encrypted revocation credentials, sessions, your card details and synced connections/notes. This data provides authentication, publication, synchronisation and account management. Local guest and demo data is not uploaded to an account.

- **Contact details:** Cards and connections can contain names, email addresses, phone numbers, addresses, company/role information, websites and social links. Only the card fields you select for publication are included in public profiles and contact downloads. Published information can be accessed and copied by recipients of your link.

- **Subscriptions, when enabled:** Apple handles payment details. TapLead uses verified transaction identifiers, product identifiers, expiry/revocation status and your account identifier to provide subscription access. TapLead does not receive your payment card number.

- **Profile activity:** If a card owner enables activity collection, the service records the card identifier, event type, link source and timestamp for profile views, contact downloads, link clicks and submissions. These records belong to the card owner's account. The current event database does not store a visitor identity or device advertising identifier. Counts do not identify unique visitors or prove that a contact was saved.

TapLead's current implementation has no advertising SDK or third-party advertising tracking and does not sell user data.

## Photos, microphone and speech

Photos/logos are stored locally while you edit. When you publish through your account, TapLead uploads only the selected photo or logo; unselected images remain on the iPhone. The service validates and re-encodes PNG/JPEG images, strips embedded metadata and stores the result with your card. The selected image is public while the card is published. Choosing None or making the card private stops public image delivery; account/card deletion removes the associated stored image. Microphone and speech permissions are requested for notes you choose to record. Recognition requires supported on-device speech processing; raw audio is not retained or uploaded by TapLead. You can review and edit the resulting text before saving; saved text notes can be synchronised with your account. The replacement release removes NFC functionality; profiles are shared using QR codes and links.

## Optional AI

Optional Smart Notes and follow-up drafts use Apple’s Foundation Models on the iPhone when its model is available for the device and language. TapLead does not send the chosen notes or contact name to an external AI processor in this path. You must opt in and choose an action; results are reviewed before saving or sharing. An optional external gateway remains disabled and is not called by the native AI screen. Any future external processor requires an updated consent flow and policy before activation.

## Sharing and external services

The account API and database are hosted by Supabase, with TapLead's database in the London region. GitHub Pages hosts the public-profile page and account-information page; the published profile fields are retrieved from the Supabase API when a recipient opens a shared link. These providers process network requests to deliver their services. TapLead's API also stores one-way source-IP hashes in rate-limit buckets for abuse prevention; buckets expire within an hour and are pruned during subsequent requests. TapLead does not operate an email/password account or password-recovery email service.

Information you publish or deliberately share goes to the recipients you choose. A connection form submits the entered information to the relevant card owner's account after consent. Private notes are not part of the public card or vCard. Apple provides App Store billing and optional Apple authentication. External website, social and booking links open services with their own privacy policies. GitHub hosts these policy/support pages and any public support issues; GitHub's own privacy practices apply to visits and issue submissions.

Provider infrastructure logs and operational copies follow the providers' own policies: [Supabase privacy policy](https://supabase.com/privacy) and [GitHub privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). TapLead does not send notes to an external AI processor.

## Retention and deletion

Local card and connection data remains in the app's storage until edited, deleted or the app's data is removed. **Settings → Export my data** creates a file you can choose to share; protect exported files because they can include contact details and private notes. Copies you export or share are outside the app's control.

The implemented account database keeps account data while the account exists; it has no automatic expiry for cards, connections, notes or profile events. **Settings → Delete account**, available when signed in, removes the account and associated cards, leads, activity, sessions and entitlement records from that database after successful processing. The app clears its local account snapshot. Apple sign-in accounts require successful grant revocation; a failed deletion is reported rather than presented as complete. Deleting an account does not cancel an Apple subscription; cancel separately in your Apple subscription settings.

Public links stop serving a card after successful unpublication/deletion, but previously downloaded or shared copies cannot be recalled. Deletion removes data from TapLead's active database; provider infrastructure logs and operational copies may remain under the provider policies above. TapLead has no separately configured backup archive or fixed backup-erasure guarantee. iPhone backups and files stored outside TapLead are managed through your device or storage provider.

## Your choices

You can edit your card's public fields, unpublish a card, turn off its activity collection, edit/delete connections, export your local data and delete an authenticated account. You can revoke microphone/speech permissions in iPhone Settings. These controls affect future actions; deleting previously collected account information requires the applicable deletion controls. Optional AI consent is scoped to the selected action.

## Questions and changes

For general privacy questions, [open a TapLead issue](https://github.com/lanray07/TapLead/issues/new) or consult the [support guide](https://github.com/lanray07/TapLead/blob/main/docs/SUPPORT.md). GitHub issues are public: do not include passwords, private contacts, recordings, identity documents or other sensitive information. Use the authenticated app's controls for account export/deletion. If you need a private support route, request one without posting the private information.

Changes to data practices will be reflected on this page. The date above identifies the current notice.

