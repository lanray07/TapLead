# Apple Wallet signing

The app includes a signed-pass download/PassKit presentation adapter. There is no live Add to Apple Wallet button or Wallet marketing screenshot because a valid signing service has not been configured or device tested.

1. Register a Pass Type ID with Apple Developer and issue a Pass Type ID certificate. Store its private key on the signing service only. Use the required Apple WWDR intermediate certificate and monitor certificate expiry.
2. Create a `generic` pass with `formatVersion: 1`, your team and pass type IDs, unique serial number, organization name and a useful description. Include public name, title and company. Use the stable published profile URL as the QR barcode message and encode with `iso-8859-1` for an ASCII URL.
3. Include correctly sized icon/logo assets, pass.json, a SHA-1 manifest of package files and a detached PKCS #7 signature over that manifest. Package them as `.pkpass`. SHA-1 here follows the Wallet manifest format, not password storage.
4. Expose an authenticated owner endpoint that returns `application/vnd.apple.pkpass` over HTTPS. Generate only for a published, owned profile. Rate-limit requests. The client should download from its configured first-party service; never pass its bearer token to an arbitrary host.
5. Add a user-triggered action that calls `WalletService` and presents `WalletPassSheet` only after a real `PKPass` validates. Check `canAddPasses()` and handle download/signature errors. The client adapter is not wired to a fake endpoint.
6. For updated pass fields, implement the Wallet web service, device registration, per-pass authentication tokens, push certificates and revocation. The URL itself remains stable even without automatic pass-field updates.
7. Test certificate chain, signing, adding, scanning, updates, private fields and deletion on a physical iPhone before enabling Wallet copy.

Primary reference: [Apple — Building a Pass](https://developer.apple.com/documentation/walletpasses/building-a-pass).
