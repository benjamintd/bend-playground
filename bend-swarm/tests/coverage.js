import assert from 'node:assert/strict';
import C from '../engine/render/coverage.bend';
import T from './mesh.bend';
const triangles=T.fixture(),saved=structuredClone(triangles),ids=triangles.map((_,i)=>i);
function sample(x,y) {
  let depth=1000,color=66051;
  for(const t of triangles) {
    const {a,b,c:q}=t;if(Math.min(a.z,b.z,q.z)<=.1)continue;
    const den=(b.y-q.y)*(a.x-q.x)+(q.x-b.x)*(a.y-q.y);if(Math.abs(den)<.00001)continue;
    const u=((b.y-q.y)*(x-q.x)+(q.x-b.x)*(y-q.y))/den;
    const v=((q.y-a.y)*(x-q.x)+(a.x-q.x)*(y-q.y))/den,w=1-u-v;if(Math.min(u,v,w)<-1e-12)continue;
    const z=1/(u/a.z+v/b.z+w/q.z);
    if(z<depth){depth=z;color=t.color;}else if(z===depth)color=Math.max(color,t.color);
  }
  return {depth,color};
}
let probes=0;
for(const x of [127.25,127.5,127.75,128,180.25,200.5,255.5,280.75,383.25,383.75,384])
 for(const y of [127.25,127.5,127.75,128,160.25,200.5,240.5,255.5,280.25,383.75,384]) {
  const samples=[[-.125,-.375],[.375,-.125],[-.375,.125],[.125,.375]].map(([dx,dy])=>sample(x+dx,y+dy));
  const got=C.query(ids.length,0,x,y,triangles,ids,{$:'Fragment',depth:1000,color:66051}).result;
  const channels=[16,8,0].map(shift=>Math.floor(samples.reduce((sum,p)=>sum+((p.color>>>shift)&255),0)/4));
  for(const [i,shift] of [16,8,0].entries())assert.ok(Math.abs(((got.color>>>shift)&255)-channels[i])<=1,`${x},${y},${shift}`);
  assert.ok(Math.abs(got.depth-Math.min(...samples.map(s=>s.depth)))<.00001);
  probes++;
 }
assert.deepEqual(triangles,saved,'coverage only reads source triangles');
console.log(`PASS: ${probes} four-sample pixels against independent subpixel depth/coverage equations, edges and occlusion.`);

// A moving axis-aligned edge now visits all four quarter-coverage levels.
// Compare coverage with exact pixel area over all phases, rather than merely
// checking the implementation's chosen sample offsets.
const vertex=(x,y)=>({$:'Vertex',x,y,z:2,light:1});
let newError=0,oldError=0;
for(const horizontal of [false,true]) for(let i=0;i<256;i++) {
  const phase=(i+.5)/256;
  const pts=[[-10,-10],[phase,-10],[phase,10],[-10,10]].map(([x,y])=>horizontal?vertex(y,x):vertex(x,y));
  const ts=[{$:'Triangle',a:pts[0],b:pts[1],c:pts[2],color:0xffffff},{$:'Triangle',a:pts[0],b:pts[2],c:pts[3],color:0xffffff}];
  const c=C.query(2,0,.5,.5,ts,[0,1],{$:'Fragment',depth:1000,color:0}).result.color&255;
  const oldCoverage=phase<.25?0:phase<.75?.5:1;
  newError+=(c/255-phase)**2;oldError+=(oldCoverage-phase)**2;
}
assert.ok(newError<oldError*.3,'rotated samples reduce horizontal and vertical moving-edge area error');
console.log(`PASS: moving-edge squared error ${(100*(1-newError/oldError)).toFixed(1)}% lower over 512 phases.`);
