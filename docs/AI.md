# AI gateway contract

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

The gateway is an integration interface, not a built-in AI model. No provider has been configured or billed. Keep this feature unavailable until its service, consent copy and outputs have been tested.
