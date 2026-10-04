# AI gateway contract

## Default native implementation

TapLead now uses Apple's Foundation Models **on device**, gated to iOS 26+, model availability, supported locale, explicit action consent and Pro (or labelled demo). No AI provider credential, vendor subscription or external AI request is required for this path. Unsupported devices keep manual notes and introduction drafts. No generated sample is presented as real output when a model is unavailable.

Structured generation separates factual extracts from suggestions. Factual values must be literal substrings of their quoted evidence, which must occur in the supplied notes; unsupported fields are omitted. Drafts are editable and never sent automatically. Generated dates never schedule reminders. Cancel/revoked consent discards pending output. Notes over 3,000 characters require the user to shorten them rather than silently dropping context.

Simulator tests verify unavailable-model behaviour; shared tests check invented-value/evidence rejection. Available-model factuality, prompt-injection, language, interruption and tone/channel evaluation require an Apple Intelligence-capable physical iPhone before release. This implementation does not claim that reviewed generative drafts can never contain errors.

Sources: [SystemLanguageModel availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel), [guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation).

## Optional future external gateway

The following server interface is retained for an explicitly approved future integration. The current native AI screen does not call it. Do not enable an external processor without changing the consent text, privacy policy and acceptance evidence first.

Set an approved `AI_GATEWAY_URL` and `AI_GATEWAY_TOKEN` only on the service. Use HTTPS. The native app sends no notes automatically and no vendor token is in the binary. The action requires `consent: true`. Publish the real provider, processing region, retention and subprocessors before enabling the feature. Consent is scoped to the action and chosen notes; it does not silently translate user content.

The authenticated gateway receives:

```json
{"kind":"smart_notes","name":"Sarah","notes":"Met Sarah at the property conference. Send the portfolio tomorrow.","tone":"Professional","channel":"Email","consent":true,"instructions":"Use only supplied facts. Missing fields must be null. Suggestions must be labelled. Return a draft, never send a message."}
```

Return the following schema for either `smart_notes` or `follow_up`:

```json
{
  "draft": null,
  "facts": [{"field":"Context","value":"Property conference","evidence":"Met Sarah at the property conference."}],
  "suggestions": ["Suggestion: confirm which portfolio to send."]
}
```

Facts need literal evidence from the input. The backend rejects evidence not present in the supplied notes; this prevents unsupported citations but does not prove that a paraphrase is correct. Evaluate extraction accuracy and hallucinations with adversarial fixtures before launch. Empty/missing values remain absent. Dates are suggestions unless explicitly supplied and must be confirmed by the user. Generated drafts are editable; sharing opens the user's chosen destination and never automatically sends.

The external gateway is an integration interface, not a built-in AI model. No external provider has been configured or billed. Keep that interface unavailable until its service, consent copy and outputs have been tested.
