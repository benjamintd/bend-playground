import assert from 'node:assert/strict';
import T from './cloth-visual.bend';
import W from '../demos/cloth/world.bend';
const r=T.projected();
assert.equal(r.side,32);
const source=W.create(5n);
for(const k of ['x','y','z']) assert.deepEqual(r.positions[k],source[k],'visual tessellation preserves the physical grid');
assert.equal(r.triangles.length,16384);
const cache=r.triangles.slice(8192,12288).map(t=>t.a);
for(const v of cache) for(const k of ['x','y','z','light']) assert.ok(Number.isFinite(v[k]));
for(let i=0;i<7938;i++) {
  const quad=i>>>1,base=quad%63+Math.floor(quad/63)*64;
  const ids=i%2?[base,base+65,base+64]:[base,base+1,base+65];
  for(const [k,j] of ['a','b','c'].map((k,j)=>[k,j])) assert.deepEqual(r.triangles[i][k],cache[ids[j]],'assembly reads cached vertices without overwriting them');
}
for(let i=7938;i<8192;i++) assert.equal(r.triangles[i].color,0,'guard range untouched');
console.log('PASS: 7938 interpolated triangles, immutable 1024-point physics, disjoint projected cache and assembly.');
