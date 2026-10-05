"""Extract source UI strings, detect gaps, and request explicitly reviewed gateway drafts.
Never submits user content. No credentials are written into application resources.
"""
import argparse, json, os, pathlib, re, urllib.request
ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'iOS/TapLead/Resources/Localizable.xcstrings'
LANGUAGES = ['en','es','fr','de','it','pt','nl','ja','ko','zh-Hans']
parser = argparse.ArgumentParser()
parser.add_argument('--draft', choices=LANGUAGES[1:])
parser.add_argument('--check', action='store_true')
parser.add_argument('--prepare', action='store_true', help='Prepare indexed public UI copy for translation')
parser.add_argument('--import-dir', type=pathlib.Path, help='Import indexed translations captured from the translation UI')
args = parser.parse_args()
catalog = json.loads(CATALOG.read_text(encoding='utf-8')) if CATALOG.exists() else {'sourceLanguage':'en','strings':{},'version':'1.0'}
pattern = r'(?:Text|Label|Button|Section|Toggle|TextField|SecureField|Picker|DatePicker|ContentUnavailableView|navigationTitle|accessibilityLabel|alert|confirmationDialog|String\(localized:|title:|copy:|shortTitle:|configurationDisplayName|description|prompt:|policyLink|urlField)\s*\(?\s*"((?:[^"\\]|\\.)*)"'
keys = set()
for file in (ROOT/'iOS').rglob('*.swift'):
    if 'UITests' in str(file): continue
    for value in re.findall(pattern, file.read_text(encoding='utf-8')):
        if '\\(' not in value:
            keys.add(value.replace('\\n','\n').replace('\\"','"'))
keys.update(['New','Follow Up','Active','Won','Archived','Minimal','Executive','Creator','Bold','Dark','Elegant','Sales','Consultant','About','Contact','Links','email','phone','website','location','portfolio','booking','socials','met','received','voice','status','follow_up_scheduled','follow_up_completed','follow_up_drafted','Friendly','Professional','Concise','Casual','None','Photo','Logo','Top left','Top right','Bottom left','Bottom right','Choose photo','Photo added','Logo added','Loading image…'])
keys.update(['Standard','Rounded','Serif','Monospaced','Networking','Recruiting','Event','Save contact','Website','Portfolio','Book a meeting','View CV','Connection made','Details received','Voice note added','Status changed','Follow-up scheduled','Follow-up completed','Draft saved','Smart Notes saved','Context','Interest','Next action','Follow-up date'])
keys.update(['Multiple card personas','Up to 20 published cards','Up to 10,000 synced leads','Advanced themes and card customisation','Voice notes with reviewed transcription','Branded QR, photo and printable exports','Measured activity insights','Optional on-device AI on eligible iOS 26 devices'])
keys.update(['Published','On this iPhone','Update published card','Publish my card','Start voice note','Stop recording','Privacy policy','Terms of use','Search names, notes or tags','Open my TapLead card','Show my networking QR','Show today’s follow-ups','Add a TapLead note','Date','Requests','Transcribe the voice notes you choose to record.','Record a voice note after a conversation.','Write your published TapLead link to an NFC card.'])
# Remove retired keys rather than carrying old email flows or corrupt punctuation into translations.
retired = {'Account registration could not be completed.','Check your email to verify your account, then sign in.','Create a new account','Create account','Forgot password?','If this account exists, a recovery email will arrive shortly.','Password (at least 12 characters)','Your account keeps published cards and connections in sync. Verify your email before signing in.','Photos and logos currently stay on this iPhone. Public image uploads require the configured storage service.','Show one logo or photo in your chosen corner. Images are saved on this iPhone.','The selected notes and contact name are sent to your configured AI service only when you choose an action. Check its privacy terms first.'}
def clean(value):
    for old,new in [('â€™','’'),('â€˜','‘'),('â€¦','…'),('â€“','–'),('â€”','—'),('Â·','·')]:
        value=value.replace(old,new)
    return value
keys={clean(key) for key in keys if key not in retired and key}
catalog['strings']={clean(key):entry for key,entry in catalog['strings'].items() if key not in retired and key}
for key in keys:
    entry = catalog['strings'].setdefault(key, {'extractionState':'manual','localizations':{}})
    entry['localizations'].setdefault('en', {'stringUnit':{'state':'translated','value':key}})
    for language in LANGUAGES[1:]:
        entry['localizations'].setdefault(language, {'stringUnit':{'state':'new','value':key}})
for key,entry in catalog['strings'].items():
    entry['comment']='Public UI copy. Non-English translations are machine-assisted with agent corrections; human language review is pending. See docs/LOCALISATION.md.'
    entry['localizations']['en']={'stringUnit':{'state':'translated','value':key}}
if args.prepare:
    directory=ROOT/'artifacts/localization'
    directory.mkdir(parents=True,exist_ok=True)
    ordered=sorted(catalog['strings'])
    batches=[]
    batch=[]
    for index,key in enumerate(ordered):
        line=f'[{index:04d}] {key}'
        if len('\n\n'.join(batch+[line]))>4500:
            batches.append('\n\n'.join(batch));batch=[]
        batch.append(line)
    if batch:batches.append('\n\n'.join(batch))
    (directory/'source.json').write_text(json.dumps({'keys':ordered,'batches':batches},ensure_ascii=False,indent=2),encoding='utf-8')
if args.import_dir:
    source=json.loads((args.import_dir/'source.json').read_text(encoding='utf-8'))
    if source['keys']!=sorted(catalog['strings']):raise SystemExit('Source keys changed during translation; prepare again.')
    for language in LANGUAGES[1:]:
        chunks=json.loads((args.import_dir/f'{language}.json').read_text(encoding='utf-8'))
        translated={}
        for chunk in chunks:
            matches=list(re.finditer(r'\[(\d{4})\]\s*',chunk))
            for position,match in enumerate(matches):
                index=int(match.group(1))
                value=chunk[match.end():matches[position+1].start() if position+1<len(matches) else len(chunk)].strip()
                if index in translated or not value:raise SystemExit(f'Invalid/duplicate translation: {language}/{index}')
                translated[index]=value
        if set(translated)!=set(range(len(source['keys']))):raise SystemExit(f'Incomplete translation: {language}')
        for index,key in enumerate(source['keys']):
            catalog['strings'][key]['localizations'][language]={'stringUnit':{'state':'translated','value':translated[index]}}
if args.draft:
    endpoint = os.environ.get('TRANSLATION_GATEWAY_URL','')
    token = os.environ.get('TRANSLATION_GATEWAY_TOKEN','')
    if not endpoint.startswith('https://') or not token: raise SystemExit('Set an approved HTTPS translation gateway and server-side token.')
    pending = [key for key,entry in catalog['strings'].items() if entry['localizations'][args.draft]['stringUnit']['state'] != 'translated']
    request = urllib.request.Request(endpoint, data=json.dumps({'source':'en','target':args.draft,'strings':pending}).encode(), headers={'Content-Type':'application/json','Authorization':'Bearer '+token})
    with urllib.request.urlopen(request,timeout=60) as response: drafts = json.load(response)['translations']
    for key,value in drafts.items():
        if key in pending and isinstance(value,str): catalog['strings'][key]['localizations'][args.draft] = {'stringUnit':{'state':'needs_review','value':value}}
overrides=json.loads((ROOT/'scripts/localization-overrides.json').read_text(encoding='utf-8'))
for key,entry in catalog['strings'].items():
    for language in LANGUAGES[1:]:
        unit=entry['localizations'][language]['stringUnit']
        if language not in {'ja','zh-Hans'}:
            unit['value']=re.sub(r'([.;!?])(?=[A-ZÀ-Ü가-힣])',r'\1 ',unit['value'])
            unit['value']=re.sub(r';(?=[a-zà-ÿ])','; ',unit['value'])
        unit['value']=unit['value'].replace('\u200b','').replace('\u200c','')
        if language in overrides.get(key,{}):
            unit.update(state='translated',value=overrides[key][language])
CATALOG.parent.mkdir(parents=True,exist_ok=True)
permissions={'NSSpeechRecognitionUsageDescription':'Transcribe the voice notes you choose to record.','NSMicrophoneUsageDescription':'Record a voice note after a conversation.','NFCReaderUsageDescription':'Write your published TapLead link to an NFC card.'}
permission_files={ROOT/f'iOS/TapLead/Resources/{language}.lproj/InfoPlist.strings':''.join(f'{json.dumps(name)} = {json.dumps(catalog["strings"][key]["localizations"][language]["stringUnit"]["value"],ensure_ascii=False)};\n' for name,key in permissions.items()) for language in LANGUAGES}
shortcuts=json.loads((ROOT/'scripts/shortcut-translations.json').read_text(encoding='utf-8'))
for language in LANGUAGES:
    if len(shortcuts[language])!=4 or any(value.count('${applicationName}')!=1 for value in shortcuts[language]):raise SystemExit(f'Invalid shortcut placeholders: {language}')
shortcut_files={ROOT/f'iOS/TapLead/Resources/{language}.lproj/AppShortcuts.strings':'/* Agent-authored phrases; human language and Siri device review pending. */\n'+''.join(f'{json.dumps(key)} = {json.dumps(value,ensure_ascii=False)};\n' for key,value in zip(shortcuts['en'],shortcuts[language])) for language in LANGUAGES}
permission_files.update(shortcut_files)
if not args.check:
    for target in [CATALOG,ROOT/'iOS/Widget/Resources/Localizable.xcstrings']:
        target.write_text(json.dumps(catalog,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    for target,value in permission_files.items():
        target.parent.mkdir(parents=True,exist_ok=True);target.write_text(value,encoding='utf-8')
report = {language:sum(entry['localizations'][language]['stringUnit']['state'] != 'translated' for entry in catalog['strings'].values()) for language in LANGUAGES}
print(json.dumps({'source_strings':len(catalog['strings']),'missing_translations':report},indent=2))
errors=[]
for key,entry in catalog['strings'].items():
    for language in LANGUAGES:
        value=entry['localizations'][language]['stringUnit']['value']
        if not value.strip() or clean(value)!=value or '\ufffd' in value:errors.append(f'{language}: invalid text for {key}')
        if sorted(re.findall(r'%(?:\d+\$)?(?:lld|ld|@|d|f|s)',key))!=sorted(re.findall(r'%(?:\d+\$)?(?:lld|ld|@|d|f|s)',value)):errors.append(f'{language}: placeholder mismatch for {key}')
if args.check:
    widget=json.loads((ROOT/'iOS/Widget/Resources/Localizable.xcstrings').read_text(encoding='utf-8'))
    if widget!=catalog:errors.append('App/widget catalogs differ')
    for target,value in permission_files.items():
        if not target.exists() or target.read_text(encoding='utf-8')!=value:errors.append(f'Permission resource differs: {target.name}/{target.parent.name}')
    if any(report.values()) or errors:
        print('\n'.join(errors));raise SystemExit(1)
