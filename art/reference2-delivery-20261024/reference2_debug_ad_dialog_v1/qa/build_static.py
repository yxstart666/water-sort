from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib,json
P=Path('deliverables/water_sort/reference2_debug_ad_dialog_v1');master=Path('deliverables/water_sort/reference2_replay_settings_buttons_v1/assets/replay_button_blank.png');font=Path('deliverables/water_sort/reference2_sc_font_v1/fonts/NotoSansCJKsc-Bold.otf');bg=Path('deliverables/water_sort/reference2_main_assembly_qa_v1/actual_components_940x1672.png');src=Image.open(master).convert('RGBA');checks=[]
def patch(w,h):
 s=[0,48,src.width-48,src.width];t=[0,48,src.height-48,src.height];a=[0,48,w-48,w];b=[0,48,h-48,h];out=Image.new('RGBA',(w,h))
 for j in range(3):
  for i in range(3):out.paste(src.crop((s[i],t[j],s[i+1],t[j+1])).resize((a[i+1]-a[i],b[j+1]-b[j]),Image.Resampling.LANCZOS),(a[i],b[j]))
 return out
for loc in ['zh','en']:
 z=loc=='zh'
 els=[dict(id='panel',kind='ninepatch',rect=[100,500,740,718],source=str(master),margins_ltrb=[48]*4),dict(id='title',kind='text',rect=[136,550,668,76],text='测试广告' if z else 'Test Ad',font_px=44),dict(id='notice',kind='text',rect=[136,680,668,62],text='仅用于开发测试' if z else 'Development testing only',font_px=33),dict(id='request_type',kind='text',rect=[136,766,668,62],text='{request_label}',font_px=33,binding='localized display label from request type; request id never displayed')]
 for id,x,label,result in [('cancel',144,'不看，退出' if z else 'Cancel','cancelled'),('complete',496,'已看完' if z else 'Completed','completed')]:
  els.append(dict(id=id,kind='button',rect=[x,1010,300,132],hit_rect=[x,1010,300,132],source=str(master),margins_ltrb=[48]*4,text=label,font_px=35,action='resolve_debug_ad_request',result=result,states={'normal':{'brightness':1,'input':True},'focus':{'brightness':1.06,'input':True},'pressed':{'brightness':.88,'input':True},'disabled':{'brightness':.48,'input':False},'resolved':{'brightness':.48,'input':False}}))
 labels={'bonus_bottle':'额外空瓶' if z else 'Extra empty bottle','bonus_slot':'订单位' if z else 'Order slot','energy_refill':'恢复体力' if z else 'Restore energy'}
 cfg=dict(canvas=[940,1672],locale=loc,font_path=str(font),path_base='workspace/package root',elements=els,request_labels=labels,overlay_rgba=[0,5,18,180],qa_sample_request_type='bonus_bottle',gate='debug build AND explicitly enabled mock-ad switch; release hidden, cannot open and cannot emit successful mock result',route_contract='ROUTE_CONTRACT.json',input_contract={'close':'cancelled','escape_or_system_back':'cancelled','outside_tap':'consume without action','double_tap':'one-shot resolution disables both actions immediately'},no_reward='Dialog emits status and captured request_id only to existing authorized business handler; never grant reward in dialog',test_identity='Test Ad and Development testing only always visible. No claim of a real ad having played; Completed is a simulated test outcome.',safe_area='Uniform safe-area adapter; 940 candidate to actual production1080 coordinate system requires owner integration. At360 button50.55dp; never shrink hit area under48dp.',qa_background='Chinese assembly placeholder, not localized/runtime/ad playback evidence')
 (P/'layouts'/f'debug_ad_{loc}.json').write_text(json.dumps(cfg,ensure_ascii=False,indent=2))
 for request_type,request_label in labels.items():
  im=Image.open(bg).convert('RGBA');im.alpha_composite(Image.new('RGBA',im.size,(0,5,18,180)))
  for e in els:
   x,y,w,h=e['rect']
   if e['kind'] in ['button','ninepatch']:im.alpha_composite(patch(w,h),(x,y))
   if 'text' in e:
    txt=e['text'].format(request_label=request_label);f=ImageFont.truetype(str(font),e['font_px']);d=ImageDraw.Draw(im);bb=d.textbbox((0,0),txt,font=f);tw=d.textlength(txt,font=f);th=bb[3]-bb[1];checks.append(dict(locale=loc,request_type=request_type,id=e['id'],fits=tw<=w-16 and th<=h));d.text((x+(w-tw)/2,y+(h-th)/2-bb[1]),txt,font=f,fill='#FFF5DE' if e['id']!='request_type' else '#DCEBFF')
  d=ImageDraw.Draw(im);d.text((470,1610),'STATIC QA / DEBUG TEST DIALOG',font=ImageFont.truetype(str(font),22),anchor='mm',fill='white');im.save(P/'qa'/f'debug_ad_{request_type}_{loc}_940.png');im.resize((360,640),Image.Resampling.LANCZOS).save(P/'qa'/f'debug_ad_{request_type}_{loc}_360.png')
contact=Image.new('RGB',(1080,1280),'#132D50')
for i,f in enumerate(sorted((P/'qa').glob('*_360.png'))):contact.paste(Image.open(f),(i%3*360,i//3*640))
contact.save(P/'qa/contact_sheet.png')
manifest=dict(layout_count=2,qa_count=12,request_variants_per_locale=3,source=str(master),font=str(font),source_sha256=hashlib.sha256(master.read_bytes()).hexdigest(),font_sha256=hashlib.sha256(font.read_bytes()).hexdigest(),checks=checks,all_text_fits=all(c['fits'] for c in checks),button_min_dp_at_360=132*360/940,button_gap_px=52,bottom_outer_clearance_px=76,bottom_clearance_after48px_band=28,new_runtime_png_count=0,static_only=True,runtime_acceptance=None)
(P/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));(P/'RUNTIME_SOURCE_ALLOWLIST.txt').write_text(str(master)+'\n'+str(font)+'\n');assert manifest['all_text_fits'];print('text checks',len(checks),'pass')
