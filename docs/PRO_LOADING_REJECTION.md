# Pro catalog rejection — 15 October 2026

Apple rejected build 1015 on an iPad Pro 11-inch (M4), iPadOS 27.0. Its attached screenshot shows the unavailable-purchases copy and the backend message “Sign in again to continue.” The reviewed submission is `4efb9bc9-9605-4f0c-9402-5885df42c110`.

## Reproduction and cause

The original `PurchaseService.load()` awaited authenticated `api/plan` and fetched `Product.products(for:)` inside the same `do` block. A missing or expired TapLead session therefore prevented StoreKit from being called at all. The Pro screen mislabeled the failure as release configuration, lacked a sign-in action, and only loaded when first presented. A successful signed-in iPhone test did not cover this clean-install/expired-session path.

The local Swift harness ran the original method body with a plan response of 401 and a successful two-product catalog adapter. It failed with `products=0, StoreKit calls=0, error=Sign in required`. After the correction, the same scenario passed with two products, sign-in required, purchasing blocked and no Pro grant. This isolates the native orchestration bug; the harness does not prove Apple's live catalog or payments.

Read-only live requests on 15 October returned:

- `GET health`: HTTP 200, `purchasesEnabled=true`, `subscriptionTesting=true`.
- `GET api/plan` without a session: HTTP 401, `Sign in again to continue.`

No backend authentication, verification, rollout flag or entitlement policy was changed.

## Correction

The public StoreKit catalog and authenticated plan refresh now load independently. The Pro screen displays Apple's product names and localized prices before sign-in, with explicit loading, empty/partial/error states and retry. Selecting a plan or restoring as a guest opens native Apple sign-in on the Pro screen. Dismissing sign-in, changing authentication or returning to the app reloads account status. An older account request cannot overwrite the result of a newer successful sign-in.

Buying still requires a valid account, server-enabled purchasing and an account UUID. Receipt signature, product/environment/owner checks and backend limits are preserved. A loaded catalog alone never grants Pro. The release build does not include a local StoreKit configuration; the fixture is bundled only into test targets.

## Verification

`PurchaseLoadingTests` exercises real StoreKit products using an explicitly local `SKTestSession`: 401 and network failures, empty catalog retry, StoreKit error retry, successful reauthentication, and a late expired-session response. `ProPurchaseUITests` opens Pro as a fresh guest, checks both plan prices, and opens sign-in from a plan. The dedicated GitHub workflow runs these on available iPhone and iPad simulators and records the exact runtime, test results and captures.

The local StoreKit fixture is not evidence of a live sandbox purchase. The available GitHub simulator runtime may differ from Apple's iPadOS 27.0 review device; the workflow records that limitation. A replacement TestFlight build needs a fresh/expired-session walkthrough before resubmission, including real catalog loading and account recovery.

The first native attempt selected iOS 26.5 and failed: `SKTestSession` logged `SKInternalErrorDomain Code=3` while saving its configuration, setting options and clearing transactions. Its empty catalog was therefore not accepted as app regression evidence. This matches the [reported Apple CLI test-session issue](https://developer.apple.com/forums/thread/826971). The dedicated StoreKit workflow now requires an installed runtime at or below 26.2, preferring 26.1, and fails explicitly if none exists. The general latest-SDK checks exclude these two StoreKit test classes; the separate iPhone/iPad job must run them. No skipped or mock StoreKit run is treated as purchase acceptance.

Apple references: [StoreKit products](https://developer.apple.com/documentation/storekit/product/products(for:)), [sandbox availability troubleshooting](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox), [StoreKit test sessions](https://developer.apple.com/documentation/storekittest/sktestsession).
