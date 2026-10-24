# Replacement Pro purchase test - build 1016

Build 1016 is processed and assigned to the existing internal tester group as of 15 October 2026. Update to 1.0.0 (1016) in TestFlight. This fixes the expired-session catalog-loading bug found during Apple's iPad review. The earlier build-1015 iPhone result below does not establish acceptance of this replacement.

1. Open **Settings > TapLead Pro** while signed out or with a session that needs sign-in. Confirm Monthly and Annual show Apple's actual localized prices. Do not delete existing local data merely to test a fresh install; use a spare device if available.
2. Select a plan. Confirm native Apple sign-in opens from Pro, then return and verify both plans remain available. If already signed in, proceed to the purchase sheet.
3. Complete a TestFlight sandbox purchase, confirm Pro features unlock, restart the app and use **Restore purchases** with the same TapLead and purchasing Apple accounts.
4. If an iPad is available, repeat the same path there. CI passed on iOS 26.2 simulators; Apple's physical iPadOS 27.0 environment has not been independently tested.
5. Report the build number, device/OS, whether both prices loaded, purchase/unlock/restore results, and any exact error. Real TestFlight acceptance for 1016 is pending; no replacement App Review submission has been made.

## Historical build-1015 test and configuration

### Pro purchase test â€” build 1015

Pro purchasing was enabled on 10 October 2026 through the existing backend, so no replacement binary is needed. Install or open build 1015 in TestFlight, sign in with Apple inside TapLead, close any open Pro sheet, and reopen **Settings â†’ TapLead Pro**. Monthly and annual buttons use StoreKit's actual localized product names and prices. TestFlight purchases use Apple's sandbox and do not charge real money.

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

## Corrected review assets — 10 October 2026

Both Pro review notes now describe enabled purchase navigation in build 1015 and distinguish user-reported device acceptance from lifecycle tests not separately confirmed. The old disabled-paywall review images were replaced by the unmodified Creator-theme simulator capture from the build-1015 UI run. This shows an advanced appearance offered by Pro, with the visible demo label retained; it does not claim to be the user’s physical-device purchase screenshot. Both saved Apple images have COMPLETE delivery status and MD5 `21be462396a01fab75ecc1e893fd5aea`. See [verified review metadata](../marketing/pro-review-verification.json) and [Apple API update run](https://github.com/lanray07/TapLead/actions/runs/38043630312).

## Review resubmission — 10 October 2026

The user instructed completion and resubmission after confirming their iPhone tests. Corrected submission `4efb9bc9-9605-4f0c-9402-5885df42c110` contains build 1015, the Pro group, Monthly and Annual. Apple returned WAITING_FOR_REVIEW at 10:08 UTC (11:08 BST), also confirmed for each item in App Store Connect. Release type is MANUAL. Sandbox Pro stays enabled for Apple review and TestFlight; turn it off and finish lifecycle acceptance/reconciliation before manually releasing to the public. The removed earlier submission retains its review-message history but no longer allows replying. The current version and both product notes include the issue resolutions and exact purchase navigation. [Submission verification](../marketing/corrected-submission-verification.json).

## Build 1016 resubmission - 24 October 2026

User confirmed purchase and Restore purchases both work on 24 October 2026. USB independently verified installed build 1016 on physical iPad11,6 running iPadOS 26.7. Transactions are user-reported, not independently observed. Renewal, expiration and refund acceptance remain unconfirmed.

Selected build 1016, saved new App Review Information instructions and posted a reply explaining the authenticated-plan dependency fix. Resubmitted the existing combined submission at 1:20 PM BST. App Store Connect confirms Waiting for Review for build 1016, Monthly, Annual and the Pro group. Release remains MANUAL. [Verification](../marketing/build-1016-submission-verification.json). Earlier pending-test statements above describe the 15 October state.
