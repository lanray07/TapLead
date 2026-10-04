"""Fail closed until every master-prompt section has reviewed acceptance evidence."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'docs/MASTER_REQUIREMENTS.json').read_text(encoding='utf-8'))
requirements = manifest['requirements']
if sorted(item['section'] for item in requirements) != list(range(1, 41)):
    raise SystemExit('The acceptance matrix must contain each master section exactly once.')
allowed = {'verified', 'conditional', 'partial', 'blocked'}
for item in requirements:
    if item['status'] not in allowed or not item.get('evidence', '').strip():
        raise SystemExit(f"Invalid acceptance evidence: section {item['section']}")
    if item['status'] == 'conditional' and item['section'] != 9:
        raise SystemExit('Only Wallet has an explicit conditional implementation exception.')
pending = [item for item in requirements if item['status'] not in {'verified', 'conditional'}]
print(f"Master prompt: {len(requirements) - len(pending)}/40 sections accepted; {len(pending)} pending.")
for item in pending:
    print(f"[{item['status']}] {item['section']}. {item['title']}: {item['evidence']}")
print('SUBMISSION BLOCKED' if pending else 'Acceptance matrix complete. Confirm the release evidence below before submission.')
if not pending:
    # A completed checklist alone cannot certify a different binary or production service.
    evidence = manifest.get('release_evidence', {})
    required = ['tested_source_commit', 'processed_build_id', 'production_api_url',
                'device_acceptance_report', 'subscription_test_report',
                'localisation_review_report', 'privacy_reconciliation_report']
    missing = [key for key in required if not str(evidence.get(key, '')).strip()]
    if missing:
        print('Missing release evidence: ' + ', '.join(missing))
        sys.exit(1)
sys.exit(1 if pending else 0)
