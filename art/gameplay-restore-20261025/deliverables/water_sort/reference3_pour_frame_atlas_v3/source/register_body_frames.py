from PIL import Image
from scipy.ndimage import label,find_objects
import numpy as np,pathlib,subprocess,json
p=pathlib.Path('deliverables/water_sort/reference3_pour_frame_atlas_v3');src=str(p/'source/art/key_shapes_edge_refined.png');a=np.array(Image.open(src).convert('RGBA'));lab,n=label(a[:,:,3]>48);cs=[]
for k,z in enumerate(find_objects(lab),1):
 if z is None:continue
 if (lab[z]==k).sum()<1000:continue
 yy,xx=z;cs.append([xx.start,yy.start,xx.stop-xx.start,yy.stop-yy.start])
cs.sort();run=lambda c:subprocess.run(c,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
widths=[30,43,55,63,65,67,68,68,68,64,68,56,38];heights=[8,12,16,20,22,23,24,24,24,16,40,24,10]
for i in range(13):
 j=0 if i<10 else(1 if i==10 else 2);x,y,bw,bh=cs[j];w,h=widths[i],heights[i];bottom=106 if i<9 else(96 if i==9 else(100 if i==10 else(95 if i==11 else 90)));part=p/'qa/body_part.png';run(['magick',src,'-crop',f'{bw}x{bh}+{x}+{y}','+repage','-colorspace','Gray','-channel','RGB','-fx','min(1,0.40+0.70*u)','+channel','-resize',f'{w}x{h}!',str(part)]);run(['magick','-size','128x128','xc:none',str(part),'-geometry',f'{round(64-w/2):+d}{bottom-h:+d}','-compose','over','-composite',str(p/f'assets/impact_frames/{i:02d}.png')])
run(['magick','montage',*[str(p/f'assets/impact_frames/{i:02d}.png') for i in range(25)],'-tile','5x5','-geometry','128x128+0+0','-background','none',str(p/'assets/impact_tail_atlas.png')])
(p/'qa/BODY_REGISTRATION.json').write_text(json.dumps({'source':src,'original_components':cs,'widths':widths,'heights':heights,'surface_anchor':[64,88],'stage_source':'0..9 low joined sheet,10 single primary bulge,11..12 collapsing sheet;13..24 existing measured droplets','no_competitor_pixels':True},indent=2));print('v3 fullbody13 registered')
