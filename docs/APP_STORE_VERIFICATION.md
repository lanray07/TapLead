# App Store receipt verification

The deployed Edge service uses Apple's pinned `@apple/app-store-server-library` 3.1.0 with online certificate checks enabled. It verifies the certificate chain, signature, environment, bundle ID `com.TapLead.app` and Production App Apple ID `6818982306`. Root CA G2/G3 are bundled from [Apple PKI](https://www.apple.com/certificateauthority/); no root supplied by a client is trusted.

Private receipt submission additionally binds the signed `appAccountToken` to the authenticated owner and checks the two exact subscription products and auto-renewable transaction type. Production and Sandbox use different verifiers and separate database primary keys. Only Production, unrevoked, unexpired records can grant the normal cloud Pro plan. A Sandbox receipt never unlocks Production Pro.

Database writes serialize per original transaction/environment, reject ownership reassignment and ignore older/equal signed updates. Public notifications require a verified signed notification and an independently verified nested transaction. Verified billing grace can extend expiry only when the signed renewal matches the transaction and environment. Later expiry/refund/revocation updates supersede older receipts. Deleted accounts are not recreated by notifications.

Notification endpoint: `https://qyflrgvolsiljpsghqku.supabase.co/functions/v1/taplead/api/apple/notifications`. App Store Connect configuration is still outstanding. Purchases remain disabled while acceptance is incomplete.

## Evidence and remaining acceptance

Deno rejects malformed and attacker-signed JWS payloads. Crypto tests verify the bundled roots' self signatures and exercise the Node X509 implementation used by the Apple library in the Edge runtime. Structural mapping tests reject mismatched owner/product/bundle/environment. Live rollback SQL checks verify environment isolation, replay protection, ownership binding and denied public receipt writes; they do not represent genuine purchases. Live unsigned notification submission returns HTTP 400.

Real Apple-signed Production/Sandbox chain and OCSP verification, monthly/yearly purchase, restore, renewal, expiry, refund, grace handling and notification delivery remain unverified. No subscription acceptance report is claimed. Server API reconciliation for missed notifications is also outstanding. Production purchases and review submission must remain blocked until those checks pass.
