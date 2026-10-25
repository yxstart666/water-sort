/*
 * Exact alpha-weighted cavity geometry, independent of animation timing/art.
 * Pixel (x,y) means the square [x,x+1] x [y,y+1], with constant alpha density.
 * Angles are RADIANS, positive clockwise in a screen-coordinate system.
 * Relative world coordinates: X=c*(x-82.5)-s*(y-400),
 *                             Y=s*(x-82.5)+c*(y-400).
 * Liquid occupies Y >= h. Volumes are logical units, not raw pixel area.
 * Never clamp outlet-retained residual to zero; the original AA mask includes
 * material on both sides of the nominated lip and may make exact zero impossible.
 * Capacity is 4, although the complete neck+body integration domain is larger.
 * CommonJS, with a browser global CavityVolume when loaded as a classic script.
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.CavityVolume = factory();
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const CAPACITY_UNITS = 4;
  const UNIT_AREA_PX2 = 8070.785294117648;
  const PIVOT = [82.5, 400];
  const RIGHT_LIP = [112, 19];
  const LEFT_LIP = [53, 19];
  const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
  const radians = d => d * Math.PI / 180;
  const degrees = r => r * 180 / Math.PI;
  function finite(v, name) { if (!Number.isFinite(v)) throw new TypeError(name + ' must be finite'); }
  function cleanTrig(v) { return Math.abs(v) < 1e-15 ? 0 : v; }
  function trig(angle) { finite(angle, 'angle'); return [cleanTrig(Math.sin(angle)), cleanTrig(Math.cos(angle))]; }

  // CDF of U[0,a]+U[0,b]. Piecewise form avoids cancellation near axis alignment.
  function uniformSumCdf(t, a, b) {
    if (t <= 0) return 0;
    const lo = Math.min(a, b), hi = Math.max(a, b), span = lo + hi;
    if (t >= span) return 1;
    if (lo === 0) return hi === 0 ? 1 : t / hi;
    if (t < lo) return t * t / (2 * lo * hi);
    if (t <= hi) return (t - lo / 2) / hi;
    const rest = span - t;
    return 1 - rest * rest / (2 * lo * hi);
  }

  function rgbaToRectangles(width, height, rgba) {
    if (rgba.length !== width * height * 4) throw new Error('RGBA size mismatch');
    const result = [], active = new Map();
    // Lossless merging of adjacent same-alpha pixels, then matching vertical runs.
    for (let y = 0; y < height; y++) {
      const next = new Map();
      for (let x = 0; x < width;) {
        const alpha = rgba[(y * width + x) * 4 + 3];
        const x0 = x++;
        while (x < width && rgba[(y * width + x) * 4 + 3] === alpha) x++;
        if (!alpha) continue;
        const key = x0 + ',' + (x - x0) + ',' + alpha;
        const prior = active.get(key);
        if (prior) { prior.h++; next.set(key, prior); }
        else { const rect = {x:x0, y, w:x-x0, h:1, alpha:alpha/255}; result.push(rect); next.set(key,rect); }
      }
      active.clear();
      for (const [key, value] of next) active.set(key, value);
    }
    return result;
  }

  function createCavitySolver(options) {
    const {width, height} = options;
    if (!(width > 0 && height > 0)) throw new Error('Positive width and height required');
    const pivot = (options.pivot || PIVOT).slice();
    const unitArea = options.unitArea || UNIT_AREA_PX2;
    const rectangles = options.rectangles ? options.rectangles.map(r => ({...r})) : rgbaToRectangles(width,height,options.rgba);
    const fullArea = rectangles.reduce((sum,r) => sum + r.w*r.h*r.alpha,0);
    const fullUnits = fullArea / unitArea;
    let cachedAngle, cachedProjection;
    const retentionTables = new Map();
    const outlet = direction => direction < 0 ? LEFT_LIP.slice() : RIGHT_LIP.slice();
    const pointToWorld = (point, angle) => {
      const [s,c]=trig(angle), dx=point[0]-pivot[0],dy=point[1]-pivot[1];
      return [c*dx-s*dy,s*dx+c*dy];
    };
    const pointToLocal = (point, angle) => {
      const [s,c]=trig(angle);
      return [c*point[0]+s*point[1]+pivot[0],-s*point[0]+c*point[1]+pivot[1]];
    };
    function project(angle) {
      if (angle === cachedAngle) return cachedProjection;
      const [s,c]=trig(angle);
      const projected=rectangles.map(r=> {
        const x=s>=0?r.x:r.x+r.w, y=c>=0?r.y:r.y+r.h;
        const minimum=s*(x-pivot[0])+c*(y-pivot[1]);
        const a=Math.abs(s)*r.w, b=Math.abs(c)*r.h;
        return {minimum,maximum:minimum+a+b,a,b,area:r.w*r.h*r.alpha};
      });
      let min=Infinity,max=-Infinity;
      for(const p of projected){min=Math.min(min,p.minimum);max=Math.max(max,p.maximum);}
      cachedAngle=angle;cachedProjection={projected,min,max};
      return cachedProjection;
    }
    function areaBelowPlane(angle,h) {
      finite(h,'h');
      const data=project(angle);
      if(h<=data.min)return fullArea;
      if(h>=data.max)return 0;
      let area=0;
      for(const r of data.projected) {
        if(h<=r.minimum)area+=r.area;
        else if(h<r.maximum)area+=r.area*uniformSumCdf(r.maximum-h,r.a,r.b);
      }
      return area;
    }
    const volumeBelowPlane=(angle,h)=>areaBelowPlane(angle,h)/unitArea;
    function solvePlane(angle,units,opts={}) {
      finite(units,'units');
      if(units<0||units>fullUnits+1e-12)throw new RangeError('Volume outside complete cavity domain');
      const {min,max}=project(angle);
      if(units===0)return max;
      if(units>=fullUnits)return min;
      let lo=min,hi=max;
      const tolerance=opts.heightTolerance || 1e-10;
      for(let i=0;i<64&&hi-lo>tolerance;i++) {
        const mid=(lo+hi)/2;
        if(volumeBelowPlane(angle,mid)>units)lo=mid;else hi=mid;
      }
      return (lo+hi)/2;
    }
    function outletPlane(angle,opts={}) {
      const direction=opts.direction===undefined?(angle<0?-1:1):Math.sign(opts.direction)||1;
      return pointToWorld(opts.lip || outlet(direction),angle)[1];
    }
    const outletRetention=(angle,opts={})=>volumeBelowPlane(angle,outletPlane(angle,opts));
    function retentionTable(direction,maxAngle=Math.PI) {
      const key=direction+':'+maxAngle;
      if(retentionTables.has(key))return retentionTables.get(key);
      const entries=[];
      for(let i=0;i<=360;i++) {
        const magnitude=maxAngle*i/360;
        entries.push({magnitude,units:outletRetention(direction*magnitude,{direction})});
      }
      const result={entries,min:entries.reduce((a,b)=>a.units<b.units?a:b)};
      retentionTables.set(key,result);
      return result;
    }
    // First static onset/crossing angle for the requested retained volume.
    // The final small AA fringe need not be monotone near 180 degrees.
    function solvePourAngle(units,opts={}) {
      finite(units,'units');
      if(units<0||units>fullUnits)throw new RangeError('Volume outside complete cavity domain');
      const direction=opts.direction<0?-1:1;
      const maxAngle=opts.maxAngle===undefined?Math.PI:Math.abs(opts.maxAngle);
      if (!(maxAngle > 0 && maxAngle <= Math.PI)) throw new RangeError('maxAngle must be in (0, pi]');
      const table=retentionTable(direction,maxAngle).entries;
      if(units>=table[0].units)return 0;
      let bracket=null;
      for(let i=1;i<table.length;i++) {
        if(table[i].units<=units) {bracket=[table[i-1].magnitude,table[i].magnitude];break;}
      }
      if(!bracket) {
        const minimum=minimumOutletRetention({direction,maxAngle});
        if (minimum.units <= units) {
          // A very shallow last crossing can lie between coarse samples.
          const magnitude=Math.abs(minimum.angle);
          let lower=0;
          for(const entry of table) { if(entry.magnitude>=magnitude)break; lower=entry.magnitude; }
          bracket=[lower,magnitude];
        } else {
          const error=new RangeError('Requested retained volume is unreachable with the original alpha mask and nominated outlet lip');
          error.code='UNREACHABLE_OUTLET_VOLUME';error.requestedUnits=units;error.minimum=minimum;
          throw error;
        }
      }
      let [lo,hi]=bracket;
      for(let i=0;i<60&&hi-lo>1e-13;i++) {
        const mid=(lo+hi)/2;
        if(outletRetention(direction*mid,{direction})>units)lo=mid;else hi=mid;
      }
      return direction*(lo+hi)/2;
    }
    function minimumOutletRetention(opts={}) {
      const direction=opts.direction<0?-1:1;
      const maxAngle=opts.maxAngle===undefined?Math.PI:Math.abs(opts.maxAngle);
      if (!(maxAngle > 0 && maxAngle <= Math.PI)) throw new RangeError('maxAngle must be in (0, pi]');
      const {entries,min}=retentionTable(direction,maxAngle);
      const idx=entries.indexOf(min);
      let lo=entries[Math.max(0,idx-1)].magnitude,hi=entries[Math.min(entries.length-1,idx+1)].magnitude;
      // Golden-section minimization on the best coarse cell neighbourhood.
      const ratio=(Math.sqrt(5)-1)/2;
      let x1=hi-ratio*(hi-lo),x2=lo+ratio*(hi-lo);
      let f1=outletRetention(direction*x1,{direction}),f2=outletRetention(direction*x2,{direction});
      for(let i=0;i<80&&hi-lo>1e-12;i++) {
        if(f1<f2){hi=x2;x2=x1;f2=f1;x1=hi-ratio*(hi-lo);f1=outletRetention(direction*x1,{direction});}
        else {lo=x1;x1=x2;f1=f2;x2=lo+ratio*(hi-lo);f2=outletRetention(direction*x2,{direction});}
      }
      const magnitude=(lo+hi)/2,units=outletRetention(direction*magnitude,{direction});
      return {angle:direction*magnitude,degrees:direction*degrees(magnitude),units,areaPx2:units*unitArea,exactEmptyReachable:units===0};
    }
    function surfaceSegments(angle,h,opts={}) {
      finite(h,'h');
      const alphaThreshold=opts.alphaThreshold===undefined?1/255:opts.alphaThreshold;
      const [s,c]=trig(angle),intervals=[];
      for(const r of rectangles) {
        if(r.alpha<alphaThreshold)continue;
        const corners=[[r.x,r.y],[r.x+r.w,r.y],[r.x+r.w,r.y+r.h],[r.x,r.y+r.h]];
        const points=[];
        for(let i=0;i<4;i++) {
          const a=corners[i],b=corners[(i+1)%4];
          const da=s*(a[0]-pivot[0])+c*(a[1]-pivot[1])-h;
          const db=s*(b[0]-pivot[0])+c*(b[1]-pivot[1])-h;
          if(Math.abs(da)<1e-10)points.push(pointToWorld(a,angle)[0]);
          if(da*db<0){const t=da/(da-db);points.push(pointToWorld([a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])],angle)[0]);}
        }
        if(points.length>1)intervals.push([Math.min(...points),Math.max(...points)]);
      }
      intervals.sort((a,b)=>a[0]-b[0]);
      const merged=[];
      for(const interval of intervals){const prev=merged[merged.length-1];if(prev&&interval[0]<=prev[1]+1e-8)prev[1]=Math.max(prev[1],interval[1]);else merged.push(interval.slice());}
      return merged.filter(a=>a[1]-a[0]>1e-10).map(([left,right])=>({world:[[left,h],[right,h]],local:[pointToLocal([left,h],angle),pointToLocal([right,h],angle)],length:right-left}));
    }
    function surfaceChord(angle,h,opts={}) {
      const segments=surfaceSegments(angle,h,opts);
      if(!segments.length)return null;
      const world=[segments[0].world[0],segments[segments.length-1].world[1]];
      return {world,local:world.map(p=>pointToLocal(p,angle)),length:world[1][0]-world[0][0],segments,bridgesDisjointSegments:segments.length>1};
    }
    function conservedTransfer(progress,opts={}) {
      finite(progress,'progress');
      const sourceStart=opts.sourceStart===undefined?1:opts.sourceStart;
      const receiverStart=opts.receiverStart===undefined?2:opts.receiverStart;
      const transferUnits=opts.transferUnits===undefined?1:opts.transferUnits;
      if(sourceStart<0||receiverStart<0||sourceStart>CAPACITY_UNITS||receiverStart>CAPACITY_UNITS||transferUnits<0||transferUnits>sourceStart||receiverStart+transferUnits>CAPACITY_UNITS)throw new RangeError('Invalid capacity-4 transfer');
      const transferred=clamp(progress,0,1)*transferUnits;
      const sourceUnits=sourceStart-transferred;
      const receiverUnits=sourceStart+receiverStart-sourceUnits;
      return {sourceUnits,receiverUnits,transferred,totalUnits:sourceUnits+receiverUnits};
    }
    return {width,height,pivot,capacityUnits:CAPACITY_UNITS,unitAreaPx2:unitArea,fullAreaPx2:fullArea,fullCavityUnits:fullUnits,rectangles,
      pointToWorld,pointToLocal,areaBelowPlane,volumeBelowPlane,solvePlane,outletPlane,outletRetention,solvePourAngle,minimumOutletRetention,surfaceSegments,surfaceChord,conservedTransfer,
      exportGeometry:()=>({width,height,pivot:pivot.slice(),unitArea,rectangles:rectangles.map(r=>({...r}))})};
  }
  async function loadCavitySolver(maskPath,options={}) {
    if(typeof require!=='function')throw new Error('loadCavitySolver is Node-only; browser callers should use createCavitySolver with RGBA or exported rectangles');
    const {createCanvas,loadImage}=require('@napi-rs/canvas');
    const image=await loadImage(maskPath),canvas=createCanvas(image.width,image.height),ctx=canvas.getContext('2d');
    ctx.drawImage(image,0,0);
    return createCavitySolver({width:image.width,height:image.height,rgba:ctx.getImageData(0,0,image.width,image.height).data,...options});
  }
  return {createCavitySolver,loadCavitySolver,rgbaToRectangles,uniformSumCdf,radians,degrees,CAPACITY_UNITS,UNIT_AREA_PX2,PIVOT,RIGHT_LIP,LEFT_LIP};
});
