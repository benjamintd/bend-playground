import assert from 'node:assert/strict';
import API from './spatial-api.bend';
function points(seed) {
  let s=seed;
  const rnd=()=>((s=(Math.imul(s,1664525)+1013904223)>>>0)/2**32);
  return {$:'Points',x:Array.from({length:32},()=>Math.fround(rnd()*8-4)),
    y:Array.from({length:32},()=>Math.fround(rnd()*8-4)),z:Array.from({length:32},()=>Math.fround(rnd()*8-4))};
}
export function masks(p,n,radius,includeSelf,span) {
  let accepted=0;
  const out=Array(32).fill(0);
  for(let i=0;i<n;i++) for(let j=0;j<n;j++) {
    let d2=0;
    for(let axis=0;axis<3;axis++) {
      const size=span?.[axis]; if(size===0) continue;
      let d=p[['x','y','z'][axis]][j]-p[['x','y','z'][axis]][i];
      if(size) d-=Math.floor(d/size+.5)*size;
      d2+=d*d;
    }
    if((includeSelf || i!==j) && d2<radius*radius) {out[i]=(out[i]|(1<<j))>>>0;accepted++;}
  }
  return {out,accepted};
}
for(const [name,span] of [['periodic',[4,4,0]],['bounded',null],['tiny',[2,1,2]]])
for(const n of [0,1,13,32]) for(const radius of [0,.2,1,2.4,10]) for(const includeSelf of [false,true]) {
  const p=points(132+n), before=structuredClone(p), expected=masks(p,n,radius,includeSelf,span);
  const r=API[name](false,n,radius,includeSelf,p);
  assert.equal(r.$,'Done',`${name}/${n}/${radius}`);
  assert.deepEqual(r.value.output,expected.out,`${name}/${n}/${radius}/${includeSelf}`);
  assert.equal(r.value.neighbors,BigInt(expected.accepted));
  assert.ok(r.value.checks<=BigInt(n*n),'wrapped cells must not duplicate candidate visits');
  assert.deepEqual(r.value.snapshot.source,before,'source is read-only');
  assert.equal(r.value.snapshot.index.offsets.at(name==='periodic'?16:name==='tiny'?4:64),n);
  assert.deepEqual(r.value.snapshot.index.ids.slice(0,n).sort((a,b)=>a-b),Array.from({length:n},(_,i)=>i));
}
for(const radius of [-1,NaN,Infinity]) assert.equal(API.periodic(false,1,radius,false,points(1)).$,'Fail');
assert.equal(API.periodic(false,33,1,false,points(1)).$,'Fail');
assert.equal(API.bad_layout().$,'Fail');
assert.equal(API.capacity(21n).$,'Fail');
console.log('PASS: generic 2D/3D spatial membership, large radii, bounded/periodic domains, tiny axes, empty/partial populations, ownership and rejected inputs (120 scenes).');
