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

## Final simulator results

[Run 38766355029](https://github.com/lanray07/TapLead/actions/runs/38766355029) passed on Xcode 26.6 using iOS 26.2: six native StoreKit regression tests plus one fresh-guest UI test on each of iPhone 17 Pro and iPad Pro 13-inch (M5). The first compatible-runtime iPad UI attempt timed out during Xcode app launch before reaching the Pro screen; retrying the same job passed, with all assertions retained. No product-loading test was skipped. The original latest-runtime failure and this launch retry remain disclosed. [Machine-readable results](../marketing/pro-loading-regression-verification.json).

Signed build 1016 was uploaded successfully by [archive run 38767929689](https://github.com/lanray07/TapLead/actions/runs/38767929689). No replacement App Review submission has been made. A real TestFlight walkthrough is still required; simulator product prices are local test data.

Apple completed processing on 15 October. Build 1016 (`5b7fe41a-8227-4b1c-8aba-c45d8eb3d858`) is assigned to the existing TapLead Internal Testers group with one invite. The downloaded signed IPA reports CFBundleVersion 1016 and contains no `.storekit` files or StoreKitTest framework. The App Store version remains on rejected build 1015 until replacement TestFlight acceptance.

## Physical TestFlight acceptance - 24 October 2026

The connected device was independently identified over USB as iPad11,6 on iPadOS 26.7, with TapLead 1.0.0 build 1016 installed. The user explicitly confirmed purchase and Restore purchases both worked and requested submission. These transaction results are user-reported; Codex did not operate or independently observe the Apple purchase UI. Renewal, expiration and refund acceptance remain unconfirmed.

## Build 1016 resubmission - 24 October 2026

User confirmed purchase and Restore purchases both work on 24 October 2026. USB independently verified installed build 1016 on physical iPad11,6 running iPadOS 26.7. Transactions are user-reported, not independently observed. Renewal, expiration and refund acceptance remain unconfirmed.

Selected build 1016, saved new App Review Information instructions and posted a reply explaining the authenticated-plan dependency fix. Resubmitted the existing combined submission at 1:20 PM BST. App Store Connect confirms Waiting for Review for build 1016, Monthly, Annual and the Pro group. Release remains MANUAL. [Verification](../marketing/build-1016-submission-verification.json). Earlier pending-test statements above describe the 15 October state.
