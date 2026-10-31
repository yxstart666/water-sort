extends RefCounted
## Reviewed three-cohort timing, normalized to the actual transaction duration.
## Pool + emitted-but-not-arrived + receiver owns each unit exactly once.
const START:=28.0/30.0
const END:=1.379
const MAIN:=30.0/33.0
const FILM:=0.96
const ARRIVAL:=[Vector2(32.0/30.0,0),Vector2(33.0/30.0,3.0/33.0),Vector2(34.0/30.0,7.0/33.0),Vector2(35.0/30.0,11.0/33.0),Vector2(36.0/30.0,15.0/33.0),Vector2(37.0/30.0,19.0/33.0),Vector2(38.0/30.0,23.0/33.0),Vector2(39.0/30.0,26.0/33.0),Vector2(40.0/30.0,MAIN)]
static var emission_cache:Dictionary={}
static func main_arrival(q: float) -> float:
	if q>ARRIVAL[-1].y:return ARRIVAL[-1].x
	var low:=1;var high:=ARRIVAL.size()-1
	while low<high:
		var mid:int=(low+high)/2
		if q<=ARRIVAL[mid].y:high=mid
		else:low=mid+1
	return lerpf(ARRIVAL[low-1].x,ARRIVAL[low].x,inverse_lerp(ARRIVAL[low-1].y,ARRIVAL[low].y,q))
## Exact emitted scalar for the planner; arrival/segments are unnecessary there.
## Uses the same quantities, ordering and arithmetic as sample(), without a LUT.
static func emitted(progress:float)->float:
	var p:=clampf(progress,0,1)
	if emission_cache.has(p):return emission_cache[p]
	var clock:=lerpf(START,END,p);var result:=0.0
	var limits:=[0.0,MAIN,FILM,1.0]
	for kind in 3:result+=quantity(kind,clock,false,limits[kind],limits[kind+1])-limits[kind]
	if emission_cache.size()>=1024:emission_cache.clear()
	emission_cache[p]=result
	return result
static func times(kind: int,q: float) -> Vector2:
	if kind==0:
		var arrive:=main_arrival(q); return Vector2(arrive-4.0/30.0,arrive)
	if kind==1:
		var p:=inverse_lerp(MAIN,FILM,q); return Vector2(1.2+0.07*p,40.0/30.0+(1.345-40.0/30.0)*p)
	var p:=inverse_lerp(FILM,1.0,q); return Vector2(1.28+0.025*p,1.369+0.01*p)
static func quantity(kind: int, clock: float, arrival: bool, low: float, high: float) -> float:
	var component:=1 if arrival else 0
	if clock<=times(kind,low)[component]: return low
	if clock>=times(kind,high)[component]: return high
	for unused in 24:
		var mid:=(low+high)*0.5
		if times(kind,mid)[component]<clock: low=mid
		else: high=mid
	return (low+high)*0.5
static func trajectory(kind: int,q: float,clock: float) -> float:
	var time:=times(kind,q)
	var p:=clampf((clock-time.x)/(time.y-time.x),0,1)
	return p if kind==2 else 0.3*p+0.7*p*p
static func sample(progress: float) -> Dictionary:
	var clock:=lerpf(START,END,clampf(progress,0,1))
	var emitted:=0.0; var arrived:=0.0; var segments: Array=[]
	var limits:=[0.0,MAIN,FILM,1.0]
	for kind in 3:
		var back:=quantity(kind,clock,false,limits[kind],limits[kind+1])
		var front:=quantity(kind,clock,true,limits[kind],limits[kind+1])
		emitted+=back-limits[kind]; arrived+=front-limits[kind]
		if back-front>0.0000001:
			var a:=trajectory(kind,front,clock); var b:=trajectory(kind,back,clock)
			segments.append({"kind":kind,"units":back-front,"from":minf(a,b),"to":maxf(a,b),"center":trajectory(kind,(front+back)*0.5,clock)})
	return {"emitted":emitted,"arrived":arrived,"inflight":maxf(0,emitted-arrived),"segments":segments,"clock":clock}
