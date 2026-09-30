import assert from 'node:assert/strict';
import F from '../../demos/turn/physics.bend';
import P from '../../demos/turn/play.bend';
import L from '../../demos/turn/levels.bend';
import C from '../../demos/turn/projection.bend';
const xyz=q=>[q.x,q.y,q.z],point=([x,y,z])=>({$:'model.Point',x,y,z});
const world=(p,q)=>p.$==='model.XY'?q:p.$==='model.YZ'?point([q.z,q.x,q.y]):point([q.y,q.z,q.x]);
const xy={$:'model.XY'},input=(left=false,right=false,fast=false)=>({$:'Input',left,right,fast});
const key=(p,code,down=true)=>P.key(code,down,p),press=(p,code)=>key(key(p,code),code,false);
const body=(q,vx=0,vy=0)=>({$:'Body',position:point(q),vx:vx+2048,vy:vy+2048,coyote:0,buffer:0,escape:0});
// Independent silhouettes enumerate all world cubes; runtime row masks are
// never consulted by this oracle.
const axes={ 'model.XY':[0,1], 'model.YZ':[1,2], 'model.ZX':[2,0] };
const silhouette=Array.from({length:L.count()},(_,level)=>Object.fromEntries(Object.entries(axes).map(([plane,[a,b]])=>{
 const set=new Set();for(let x=0;x<10;x++)for(let y=0;y<10;y++)for(let z=0;z<10;z++){
  if(L.solid(level,point([x,y,z]))){const q=[x,y,z];set.add(q[a]+q[b]*10);}
 }return [plane,set];
})));
function clear(level,plane,q){
 const v=xyz(q);if(v.some(n=>n<256||n>9984))return false;
 const [a,b]=axes[plane.$];
 for(let u=Math.floor((v[a]-256)/1024);u<=Math.floor((v[a]+255)/1024);u++)
  for(let w=Math.floor((v[b]-256)/1024);w<=Math.floor((v[b]+255)/1024);w++)
   if(silhouette[level][plane.$].has(u+w*10))return false;
 return true;
}
// The entire projected column is solid at every hidden depth, in every view.
for(let level=0;level<L.count();level++)for(const name of Object.keys(axes)){
 const plane={$:name},[a,b]=axes[name],hidden=[0,1,2].find(i=>i!==a&&i!==b);
 for(let u=0;u<10;u++)for(let v=0;v<10;v++)for(const depth of [256,512,2048,5500,9984]){
  const q=[0,0,0];q[a]=u*1024+512;q[b]=v*1024+512;q[hidden]=depth;
  assert.equal(F.clear(level,plane,point(q)),clear(level,plane,point(q)),'all depth layers share the projected collider');
 }
}
function swept(level,plane,vertical,q,velocity){
  const old=xyz(q),axis=axes[plane.$][+vertical],delta=velocity-2048,dir=Math.sign(delta);
  const full=old.slice();full[axis]=Math.max(256,Math.min(9984,old[axis]+delta));
  if(clear(level,plane,point(full)))return full;
  let lo=0,hi=Math.abs(full[axis]-old[axis]);
  while(lo<hi){const mid=Math.ceil((lo+hi)/2),test=old.slice();test[axis]+=mid*dir;if(clear(level,plane,point(test)))lo=mid;else hi=mid-1;}
  old[axis]+=lo*dir;return old;
}
function checkStep(level,plane,control,b){
  const old=xyz(b.position),next=F.step(level,plane,control,b);
  assert.ok(clear(level,plane,next.position),'character box never overlaps a wall');
  const delta=xyz(next.position).map((n,i)=>Math.abs(n-old[i]));
  assert.ok(Math.max(...delta)<=128,'hard per-axis displacement bound');
  assert.ok(Math.hypot(...delta)<1024,'less than one whole cell per physics step');
  return next;
}
// A free jump has constant vertical acceleration: no animation-only path.
let b=F.request(F.initial()),ys=[];
for(let i=0;i<40;i++){b=checkStep(0,xy,input(),b);ys.push(b.position.y);assert.equal(b.position.x,512);}
for(let i=2;i<ys.length;i++)assert.equal(ys[i]-2*ys[i-1]+ys[i-2],-2,'a parabola during unobstructed flight');
assert.ok(Math.max(...ys)>1800);
for(let i=0;i<60;i++)b=checkStep(0,xy,input(),b);assert.equal(b.position.y,256,'lands on floor');
// Wall contact resolves to the face, not to cell centers.
b=F.initial();for(let i=0;i<60;i++)b=checkStep(0,xy,input(false,true),b);assert.equal(b.position.x,768);
b=F.request(b);for(let i=0;i<100;i++)b=checkStep(0,xy,input(false,true),b);
assert.equal(b.position.y,1280,'lands on top of a one-cell block');assert.equal(b.position.x,1792);
// Regression: the first staircase cannot be crossed in front or behind.
for(const z of [256,1536,4608,9984]){
 let q=body([512,256,z]);for(let i=0;i<70;i++)q=checkStep(0,xy,input(false,true),q);
 assert.equal(q.position.x,768,'same wall face at every hidden depth');
}
// Find a clear flat two-cell gap in the authored silhouettes, then exercise
// the real jump arc across it. Also locate an actual low ceiling fixture.
let gapChecked=false,ceilingChecked=false;
for(let level=0;level<L.count();level++)for(const name of Object.keys(axes)){
 const plane={$:name},cells=silhouette[level][name];
 for(let y=0;y<7;y++)for(let x=0;x<8;x++){
  if(!gapChecked&&cells.has(x+y*10)&&!cells.has(x+1+y*10)&&cells.has(x+2+y*10)
   &&[0,1,2].every(dx=>[1,2].every(dy=>!cells.has(x+dx+(y+dy)*10)))){
   let q=F.request(body(xyz(world(plane,point([x*1024+512,(y+1)*1024+256,4608])))));
   const target=(x+2)*1024+512;
   for(let i=0;i<150;i++){
    const u=xyz(q.position)[axes[name][0]];
    q=checkStep(level,plane,input(false,u<target-60),q);
   }
   assert.equal(Math.floor(xyz(q.position)[axes[name][0]]/1024),x+2);
   assert.equal(xyz(q.position)[axes[name][1]],(y+1)*1024+256,'flat two-cell gap landing');gapChecked=true;
  }
  if(!ceilingChecked&&cells.has(x+(y+1)*10)&&!cells.has(x+y*10)&&(y===0||cells.has(x+(y-1)*10))){
   let q=F.request(body(xyz(world(plane,point([x*1024+512,y*1024+256,4608]))))),peak=0;
   for(let i=0;i<90;i++){q=checkStep(level,plane,input(),q);peak=Math.max(peak,xyz(q.position)[axes[name][1]]);}
   assert.equal(peak,(y+1)*1024-256,'projected ceiling stops the head at its face');ceilingChecked=true;
  }
 }
}
assert.ok(gapChecked,'campaign contains a tested flat gap');assert.ok(ceilingChecked,'campaign contains a tested low ceiling');
b=F.request(body([512,3072,3584]));b=checkStep(0,xy,input(),b);assert.equal(b.vy,2046,'no double jump');
let p=P.create(3);p=key(p,114);p=key(p,114);assert.equal(p.turns,1,'rotation is edge triggered');
p=P.steps(80n,p);assert.equal(p.time,0,'physics freezes throughout the camera turn');assert.equal(p.plane.$,'model.XY');
p=P.steps(BigInt(P.rotation_ticks()-80),p);assert.equal(p.turn,0);assert.equal(p.plane.$,'model.YZ');
p=press(P.create(0),114);assert.equal(p.turn,1,'rotation into the staircase is allowed');
p=P.steps(BigInt(P.rotation_ticks()),p);assert.equal(p.plane.$,'model.YZ');assert.ok(p.body.escape,'embedded body starts automatic settling');
assert.equal(P.can_turn(p),true,'a frozen chain may cross an embedded intermediate view');
p=press(p,63233);
for(let i=0;i<240&&!F.settled(p.body);i++)p=P.step(p);
assert.ok(F.settled(p.body));assert.ok(clear(0,p.plane,p.body.position));
assert.equal(p.body.position.x,512,'settling preserves hidden depth');
for(const plane of ['XY','YZ','ZX']){
  p=P.create(0);p.plane={$:`model.${plane}`};p.body=body([9472,9728,9670]);assert.ok(P.arrived(p),'projected exit works in every plane');
  const old=xyz(p.body.position);p=P.steps(10n,key(p,100));assert.deepEqual(xyz(p.body.position),old,'victory stops motion');
  p=press(p,110);assert.equal(p.level,L.next(0));
}
// Completion advances without another key; the last level stays completed.
for(let level=0;level<L.count();level++)for(const plane of ['XY','YZ','ZX']){
  p=P.create(level);p.plane={$:`model.${plane}`};p.body=body([9472,9728,9670]);
  p=key(p,100);p=P.steps(119n,p);
  assert.equal(p.level,level,'show completion for one second');assert.ok(P.arrived(p));
  p=P.steps(1n,p);
  if(!L.last(level)){
    assert.equal(p.level,L.next(level),'exit automatically opens next level');
    assert.deepEqual(xyz(p.body.position),[512,256,512]);assert.equal(p.keys,0);assert.equal(p.turns,0);
    assert.equal(p.plane.$,'model.XY');assert.equal(P.arrived(p),false);
    p=P.steps(240n,p);assert.equal(p.level,L.next(level),'advance only once');
    assert.equal(p.body.position.x,512,'held movement cannot carry into the next level');
  }else{
    p=P.steps(240n,p);assert.equal(p.level,level);assert.ok(P.arrived(p),'final victory stays visible');
    p=press(p,110);assert.equal(p.level,L.at(0),'N replays after completing all levels');
  }
}
assert.equal(press(P.create(0),110).level,0,'N cannot skip an unfinished level');
// Native arrow codes are distinct held keys, so releasing one alias does not
// cancel another key that is still down.
for(const [arrow,letter] of [[63234,97],[63235,100],[63232,119],[63233,115]]){
  let a=key(P.create(1),arrow),b=key(P.create(1),letter);
  for(let i=0;i<20;i++){a=P.step(a);b=P.step(b);assert.deepEqual(a.body,b.body,'arrow matches its existing control');}
}
p=key(key(P.create(1),63235),100);p=key(p,63235,false);p=P.steps(5n,p);
assert.ok(p.body.position.x>512,'releasing Right preserves held D');
p=key(key(P.create(1),100),63235);p=key(p,100,false);p=P.steps(5n,p);
assert.ok(p.body.position.x>512,'releasing D preserves held Right');
p=key(P.create(1),63232);p=P.step(p);p=key(p,63232);assert.equal(p.body.buffer,0,'repeated Up does not request another jump');
for(const name of ['XY','YZ','ZX'])for(const depth of [256,512,4608,9984]){
  const plane={$:`model.${name}`},q=world(plane,point([9472,9472,depth]));
  for(const x of [9472,9728,9984])for(const y of [9472,9728,9984])
    assert.ok(F.exit(plane,world(plane,point([x,y,depth]))),'body touches the exit center from any side, at any depth');
  for(const [x,y] of [[8960,8960],[9300,9450],[9471,9728],[9728,9471],[9985,9728],[9728,9985]]){
    const outside=world(plane,point([x,y,depth]));
    assert.equal(F.exit(plane,outside),false,'cell contact without center contact is not victory');
    p=P.create(17);p.plane=plane;p.body=body(xyz(outside));
    assert.equal(P.arrived(p),false,'no premature completion');
  }
  p=P.create(17);p.plane=plane;p.body=body(xyz(q));p.seals=0;
  assert.ok(P.arrived(p),'seals never lock the projected exit');
}
// Walk through the former trigger without stopping; finish only when the body
// reaches the center point, then freeze at that actual contact position.
p=P.create(0);p.body=body([9300,9472,512]);p=key(p,100);
for(let i=0;i<100&&!P.arrived(p);i++){
  assert.ok(p.body.position.x<9472);p=P.step(p);
}
assert.ok(P.arrived(p));assert.ok(p.body.position.x>=9472&&p.body.position.x<9498);
const centerContact=xyz(p.body.position);p=P.steps(10n,p);
assert.deepEqual(xyz(p.body.position),centerContact);
// Once contact completes a level, an in-progress turn cannot undo completion.
p=P.create(0);p.turn=83;p.body=body([9472,9472,512]);p=P.step(p);
const contact=xyz(p.body.position);p=P.steps(10n,p);
assert.ok(P.arrived(p));assert.deepEqual(xyz(p.body.position),contact);
p=press(P.create(0),119);p=P.steps(1n,p);assert.ok(p.body.position.y>256,'W jumps');
p=press(p,127);assert.equal(p.body.position.y,256,'native Backspace resets');
// Both Backspace encodings recover a stranded or mid-turn room completely,
// while retaining the player's chapter completion marks.
for(let level=0;level<L.count();level++)for(const code of [8,127]){
  let stuck=P.create(level);stuck.body=body([7000,256,7000],18,-30);
  stuck.plane={$:'model.YZ'};stuck.turn=47;stuck.slow=3;stuck.time=900;
  stuck.turns=12;stuck.seals=L.all_seals(level);stuck.keys=63;stuck.finished=45;
  stuck.pace=1;stuck.accumulator=.007;stuck.completed=L.flag(0);stuck.body.escape=1+512+16384*1536;
  const expected=P.create(level);expected.completed=L.flag(0);
  assert.deepEqual(press(stuck,code),expected,'restart keeps this chapter and past completions, clears all attempt state');
}
// Mixed controls and rotations, tested against independent geometric sweeps.
let random=51,checked=0;
const rand=()=>{random=(Math.imul(random,1664525)+1013904223)>>>0;return random;};
for(let level=0;level<L.count();level++){
  p=P.create(level);
  for(let i=0;i<1000;i++){
    if(P.arrived(p))p=P.create(level);
    if(i%45===0){p=key(p,97,rand()%3===0);p=key(p,100,rand()%3===0);}
    if(i%67===0)p=press(p,32);if(i%211===0)p=press(p,114);
    const previous=p.body.position;
    if(F.settled(p.body))for(const vertical of [false,true])for(const velocity of [1948,2074,2148])
      assert.deepEqual(xyz(F.axis(level,p.plane,vertical,previous,velocity)),swept(level,p.plane,vertical,previous,velocity),'exact voxel face matches independent binary-search sweep');
    p=P.step(p);if(F.settled(p.body))assert.ok(clear(level,p.plane,p.body.position));assert.ok(F.bounded(p.body.position));assert.ok(F.nearby(previous,p.body.position));checked++;
  }
}
// Camera endpoints coincide; the exit mesh has no plane-dependent visibility.
for(const plane of ['XY','YZ','ZX']){
  const c=C.camera({$:`model.${plane}`},1),next={XY:'YZ',YZ:'ZX',ZX:'XY'}[plane];
  for(const v of [[0,0,0],[9,9,9],[1,4,7]]){
    const q={$:'V',x:v[0],y:v[1],z:v[2]},a=C.rotated(c,q),b=C.rotated(C.camera({$:`model.${next}`},0),q);
    for(const k of ['x','y','z'])assert.ok(Math.abs(a[k]-b[k])<1e-5);
  }
}
console.log(`PASS: parabolic flight, collisions, two-cell gap, all-plane exit, automatic progression, arrow keys, frozen rotations, and ${checked} mixed-control ticks with independent collision sweeps.`);

// A slow frame must catch up in fixed collision-checked steps, not silently
// cap game speed at 20 frames per second. A long suspension remains bounded.
for(const dt of [.025,.1,.2]){
 const start=key(P.create(1),100),actual=P.tick(dt,start),expected=P.steps(BigInt(Math.floor(dt*120)),start);
 assert.deepEqual(actual.body,expected.body);assert.equal(actual.time,expected.time);
}
assert.equal(P.tick(10,P.create(1)).time,30,'suspension catch-up is bounded to 250 ms');

// Campaign navigation pauses the entire simulation and preserves earned marks.
p=P.create(3);p=P.steps(12n,key(p,100));p=press(p,9);
assert.equal(p.menu,true);assert.deepEqual(P.tick(.2,p),p,'chapter picker pauses physics and time');
const held=key(p,63235);assert.equal(P.key(63235,true,held).selection,held.selection,'key repeat does not skip cards');
for(let i=0;i<L.count();i++){
 p=P.create(L.at(0));p=press(p,9);for(let j=0;j<i;j++)p=press(p,63235);
 p=press(p,13);assert.equal(p.level,L.at(i));assert.equal(p.menu,false);assert.equal(p.keys,0);
}
p=press(P.create(3),9);p=press(p,27);assert.equal(p.menu,false);assert.equal(p.quit,false,'Escape closes picker');
p=P.create(3);p.body=body([9472,9472,512]);p=P.step(p);assert.ok(P.down(p.completed,L.flag(3)));
p=P.load(17,p);assert.ok(P.down(p.completed,L.flag(3)));p=press(p,127);assert.ok(P.down(p.completed,L.flag(3)));
assert.equal(p.seals,0);
// All visible interactions share projected contact. Hidden depth does not
// disable a seal or ring. Newly intersecting views are resolved after rotation.
assert.ok(P.touches(point([3328,3328,512]),point([3,3,0])));
assert.ok(P.touches(point([3328,3328,4608]),point([3,3,0])));
p=P.create(0);p.body=body([3328,3328,4608]);p=P.collect(p);assert.equal(p.seals,1);
assert.equal(P.collect(p).seals,1,'a seal is collected only once');
let ringChecked=false,depthRing=false;
for(let level=18;level<L.count();level++)for(let i=0;i<L.ring_count(level);i++)for(const name of Object.keys(axes)){
 const plane={$:name},q=L.ring(level,i),at=xyz(q).map(n=>n*1024+512);
 p=P.create(level);p.plane=plane;p.body=body(at);
 const next={$:{'model.XY':'model.YZ','model.YZ':'model.ZX','model.ZX':'model.XY'}[name]};
 const allowed=clear(level,plane,p.body.position);
 assert.equal(P.can_turn(p),allowed,'projected ring contact permits turning even into an occupied silhouette');
 if(!allowed||P.arrived(p))continue;
 const hidden=[0,1,2].find(a=>!axes[name].includes(a));
 for(let depth=0;depth<10;depth++){
  const other=at.slice();other[hidden]=depth*1024+512;
  const r={...p,body:body(other)};
  assert.ok(P.can_turn(r),'a projected ring admits every hidden depth');
  if(depth!==xyz(q)[hidden])depthRing=true;
 }
 if(!ringChecked){
  const edge=at.slice();edge[axes[name][0]]=xyz(q)[axes[name][0]]*1024+255;
  assert.equal(P.can_turn({...p,body:body(edge)}),false,'entire projected body must fit inside the ring');
  p=key(press(key(p,100),114),32);const anchored=xyz(p.body.position);
  p=P.steps(BigInt(P.rotation_ticks()),p);assert.deepEqual(xyz(p.body.position),anchored);
  assert.equal(p.plane.$,next.$);assert.equal(p.time,0);ringChecked=true;
 }
}
assert.ok(ringChecked&&depthRing,'ring anchoring and projected depth independence are covered');
p=press(P.create(L.at(0)),9);p=press(p,101);assert.equal(p.selection,18);assert.equal(p.menu,true);
p=press(p,113);assert.equal(p.selection,0);
p=press(P.create(L.at(17)),9);p=press(p,101);assert.equal(p.selection,L.count()-1,'partial last page clamps selection');
p=press(p,13);assert.equal(p.level,L.at(L.count()-1));
console.log(`PASS: ${L.count()}-level paged picker, projected turn rings, automatic intersection settling, pause, completion marks, optional seals, and projected-exit contact/latching.`);
