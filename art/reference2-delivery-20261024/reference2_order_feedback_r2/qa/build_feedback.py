from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np, json, shutil, hashlib
P=Path('deliverables/water_sort/reference2_order_feedback_r2'); R=P.parent
original=Image.open(R/'reference2_order_card_local_repair_v1/assets/order_card_reference2_empty.png').convert('RGBA')
generated=Image.open('generated_images/exec-707169cc-0e2a-4ad2-9761-1ed95d1141c4.png').convert('RGBA').resize(original.size,Image.Resampling.LANCZOS)
# Deterministic production normalization only: imagegen creates white material;
# preserve original approved silhouette alpha and original blue interior pixel-for-pixel.
a=np.array(original); g=np.array(generated); rgb=a[:,:,:3].astype(float)
# Full outer frame region, separated from navy interior by hue. Includes gold tab.
frame=(rgb[:,:,0]>rgb[:,:,2]*1.15)&(rgb[:,:,1]>rgb[:,:,2]*1.1)&(a[:,:,3]>0)
out=a.copy();out[frame,:3]=g[frame,:3];out[:,:,3]=a[:,:,3]
white=Image.fromarray(out);white.save(P/'assets/order_card_pending_white.png')
shutil.copy2(R/'reference2_order_card_local_repair_v1/assets/order_card_reference2_empty.png',P/'assets/order_card_complete_gold.png')
badge_src=Image.open('generated_images/exec-24422431-3fa5-4d43-a67f-0c36f9b9507c.png').convert('RGBA')
# Trim fully transparent imagegen padding; keep 1px final transparent safe inset.
bb=badge_src.getchannel('A').point(lambda v:255 if v>8 else 0).getbbox();badge=Image.new('RGBA',(52,52));badge.alpha_composite(badge_src.crop(bb).resize((50,50),Image.Resampling.LANCZOS),(1,1));badge.save(P/'assets/order_complete_badge_52.png')
shutil.copy2('generated_images/exec-707169cc-0e2a-4ad2-9761-1ed95d1141c4.png',P/'source/imagegen_white_frame.png')
shutil.copy2('generated_images/exec-24422431-3fa5-4d43-a67f-0c36f9b9507c.png',P/'source/imagegen_badge.png')
fontpath='cloud_takeover/water_sort_project/assets/ui_restore/gameplay_state_binding_v1/fonts/NotoSansCJK-Bold.ttc'
def font(s):return ImageFont.truetype(fontpath,s)
def card(t,color='red',sz=52):
 c=Image.blend(white,original,t) if t<1 else original.copy()
 bottle=Image.open(R/f'reference2_order_bottle_states_v1/assets/order_{color}_cork.png').convert('RGBA');c.alpha_composite(bottle,(44,41))
 if sz:
  b=badge.resize((sz,sz),Image.Resampling.LANCZOS);c.alpha_composite(b,(128-sz//2,34-sz//2))
 return c
# Static transition uses existing two frame textures crossfaded, not extra raster painting.
states=[('pending',0,0,0),('frame_to_gold',.55,0,90),('badge_pop',1,56,180),('complete',1,52,260)]
for name,t,sz,ms in states:card(t,sz=sz).save(P/f'qa/keyframe_{ms:03}_{name}.png')
board=Image.new('RGB',(850,330),'#13284A');d=ImageDraw.Draw(board)
for i,(name,t,sz,ms) in enumerate(states):
 x=25+i*208;board.paste(card(t,sz=sz),(x,55),card(t,sz=sz));d.text((x,16),['未完成','白框转金','大勾弹出','完成停留'][i],font=font(20),fill='white');d.text((x,273),f'{ms} ms',font=font(17),fill='#C7DDF4')
board.save(P/'qa/transition_keyframes.png')
# All eight existing bottle colors remain exactly the same asset in both states.
board=Image.new('RGB',(8*173+16,470),'#14294A');d=ImageDraw.Draw(board)
for i,col in enumerate(['red','blue','green','yellow','purple','orange','pink','cyan']):
 for j,t in enumerate([0,1]):
  c=card(t,col,52 if t else 0);board.paste(c,(16+i*173,20+j*228),c)
board.save(P/'qa/eight_colors_pending_complete.png')
# Recompose only existing order card regions against clean background, preserve everything else.
base=Image.open(R/'reference2_main_assembly_qa_v1/actual_components_940x1672.png').convert('RGBA');bg=Image.open(R/'reference2_background_cleanplate_v1/assets/background_native_940x1672.png').convert('RGBA')
new=base.copy()
for x,color,t in [(148,'red',0),(312,'blue',1),(476,'green',0)]:
 new.paste(bg.crop((x,216,x+157,420)),(x,216));new.alpha_composite(card(t,color,52 if t else 0),(x,216))
new.save(P/'qa/main_mixed_states_940x1672.png');new.resize((360,640),Image.Resampling.LANCZOS).save(P/'qa/main_mixed_states_360x640.png')
for w,h in [(940,1672),(360,640)]:
 left=base.resize((w,h),Image.Resampling.LANCZOS);right=new.resize((w,h),Image.Resampling.LANCZOS);b=Image.new('RGB',(w*2,h+46),'#13284A');b.paste(left,(0,46));b.paste(right,(w,46));dd=ImageDraw.Draw(b);dd.text((14,10),'旧版：小圈 / Old',font=font(19),fill='white');dd.text((w+14,10),'新版：白框未完成，金框＋大勾完成',font=font(19),fill='white');b.save(P/f'qa/same_position_comparison_{w}.png')
# Explicit alpha support test, not merely rectangle intersection.
bottle=Image.open(R/'reference2_order_bottle_states_v1/assets/order_red_cork.png').convert('RGBA');ba=np.zeros((204,157),dtype='uint8');ba[41:178,44:114]=np.array(bottle.getchannel('A'))
checks={}
for sz in [52,56]:
 ca=np.zeros_like(ba);b=np.array(badge.resize((sz,sz),Image.Resampling.LANCZOS).getchannel('A'));x=128-sz//2;y=34-sz//2;ca[y:y+sz,x:x+sz]=b;checks[str(sz)]={'position':[x,y],'alpha_overlap_pixels_gt_8':int(((ba>8)&(ca>8)).sum()),'rect_inside_card':x>=0 and y>=0 and x+sz<=157 and y+sz<=204}
report={'native_card':[157,204],'original_alpha_identical':bool(np.array_equal(a[:,:,3],out[:,:,3])),'blue_interior_pixels_identical':bool(np.array_equal(a[~frame],out[~frame])),'original_gold_file_sha256':hashlib.sha256((P/'assets/order_card_complete_gold.png').read_bytes()).hexdigest(),'badge_checks':checks,'runtime_integrated':False,'text_baked_in_runtime_assets':False}
(P/'qa/VALIDATION.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
