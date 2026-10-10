"""Update only the two authorized Pro review notes and feature screenshots.

No pricing, product IDs, build, entitlements, or review submission changes.
"""
import hashlib
import importlib.util
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

spec = importlib.util.spec_from_file_location('metadata', Path(__file__).with_name('store-metadata.py'))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
api = helper.api
KIND = 'subscriptionAppStoreReviewScreenshots'
FILE = Path('marketing/assets/pro-review-creator-native-build-1015.png')
DATA = FILE.read_bytes()
assert hashlib.sha256(DATA).hexdigest() == '692cfec1757248445943ff63914924a66539ac5960c7f33e56ccbe7ddc4252e2'
MD5 = hashlib.md5(DATA).hexdigest()
OLD_MD5 = hashlib.md5(Path('marketing/assets/pro-review-current-configuration.png').read_bytes()).hexdigest()
SHARED = (' Pro is enabled in build 1015. Open Settings, complete native Sign in with Apple, then open TapLead Pro. '
          'Select the monthly or annual StoreKit product and complete the Apple purchase sheet. Restore purchases is on the same sheet. '
          'Close and reopen the Pro sheet if it was opened before sign-in. Active verified access displays A verified Pro entitlement is active. '
          'Both plans provide the same Pro tier: up to 20 published cards and 10,000 synced leads, advanced card themes, voice notes, branded QR exports and activity insights. '
          'No storefront-specific purchase restriction is applied. The Paid Apps Agreement is active. Signed transactions and V2 server notifications are configured for Production and Sandbox. '
          'On 10 October 2026 the developer reported successful TestFlight purchase, Pro unlock and restore on a physical iPhone. Renewal/expiration/refund notification acceptance was not separately confirmed. '
          'The review screenshot is an unmodified native build-1015 simulator capture of the Creator card theme in labelled demo mode, illustrating an advanced appearance included in Pro. '
          'It is not a purchase receipt or a screenshot of the physical-device test.')

def picture(sub_id):
    record = api('/v1/subscriptions/' + sub_id + '/appStoreReviewScreenshot')['data']
    if record:
        attrs = record['attributes']
        state = (attrs.get('assetDeliveryState') or {}).get('state')
        if attrs.get('sourceFileChecksum') == MD5 and state == 'COMPLETE':
            return record
        # Replace only the known previous task image, or our own failed reservation.
        assert attrs.get('sourceFileChecksum') == OLD_MD5 or (
            attrs.get('fileName') == FILE.name and not attrs.get('sourceFileChecksum') and state != 'COMPLETE'
        ), 'Unexpected review asset; preserve for inspection'
        if not attrs.get('uploadOperations'):
            api('/v1/' + KIND + '/' + record['id'], 'DELETE')
            record = None
        elif attrs.get('sourceFileChecksum') == OLD_MD5:
            api('/v1/' + KIND + '/' + record['id'], 'DELETE')
            record = None
    if not record:
        record = api('/v1/' + KIND, 'POST', {'data': {
            'type': KIND, 'attributes': {'fileName': FILE.name, 'fileSize': len(DATA)},
            'relationships': {'subscription': {'data': {'type': 'subscriptions', 'id': sub_id}}}
        }})['data']
    for operation in record['attributes'].get('uploadOperations') or []:
        parsed = urllib.parse.urlparse(operation['url'])
        host = parsed.hostname or ''
        assert parsed.scheme == 'https' and any(host == d or host.endswith('.' + d) for d in ['apple.com', 'icloud-content.com', 'mzstatic.com', 'amazonaws.com'])
        assert operation['method'] == 'PUT'
        chunk = DATA[operation['offset']:operation['offset'] + operation['length']]
        assert len(chunk) == operation['length']
        headers = {x['name']: x['value'] for x in operation['requestHeaders']}
        with urllib.request.urlopen(urllib.request.Request(operation['url'], data=chunk, headers=headers, method='PUT'), timeout=90) as response:
            assert 200 <= response.status < 300
    api('/v1/' + KIND + '/' + record['id'], 'PATCH', {'data': {'type': KIND, 'id': record['id'], 'attributes': {'sourceFileChecksum': MD5, 'uploaded': True}}})
    for _ in range(60):
        saved = api('/v1/' + KIND + '/' + record['id'])['data']
        attrs = saved['attributes']
        state = (attrs.get('assetDeliveryState') or {}).get('state')
        if state == 'COMPLETE':
            assert attrs.get('sourceFileChecksum') == MD5
            return saved
        assert state != 'FAILED', 'Apple image processing failed'
        time.sleep(3)
    raise RuntimeError('Review image is still processing')

assert api('/v1/apps/' + helper.APP)['data']['attributes']['bundleId'] == 'com.TapLead.app'
report = {'app_id': helper.APP, 'subscriptions': []}
for sub_id, product_id, prefix in [
    ('6818996808', 'com.taplead.pro.yearly', 'Annual access paid upfront for one year; auto-renewable.'),
    ('6818996322', 'com.taplead.pro.monthly', 'Monthly access; auto-renewable.')
]:
    subscription = api('/v1/subscriptions/' + sub_id)['data']
    assert subscription['attributes']['productId'] == product_id
    note = prefix + ' Product ID: ' + product_id + '.' + SHARED
    assert len(note) <= 4000
    api('/v1/subscriptions/' + sub_id, 'PATCH', {'data': {'type': 'subscriptions', 'id': sub_id, 'attributes': {'reviewNote': note}}})
    assert api('/v1/subscriptions/' + sub_id)['data']['attributes']['reviewNote'] == note
    saved = picture(sub_id)
    report['subscriptions'].append({'id': sub_id, 'product_id': product_id, 'review_note': note, 'screenshot_id': saved['id'], 'checksum': MD5, 'delivery': saved['attributes']['assetDeliveryState']})
    Path('artifacts/storefront').mkdir(parents=True, exist_ok=True)
    Path('artifacts/storefront/pro-review-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Saved and verified Pro review metadata:', product_id, flush=True)
