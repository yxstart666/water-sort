/* Independent v3 bounded tail timing. Not CFD and not reference parity.
 * Three cohorts only, with positive travel time and disjoint mass ownership.
 * Source empty 1.305; final drop lands 1.369..1.379; refill may start 1.382.
 * Compared with v2.1, source residue is shorter so frames 040 and 041 can both
 * show the same last drop below the opaque receiver neck. No visibility patch,
 * hidden source mass, new launch boost, or extra late emission is permitted.
 */
'use strict';
const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
const MAIN_END_Q=30/33,TAIL_SPLIT_Q=.96;
const SOURCE_EMPTY_TIME=1.305,ARRIVAL_END_TIME=1.379,LONG_STREAM_CUT=1.300;
const RESPONSE_TIMING=Object.freeze({lastFilmArrival:1.345,firstDropArrival:1.369,lastDropArrival:ARRIVAL_END_TIME,refillStart:1.382,refillPeak:1.400});
const REFERENCE_ARRIVAL_KNOTS=Object.freeze([[32/30,0],[33/30,3/33],[34/30,7/33],[35/30,11/33],[36/30,15/33],[37/30,19/33],[38/30,23/33],[39/30,26/33],[40/30,30/33],[41/30,32/33],[42/30,1]].map(Object.freeze));
function interpolate(knots,x){
 if(x<=knots[0][0])return knots[0][1];
 for(let j=1;j<knots.length;j++){const[a,u]=knots[j-1],[b,v]=knots[j];if(x<=b)return u+(v-u)*(x-a)/(b-a);}
 return knots[knots.length-1][1];
}
const referenceArrivalTime=q=>interpolate(REFERENCE_ARRIVAL_KNOTS.map(([t,a])=>[a,t]),clamp(q));
const ARRIVAL_KNOTS=Object.freeze([...REFERENCE_ARRIVAL_KNOTS.filter(([,q])=>q<=MAIN_END_Q),[1.345,TAIL_SPLIT_Q],[1.369,TAIL_SPLIT_Q],[ARRIVAL_END_TIME,1]].map(Object.freeze));
const arrived=t=>interpolate(ARRIVAL_KNOTS,t);
function arrivalTime(q){q=clamp(q);if(q<=MAIN_END_Q)return referenceArrivalTime(q);if(q<=TAIL_SPLIT_Q)return 40/30+(q-MAIN_END_Q)/(TAIL_SPLIT_Q-MAIN_END_Q)*(1.345-40/30);return 1.369+(q-TAIL_SPLIT_Q)/(1-TAIL_SPLIT_Q)*.010;}
function createTransferTiming(options={}){
 // This reviewed schedule is fixed. Do not silently invalidate the neck
 // visibility / material-order checks by tuning only one of these fields.
 if(options.sourceEmptyTime!==undefined&&Math.abs(options.sourceEmptyTime-SOURCE_EMPTY_TIME)>1e-10)throw new RangeError('v3 sourceEmptyTime is fixed at 1.305');
 if(options.longStreamCut!==undefined&&Math.abs(options.longStreamCut-LONG_STREAM_CUT)>1e-10)throw new RangeError('v3 longStreamCut is fixed at 1.300');
 const sourceEmptyTime=SOURCE_EMPTY_TIME,longStreamCut=LONG_STREAM_CUT;
 const definitions=[
  {id:'main',kind:'stream',q0:0,q1:MAIN_END_Q,emit:q=>referenceArrivalTime(q)-4/30,arrive:referenceArrivalTime},
  {id:'tail-film',kind:'detached-film',q0:MAIN_END_Q,q1:TAIL_SPLIT_Q,emit:q=>1.200+(q-MAIN_END_Q)/(TAIL_SPLIT_Q-MAIN_END_Q)*.070,arrive:q=>40/30+(q-MAIN_END_Q)/(TAIL_SPLIT_Q-MAIN_END_Q)*(1.345-40/30)},
  {id:'tail-drop',kind:'compact-drop',q0:TAIL_SPLIT_Q,q1:1,emit:q=>1.280+(q-TAIL_SPLIT_Q)/(1-TAIL_SPLIT_Q)*.025,arrive:q=>1.369+(q-TAIL_SPLIT_Q)/(1-TAIL_SPLIT_Q)*.010}
 ];
 function emittedQ(d,t){
  if(t<=d.emit(d.q0))return d.q0;if(t>=d.emit(d.q1))return d.q1;
  let lo=d.q0,hi=d.q1;for(let j=0;j<48;j++){const q=(lo+hi)/2;if(d.emit(q)<t)lo=q;else hi=q;}return(lo+hi)/2;
 }
 function trajectory(d,q,t){
  const emittedAt=d.emit(q),arrivesAt=d.arrive(q),flightTime=arrivesAt-emittedAt;
  if(!(flightTime>0))throw new Error('Every material parcel must have positive transit');
  const fraction=clamp((t-emittedAt)/flightTime);
  // Same compact-drop linear law as v2.1, now with a longer, slower flight.
  // Stream/film use the existing gravity-like ease. Their boundary ordering
  // is checked separately because differing laws alone do not prove ordering.
  const progress=d.kind==='compact-drop'?fraction:.30*fraction+.70*fraction*fraction;
  return {q,emittedAt,arrivesAt,flightTime,fraction,progress};
 }
 const minimumTransit=Math.min(...definitions.flatMap(d=>Array.from({length:257},(_,i)=>{const q=d.q0+(d.q1-d.q0)*i/256;return d.arrive(q)-d.emit(q);}))); 
 if(!(minimumTransit>0))throw new Error('Timing configuration has zero or negative transit');
 function sample(t,settings={}){
  if(!Number.isFinite(t))throw new TypeError('time must be finite');
  const A=arrived(t),E=clamp(definitions.reduce((sum,d)=>sum+emittedQ(d,t)-d.q0,0));
  const S=1-E,I=E-A,segments=[],sectionCount=settings.sections??12;
  if(I< -1e-10)throw new Error('Arrival cannot precede emission');
  for(const d of definitions){
   const qFront=Math.max(d.q0,A),qBack=Math.min(d.q1,emittedQ(d,t));
   if(qBack-qFront<1e-12)continue;
   const front=trajectory(d,qFront,t),back=trajectory(d,qBack,t),center=trajectory(d,(qFront+qBack)/2,t);
   const sections=[];for(let j=0;j<sectionCount;j++){
    const qa=qFront+(qBack-qFront)*j/sectionCount,qb=qFront+(qBack-qFront)*(j+1)/sectionCount;
    const a=trajectory(d,qa,t),b=trajectory(d,qb,t),m=trajectory(d,(qa+qb)/2,t);
    sections.push({q0:qa,q1:qb,units:qb-qa,from:Math.min(a.progress,b.progress),to:Math.max(a.progress,b.progress),center:m.progress,emittedAt:m.emittedAt,arrivesAt:m.arrivesAt});
   }
   segments.push({id:d.id,kind:d.kind,units:qBack-qFront,qFront,qBack,front,back,center,
    bounds:{from:Math.min(front.progress,back.progress),to:Math.max(front.progress,back.progress)},
    connectedToSource:Math.abs(back.progress)<1e-8&&t<d.emit(d.q1),
    touchingReceiver:Math.abs(front.progress-1)<1e-8,sections});
  }
  return {time:t,S,E,A,I,sourceUnits:S,emitted:E,arrived:A,inflight:Math.max(0,I),receiverUnits:2+A,total:S+Math.max(0,I)+2+A,
   sourceHasResidual:S>1e-9,longStreamActive:t<longStreamCut&&t>=28/30,segments,inflightSegments:segments,
   sourceEmptyTime,arrivalEndTime:ARRIVAL_END_TIME,longStreamCut,minimumTransit,responseTiming:RESPONSE_TIMING};
 }
 const cohorts=definitions.map(d=>({id:d.id,kind:d.kind,q0:d.q0,q1:d.q1,units:d.q1-d.q0,emitStart:d.emit(d.q0),emitEnd:d.emit(d.q1),arrivalStart:d.arrive(d.q0),arrivalEnd:d.arrive(d.q1)}));
 return {sample,arrived,arrivalTime,sourceEmptyTime,arrivalEndTime:ARRIVAL_END_TIME,longStreamCut,minimumTransit,cohorts,responseTiming:RESPONSE_TIMING};
}
const defaultTiming=createTransferTiming();
module.exports={ARRIVAL_KNOTS,REFERENCE_ARRIVAL_KNOTS,RESPONSE_TIMING,arrived,arrivalTime,createTransferTiming,sampleTransfer:t=>defaultTiming.sample(t),defaultTiming};
