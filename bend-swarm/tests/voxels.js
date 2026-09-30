import assert from 'node:assert/strict';
import W from '../engine/voxel/world.bend';
const p=(x,y,z)=>({$:'Point',x,y,z});
const xyz=(a,b)=>['x','y','z'].forEach(k=>assert.equal(a[k]+0,b[k]+0));
let world=W.create(8,8,8).value;
world=W.write(world,p(3,3,3),2);
const snapshot=structuredClone(world.cells);
const cast=(o,d,min=0,max=100)=>{
  const l=Math.hypot(d.x,d.y,d.z),ray={$:'Ray',origin:o,direction:p(d.x/l,d.y/l,d.z/l),minimum:min,maximum:max};
  const r=W.raycast(world,ray);world=r.fst;assert.deepEqual(world.cells,snapshot);return r.snd;
};
for(const [o,d,normal,t] of [
  [p(-2,3.5,3.5),p(1,0,0),p(-1,0,0),5],
  [p(10,3.5,3.5),p(-1,0,0),p(1,0,0),6],
  [p(3.5,10,3.5),p(0,-1,0),p(0,1,0),6],
  [p(3.5,3.5,-2),p(0,0,1),p(0,0,-1),5],
  [p(4,3.5,3.5),p(-1,0,0),p(0,0,0),0]
]) {const hit=cast(o,d);assert.equal(hit.$,'Some');xyz(hit.value.cell,p(3,3,3));xyz(hit.value.normal,normal);assert.ok(Math.abs(hit.value.distance-t)<1e-5);}
assert.equal(cast(p(-1,2.5,3.5),p(1,0,0)).$,'None');
assert.equal(cast(p(-1,3.5,3.5),p(-1,0,0)).$,'None');
assert.equal(cast(p(-1,3.5,3.5),p(1,0,0),0,3).$,'None');
assert.equal(cast(p(8,3.5,3.5),p(0,0,1)).$,'None');
assert.equal(cast(p(3.5,3.5,3.5),p(0,1,0)).value.distance,0);
// Oracle intersects every occupied unit box, independent of grid traversal.
let seed=71; const random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/2**32);
const occupied=[];
world=W.create(8,8,8).value;
for(let z=0;z<8;z++)for(let y=0;y<8;y++)for(let x=0;x<8;x++) if(random()<.12){occupied.push(p(x,y,z));world=W.write(world,p(x,y,z),1);}
for(let j=0;j<250;j++) {
  const o=p(random()*14-3,random()*14-3,random()*14-3),target=p(random()*8,random()*8,random()*8);
  const delta=p(target.x-o.x,target.y-o.y,target.z-o.z),l=Math.hypot(delta.x,delta.y,delta.z),d=p(delta.x/l,delta.y/l,delta.z/l);
  let nearest=Infinity,cell;
  for(const c of occupied) {
    let lo=0,hi=100;
    for(const k of ['x','y','z']) {let a=(c[k]-o[k])/d[k],b=(c[k]+1-o[k])/d[k];lo=Math.max(lo,Math.min(a,b));hi=Math.min(hi,Math.max(a,b));}
    if(lo<=hi&&lo<nearest){nearest=lo;cell=c;}
  }
  const r=W.raycast(world,{$:'Ray',origin:o,direction:d,minimum:0,maximum:100});world=r.fst;
  assert.equal(r.snd.$,cell?'Some':'None',JSON.stringify({ray:j,origin:o,direction:d,expected:cell,distance:nearest}));
  if(cell){xyz(r.snd.value.cell,cell);assert.ok(Math.abs(r.snd.value.distance-nearest)<.0001);}
}
console.log('PASS: bounded voxel edits, axis/inside/boundary rays, distance limits, ownership and 250 independent nearest-box oracle rays.');
assert.equal(W.create(0,8,8).$,'None');assert.equal(W.create(0xffffffff,8,8).$,'None');
assert.equal(W.create(1024,1024,1024).$,'None');
let thin=W.write(W.create(8,8,8).value,p(0,3,3),1);
const nearParallel={$:'Ray',origin:p(-.00000005,3.5,-2),direction:p(.00000001,0,1),minimum:0,maximum:20};
assert.equal(W.raycast(thin,nearParallel).snd.$,'Some','small nonzero ray components remain meaningful');
let boundary=W.write(W.create(8,8,8).value,p(3,3,3),1);
const insideEdge={$:'Ray',origin:p(3.999998,3.5,3.5),direction:p(1,0,0),minimum:0,maximum:1};
assert.equal(W.raycast(boundary,insideEdge).snd.value.distance,0,'near-integer origins remain in their occupied cell');
