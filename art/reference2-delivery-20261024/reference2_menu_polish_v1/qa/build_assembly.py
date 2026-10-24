from PIL import Image,ImageDraw,ImageFont,ImageFilter
from pathlib import Path
import numpy as np,json,shutil,hashlib
P=Path(__file__).resolve().parents[1];R=P.parent; A=P/'assets'; Q=P/'qa';L=P/'layouts'
F=Path('cloud_takeover/water_sort_project/assets/ui_restore/gameplay_state_binding_v1/fonts')
for name,src in {'background':'reference2_background_cleanplate_v1/assets/background_native_940x1672.png','primary':'reference2_replay_settings_buttons_v1/assets/replay_button_blank.png','settings':'reference2_replay_settings_buttons_v1/assets/settings_icon_original.png','settings_base':'reference2_replay_settings_buttons_v1/assets/settings_button_blank.png','energy':'reference2_energy_component_v1/assets/energy_pill_base.png','bolt':'reference2_energy_component_v1/assets/energy_bolt.png','cork':'reference2_main_cork_completion_v1/assets/main_bottle_cork.png','glass_back':'reference2_original_bottle_layers_v1/assets/glass_back_shadow.png','glass_front':'reference2_original_bottle_layers_v1/assets/glass_front_reflection.png','cavity':'reference2_original_bottle_layers_v1/assets/pour_cavity_mask.png','order_frame':'reference2_order_card_local_repair_v1/assets/order_card_reference2_empty.png','order_blue':'reference2_order_bottle_states_v1/assets/order_blue_cork.png'}.items(): shutil.copyfile(R/src,A/(name+'.png'))
checks=[]; els=[]; im=None

def font(n):return ImageFont.truetype(str(F/'NotoSansCJK-Bold.ttc'),n)
def tx(s,r,n=36,c='#fff3d7',align='center',binding=None):
 x,y,w,h=r;d=ImageDraw.Draw(im);f=font(n);b=d.textbbox((0,0),s,font=f);tw=d.textlength(s,font=f);th=b[3]-b[1];px=x+(w-tw)/2 if align=='center' else x
 d.text((px,y+(h-th)/2-b[1]),s,font=f,fill=c);checks.append({'text':s,'fits':tw<=w and th<=h});els.append(dict(kind='text',text=s,rect=r,font_size=n,color=c,align=align,binding=binding))
def pic(name,r):
 x,y,w,h=r;a=Image.open(A/(name+'.png')).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS);im.alpha_composite(a,(x,y));els.append(dict(kind='image',asset='assets/'+name+'.png',rect=r))
def nine(name,size,m=45):
 src=Image.open(A/(name+'.png')).convert('RGBA');w,h=size;out=Image.new('RGBA',size);sx=[0,m,src.width-m,src.width];sy=[0,m,src.height-m,src.height];dx=[0,m,w-m,w];dy=[0,m,h-m,h]
 for j in range(3):
  for i in range(3):out.paste(src.crop((sx[i],sy[j],sx[i+1],sy[j+1])).resize((dx[i+1]-dx[i],dy[j+1]-dy[j])),(dx[i],dy[j]))
 return out

def panel(name,w,h,stroke='#3768ad',filltop=(16,53,108),fillbot=(5,22,55),radius=28):
 a=Image.new('RGBA',(w,h));mask=Image.new('L',(w,h));d=ImageDraw.Draw(mask);d.rounded_rectangle((1,1,w-2,h-2),radius,fill=255)
 arr=np.zeros((h,w,4),dtype=np.uint8)
 for y in range(h):arr[y,:,:3]=np.array(filltop)*(1-y/h)+np.array(fillbot)*(y/h)
 arr[:,:,3]=np.array(mask);a=Image.fromarray(arr);d=ImageDraw.Draw(a);d.rounded_rectangle((2,2,w-3,h-3),radius,outline=stroke,width=3);d.line((radius+8,8,w-radius-8,8),fill='#345886',width=1);a.save(A/(name+'.png'))

# Native vector icons, also supplied as transparent PNGs. No generative replacement art.
paths={'check':'M 18 49 L 39 69 L 79 27','lock':'M 29 42 V 30 C 29 5 67 5 67 30 V 42 M 23 42 H 73 V 82 H 23 Z','arrow':'M 18 48 H 76 M 57 29 L 77 48 L 57 67','back':'M 61 23 L 34 48 L 61 73','grid':'M 20 20 H 39 V 39 H 20 Z M 57 20 H 76 V 39 H 57 Z M 20 57 H 39 V 76 H 20 Z M 57 57 H 76 V 76 H 57 Z','records':'M 25 70 V 50 M 48 70 V 30 M 71 70 V 17 M 17 81 H 80','tap':'M 45 58 V 23 C 45 12 59 12 59 23 V 47 L 70 45 L 82 53 L 77 80 H 45 L 25 58 C 22 49 32 45 38 51 Z'}
for name,path in paths.items():
 color='#76efc3' if name=='check' else '#fff1cf'
 (A/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96"><path d="{path}" stroke="{color}" stroke-width="7" fill="none" stroke-linejoin="round" stroke-linecap="round"/></svg>')
 a=Image.new('RGBA',(192,192));d=ImageDraw.Draw(a);col=color;sc=lambda ps:[(x*2,y*2) for x,y in ps]
 if name=='check':d.line(sc([(18,49),(39,69),(79,27)]),fill=col,width=14,joint='curve')
 elif name=='lock':d.arc((58,16,134,110),180,360,fill=col,width=12);d.rounded_rectangle((46,80,146,164),8,outline=col,width=12)
 elif name=='arrow':d.line(sc([(18,48),(76,48)]),fill=col,width=12);d.line(sc([(57,29),(77,48),(57,67)]),fill=col,width=12)
 elif name=='back':d.line(sc([(61,23),(34,48),(61,73)]),fill=col,width=12)
 elif name=='grid':
  for x,y in [(20,20),(57,20),(20,57),(57,57)]:d.rounded_rectangle((x*2,y*2,(x+19)*2,(y+19)*2),4,fill=col)
 elif name=='records':
  for x,y in [(25,50),(48,30),(71,17)]:d.line(sc([(x,y),(x,70)]),fill=col,width=14)
  d.line(sc([(17,81),(80,81)]),fill=col,width=10)
 else:
  d.line(sc([(45,58),(45,23),(48,17),(55,17),(59,23),(59,47),(70,45),(82,53),(77,80),(45,80),(25,58),(25,52),(31,49),(38,51),(45,58)]),fill=col,width=10,joint='curve')
 a.resize((96,96),Image.Resampling.LANCZOS).save(A/(name+'.png'))

C=json.loads((R/'reference2_original_bottle_layers_v1/BOTTLE_CONTRACT.json').read_text());mask=np.asarray(Image.open(A/'cavity.png').getchannel('A')); yy,xx=np.indices(mask.shape)
def bottle(name,colors):
 arr=np.zeros((410,165,4),dtype=np.uint8);shade=.86+.14*np.sin(np.clip((xx-16)/133,0,1)*np.pi)
 for j,c in enumerate(colors):
  reg=(yy>=382-(j+1)*68.25)&(yy<=382-j*68.25);rgb=np.array(tuple(bytes.fromhex(C['palette'][c])));arr[reg,:3]=(shade[:,:,None]*rgb)[reg].astype('uint8');arr[reg,3]=mask[reg]
 if colors:
  cy=382-len(colors)*68.25;ellipse=((xx-82.5)/66)**2+((yy-cy)/3)**2<=1;rgb=np.array(tuple(bytes.fromhex(C['palette'][colors[-1]])))*.92+255*.08;arr[ellipse,:3]=(shade[:,:,None]*rgb)[ellipse].astype('uint8');arr[ellipse,3]=mask[ellipse]
 a=Image.open(A/'glass_back.png').convert('RGBA');a.alpha_composite(Image.fromarray(arr));a.alpha_composite(Image.open(A/'glass_front.png'));a.save(A/(name+'.png'))
for n,cs in [('mixed',['blue','green','yellow','red']),('warm',['orange','purple','yellow']),('blue',['blue']*4),('empty',[]),('blue_low',['blue']*2),('red_low',['red'])]:bottle(n,cs)
# Demonstration pose uses rotated original glass with gravity-horizontal liquid, not rotated baked liquid.
angle=-70;back=Image.open(A/'glass_back.png').convert('RGBA').rotate(angle,Image.Resampling.BICUBIC,expand=True);front=Image.open(A/'glass_front.png').convert('RGBA').rotate(angle,Image.Resampling.BICUBIC,expand=True);rm=Image.open(A/'cavity.png').getchannel('A').rotate(angle,Image.Resampling.BICUBIC,expand=True);ma=np.array(rm);ar=np.zeros((back.height,back.width,4),dtype=np.uint8);mass=ma.sum(axis=1);cum=np.cumsum(mass[::-1])[::-1];total=mass.sum();shade=np.linspace(.9,1,back.width)[None,:,None]
for frac0,frac1,color in [(0,.48,'blue'),(.48,.91,'red')]:
 reg=(cum[:,None]/total>frac0)&(cum[:,None]/total<=frac1)&(ma>0);rgb=np.array(tuple(bytes.fromhex(C['palette'][color])));ar[reg,:3]=np.broadcast_to(rgb,(back.height,back.width,3))[reg];ar[reg,3]=ma[reg]
back.alpha_composite(Image.fromarray(ar));back.alpha_composite(front)
diag=Image.new('RGBA',(860,364));src=back.resize((370,260),Image.Resampling.LANCZOS);diag.alpha_composite(src,(30,0));dst=Image.open(A/'red_low.png').resize((115,255),Image.Resampling.LANCZOS);diag.alpha_composite(dst,(550,95))
# Native vector curve conveys red flow into red top. This is an instructional static diagram.
d=ImageDraw.Draw(diag);pts=[]
for t in np.linspace(0,1,80):
 x=(1-t)**3*362+3*(1-t)**2*t*490+3*(1-t)*t*t*607+t**3*607;y=(1-t)**3*75+3*(1-t)**2*t*75+3*(1-t)*t*t*80+t**3*108;pts.append((x,y))
pts.append((607,300));d.line(pts,fill='#ff3043',width=15,joint='curve');d.line([(x-2,y-2) for x,y in pts],fill='#ff8b95',width=4,joint='curve');diag.save(A/'pour_diagram.png')
panel('secondary',340,120);panel('tile_done',174,174);panel('tile_locked',174,174,'#253e6b',(9,29,63),(5,18,44));panel('help_card',804,320,'#244c85',(10,37,80),(6,23,53),32)


def begin():
 global im,els
 im=Image.open(A/'background.png').convert('RGBA');els=[]
def hud(back=False):
 pic('energy',[50,58,218,75]);pic('bolt',[57,62,44,64]);tx('30/30',[104,72,115,44],32,binding='energy.current/max');plus=Image.open(R/'reference2_finish_assets_v1/sprites/plus_gold.png').convert('RGBA');im.alpha_composite(plus.resize((30,30),Image.Resampling.LANCZOS),(226,77));els.append(dict(kind='image',asset='../reference2_finish_assets_v1/sprites/plus_gold.png',rect=[226,77,30,30],action='open_energy'))
 if back:pic('secondary',[798,54,94,94]);pic('back',[808,64,74,74])
 else:pic('settings_base',[790,50,106,104]);pic('settings',[790,50,106,104])
def primary(s,r,action):
 im.alpha_composite(nine('primary',tuple(r[2:])),tuple(r[:2]));els.append(dict(kind='ninepatch',asset='assets/primary.png',rect=r,margins=[45]*4,action=action));tx(s,[r[0]+30,r[1]+12,r[2]-60,r[3]-24],43)
def save(n,loc,bindings):
 im.save(Q/(n+'_'+loc+'_940.png'));im.resize((360,640),Image.Resampling.LANCZOS).save(Q/(n+'_'+loc+'_360.png'));(L/(n+'_'+loc+'.json')).write_text(json.dumps({'canvas':[940,1672],'locale':loc,'elements':els,'bindings':bindings,'status':'static assembly; no runtime acceptance'},ensure_ascii=False,indent=2))
for loc in ['zh','en']:
 zh=loc=='zh'
 begin();hud();tx('彩瓶时光',[120,250,700,112],82);tx('Color Pause',[140,375,660,64],36,'#c5d6eb');
 # A single grouping of original glass components; no app icon tile.
 pic('warm',[238,568,145,360]);pic('blue_low',[562,568,145,360]);pic('mixed',[374,515,192,477]);
 tx('让色彩，慢慢归位' if zh else 'A little color. A little calm.',[130,1000,680,60],32,'#b7d3ee')
 primary('继续游戏' if zh else 'Continue',[130,1100,680,136],'continue_existing_save');tx('第 9 关' if zh else 'Level 9',[300,1250,340,48],29,'#dfc889',binding='resume_level')
 pic('secondary',[130,1340,330,116]);pic('grid',[153,1370,52,52]);tx('选择关卡' if zh else 'Levels',[211,1358,224,78],32)
 pic('secondary',[480,1340,330,116]);pic('records',[502,1370,52,52]);tx('本机记录' if zh else 'Records',[562,1358,224,78],32)
 tx('续玩不扣体力' if zh else 'Resume without using energy',[150,1515,640,52],27,'#8aa9cf')
 save('home',loc,{'continue':'Use existing resumable state. Otherwise Start / 开始游戏. Hide resume-level and energy-resume note without save.','settings':'existing settings route, unchanged','level_select':'existing paginated selector','records':'existing local records','hero':'one group of original bottle components; animate components, not flattened page','app_icon':'unchanged, not shown as a white tile inside scene'})
 begin();hud(True);tx('选择关卡' if zh else 'Choose a level',[120,220,700,84],54);tx('已完成 8 关' if zh else '8 levels completed',[160,319,620,55],30,'#a3c2e8',binding='completed_count')
 for k in range(20):
  num=k+1;row,col=divmod(k,4);x=92+col*194;y=435+row*192
  if num==9:
   im.alpha_composite(nine('primary',(174,174)),(x,y));els.append(dict(kind='current_tile',rect=[x,y,174,174],level=num));tx(str(num),[x,y+18,174,78],57,'#ffdc77');pic('arrow',[x+61,y+109,52,52])
  else:
   pic('tile_done' if num<9 else 'tile_locked',[x,y,174,174]);tx(str(num),[x,y+14,174,82],52,'#fff2d5' if num<9 else '#718aaf');pic('check' if num<9 else 'lock',[x+57,y+103,60,60])
 tx('1 / 3',[350,1410,240,60],33,'#bfd6ed',binding='page_index/page_count');pic('back',[250,1414,54,54]);pic('arrow',[638,1414,54,54]);primary('继续第 9 关' if zh else 'Continue level 9',[180,1510,580,112],'continue_existing_save')
 save('level_select',loc,{'page_size':20,'page_count':'ceil(actual_level_count / 20)','examples':'8 completed, current9, others locked. Bind all to actual save; never write sample progress.','states':'completed: check + normal blue tile; current: gold CTA frame + arrow; locked: subdued blue + lock; no stars','pagination':'last page only actual entries; disable prior/next at boundaries','return':'actual caller','tile_hitboxes':'174x174; 20px horizontal and 18px vertical gaps'})
 begin();hud(True);tx('三步学会' if zh else 'How to play',[120,210,700,82],52);tx('轻点一下，色彩归位' if zh else 'Tap, pour, collect',[120,301,700,55],29,'#a3c2e8')
 titles=['点击源瓶','倒入空瓶或顶部同色的瓶子','满瓶匹配订单，自动收集'] if zh else ['Tap a source bottle','Pour into empty or matching tops','Match a full bottle to an order']
 subs=['先选择要倒出的颜色','空瓶或顶部同色，且有空间','匹配当前订单才收集'] if zh else ['Choose the color on top','The target needs free space','Collect every order to finish']
 for k in range(3):
  y=395+k*350;pic('help_card',[68,y,804,320]);tx('0'+str(k+1),[98,y+20,70,54],31,'#f8cd67');tx(titles[k],[177,y+19,665,56],31,align='left')
  if k==0:
   pic('mixed',[315,y+89,74,184]);pic('tap',[386,y+137,77,77]);pic('empty',[547,y+103,68,170])
  elif k==1:
   pic('pour_diagram',[213,y+84,430,182]);pic('check',[673,y+159,52,52])
  else:
   pic('blue',[268,y+91,67,167]);pic('cork',[283,y+85,40,24]);pic('arrow',[389,y+145,62,62]);pic('order_frame',[513,y+94,130,157]);pic('order_blue',[542,y+112,72,120]);pic('check',[654,y+151,54,54])
  tx(subs[k],[110,y+269,720,42],23,'#9cbada')
 primary('知道了' if zh else 'Got it',[220,1500,500,112],'return_to_actual_caller');save('graphical_help',loc,{'back':'actual caller, no forced home','semantics':'tap source -> target empty or same top color AND has capacity -> monochrome full bottle matching active order is collected','text':'no developer/test/ad-integration wording','art':'all bottle/order assets same approved family','optional_loop':'animate existing illustration components only; no new gameplay; static page is not a runtime recording'})

sheet=Image.new('RGB',(1080,640),'#06142d')
for i,n in enumerate(['home','level_select','graphical_help']):sheet.paste(Image.open(Q/(n+'_zh_360.png')),(i*360,0))
sheet.save(Q/'overview_360.png');(Q/'text_bounds.json').write_text(json.dumps({'checks':checks,'failures':[x for x in checks if not x['fits']]},ensure_ascii=False,indent=2));print('text failures', [x for x in checks if not x['fits']])
