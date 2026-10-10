"""Submit the explicitly authorized build 1015 and the two corrected Pro plans.

Reuse the current draft, preserve all pricing, and hold release for production readiness.
"""
import hashlib
import importlib.util
import json
import time
from pathlib import Path

spec = importlib.util.spec_from_file_location('metadata', Path(__file__).with_name('store-metadata.py'))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
api, listing = helper.api, helper.listing
APP = '6818982306'
VERSION = '19190b9a-9bcb-4393-8d33-2406f00f56da'
BUILD = 'a8bedb4b-080e-432a-ae00-a55d850c4209'
GROUP = '22439298'
PRODUCTS = {'6818996322': 'com.taplead.pro.monthly', '6818996808': 'com.taplead.pro.yearly'}
report = {'app_id': APP, 'version_id': VERSION, 'build': '1015', 'items': []}
Path('artifacts/storefront').mkdir(parents=True, exist_ok=True)

def save():
    Path('artifacts/storefront/corrected-submission-report.json').write_text(json.dumps(report, indent=2) + '\n')

def create(kind, relations, attributes=None):
    data = {'type': kind, 'relationships': {key: {'data': {'type': value[0], 'id': value[1]}} for key, value in relations.items()}}
    if attributes:
        data['attributes'] = attributes
    return api('/v1/' + kind, 'POST', {'data': data})['data']

assert api('/v1/apps/' + APP)['data']['attributes']['bundleId'] == 'com.TapLead.app'
version = api('/v1/appStoreVersions/' + VERSION + '?include=build')['data']
assert version['relationships']['build']['data']['id'] == BUILD
assert version['attributes']['versionString'] == '1.0.0'
assert version['attributes']['appStoreState'] in {'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'READY_FOR_REVIEW'}
notes = api('/v1/appStoreVersions/' + VERSION + '/appStoreReviewDetail')['data']['attributes']['notes']
assert '1015' in notes and 'Pro purchases are enabled' in notes and 'no NFC reading' in notes
expected_md5 = hashlib.md5(Path('marketing/assets/pro-review-creator-native-build-1015.png').read_bytes()).hexdigest()
for sub_id, product_id in PRODUCTS.items():
    sub = api('/v1/subscriptions/' + sub_id)['data']
    assert sub['attributes']['productId'] == product_id
    assert 'Pro is enabled in build 1015' in sub['attributes']['reviewNote']
    shot = api('/v1/subscriptions/' + sub_id + '/appStoreReviewScreenshot')['data']['attributes']
    assert shot['sourceFileChecksum'] == expected_md5 and shot['assetDeliveryState']['state'] == 'COMPLETE'

api('/v1/appStoreVersions/' + VERSION, 'PATCH', {'data': {'type': 'appStoreVersions', 'id': VERSION, 'attributes': {'releaseType': 'MANUAL'}}})
assert api('/v1/appStoreVersions/' + VERSION)['data']['attributes']['releaseType'] == 'MANUAL'
report['release_type'] = 'MANUAL'
save()
submissions = listing('/v1/apps/' + APP + '/reviewSubmissions?limit=200')
active = [s for s in submissions if s['attributes'].get('platform') == 'IOS' and s['attributes']['state'] not in {'COMPLETE', 'CANCELED'}]
assert all(s['attributes']['state'] == 'READY_FOR_REVIEW' for s in active), 'Another active submission must complete cancellation first'
assert len(active) <= 1
submission = active[0] if active else create('reviewSubmissions', {'app': ('apps', APP)}, {'platform': 'IOS'})
submission_id = submission['id']
report['submission_id'] = submission_id
save()
existing = listing('/v1/reviewSubmissions/' + submission_id + '/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion&limit=200')
allowed = {'appStoreVersion', 'subscriptionVersion', 'subscriptionGroupVersion'}
for item in existing:
    populated = {k: v['data'] for k, v in item.get('relationships', {}).items() if v.get('data') and k != 'reviewSubmission'}
    assert set(populated).issubset(allowed), 'Preserve unexpected submission items for inspection'

def add(relation, kind, resource_id):
    match = [i for i in existing if (i.get('relationships', {}).get(relation, {}).get('data') or {}).get('id') == resource_id]
    assert len(match) <= 1
    item = match[0] if match else create('reviewSubmissionItems', {'reviewSubmission': ('reviewSubmissions', submission_id), relation: (kind, resource_id)})
    report['items'].append({'id': item['id'], 'relation': relation, 'resource_id': resource_id})
    save()

add('appStoreVersion', 'appStoreVersions', VERSION)
for sub_id in PRODUCTS:
    matching = [i for i in existing if (i.get('relationships', {}).get('subscriptionVersion', {}).get('data'))]
    found = []
    for item in matching:
        v_id = item['relationships']['subscriptionVersion']['data']['id']
        record = api('/v1/subscriptionVersions/' + v_id)['data']
        if (record.get('relationships', {}).get('subscription', {}).get('data') or {}).get('id') == sub_id:
            found.append(record)
    assert len(found) <= 1
    response = api('/v1/subscriptions/' + sub_id + '?include=versions')
    versions = [v for v in response.get('included', []) if v['type'] == 'subscriptionVersions' and v['attributes']['state'] in {'PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW', 'DEVELOPER_REJECTED', 'REJECTED'}]
    latest = max(versions, key=lambda v: v['attributes']['version']) if versions else None
    record = found[0] if found else latest or create('subscriptionVersions', {'subscription': ('subscriptions', sub_id)})
    add('subscriptionVersion', 'subscriptionVersions', record['id'])
group_items = [i for i in existing if i.get('relationships', {}).get('subscriptionGroupVersion', {}).get('data')]
assert len(group_items) <= 1
group_response = api('/v1/subscriptionGroups/' + GROUP + '?include=versions')
group_versions = [v for v in group_response.get('included', []) if v['type'] == 'subscriptionGroupVersions' and v['attributes']['state'] in {'PREPARE_FOR_SUBMISSION', 'READY_FOR_REVIEW', 'DEVELOPER_REJECTED', 'REJECTED'}]
latest_group = max(group_versions, key=lambda v: v['attributes']['version']) if group_versions else None
group_version = group_items[0]['relationships']['subscriptionGroupVersion']['data'] if group_items else latest_group or create('subscriptionGroupVersions', {'subscriptionGroup': ('subscriptionGroups', GROUP)})
add('subscriptionGroupVersion', 'subscriptionGroupVersions', group_version['id'])
all_items = listing('/v1/reviewSubmissions/' + submission_id + '/items?include=appStoreVersion,subscriptionVersion,subscriptionGroupVersion&limit=200')
assert len(all_items) == 4 and {i['id'] for i in all_items} == {i['id'] for i in report['items']}
api('/v1/reviewSubmissions/' + submission_id, 'PATCH', {'data': {'type': 'reviewSubmissions', 'id': submission_id, 'attributes': {'submitted': True}}})
for _ in range(30):
    actual = api('/v1/reviewSubmissions/' + submission_id)['data']
    report['state'] = actual['attributes']['state']
    report['submitted_date'] = actual['attributes'].get('submittedDate')
    save()
    if report['state'] in {'WAITING_FOR_REVIEW', 'IN_REVIEW'}:
        print('Verified combined submission:', submission_id, report['state'], '4 items, build 1015, MANUAL release', flush=True)
        break
    assert report['state'] in {'READY_FOR_REVIEW', 'PROCESSING_FOR_REVIEW'}, 'Unexpected review state'
    time.sleep(3)
else:
    raise RuntimeError('Submission processing is not complete; inspect before repeating')
