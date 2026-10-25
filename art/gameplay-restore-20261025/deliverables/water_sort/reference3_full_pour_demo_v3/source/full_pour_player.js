/* Independent two-bottle atlas player, not runtime game integration. */
const {createCanvas,loadImage}=require('@napi-rs/canvas');const fs=require('fs'),path=require('path');const V=require('./cavity_volume.js');const {sampleTransfer}=require('./transfer_timing_v3.js');const {createNeckFilmRenderer}=require('./neck_film.js');const D=path.resolve(__dirname,'..'),R=path.resolve(D,'..'),A=R+'/reference3_pour_frame_atlas_v3';
const FPS=30,SCALE=.62,TARGET=[110,550],SOURCE_HOME=[265,550],LIP=[53,19],EFFECT_START=28/30,TRANSIT=4/30;
const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x)),smooth=x=>{x=clamp(x);return x*x*(3-2*x)};
const arrivalKnots=[[32/30,0],[33/30,3/33],[34/30,7/33],[35/30,11/33],[36/30,15/33],[37/30,19/33],[38/30,23/33],[39/30,26/33],[40/30,30/33],[41/30,32/33],[42/30,1]];
function arrived(t){if(t<=arrivalKnots[0][0])return 0;for(let j=1;j<arrivalKnots.length;j++){let[a,u]=arrivalKnots[j-1],[b,v]=arrivalKnots[j];if(t<=b)return u+(v-u)*(t-a)/(b-a);}return 1;}
function tint(img,hex){const c=createCanvas(img.width,img.height),x=c.getContext('2d');x.drawImage(img,0,0);let d=x.getImageData(0,0,c.width,c.height),rgb=[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16));for(let i=0;i<d.data.length;i+=4){let g=d.data[i]/255;for(let k=0;k<3;k++)d.data[i+k]=Math.round(rgb[k]*g);}x.putImageData(d,0,0);return c;}
(async()=>{let im={};for(const[k,p]of Object.entries({front:'reference3_cartoon_bottle_v2_highlight_fix/assets/glass_front_material.png',back:'reference3_cartoon_bottle_v2_highlight_fix/assets/glass_back_transmission.png',cavity:'reference3_cartoon_bottle_v2/assets/pour_cavity_mask.png',background:'reference2_background_cleanplate_v1/assets/background_native_940x1672.png'}))im[k]=await loadImage(R+'/'+p);const solver=await V.loadCavitySolver(R+'/reference3_cartoon_bottle_v2/assets/pour_cavity_mask.png');const renderSource=createNeckFilmRenderer(solver);const impact=[],flow=[];for(let i=0;i<25;i++)impact.push(tint(await loadImage(A+`/assets/impact_frames/${String(i).padStart(2,'0')}.png`),'#9DCB3F'));for(let i=0;i<15;i++)flow.push(tint(await loadImage(A+`/assets/flow_frames/${String(i).padStart(2,'0')}.png`),'#9DCB3F'));
const openCore=tint(await loadImage(A+'/assets/open_stream_core.png'),'#9DCB3F'),transportDrop=tint(await loadImage(A+'/assets/transport_drop.png'),'#9DCB3F');
const dropPixels=transportDrop.getContext('2d').getImageData(0,0,transportDrop.width,transportDrop.height).data;let transportDropAlphaArea=0;for(let j=3;j<dropPixels.length;j+=4)transportDropAlphaArea+=dropPixels[j]/255;
function liquid(angle,units){const c=createCanvas(165,410),x=c.getContext('2d');if(units<=0)return {canvas:c,h:solver.solvePlane(angle,0),area:0};let h=solver.solvePlane(angle,units),chord=solver.surfaceChord(angle,h,{alphaThreshold:.5});x.save();x.translate(82.5,400);x.rotate(-angle);x.fillStyle='#83B718';x.fillRect(-1000,h,2000,2000);if(chord){let [a,b]=chord.world,rx=(b[0]-a[0])/2,cx=(a[0]+b[0])/2,ry=Math.min(17,rx*2*17/111);x.fillStyle='#9DCB3F';x.beginPath();x.ellipse(cx,h,rx,ry,0,0,Math.PI*2);x.fill();}x.restore();x.globalCompositeOperation='destination-in';x.drawImage(im.cavity,0,0);return {canvas:c,h,area:solver.areaBelowPlane(angle,h)};}
function bottle(angle,units,impactIndex=-1,isSource=false){let l=isSource&&Math.abs(angle)>.1&&units>0?renderSource(angle,units):liquid(angle,units),c=createCanvas(165,410),x=c.getContext('2d');x.drawImage(im.back,0,0);x.drawImage(l.canvas,0,0);if(impactIndex>=0&&impactIndex<25){const z=createCanvas(165,410),q=z.getContext('2d');q.drawImage(impact[impactIndex],82.5-64,l.h+400-88);q.globalCompositeOperation='destination-in';q.drawImage(im.cavity,0,0);x.drawImage(z,0,0);}x.drawImage(im.front,0,0);return {canvas:c,liquid:l};}
function pose(t,sourceUnits){const startAngle=solver.solvePourAngle(1,{direction:-1}),safeUnits=Math.max(sourceUnits,.001);let pourAngle=solver.solvePourAngle(safeUnits,{direction:-1});if(sourceUnits<.001)pourAngle+=(-112*Math.PI/180-pourAngle)*(1-sourceUnits/.001);let outlet=[TARGET[0],TARGET[1]+(19-400)*SCALE-28];function pivotFor(a){let q=solver.pointToWorld(LIP,a);return[outlet[0]-q[0]*SCALE,outlet[1]-q[1]*SCALE];}let activePivot=pivotFor(pourAngle),angle,pivot;
 if(t<.7){angle=0;pivot=[SOURCE_HOME[0],SOURCE_HOME[1]-70*smooth((t-.2)/.3)];}
 else if(t<EFFECT_START){let q=smooth((t-.7)/(EFFECT_START-.7)),dest=pivotFor(startAngle);angle=startAngle*q;pivot=[SOURCE_HOME[0]+(dest[0]-SOURCE_HOME[0])*q,480+(dest[1]-480)*q];}
 else if(t<1.4){angle=pourAngle;pivot=activePivot;}
 else if(t<1.7){let q=clamp((t-1.4)/.3),pos=smooth(q),rot=1-Math.pow(1-q,3);angle=(-112*Math.PI/180)*(1-rot);let begin=pivotFor(-112*Math.PI/180);pivot=[begin[0]+(SOURCE_HOME[0]-begin[0])*pos,begin[1]+(SOURCE_HOME[1]-begin[1])*pos];}
 else{angle=0;pivot=SOURCE_HOME.slice();}
 let q=solver.pointToWorld(LIP,angle);return{angle,pivot,outlet:[pivot[0]+q[0]*SCALE,pivot[1]+q[1]*SCALE]};}
function paintBottle(ctx,b,pivot,angle){ctx.save();ctx.translate(...pivot);ctx.rotate(angle);ctx.scale(SCALE,SCALE);ctx.drawImage(b,-82.5,-400);ctx.restore();}
const ledger=[];fs.mkdirSync(D+'/qa/frames',{recursive:true});fs.mkdirSync(D+'/qa/receiver_frames',{recursive:true});for(let n=0;n<70;n++){let t=n/FPS,mass=sampleTransfer(t),E=mass.E,B=mass.A,sourceUnits=mass.S,receiverUnits=mass.receiverUnits,inflight=mass.I,k=Math.floor((t-EFFECT_START)*30+1e-7),ii=k-4;let pp=pose(t,sourceUnits),src=bottle(pp.angle,sourceUnits,-1,t>=EFFECT_START),dst=bottle(0,receiverUnits,ii);let c=createCanvas(360,640),x=c.getContext('2d');x.drawImage(im.background,0,0,360,640);
 // Target back/liquid, atlas stream, atlas impact, target front. Sprite artwork remains separate.
 const targetWithoutFront=createCanvas(165,410),tc=targetWithoutFront.getContext('2d');tc.drawImage(im.back,0,0);tc.drawImage(dst.liquid.canvas,0,0);paintBottle(x,targetWithoutFront,TARGET,0);
 let surfaceY=TARGET[1]+dst.liquid.h*SCALE;
 const start=pp.outlet,dx=TARGET[0]-start[0],dy=surfaceY-start[1],len=Math.hypot(dx,dy);
 const ribbons=mass.segments.filter(z=>z.kind!=='compact-drop');
 if(ribbons.length){
  const from=Math.min(...ribbons.map(z=>z.bounds.from)),to=Math.max(...ribbons.map(z=>z.bounds.to));
  x.save();x.translate(...start);x.rotate(-Math.atan2(dx,dy));
  if(k<4)x.drawImage(flow[Math.max(0,k)],-16*SCALE,0,32*SCALE,len);
  else{
   const main=ribbons.find(z=>z.id==='main'),film=ribbons.find(z=>z.id==='tail-film');
   const begin=from*len,finish=to*len;
   for(let yy=begin;yy<finish;yy+=.5){
    const p=(yy+.25)/len;let w=32;
    if(!main)w=21;else if(film){let join=main.bounds.from;w=21+11*smooth((p-join+.065)/.13);}
    let cap=from>0?Math.sqrt(Math.max(0,1-Math.pow(1-clamp((yy-begin)/(5*SCALE)),2))):1;
    w*=SCALE*cap;if(w<.05)continue;
    x.drawImage(openCore,0,Math.min(255,p*256),32,1,-w/2,yy,w,Math.min(.55,finish-yy));
   }
  }
  x.restore();
 }
 for(const seg of mass.segments.filter(z=>z.kind==='compact-drop')){
   const amount=seg.units,progress=seg.center.progress,cx=start[0]+dx*progress,cy=start[1]+dy*progress;
   const nativeScale=Math.sqrt(amount*solver.unitAreaPx2/transportDropAlphaArea),ww=20*SCALE*nativeScale,hh=24*SCALE*nativeScale;
   const contact=clamp((progress-.82)/.18),flatten=1-.55*contact,height=hh*flatten,width=ww/flatten;
   x.drawImage(transportDrop,cx-width/2,Math.min(cy-height/2,surfaceY-height),width,height);
 }

 if(ii>=0&&ii<25){x.drawImage(impact[ii],TARGET[0]-64*SCALE,surfaceY-88*SCALE,128*SCALE,128*SCALE);}
 paintBottle(x,im.front,TARGET,0);paintBottle(x,src.canvas,pp.pivot,pp.angle);
 x.textAlign='center';x.fillStyle='#E2EDFA';x.font='14px sans-serif';x.fillText('One conserved transfer · original frame atlas',180,30);x.font='11px sans-serif';x.fillStyle='#AEC2D9';x.fillText('Independent cloud sample · not gameplay capture',180,49);x.fillText(`Receiver ${receiverUnits.toFixed(3)} / 4`,110,580);x.fillText(`Source ${sourceUnits.toFixed(3)} / 4`,265,580);x.fillText(`In transit ${inflight.toFixed(3)} · total ${(sourceUnits+receiverUnits+inflight).toFixed(3)}`,180,603);x.fillText(`${t.toFixed(2)} s`,180,623);
 fs.writeFileSync(D+`/qa/frames/frame_${String(n).padStart(3,'0')}.png`,c.toBuffer('image/png'));fs.writeFileSync(D+`/qa/receiver_frames/frame_${String(n).padStart(3,'0')}.png`,dst.canvas.toBuffer('image/png'));
 ledger.push({frame:n,time:t,emitted:E,arrived:B,sourceUnits,receiverUnits,inflight,total:sourceUnits+receiverUnits+inflight,sourceAngleDeg:pp.angle*180/Math.PI,sourcePlane:src.liquid.h,receiverPlaneY:dst.liquid.h+400,sourceArea:src.liquid.area,sourcePoolUnits:src.liquid.poolUnits??sourceUnits,sourceFilmUnits:src.liquid.filmUnits??0,sourceRenderQuantizationError:src.liquid.renderQuantizationError??0,receiverArea:dst.liquid.area,sourceIntegrationError:src.liquid.area/solver.unitAreaPx2-sourceUnits,receiverIntegrationError:dst.liquid.area/solver.unitAreaPx2-receiverUnits,parcelSegments:mass.segments.map(z=>({id:z.id,units:z.units,bounds:z.bounds,center:z.center.progress})),minimumTransit:mass.minimumTransit,atlasTick:k,impactFrame:ii>=0&&ii<25?ii:null,flowFrame:k>=0&&k<15?k:null});}
fs.writeFileSync(D+'/qa/CONSERVATION_LEDGER.json',JSON.stringify(ledger,null,2));fs.copyFileSync(D+'/qa/receiver_frames/frame_042.png',D+'/assets/home_peak_static.png');console.log('70 frames + exact receiver42 exported');})();
