import assert from 'node:assert/strict';
import G from '../engine/geometry/grid_surface.bend';
import T from './grid-surface.bend';
const close=(a,b,message)=>assert.ok(Math.abs(a-b)<1e-5,`${message}: ${a} != ${b}`);
for(const [x,y] of [[1,1],[2.25,3.75],[5.5,4.125],[6,6]]) {
  const r=T.sample(x,y),s=r.snd;
  assert.equal(r.fst,16,'one bounded 4x4 neighborhood');
  for(const [k,v] of Object.entries({x,y:2*x+3*y,z:y})) close(s.point[k],v,'planar sample');
  for(const [k,v] of Object.entries({x:1,y:2,z:0})) close(s.du[k],v,'u derivative');
  for(const [k,v] of Object.entries({x:0,y:3,z:1})) close(s.dv[k],v,'v derivative');
}
for(let y=0;y<8;y++) for(let x=0;x<8;x++) {
  const s=T.sample(x,y).snd;
  close(s.point.x,x,'interpolates grid x');close(s.point.y,2*x+3*y,'interpolates grid height');close(s.point.z,y,'interpolates grid z');
  for(const p of [s.point,s.du,s.dv]) for(const k of ['x','y','z']) assert.ok(Number.isFinite(p[k]));
}
for(let base=0;base<8;base++) for(let k=0;k<4;k++) assert.ok(G.index(8,base,k)<8,'clamped boundary address');
console.log('PASS: generic grid surface interpolation, analytic normals, edge clamping and bounded reads.');

for(const [x,y] of [[-2,3],[3,20],[-1,-1],[50,50]]) {
  const got=T.sample(x,y).snd.point,expected=T.sample(Math.min(7,Math.max(0,x)),Math.min(7,Math.max(0,y))).snd.point;
  assert.deepEqual(got,expected,'out-of-domain queries clamp to the finite grid');
}
