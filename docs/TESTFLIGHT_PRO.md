# Pro purchase test — build 1015

Pro purchasing was enabled on 10 October 2026 through the existing backend, so no replacement binary is needed. Install or open build 1015 in TestFlight, sign in with Apple inside TapLead, close any open Pro sheet, and reopen **Settings → TapLead Pro**. Monthly and annual buttons use StoreKit's actual localized product names and prices. TestFlight purchases use Apple's sandbox and do not charge real money.

1. Purchase monthly or annual. Confirm Apple's purchase sheet appears and completes.
2. Confirm **A verified Pro entitlement is active** appears. Close the sheet and verify a second card, a Pro theme and cloud sync work.
3. Close and reopen the app, open Pro again, and confirm the entitlement remains active while the test subscription is unexpired.
4. Use **Restore purchases** with the same TapLead Apple sign-in account and the same purchasing Apple account. Confirm access is recovered without a second purchase.
5. Test accelerated sandbox renewal, expiration, cancellation and refund/revocation using Apple's sandbox controls where available. Cancellation alone does not end access before the current paid test period expires.

If no product buttons appear, confirm native Apple sign-in has completed and internet access works, then close and reopen the Pro sheet. Send the exact error and a screenshot if products still do not load. On 10 October 2026, the user confirmed successful Pro purchase, Pro feature unlock and Restore purchases on their physical iPhone through TestFlight. These are user-reported results, not independently observed by Codex. Renewal, expiration, cancellation and refund notification acceptance remain unconfirmed; backend fixture tests do not establish those device results.

The live Edge function is version 7. Administrative settings in `public.taplead_subscription_settings` currently enable purchases and sandbox testing. Only cryptographically verified Apple transactions bound to the authenticated account can grant Pro. Sandbox transactions remain stored separately from Production transactions; Free users do not become Pro simply because purchase buttons are enabled. Database tests cover expiry, revocation, stale replay, environment separation, test quotas and settings permissions. The live HTTPS smoke test passed and its disposable fixture accounts were deleted.

Before public release, turn off sandbox grants after collecting purchase acceptance evidence:

```sql
update public.taplead_subscription_settings
set sandbox_enabled = false
where singleton;
```

This leaves genuine Production subscriptions intact. `purchases_enabled` is a separate administrative availability switch; it does not fabricate an entitlement. No App Review resubmission occurred as part of enabling this test.

References: [Apple sandbox testing](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox), [TestFlight](https://developer.apple.com/testflight/).
