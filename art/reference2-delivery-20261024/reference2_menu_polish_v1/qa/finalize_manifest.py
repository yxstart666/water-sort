from pathlib import Path
from PIL import Image
import json,hashlib
p=Path(__file__).resolve().parents[1]
(p/'assets/logo.png').unlink(missing_ok=True)
for f in (p/'layouts').glob('*.json'):
 d=json.loads(f.read_text())
 for e in d['elements']:
  if f.name.startswith('level_select') and e['kind']=='text':
   t=e['text'];r=e['rect']
   if t.isdigit():e['binding']='levels[pageIndex*20+slotIndex].number';e['sample_only']=True
   elif t.startswith('继续第') or t.startswith('Continue level'):e['binding']='continue_label(actual_resume_level)';e['sample_only']=True
  if e.get('asset')=='assets/tile_locked.png':e['state_binding']='locked'
  elif e.get('asset')=='assets/tile_done.png':e['state_binding']='completed_or_available'
  elif e['kind']=='current_tile':e['state_binding']='current';e['asset']='assets/primary.png';e['margins']=[45]*4
 d['sample_progress_only']=True;d['font']='Use existing NotoSansCJK-Bold SC face from project; no font replacement';d['min_touch_target']='44pt, enlarge invisible hitbox when visual is smaller'
 f.write_text(json.dumps(d,ensure_ascii=False,indent=2))
assets=[]
for f in sorted((p/'assets').glob('*')):
 a={'file':str(f.relative_to(p)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
 if f.suffix=='.png':
  im=Image.open(f);a.update(size=list(im.size),alpha=im.mode=='RGBA')
 assets.append(a)
(p/'manifest.json').write_text(json.dumps({'version':1,'method':'Deterministic code-native component assembly. Existing approved raster assets reused unchanged; UI icons/cards drawn from code. No AI image replacement.','production_code_changed':False,'screens':['home','level_select','graphical_help'],'locales':['zh','en'],'canvas':[940,1672],'qa_size':[360,640],'dependencies':['../reference2_finish_assets_v1/sprites/plus_gold.png'],'assets':assets,'qa_is_runtime_asset':False,'pour_diagram':'Static educational illustration. Rotated original glass layers; horizontal liquid fill independently reconstructed. Not a simulation recording or production animation.'},indent=2))
(p/'READY_ASSETS.txt').write_text('\n'.join(a['file'] for a in assets)+'\n../reference2_finish_assets_v1/sprites/plus_gold.png\n')
(p/'FREEZE.sha256').write_text('\n'.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+str(f.relative_to(p)) for f in sorted(p.rglob('*')) if f.is_file() and f.name!='FREEZE.sha256')+'\n')
