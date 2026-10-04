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
args = parser.parse_args()
catalog = json.loads(CATALOG.read_text(encoding='utf-8')) if CATALOG.exists() else {'sourceLanguage':'en','strings':{},'version':'1.0'}
pattern = r'(?:Text|Label|Button|Section|Toggle|TextField|SecureField|Picker|DatePicker|ContentUnavailableView|navigationTitle|accessibilityLabel|String\(localized:|title:|copy:|shortTitle:|configurationDisplayName|description)\s*\(?\s*"((?:[^"\\]|\\.)*)"'
keys = set()
for file in (ROOT/'iOS').rglob('*.swift'):
    if 'UITests' in str(file): continue
    for value in re.findall(pattern, file.read_text(encoding='utf-8')):
        if '\\(' not in value:
            keys.add(value.replace('\\n','\n').replace('\\"','"'))
keys.update(['New','Follow Up','Active','Won','Archived','Minimal','Executive','Creator','Bold','Dark','Elegant','Sales','Consultant','About','Contact','Links','email','phone','website','location','portfolio','booking','socials','met','received','voice','status','follow_up_scheduled','follow_up_completed','follow_up_drafted','Friendly','Professional','Concise','Casual'])
for key in keys:
    entry = catalog['strings'].setdefault(key, {'extractionState':'manual','localizations':{}})
    entry['localizations'].setdefault('en', {'stringUnit':{'state':'translated','value':key}})
    for language in LANGUAGES[1:]:
        entry['localizations'].setdefault(language, {'stringUnit':{'state':'new','value':key}})
if args.draft:
    endpoint = os.environ.get('TRANSLATION_GATEWAY_URL','')
    token = os.environ.get('TRANSLATION_GATEWAY_TOKEN','')
    if not endpoint.startswith('https://') or not token: raise SystemExit('Set an approved HTTPS translation gateway and server-side token.')
    pending = [key for key,entry in catalog['strings'].items() if entry['localizations'][args.draft]['stringUnit']['state'] != 'translated']
    request = urllib.request.Request(endpoint, data=json.dumps({'source':'en','target':args.draft,'strings':pending}).encode(), headers={'Content-Type':'application/json','Authorization':'Bearer '+token})
    with urllib.request.urlopen(request,timeout=60) as response: drafts = json.load(response)['translations']
    for key,value in drafts.items():
        if key in pending and isinstance(value,str): catalog['strings'][key]['localizations'][args.draft] = {'stringUnit':{'state':'needs_review','value':value}}
CATALOG.parent.mkdir(parents=True,exist_ok=True)
CATALOG.write_text(json.dumps(catalog,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8')
report = {language:sum(entry['localizations'][language]['stringUnit']['state'] != 'translated' for entry in catalog['strings'].values()) for language in LANGUAGES}
print(json.dumps({'source_strings':len(catalog['strings']),'unreviewed':report},indent=2))
if args.check and any(report.values()): raise SystemExit(1)
