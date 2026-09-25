import assert from 'node:assert/strict';
import P from '../demos/cloth/physics.bend';
import W from '../demos/cloth/world.bend';
import V from '../demos/cloth/view.bend';
import Input from '../demos/cloth/input.bend';
import S from '../demos/cloth/simulation.bend';
const point=(x,y,z)=>({$:'Point',x,y,z});
const controls={$:'Controls',side:8,grab:0xffffffff,gx:0,gy:0,gz:0,time:0,wind:0};
const rest=W.create(3n), saved=structuredClone(rest);
const r=P.predict_run(false,3n,64,{$:'Prediction',current:rest,previous:structuredClone(rest),output:W.empty(6n),controls});
for(const k of ['x','y','z']) {assert.deepEqual(r.current[k],saved[k]);assert.deepEqual(r.previous[k],saved[k]);}
for(let i=0;i<64;i++) {
  assert.equal(r.output.x[i],rest.x[i]);assert.equal(r.output.z[i],rest.z[i]);
  assert.ok(Math.abs(r.output.y[i]-(1.55-(i===0||i===63?0:9.81/120**2)))<1e-6,'gravity and pinned corners');
}
const center=P.contact(point(0,-.25,0));assert.ok(Math.hypot(center.x,center.y+.25,center.z)>=1.22-1e-6);
assert.equal(P.contact(point(4,-10,4)).y,Math.fround(-1.6));
const zero={$:'Correction',x:0,y:0,z:0,count:0};
const delta={$:'Delta',x:0,y:0,z:0,squared:0};
const a=P.collision(0,point(0,0,0),63,point(0,0,0),delta,controls,zero);
const b=P.collision(63,point(0,0,0),0,point(0,0,0),delta,controls,zero);
assert.ok(a.x<0 && b.x>0 && Math.abs(a.x+b.x)<1e-6,'coincident distant vertices separate antisymmetrically');
const adjacent=P.collision(1,point(0,0,0),2,point(0,0,0),delta,controls,zero);
assert.equal(adjacent.count,0,'connected vertices excluded from self-contact');
const mouse=V.project(W.rest(8,35));
const picked=Input.pick(64,mouse.x,mouse.y,W.create(3n));assert.equal(picked.snd.id,35);
const unprojected=V.target(mouse.x,mouse.y,mouse.z);
const original=W.rest(8,35);
for(const k of ['x','y','z']) assert.ok(Math.abs(unprojected[k]-original[k])<2e-6,'perspective pick/unproject roundtrip');


assert.equal(S.create(0n).$, 'Fail');assert.equal(S.create(9n).$, 'Fail');
const grabbed=P.constrained(35,{...controls,grab:35,gx:2,gy:1,gz:2},point(0,0,0));
assert.deepEqual([grabbed.x,grabbed.y,grabbed.z],[2,1,2]);
const fixed=P.constrained(0,{...controls,grab:0,gx:2,gy:1,gz:2},point(0,0,0));
assert.ok(Math.abs(fixed.x+1.8)<1e-6 && Math.abs(fixed.y-1.55)<1e-6,'pinned corners remain fixed during dragging');

console.log('PASS: cloth gravity, pinned corners, sphere/floor contact, coincident self-contact, source ownership and perspective picking.');
