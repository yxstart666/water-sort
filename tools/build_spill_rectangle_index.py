"""Conservative rectangle classification; never quantizes the evaluated angle.
The binary retains original rectangle order and exact area additions. Ambiguous
rectangles use the unchanged alpha integration. No runtime geometry is rewritten.
"""
from pathlib import Path
import json,math,hashlib,struct,sys,re
assert len(sys.argv)==2,'Usage: python build_spill_rectangle_index.py PROJECT_DIRECTORY'
root=Path(sys.argv[1]).resolve()
src=root/'art/gameplay-restore-20261025/deliverables/water_sort/reference3_cartoon_bottle_v2/assets/cavity_rectangles.json'
rs=json.loads(src.read_text(encoding='utf8'))['rectangles']
# Read the actual runtime asset contract, never QA sample coordinates.
contract=(root/'scripts/water_sort/order_gameplay_assets.gd').read_text(encoding='utf8')
edge=re.search(r'"outlet_right":\s*([-\d.]+)',contract)
tip=re.search(r'"mouth":\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)',contract)
assert edge and tip,'Approved numeric asset contract is required'
mouth=[float(edge[1]),float(tip[2])]
maximum=math.radians(179);bins=1668;step=maximum/bins;margin=.01
def extrema(x,y,lo,hi):
 vals=[math.sin(lo)*x+math.cos(lo)*y,math.sin(hi)*x+math.cos(hi)*y]
 critical=math.atan2(x,y)
 for k in range(math.floor((lo-critical)/math.pi),math.ceil((hi-critical)/math.pi)+1):
  a=critical+k*math.pi
  if lo<=a<=hi:vals.append(math.sin(a)*x+math.cos(a)*y)
 return min(vals),max(vals)
offsets=[0];codes=[];counts=[]
for i in range(bins):
 lo=i*step;hi=(i+1)*step;part=0
 for j,(x,y,w,h,alpha) in enumerate(rs):
  spans=[extrema(a-mouth[0],b-mouth[1],lo,hi) for a,b in [(x,y),(x+w,y),(x+w,y+h),(x,y+h)]]
  mn=min(t[0] for t in spans);mx=max(t[1] for t in spans)
  if mx < -margin:continue
  if mn > margin:codes.append(j+1)
  else:codes.append(-(j+1));part+=1
 offsets.append(len(codes));counts.append(part)
out=root/'data/water_sort/rendering';data=struct.pack('<'+'i'*(len(offsets)+len(codes)),*(offsets+codes));name='spill_rectangle_index.bin';(out/name).write_bytes(data)
meta={'schema':1,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'binary_sha256':hashlib.sha256(data).hexdigest(),'bins':bins,'maximum_angle':maximum,'mouth':mouth,'classification_margin_native_pixels':margin,'offset_count':len(offsets),'rectangle_count':len(rs),'codes':len(codes),'description':'Conservative empty/full classification only; ambiguous rectangles evaluated exactly; original addition order. Float32 mouth projection error guarded by .01 native pixels.'}
(out/'spill_rectangle_index.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf8')
print(json.dumps({'bytes':len(data),'codes':len(codes),'average_included':len(codes)/bins,'average_partial':sum(counts)/bins,'max_partial':max(counts),'mouth':mouth},indent=2))
