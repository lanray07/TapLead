"""Upload the exact exported screenshots to Apple; retain correct existing assets.
Duo's display type was read from this app's saved Apple API collections.
Only allowlisted empty reservations from this uploader may be recreated.
No delivered asset deletion, binary upload, subscription change or submission.
"""
import hashlib,json,urllib.request,urllib.parse,urllib.error,importlib.util,os
from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path
helper_spec=importlib.util.spec_from_file_location('store_metadata',Path(__file__).with_name('store-metadata.py'))
helper=importlib.util.module_from_spec(helper_spec);helper_spec.loader.exec_module(helper)
api,listing,APP=helper.api,helper.listing,helper.APP

ROOT=Path('artifacts/storefront-export')
manifest=json.loads(Path('marketing/localized-assets/manifest.json').read_text(encoding='utf-8'))['assets']
localizations=json.loads(Path('marketing/store-metadata-verification.json').read_text())['verified_localizations']
placements={'APP_IPHONE_DUO':('duo-inner','duo-outer'),'APP_IPHONE_61':('iphone-medium',)}
failed_reservations={x['id']:x for x in json.loads(Path('marketing/pending-upload-reservations.json').read_text())}

def finish_picture(record,asset):
    data=(ROOT/asset['file']).read_bytes()
    assert hashlib.sha256(data).hexdigest()==asset['sha256'], 'Export integrity mismatch: '+asset['file']
    fresh=api('/v1/appScreenshots/'+record['id']+'?fields[appScreenshots]=fileName,fileSize,sourceFileChecksum,uploadOperations,assetDeliveryState')['data']
    attrs=fresh['attributes']
    if attrs.get('sourceFileChecksum')==asset['md5'] and attrs.get('assetDeliveryState',{}).get('state')=='COMPLETE':return fresh
    operations=record['attributes'].get('uploadOperations') or attrs.get('uploadOperations') or []
    assert operations, 'Apple returned no resumable upload operations for '+asset['file']
    for operation in operations:
        parsed=urllib.parse.urlparse(operation['url']);host=parsed.hostname or ''
        assert parsed.scheme=='https' and any(host==domain or host.endswith('.'+domain) for domain in ['apple.com','icloud-content.com','mzstatic.com','amazonaws.com']), 'Unexpected Apple upload host'
        assert operation['method']=='PUT','Unexpected upload method'
        offset,length=operation['offset'],operation['length'];chunk=data[offset:offset+length]
        assert len(chunk)==length,'Invalid upload range'
        headers={x['name']:x['value'] for x in operation['requestHeaders']}
        # Use only Apple's operation headers; never send the App Store API JWT here.
        req=urllib.request.Request(operation['url'],data=chunk,headers=headers,method='PUT')
        try:
            with urllib.request.urlopen(req,timeout=90) as response:assert 200<=response.status<300
        except urllib.error.HTTPError as error:
            raise RuntimeError('Apple file upload HTTP '+str(error.code)+' at '+host) from None
    api('/v1/appScreenshots/'+record['id'],'PATCH',{'data':{'type':'appScreenshots','id':record['id'],'attributes':{'sourceFileChecksum':asset['md5'],'uploaded':True}}})
    return api('/v1/appScreenshots/'+record['id'])['data']

def locale_upload(localization):
    locale=localization['copy_locale'];result={'locale':localization['locale'],'copy_locale':locale,'sets':[]}
    sets=listing('/v1/appStoreVersionLocalizations/'+localization['version_localization_id']+'/appScreenshotSets?limit=200')
    for display,kinds in placements.items():
        expected=[x for x in manifest if x['locale']==locale and x['placement'] in kinds]
        found=[s for s in sets if s['attributes']['screenshotDisplayType']==display]
        assert len(found)<=1,'Duplicate collections: '+locale
        if found:collection=found[0]
        else:collection=api('/v1/appScreenshotSets','POST',{'data':{'type':'appScreenshotSets','attributes':{'screenshotDisplayType':display},'relationships':{'appStoreVersionLocalization':{'data':{'type':'appStoreVersionLocalizations','id':localization['version_localization_id']}}}}})['data']
        pictures=listing('/v1/appScreenshotSets/'+collection['id']+'/appScreenshots?limit=200')
        expected_hashes={x['md5'] for x in expected}
        for existing in pictures:
            a=existing['attributes'];checksum=a.get('sourceFileChecksum')
            assert checksum in expected_hashes or not checksum, 'Unexpected existing screenshot; preserve it for inspection: '+locale
        saved=[]
        for asset in expected:
            name=locale+'__'+Path(asset['file']).name
            matches=[p for p in pictures if p['attributes'].get('sourceFileChecksum')==asset['md5']]
            assert len(matches)<=1,'Duplicate screenshot checksum: '+locale
            if matches:picture=matches[0]
            else:
                pending=[p for p in pictures if p['attributes'].get('fileName')==name and not p['attributes'].get('sourceFileChecksum')]
                assert len(pending)<=1,'Duplicate pending upload: '+locale
                if pending:
                    picture=pending[0];reservation=failed_reservations.get(picture['id'])
                    if not picture['attributes'].get('uploadOperations') and reservation:
                        assert reservation['locale']==locale and reservation['file_name']==name
                        assert not picture['attributes'].get('sourceFileChecksum')
                        assert picture['attributes'].get('fileSize')==(ROOT/asset['file']).stat().st_size
                        assert (picture['attributes'].get('assetDeliveryState') or {}).get('state')!='COMPLETE'
                        # Remove only this task's known empty failed reservation;
                        # the original art and all delivered screenshots remain.
                        api('/v1/appScreenshots/'+picture['id'],'DELETE')
                        picture=None
                else:picture=None
                if picture is None:
                    size=(ROOT/asset['file']).stat().st_size
                    picture=api('/v1/appScreenshots','POST',{'data':{'type':'appScreenshots','attributes':{'fileName':name,'fileSize':size},'relationships':{'appScreenshotSet':{'data':{'type':'appScreenshotSets','id':collection['id']}}}}})['data']
                    print('Reserved screenshot operation count:',locale,len(picture['attributes'].get('uploadOperations') or []),flush=True)
            finished=finish_picture(picture,asset)
            assert finished['attributes'].get('sourceFileChecksum')==asset['md5'],'Checksum read-back mismatch'
            saved.append({'id':finished['id'],'file':asset['file'],'checksum':asset['md5'],'delivery':finished['attributes'].get('assetDeliveryState')})
        result['sets'].append({'id':collection['id'],'display_type':display,'screenshots':saved})
    print('Uploaded or retained exact screenshots:',locale,flush=True)
    return result

if __name__=='__main__':
    assert api('/v1/apps/'+APP)['data']['attributes']['bundleId']=='com.TapLead.app'
    report={'app_id':APP,'locales':[],'errors':[]}
    selected=os.environ.get('TAPLEAD_ASSET_LOCALE','all')
    assert selected=='all' or any(x['copy_locale']==selected for x in localizations),'Unknown locale selection'
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures={pool.submit(locale_upload,item):item for item in localizations if selected=='all' or item['copy_locale']==selected}
        for future in as_completed(futures):
            locale=futures[future]['copy_locale']
            try:report['locales'].append(future.result())
            except Exception as error:report['errors'].append({'locale':locale,'message':str(error)});print('Needs attention:',locale,str(error),flush=True)
            Path('artifacts/storefront').mkdir(parents=True,exist_ok=True)
            Path('artifacts/storefront/screenshot-upload-report.json').write_text(json.dumps(report,indent=2)+'\n')
    if report['errors']:raise SystemExit('Some screenshots need attention; existing assets were preserved.')
