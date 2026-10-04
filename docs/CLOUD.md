# TapLead cloud deployment

The user approved creating TapLead in **lanray07's Org** on the **£0/month** plan. Project `qyflrgvolsiljpsghqku` is a new, separate Postgres project in London (`eu-west-2`), created 4 October 2026. The pre-existing unrelated project was not modified.

- API: `https://qyflrgvolsiljpsghqku.supabase.co/functions/v1/taplead`
- Public profiles: `https://lanray07.github.io/TapLead/card/?id=<card UUID>&source=qr`
- Account email redirects: `https://lanray07.github.io/TapLead/account/`
- Dashboard: `https://supabase.com/dashboard/project/qyflrgvolsiljpsghqku`

The existing Node/SQLite server remains a local/reference implementation. The production API uses Supabase Edge, Postgres and managed email authentication. `scripts/prepare-edge.py` copies the canonical Zod validation, visibility filtering, CSS and vCard logic into its independently deployable bundle. CI rejects a stale copy. Deno/package versions and the dependency lockfile are committed.

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

1. **Completed 4 October 2026:** signed in to TapLead under `lanray07's Org`, saved site URL `https://lanray07.github.io/TapLead/` and the single exact redirect `https://lanray07.github.io/TapLead/account/`. The dashboard confirmed both saves. [Saved configuration proof](assets/auth-redirects.jpg). Email authentication and mandatory email confirmation are enabled; anonymous sign-ins and manual identity linking are disabled. Custom SMTP and the Apple provider are still disabled.
2. Configure a production SMTP sender with email confirmation enabled. Supabase's default sender only delivers to organisation team addresses and is unsuitable for public signups. [Official SMTP instructions](https://supabase.com/docs/guides/auth/auth-smtp). Verify signup, confirmation, recovery and revocation end to end.
3. Configure a separate Sign in with Apple credential for code exchange and grant revocation. Existing App Store Connect upload secrets are not this credential. Apple endpoints currently fail closed.
4. Configure real App Store signature-chain/receipt/notification verification, renewal, refund and grace handling. Purchases are explicitly disabled and no production Pro entitlement has been inserted. Sandbox evidence must be isolated from Production entitlements.
5. Complete the master prompt's device, locale, privacy, screenshot and subscription acceptance checks, then build a new signed candidate. Build 1012 predates this deployment and still has no API URL.

Creating/deploying this infrastructure does **not** satisfy all master requirements. The submission gate remains closed.
