# Architecture and deployment

## Data flow

`SwiftUI → AppStore → protected local JSON + durable lead outbox → authenticated API → SQLite`

`QR / source link → /p/:id → public-field projection → consented form → owner's lead inbox`

Cards use stable UUID URLs. Updating a published card changes its web contents without changing the QR. Build 1015 removes native NFC functionality at the user's request on 10 October 2026. Historical server records and links may still carry `source=nfc`; this is legacy link attribution, not NFC reader/writer functionality or proof of a physical tap. Public views record only kind, source and time when the owner opts in. They do not store IPs, fingerprints, precise locations, email addresses or visitor identifiers. Request limiter buckets temporarily use IPs in memory for abuse protection and are not analytics records.

## Security boundaries

The server derives ownership from a hashed opaque bearer session, never from a client-provided owner ID. Card and lead updates are idempotent; another user cannot replace an existing ID. Zod validates input and strips unknown fields. Public HTML is escaped, outbound web links require HTTPS and private contact fields are removed before rendering or exporting. vCards escape newline/property injection and fold by UTF-8 octet length. CSP blocks scripts, embedding and off-origin form submissions. No arbitrary HTML or SVG uploads are accepted. Card image uploads accept bounded PNG/JPEG bytes only, check ownership, decode with pixel/channel limits and re-encode stripped PNG thumbnails using pinned sharp 0.35.5. One image blob per card is stored in card_media with cascade deletion. Public image delivery requires a published card and matching selected image kind. Deployment must also bound process memory/CPU, upload concurrency, storage capacity and backup retention.

Passwords use salted scrypt. Sessions expire after 30 days and are stored in the iOS Keychain. Add email verification, password recovery and a user-controlled session management screen before commercial launch. Current sign-up does not establish ownership of the email address. Native notes use protected local files and retry on network restoration. The current outbox stores lead writes/deletes; profile publication is an explicit online action. Card refresh now merges clean remote cards while preserving local images and unpublished edits; profile publication stays an explicit online action. Concurrent edits on different devices still use last accepted publication, so versioned conflict resolution and background task processing require additional implementation; avoid promising automatic background sync.

Apple sign-in is unavailable unless both authentication and token-revocation credentials are configured. The backend checks Apple issuer, audience, algorithm and a one-use nonce; exchanges the authorization code; verifies it refers to the same subject; and encrypts the refresh token with AES-256-GCM. Account deletion first revokes the Apple token and then cascades owner data. An Apple outage preserves data and reports a retryable error. Add credential-revocation notifications and a documented backup erasure policy before release.

## Deploy

1. Deploy Node 24 behind a supported HTTPS reverse proxy with a dedicated persistent volume and restrictive OS permissions. A production environment needs `PUBLIC_URL`, `PRIVACY_URL` and `TERMS_URL`. Back up SQLite using its online backup facilities, not by copying a live WAL database blindly.
2. Keep the service interface private and enforce body/time limits at the proxy. Keep ports bound to loopback unless your container networking requires a private interface. Do not expose plain HTTP publicly.
3. Configure trusted proxy hops explicitly if using client IP request limits. Do not trust arbitrary `X-Forwarded-For` headers. The current app leaves Express trust proxy disabled; without explicit configuration all proxied clients may share a bucket.
4. Replace in-memory rate limits with shared infrastructure for multiple instances, and add a bot challenge to the public form. The honeypot and request limits are a first layer, not a complete abuse service. Monitor aggregate failures without logging personal fields or bearer tokens.
5. Store Apple credentials and the encryption key in a secret manager. Set `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_PATH`, and a 32-byte hex `TOKEN_ENCRYPTION_KEY`. Plan encryption-key rotation and re-encryption.
6. Use deployment health checks against `/health`. Add migration versions, disaster-recovery exercises, retention policy, telemetry, capacity testing and alerting before opening sign-up broadly.

SQLite and synchronous password hashing suit a single-instance pilot. Move password hashing off the event loop and use Postgres plus distributed request limits for larger workloads. No infrastructure has been deployed in this task.

## Plan enforcement

Server limits enforce one card and 50 leads for Free, or 20 cards and 10,000 leads for verified Pro accounts. No client flag can grant cloud Pro access. The StoreKit adapter binds purchases with `appAccountToken`, uploads their JWS representation and finishes verified purchases after server acknowledgement. Apple's official App Store Server Library verifies signatures and certificate chains. The notification endpoint processes signed renewal/revocation transaction updates; account binding, expiry, product allow-list and signed-date ordering prevent cross-account grants and old-transaction replay.

Set `APPLE_ROOT_CERT_PATHS` to semicolon-separated Apple Root CA DER certificate paths from Apple's PKI site, `APPLE_BUNDLE_ID` to the registered bundle ID and `APPLE_APP_ID` to the numeric App Store app ID in production. Development verification uses Sandbox; production rejects Sandbox transactions. Configure the App Store Server Notifications V2 URL as `/api/apple/notifications`. Add notification delivery monitoring/reconciliation, billing retry/grace-period policy and real signed-transaction sandbox tests before release. `SUBSCRIPTIONS_ENABLED=false` keeps purchase actions unavailable by default. Enable only after those tests, policy URLs and advertised features are verified. Product prices come from StoreKit, not hard-coded labels.

Teams should use `organization`, `membership(user_id, organization_id, role)`, `brand_template`, and organization-scoped cards/events. Define owner/admin/member roles and authorize every tenant query. The current service intentionally has no shared-team routes or data. Team features are a future schema and authorization layer, not an existing capability.
