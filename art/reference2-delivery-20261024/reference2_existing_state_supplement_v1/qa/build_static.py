from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageEnhance
import json,hashlib
P=Path('deliverables/water_sort/reference2_existing_state_supplement_v1')
master=Path('deliverables/water_sort/reference2_replay_settings_buttons_v1/assets/replay_button_blank.png');font=Path('deliverables/water_sort/reference2_sc_font_v1/fonts/NotoSansCJKsc-Bold.otf');bg=Path('deliverables/water_sort/reference2_main_assembly_qa_v1/actual_components_940x1672.png');src=Image.open(master).convert('RGBA');checks=[]
def patch(w,h):
 s=[0,48,src.width-48,src.width];t=[0,48,src.height-48,src.height];a=[0,48,w-48,w];b=[0,48,h-48,h];out=Image.new('RGBA',(w,h))
 for j in range(3):
  for i in range(3):out.paste(src.crop((s[i],t[j],s[i+1],t[j+1])).resize((a[i+1]-a[i],b[j+1]-b[j]),Image.Resampling.LANCZOS),(a[i],b[j]))
 return out
states={'normal':{'brightness':1,'input':True},'focus':{'brightness':1.06,'input':True},'pressed':{'brightness':.88,'input':True},'disabled':{'brightness':.48,'input':False},'processing':{'brightness':.48,'input':False}}
for loc in ['zh','en']:
 z=loc=='zh'
 specs={
 'mask_intro':('隐藏颜色' if z else 'Hidden colors',['下层部分颜色暂时隐藏。','顶部颜色仍可按规则倾倒。','隐藏颜色不等于整瓶锁定。'] if z else ['Some lower colors are hidden.','Top colors can still be poured','according to the normal rules.','Hidden colors do not lock a bottle.'],'开始' if z else 'Start','existing_mask_intro_Start_resume'),
 'bonus_bottle':('增加空瓶' if z else 'Add empty bottle',['本局可免费试用一次辅助空瓶。','确认后增加一个空瓶。','与增加订单位的试用次数独立。'] if z else ['Try one extra empty bottle this game.','This local trial is free.','Separate from the extra order slot.'],'增加空瓶' if z else 'Add bottle','existing_bonus_bottle_local_trial_confirm'),
 'bonus_slot':('增加订单位' if z else 'Add order slot',['本局可免费试用一次额外订单位。','确认后启用第四个订单位。','与增加空瓶的试用次数独立。'] if z else ['Try an extra order slot this game.','Enable the fourth order slot for free.','Separate from the extra empty bottle.'],'增加订单位' if z else 'Add order slot','existing_bonus_slot_local_trial_confirm')}
 for name,(title,lines,label,action) in specs.items():
  els=[dict(id='panel',kind='ninepatch',rect=[100,470,740,778],source=str(master),margins_ltrb=[48]*4),dict(id='title',kind='text',rect=[132,520,676,76],text=title,font_px=44,color='#FFF5DE')]
  for i,line in enumerate(lines):els.append(dict(id='body_'+str(i),kind='text',rect=[136,650+i*70,668,60],text=line,font_px=32,color='#DCEBFF'))
  button_defs=[('start',310,320,label,action)] if name=='mask_intro' else [('cancel',144,300,'取消' if z else 'Cancel','existing_local_trial_cancel_no_reward'),('confirm',496,300,label,action)]
  for id,x,w,label,act in button_defs:els.append(dict(id=id,kind='button',rect=[x,1034,w,132],hit_rect=[x,1034,w,132],source=str(master),margins_ltrb=[48]*4,text=label,font_px=35,color='#FFF5DE',action=act,states=states,state='normal'))
  cfg=dict(canvas=[940,1672],production_coordinate_adapter='orders_v3 is 1080x1920; transform root uniformly and reconcile actual safe area and existing control slots. This 940x1672 candidate is not a production scene.',locale=loc,elements=els,font_path=str(font),path_base='workspace/package root',overlay_rgba=[0,5,18,180],status='existing production state static supplement, not engine acceptance',source_evidence='deliverables/water_sort/reference2_production_state_binding_v1/LOCAL_SOURCE_EVIDENCE.txt',underlay='block pointer input; do not mutate board or clocks merely for display',qa_background=str(bg),qa_note='Chinese component assembly placeholder, not a production screenshot of this level or a localized runtime capture')
  if name=='mask_intro':cfg.update(entry='Only first load_level(2) in this instance when mask_intro_seen false; not persistent tutorial preference',exit='Existing Start handler resumes; retain existing input and pause semantics, do not add Cancel/Home or an auto tutorial chain',mask_visual_binding={'target':'actual lower concealed liquid layers only','source':'existing mask/visibility model and configured hidden threshold','threshold':'read actual configuration; no invented number, extra rule, fixed layer count or whole-bottle overlay','top':'respect existing visible/pourable top; mask is not a lock','restore':'follow actual reveal/undo model'},unverified='Lower-layer mask visual texture is not provided or invented here; layout explains actual existing mask. Use production concealment rendering and verified visibility model.')
  else:cfg.update(entry='Level 2 onward, eligible current attempt, own trial not yet claimed, presentation not busy; bonus bottle may also enter through existing stuck rescue' if name=='bonus_bottle' else 'Level 2 onward, fourth-order-slot plus entry, own slot trial not yet claimed, presentation not busy',exit='Existing local_trial confirm or cancel only; no video, ad SDK, reward page, energy debit or new account flow',eligibility='Revalidate own type, attempt/request identity, not busy and not already claimed before committing. Never share bottle and slot claimed flags.',commit='Existing bottle trial adds empty helper bottle once; retain on undo per existing model.' if name=='bonus_bottle' else 'Existing slot trial enables fourth order slot once; may trigger existing waiting finished bottle receipt queue, never synthesize duplicate completion.',reward_provider='local_trial only; unavailable ad flow has no entry',cancel_failed_stale='No reward on cancellation, failure, duplicate or stale request. Preserve existing dismissal/status behavior; no invented error modal or retry/reward button.',double_tap='Use existing one-shot guard; while committing both buttons processing/disabled. Never treat visual state as entitlement.')
  (P/'layouts'/f'{name}_{loc}.json').write_text(json.dumps(cfg,ensure_ascii=False,indent=2))
  im=Image.open(bg).convert('RGBA');im.alpha_composite(Image.new('RGBA',im.size,(0,5,18,180)))
  for e in els:
   x,y,w,h=e['rect']
   if e['kind'] in ['button','ninepatch']:im.alpha_composite(patch(w,h),(x,y))
   if 'text' in e:
    f=ImageFont.truetype(str(font),e['font_px']);d=ImageDraw.Draw(im);bb=d.textbbox((0,0),e['text'],font=f);tw=d.textlength(e['text'],font=f);th=bb[3]-bb[1];checks.append(dict(layout=name+'_'+loc,id=e['id'],fits=tw<=w-16 and th<=h,width=tw,available=w-16));d.text((x+(w-tw)/2,y+(h-th)/2-bb[1]),e['text'],font=f,fill=e['color'])
  d=ImageDraw.Draw(im);d.text((470,1585),'STATIC QA / EXISTING STATE',font=ImageFont.truetype(str(font),23),anchor='mm',fill='white');d.text((470,1620),'Chinese backdrop is a layout placeholder only',font=ImageFont.truetype(str(font),20),anchor='mm',fill='white');im.save(P/'qa'/f'{name}_{loc}_940.png');im.resize((360,640),Image.Resampling.LANCZOS).save(P/'qa'/f'{name}_{loc}_360.png')
contact=Image.new('RGB',(1080,1280),'#132D50')
for i,f in enumerate(sorted((P/'qa').glob('*_360.png'))):contact.paste(Image.open(f),(i%3*360,i//3*640))
contact.save(P/'qa/contact_sheet.png')
manifest=dict(layout_count=6,source=str(master),font=str(font),source_sha256=hashlib.sha256(master.read_bytes()).hexdigest(),font_sha256=hashlib.sha256(font.read_bytes()).hexdigest(),text_checks=checks,all_text_fits=all(c['fits'] for c in checks),new_runtime_png_count=0,button_min_dp_at360=132*360/940,bottom_outer_clearance_px=82,bottom_clearance_after48px_band=34,not_new_features=True,real_engine_acceptance=None)
(P/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));(P/'RUNTIME_SOURCE_ALLOWLIST.txt').write_text(str(master)+'\n'+str(font)+'\n');assert manifest['all_text_fits'],[c for c in checks if not c['fits']];print('text checks',len(checks),'all pass')
