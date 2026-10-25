/* Independent mass-conserving illustrative source renderer, not a fluid simulation.
 * Usage: const drawSource = createNeckFilmRenderer(cavitySolver);
 *        const result = drawSource(angleRadians, sourceUnits);
 * The moving internal film is counted inside sourceUnits, never external in-flight.
 * A continuous wall-following strip is narrowed geometrically, not alpha-faded.
 * Pool and film have disjoint volume ownership, although their shapes may overlap.
 */
'use strict';
const {createCanvas}=require('@napi-rs/canvas');
const {uniformSumCdf}=require('./cavity_volume');
const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
function polygonArea(p){let a=0;for(let i=0;i<p.length;i++){const q=p[(i+1)%p.length];a+=p[i][0]*q[1]-q[0]*p[i][1];}return Math.abs(a)/2;}
function clip(p,fn){if(!p.length)return p;const out=[];let a=p[p.length-1],da=fn(a);for(const b of p){const db=fn(b);if((da>=0)!==(db>=0)){const t=da/(da-db);out.push([a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])]);}if(db>=0)out.push(b);a=b;da=db;}return out;}
function rgb(hex){return [1,3,5].map(i=>parseInt(hex.slice(i,i+2),16));}
function createNeckFilmRenderer(solver,options={}){
 const W=solver.width,H=solver.height,U=solver.unitAreaPx2,pivot=solver.pivot,alpha=new Uint8Array(W*H);
 for(const r of solver.rectangles)for(let y=r.y;y<r.y+r.h;y++)for(let x=r.x;x<r.x+r.w;x++)alpha[y*W+x]=Math.round(r.alpha*255);
 const left=new Float64Array(H).fill(Infinity);
 for(let y=0;y<H;y++)for(let x=0;x<W;x++)if(alpha[y*W+x]>=128){left[y]=x;break;}
 // Keep a short mouth-to-shoulder film, not a 91px stripe which consumes
 // all late source volume and becomes an invisible subpixel line.
 const yStart=options.yStart===undefined?19:options.yStart,yEnd=options.yEnd===undefined?75:options.yEnd;
 const wall=[];for(let y=yStart;y<=yEnd;y++)wall.push([Math.max(left[Math.max(yStart,y-1)],left[Math.min(y,H-1)])+.08,y]);
 const color=rgb(options.poolColor||'#83B718'),filmColor=rgb(options.filmColor||'#83B718');
 const cavityCanvas=createCanvas(W,H),cavityContext=cavityCanvas.getContext('2d'),cavityPixels=cavityContext.createImageData(W,H);
 for(let i=0;i<alpha.length;i++){cavityPixels.data[i*4]=255;cavityPixels.data[i*4+1]=255;cavityPixels.data[i*4+2]=255;cavityPixels.data[i*4+3]=alpha[i];}cavityContext.putImageData(cavityPixels,0,0);
 function makeFilm(width){const cells=[],polygons=[];let area=0;
  for(let j=0;j<wall.length-1;j++){const [l0,y]=wall[j],[l1]=wall[j+1];const poly=[[l0,y],[l0+width,y],[l1+width,y+1],[l1,y+1]];polygons.push(poly);
   const x0=Math.max(0,Math.floor(Math.min(l0,l1))),x1=Math.min(W-1,Math.ceil(Math.max(l0,l1)+width));
   for(let x=x0;x<=x1;x++){const i=y*W+x;if(!alpha[i])continue;let p=clip(poly,q=>q[0]-x);p=clip(p,q=>x+1-q[0]);const coverage=polygonArea(p);if(coverage<=1e-15)continue;const a=coverage*alpha[i]/255;area+=a;cells.push({i,polygon:p,coverage,alpha:alpha[i]/255});}
  }return {cells,polygons,area,width};
 }
 function filmForArea(target){if(target<=0)return {cells:[],polygons:[],area:0,width:0};let lo=0,hi=58;const maximum=makeFilm(hi).area;if(target>maximum)throw new RangeError('Internal film exceeds original neck strip capacity');for(let k=0;k<43;k++){const mid=(lo+hi)/2;if(makeFilm(mid).area<target)lo=mid;else hi=mid;}return makeFilm((lo+hi)/2);}
 return function renderSource(angle,units){
  if(!Number.isFinite(angle)||!Number.isFinite(units)||units<0||units>4)throw new RangeError('Invalid source angle or units');
  const canvas=createCanvas(W,H),ctx=canvas.getContext('2d');
  if(units===0)return {canvas,h:solver.solvePlane(angle,0),area:0,poolUnits:0,filmUnits:0,poolArea:0,filmArea:0,integrationError:0,renderQuantizationError:0,filmPolygons:[],model:'empty'};
  // The late residue remains predominantly in the real shoulder/neck pool.
  // Smoothly reserve 75% of the last <=.07 units for that pool; the short
  // connecting film owns only 25%. Their overlap is subtracted exactly below.
  const z=clamp((.12-units)/.05),blend=z*z*(3-2*z),base=Math.min(.045,units*.6);
  const wantedFilm=options.filmUnits===undefined?base*(1-blend)+units*.25*blend:clamp(options.filmUnits,0,units);
  const film=filmForArea(wantedFilm*U),filmUnits=film.area/U,poolUnits=units-filmUnits;
  const s=Math.sin(angle),c=Math.cos(angle),A=Math.abs(s),B=Math.abs(c);
  const Y=p=>s*(p[0]-pivot[0])+c*(p[1]-pivot[1]);
  function overlapAt(h,details=false){let area=0;const values=details?new Map():null;for(const f of film.cells){const coverage=polygonArea(clip(f.polygon,p=>Y(p)-h));area+=coverage*f.alpha;if(details)values.set(f.i,coverage);}return details?{area,values}:area;}
  let h;if(poolUnits<1e-12)h=solver.solvePlane(angle,0);else{
   let lo=solver.solvePlane(angle,units),hi=solver.solvePlane(angle,poolUnits);
   for(let k=0;k<48;k++){const mid=(lo+hi)/2,v=solver.areaBelowPlane(angle,mid)-overlapAt(mid);if(v>poolUnits*U)lo=mid;else hi=mid;}h=(lo+hi)/2;
  }
  const overlap=overlapAt(h,true),poolArea=Math.max(0,solver.areaBelowPlane(angle,h)-overlap.area),area=poolArea+film.area;
  const filmMap=new Map(film.cells.map(f=>[f.i,f])),image=ctx.createImageData(W,H),remainders=[];let roundedSum=0;
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const i=y*W+x;if(!alpha[i])continue;const max=Y([s>=0?x+1:x,c>=0?y+1:y]),p=uniformSumCdf(max-h,A,B),f=filmMap.get(i),filmCoverage=f?f.coverage:0,poolCoverage=Math.max(0,p-(overlap.values.get(i)||0)),coverage=clamp(poolCoverage+filmCoverage),raw=alpha[i]*coverage,n=Math.floor(raw+1e-12);if(raw<=0)continue;roundedSum+=n;const k=i*4,ratio=coverage>0?filmCoverage/coverage:0;for(let channel=0;channel<3;channel++)image.data[k+channel]=Math.round(color[channel]*(1-ratio)+filmColor[channel]*ratio);image.data[k+3]=n;remainders.push({i,remainder:raw-n,max:alpha[i]});}
  const targetSum=Math.round(area*255);let missing=targetSum-roundedSum;remainders.sort((a,b)=>b.remainder-a.remainder);for(const r of remainders){if(missing<=0)break;if(image.data[r.i*4+3]<r.max){image.data[r.i*4+3]++;roundedSum++;missing--;}}
  ctx.putImageData(image,0,0);
  // Top-face lighting is clipped to the existing liquid alpha as well as the
  // unchanged cavity. It cannot create an extra green patch outside real S.
  // Use only the main pool chord, not disconnected mouth/body chord bridges.
  if(poolUnits>1e-8&&options.drawPoolTop!==false){
   const segments=solver.surfaceSegments(angle,h,{alphaThreshold:.5}),main=segments.reduce((a,b)=>!a||b.length>a.length?b:a,null);
   if(main){const top=createCanvas(W,H),q=top.getContext('2d'),a=main.world[0],b=main.world[1],rx=(b[0]-a[0])/2,cx=(a[0]+b[0])/2,ry=Math.min(17,rx*2*17/111);
    q.save();q.translate(...pivot);q.rotate(-angle);q.fillStyle=options.topColor||'#9DCB3F';q.beginPath();q.ellipse(cx,h,rx,ry,0,0,Math.PI*2);q.fill();q.restore();q.globalCompositeOperation='destination-in';q.drawImage(cavityCanvas,0,0);ctx.save();ctx.globalCompositeOperation='source-atop';ctx.drawImage(top,0,0);ctx.restore();
   }
  }
  return {canvas,h,area,poolUnits:poolArea/U,filmUnits,poolArea,filmArea:film.area,filmWidthPx:film.width,filmPolygons:film.polygons,integrationError:area/U-units,renderedArea:roundedSum/255,renderQuantizationError:roundedSum/(255*U)-units,model:'visible shoulder pool plus short neck film',allocationBlend:blend,topFaceClippedToLiquid:true,opticalTopFaceExcludedFromVolume:false,notes:'Illustrative short-film and shoulder-pool capacity allocation, clipped to the unchanged cavity. The late pool owns 75% of S; overlap is counted once. Internal film belongs to S; external in-flight begins only after the mouth.'};
 };
}
module.exports={createNeckFilmRenderer};
