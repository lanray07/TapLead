"""Print only relevant, redacted Xcode export diagnostics on a failed export."""
import os,pathlib,re
root=pathlib.Path(os.environ['TMPDIR'])
count=0
for bundle in root.glob('TapLead_*.xcdistributionlogs'):
    for file in bundle.rglob('*.log'):
        for line in file.read_text(errors='replace').splitlines():
            if not re.search(r'error|failed|app.?group',line,re.I):continue
            line=re.sub(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+','[redacted JWT]',line)
            line=re.sub(r'Bearer\s+\S+','Bearer [redacted]',line,flags=re.I)
            if 'PRIVATE KEY' in line:continue
            print(file.name+': '+line[:2000])
            count+=1
            if count>=80:raise SystemExit(0)
