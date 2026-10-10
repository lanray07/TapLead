"""Verify Apple's saved, processed screenshots against the intended locale exports."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('report', type=Path)
parser.add_argument('--output', type=Path, default=Path('marketing/store-screenshot-verification.json'))
parser.add_argument('--creative-ledger', type=Path)
args = parser.parse_args()
report = json.loads(args.report.read_text(encoding='utf-8'))
manifest = json.loads(Path('marketing/localized-assets/manifest.json').read_text(encoding='utf-8'))
metadata = json.loads(Path('marketing/store-metadata-verification.json').read_text(encoding='utf-8'))
aliases = {r['locale']: r['copy_locale'] for r in metadata['verified_localizations']}
placements = {'APP_IPHONE_DUO': ('duo-inner', 'duo-outer'), 'APP_IPHONE_61': ('iphone-medium',)}
actual = {r['locale']: r for r in report['locales']}
creative = json.loads(args.creative_ledger.read_text(encoding='utf-8')) if args.creative_ledger else None
verified, failures = [], []
for locale, copy_locale in aliases.items():
    row = {'locale': locale, 'copy_locale': copy_locale, 'sets': []}
    if creative is not None:
        assignment = creative.get(copy_locale, {})
        if assignment.get('header') != 1 or assignment.get('searchReuse') is not True:
            failures.append(f'{locale}: header/search assignment not confirmed in App Store UI')
        header = next(a for a in manifest['assets'] if a['locale'] == copy_locale and a['placement'] == 'universal-header-search')
        row['creative'] = {'verification': 'App Store Connect visible saved counts and checked reuse control',
                           'header_count': assignment.get('header', 0), 'search_reuses_header': assignment.get('searchReuse', False),
                           'export_file': header['file'], 'export_sha256': header['sha256']}
    if locale not in actual:
        failures.append(f'{locale}: localization missing')
        continue
    for display_type, targets in placements.items():
        expected = [a for a in manifest['assets'] if a['locale'] == copy_locale and a['placement'] in targets]
        sets = [s for s in actual[locale]['sets'] if s['display_type'] == display_type]
        pictures = [p for s in sets for p in s['screenshots']]
        if len(sets) != 1 or len(pictures) != len(expected):
            failures.append(f'{locale}/{display_type}: expected one set with {len(expected)} images, got {len(sets)} sets and {len(pictures)} images')
        if sorted(p.get('checksum') or '' for p in pictures) != sorted(a['md5'] for a in expected):
            failures.append(f'{locale}/{display_type}: saved checksums do not match intended locale exports')
        if any(p.get('delivery', {}).get('state') != 'COMPLETE' for p in pictures):
            failures.append(f'{locale}/{display_type}: image processing incomplete')
        row['sets'].append({'display_type': display_type, 'count': len(pictures), 'screenshots': pictures})
    verified.append(row)
result = {'app_id': report['app_id'], 'version_id': report['version_id'], 'localization_count': len(verified),
          'screenshot_count': sum(s['count'] for r in verified for s in r['sets']),
          'failures': failures, 'locales': verified}
if creative is not None:
    result['header_count'] = sum(r['creative']['header_count'] for r in verified)
    result['search_creative_count'] = sum(r['creative']['search_reuses_header'] for r in verified)
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k != 'locales'}, ensure_ascii=False))
if failures:
    raise SystemExit(1)
