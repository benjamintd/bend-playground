import assert from 'node:assert/strict';
import F from '../../demos/turn/physics.bend';
import P from '../../demos/turn/play.bend';
import L from '../../demos/turn/levels.bend';
import C from '../../demos/turn/collision.bend';
const point=(x,y,z)=>({$:'model.Point',x,y,z}),input={ $:'physics.Input',left:true,right:false,fast:true };
const planes=['XY','YZ','ZX'].map(p=>({$:`model.${p}`}));
const coords=q=>[q.x,q.y,q.z];
const world=(p,q)=>p.$==='model.XY'?q:p.$==='model.YZ'?point(q.z,q.x,q.y):point(q.y,q.z,q.x);
const local=(p,q)=>p.$==='model.XY'?q:p.$==='model.YZ'?point(q.y,q.z,q.x):point(q.z,q.x,q.y);
const make=q=>({$:'physics.Body',position:q,vx:2074,vy:2120,coyote:8,buffer:12,escape:0});
let escapes=0,maxTicks=0,downward=0,fallback=0;
for(let level=0;level<L.count();level++)for(const plane of planes)for(let y=0;y<10;y++)for(let x=0;x<10;x++){
 const q=world(plane,point(x*1024+512,y*1024+512,4608));
 const clear=F.clear(level,plane,q);let b=F.rotated(level,plane,make(q));
 assert.deepEqual(b.position,q,'rotation starts at the same exact point');
 assert.equal(F.settled(b),clear,'only intersecting rotations enable escape');
 if(clear)continue;
 escapes++;
 const tx=(b.escape-1)%16384,ty=Math.floor((b.escape-1)/16384);
 const certified=C.cell(level,plane,world(plane,point(x,y,4)));
 const expected=local(plane,certified);
 assert.deepEqual([tx,ty],[expected.x*1024+512,expected.y*1024+512],'cell certificate matches the continuous resolver at every occupied cell center');
 const isDown=ty<y*1024+512&&tx===x*1024+512;
 if(isDown)downward++;else fallback++;
 let ticks=0;
 while(!F.settled(b)&&ticks<240){
  assert.deepEqual(F.request(b),b,'jump cannot alter automatic settling');
  const previous=b;b=F.step(level,plane,input,b);ticks++;
  assert.ok(F.bounded(b.position));assert.ok(F.nearby(previous.position,b.position));
  const displacement=coords(b.position).map((n,i)=>Math.abs(n-coords(previous.position)[i]));
  assert.ok(displacement.every(n=>n<=128),'independent per-axis movement bound');
  assert.ok(Math.hypot(...displacement)<1024);
  const here=local(plane,b.position),old=local(plane,previous.position);
  assert.equal(here.z,4608,'hidden coordinate stays fixed');
  if(isDown){assert.equal(here.x,old.x);assert.ok(here.y<=old.y,'falling cannot climb or steer');}
  // The first clear position ends the phase immediately: a subsequent wall
  // is solid again, rather than being included in a broad ghosting interval.
  assert.equal(F.settled(b),F.clear(level,plane,b.position));
 }
 assert.ok(F.settled(b),`level ${level} ${plane.$} ${x},${y}: finite settling`);
 maxTicks=Math.max(maxTicks,ticks);
 for(let i=0;i<20;i++){b=F.step(level,plane,input,b);assert.ok(F.clear(level,plane,b.position));}
}
assert.ok(downward>0&&fallback>0);
let p=P.create(0);p.body={...make(point(9728,9728,512)),escape:1};
assert.equal(P.arrived(p),false,'escaping through the exit is not a victory');
assert.equal(P.collect(p).seals,0,'escaping through a seal cannot collect it');
console.log(`PASS: ${escapes} intersecting poses across all 26 levels and all planes settle in at most ${maxTicks} ticks (${downward} downward, ${fallback} boundary escapes); bounded motion, no teleport, no steering, collisions resume at first air.`);
