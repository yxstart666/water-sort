from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parent
m=json.loads((root/'DELIVERY_MANIFEST.json').read_text(encoding='utf-8'))
font=next(x for x in m['files'] if x['path'].endswith('.otf'))
target=root/font['path']
chunks=[]
for p in m['font_parts']:
    b=(root/p['path']).read_bytes()
    if len(b)!=p['bytes'] or hashlib.sha256(b).hexdigest()!=p['sha256']: raise SystemExit('Invalid font part: '+p['path'])
    chunks.append(b)
b=b''.join(chunks)
if len(b)!=font['bytes'] or hashlib.sha256(b).hexdigest()!=font['sha256']: raise SystemExit('Invalid reconstructed font')
if target.exists() and target.read_bytes()!=b: raise SystemExit('Refusing to overwrite different existing font')
if not target.exists(): target.write_bytes(b)
for p in m['files']:
    b=(root/p['path']).read_bytes()
    if len(b)!=p['bytes'] or hashlib.sha256(b).hexdigest()!=p['sha256']: raise SystemExit('Invalid file: '+p['path'])
print('PASS: font restored and '+str(len(m['files']))+' files verified. Runtime template root: '+str(root/'reference2_runtime_layouts_v1/layouts'))
