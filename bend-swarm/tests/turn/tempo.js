import assert from 'node:assert/strict';
import P from '../../demos/turn/play.bend';
import F from '../../demos/turn/physics.bend';
import T from '../../demos/turn/tempo.bend';
import L from '../../demos/turn/levels.bend';
import S from '../../demos/turn/schedule.bend';
const press=(p,c)=>P.key(c,false,P.key(c,true,p));
const turn=p=>P.steps(BigInt(P.rotation_ticks()),press(p,114));
const position=p=>[p.body.position.x,p.body.position.y,p.body.position.z];
// Each resumed frame can perform at most one ordinary, collision-checked
// physics step. Verify the curve against an independent smoothstep formula.
let previous=0,phase=0,runs=0;
for(let age=1;age<=60;age++){
 const expected=Math.floor(100*(age/60)**2*(3-2*age/60)+1e-9);
 const rate=T.rate(age+1);assert.equal(rate,expected);assert.ok(rate>=previous&&rate<=100);previous=rate;
 const pulse=T.pulse(false,age+1,phase);phase=pulse.phase;runs+=+pulse.run;
}
assert.ok(runs>20&&runs<40);assert.equal(T.advance(60n,2),0);assert.equal(T.rate(0),100);
for(let fraction=0;fraction<100;fraction++)for(const pace of [0,1,2,31,61]){
 assert.equal(T.pulse(true,pace,fraction).run,false);
 assert.equal(T.pulse(false,1,fraction).run,false);
}
// Freeze in a projection that intersects the first staircase. R remains
// available so XY -> YZ -> ZX does not require an intermediate fall.
let p=P.create(0),start=position(p),clock=p.time;
p=turn(p);assert.equal(p.plane.$,'model.YZ');assert.ok(p.body.escape);
assert.ok(P.frozen(p));assert.ok(P.can_turn(p));
const held=structuredClone(p);p=P.steps(1200n,p);
assert.deepEqual(p,held,'ten seconds without input cannot change the body, world time or collectibles');
p=turn(p);assert.equal(p.plane.$,'model.ZX');assert.deepEqual(position(p),start);assert.equal(p.time,clock);
p=turn(p);assert.equal(p.plane.$,'model.XY');assert.deepEqual(position(p),start);assert.equal(p.turns,3);
// Every movement alias releases the hold. R, key-up, menus and focus changes
// leave it frozen. Held keys and OS key-repeat cannot accidentally release it.
for(const code of [97,100,119,115,32,63234,63235,63232,63233]){
 const frozen=turn(P.create(0));assert.equal(P.key(code,false,frozen).pace,1);
 assert.equal(press(frozen,code).pace,2);
}
p=P.key(100,true,P.create(0));p=turn(p);const fixed=position(p);
p=P.steps(240n,P.key(100,true,p));assert.equal(p.pace,1);assert.deepEqual(position(p),fixed);
p=P.key(100,false,p);p=P.key(100,true,p);assert.equal(p.pace,2);
p=P.create(0);p=press(p,114);p=press(p,63233);assert.equal(p.pace,2);
p=P.steps(BigInt(P.rotation_ticks()),p);assert.equal(p.pace,2,'resume during camera animation is queued');assert.deepEqual(position(p),start);assert.equal(p.time,0);
const atTurn=p;
for(let i=0;i<60;i++){
 const before=p;p=P.step(p);assert.ok(F.nearby(before.body.position,p.body.position));
 assert.ok(F.bounded(p.body.position));assert.ok(p.time-before.time<=1);
 if(F.settled(p.body))assert.ok(F.clear(p.level,p.plane,p.body.position));
}
assert.equal(p.pace,0);assert.ok(p.time-atTurn.time>20&&p.time-atTurn.time<40);
const time=p.time;p=P.steps(120n,p);assert.equal(p.time-time,120,'normal time resumes exactly');
p=turn(P.create(0));assert.equal(P.toggle(P.toggle(p)).pace,1);
assert.equal(S.elapsed(false,true,60,p).pace,1);assert.equal(S.elapsed(true,false,60,p).pace,1);
for(const code of [8,127])assert.deepEqual(press(p,code),P.create(0),'reset clears freeze and fade');
// A turn ring authorizes view selection until the next movement press.
let ring=P.create(18);ring.body={...ring.body,position:{$:'model.Point',x:512,y:256,z:512}};
// Admission still applies before beginning a chain; starting a hold cannot
// create a turn for an ordinary pose that is outside every ring.
assert.equal(P.can_turn(ring),false);
let ringChains=0;
for(let level=18;level<L.count();level++)for(let i=0;i<L.ring_count(level);i++){
 const cell=L.ring(level,i);
 let r=P.create(level);r.body={...r.body,position:{$:'model.Point',x:cell.x*1024+512,y:cell.y*1024+512,z:cell.z*1024+512}};
 if(!P.can_turn(r)||P.arrived(r))continue;
 const q=position(r);r=turn(r);assert.ok(P.can_turn(r),'a ring authorizes further view selection while frozen');
 r=turn(r);assert.deepEqual(position(r),q);assert.equal(r.turns,2);ringChains++;
}
assert.ok(ringChains>0);
console.log('PASS: stationary chained turns, embedded intermediate views, fresh input, all aliases, queued resume, 0.5-second smoothstep, fixed-step bounds, focus/menu preservation and reset.');
