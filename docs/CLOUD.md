# TapLead cloud deployment

The user approved creating TapLead in **lanray07's Org** on the **£0/month** plan. Project `qyflrgvolsiljpsghqku` is a new, separate Postgres project in London (`eu-west-2`), created 4 October 2026. The pre-existing unrelated project was not modified.

- API: `https://qyflrgvolsiljpsghqku.supabase.co/functions/v1/taplead`
- Public profiles: `https://lanray07.github.io/TapLead/card/?id=<card UUID>&source=qr`
- Account email redirects: `https://lanray07.github.io/TapLead/account/`
- Dashboard: `https://supabase.com/dashboard/project/qyflrgvolsiljpsghqku`

The existing Node/SQLite server remains a local/reference implementation. The production API uses Supabase Edge, Postgres and managed account storage. `scripts/prepare-edge.py` copies the canonical Zod validation, visibility filtering, CSS and vCard logic into its independently deployable bundle. CI rejects a stale copy. Deno/package versions and the dependency lockfile are committed.

## Security and data

TapLead tables enable RLS and explicitly revoke all anonymous/authenticated table and RPC privileges. Only the server-side service role can access them. No service key appears in the app, public pages, repository or logs. The publishable key on the recovery page cannot access private TapLead data.

The function has gateway JWT verification disabled because public profiles, registration and password recovery are intentionally public, and private routes authenticate **opaque application sessions** rather than Supabase JWTs. Every owner route checks a 32-byte random token's SHA-256 hash against a live database session before accessing records. Logout deletes that session; account deletion cascades sessions, cards, images, leads and events. A private, narrowly scoped password-change trigger also revokes application sessions during password recovery. The function refuses Apple account deletion until Apple grant revocation is implemented/configured.

Owner writes and public lead capture serialize through transaction-scoped advisory locks. Database functions enforce ownership, free/Pro quotas, public-card state and consent. Pro flags are never accepted from user metadata or client input. Image writes re-check card ownership and the selected image kind under a row lock.

PNG/JPEG uploads are limited to 2 MB and 4,194,304 input pixels before decompression. PNG chunk bounds, CRCs and animation rejection, JPEG allocation bounds/MPO rejection, strict decoding, EXIF orientation and fresh RGBA-to-PNG encoding protect the upload path. Stored images have a maximum edge of 512 pixels and exclude EXIF/GPS/text/ICC metadata. No native image module or third-party runtime image fetch is used.

Rate limits are database-backed. Only hashed source-IP buckets are stored, and expired buckets are pruned during requests. Public profile JSON contains only permitted fields; private cards/images return unavailable. Analytics remain opt-in and describe requests/downloads rather than claiming unique people or saved contacts.

## Verification completed

Full [GitHub check run 37220371267](https://github.com/lanray07/TapLead/actions/runs/37220371267) passed for source `ae2baa3`: app/widget compilation, 13 shared tests, 16 backend tests, five portable Edge image tests, QR/PDF validation and seven native UI tests. The unavailable-AI case was skipped when the runner reported an available model. Device AI evaluation remains required. [Pages deployment 37220371264](https://github.com/lanray07/TapLead/actions/runs/37220371264) also passed.

- Live `/health`: HTTP 200; unsigned `/api/cards`: HTTP 401.
- Live rollback SQL suite: owner isolation, one-card/50-lead free quotas, Pro appearance gate, consent, media ownership, expired sessions, private API privileges and account deletion cascades passed. Synthetic records were rolled back.
- Deno type checking and five portable image tests passed, including EXIF orientation and malformed/animated file rejection.
- Live HTTPS smoke checks passed for Free quotas, cross-owner denial, private field/CTA filtering, MIME spoofing rejection, actual portable image upload, public logo/vCard access, consented capture, owned inbox/export and paid-feature denial. Two disposable unverified identities were provisioned only for this transport test; this does not validate email or Apple authentication. Both were deleted through the normal API, after which their sessions and public profile returned unavailable.
- The GitHub page was inspected in the browser. An explicit-consent fictional introduction was submitted and verified in the cloud inbox with `source=qr`. The uploaded corner logo rendered. The synthetic public profile and leads were removed with their owner after capture. Saved [profile proof](assets/cloud-profile.png) is browser evidence, not an App Store screenshot.
- Security advisor reports seven informational `rls_enabled_no_policy` notices. This is intentional deny-by-default for server-only tables, reinforced by revoked client grants. See [the Supabase advisory](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). No client-facing policy should be added merely to silence this notice.

## Required configuration / acceptance still outstanding

1. **User scope change, 4 October 2026:** use native Apple sign-in and local guest mode; email login is no longer a release requirement. Email UI/DTOs and public recovery form are removed; live Edge email endpoints return HTTP 410 and the dashboard email provider is disabled. The unsaved Gmail SMTP draft was cancelled. No SMTP sender or Gmail app password is needed. Guest mode remains local and does not create an anonymous Supabase account.
2. Native Apple UI now shows loading, explicit challenge errors and retry instead of silently failing. The Apple provider and live Apple endpoints remain disabled until sign-in, encrypted refresh credentials and grant revocation are configured and verified. [Dashboard proof](assets/apple-only-auth.jpg).
3. **Apple key registered with user approval:** `C6NC8YGQWA`, team `5ZP6GV85J6`, scoped to `com.TapLead.app`. The private key is backed up outside the repository in a restricted local directory. Live Edge v4 implements Apple RS256 issuer/audience/nonce verification, authorization-code exchange, subject matching, AES-GCM encryption bound to the Apple subject, managed Apple identity creation, opaque app sessions and revocation before account deletion. Two crypto tests and live rollback challenge tests passed (single use, expiry and denied public credential/RPC access). Seven total Edge tests pass. No genuine Apple login/revocation has been exercised yet. The four `TAPLEAD_APPLE_TEAM_ID`, `TAPLEAD_APPLE_KEY_ID`, `TAPLEAD_APPLE_PRIVATE_KEY_B64`, `TAPLEAD_TOKEN_ENCRYPTION_KEY` secrets must be installed in Edge Secrets; enable the native Apple provider for the exact bundle ID. Endpoints stay fail closed until configured. Existing App Store Connect upload secrets are not this credential. [Registration proof](assets/apple-key-registered.jpg).
4. Configure real App Store signature-chain/receipt/notification verification, renewal, refund and grace handling. Purchases are explicitly disabled and no production Pro entitlement has been inserted. Sandbox evidence must be isolated from Production entitlements.
5. Complete the master prompt's device, locale, privacy, screenshot and subscription acceptance checks, then build a new signed candidate. Build 1012 predates this deployment and still has no API URL.

Creating/deploying this infrastructure does **not** satisfy all master requirements. The submission gate remains closed.
