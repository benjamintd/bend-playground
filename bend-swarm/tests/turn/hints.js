import assert from 'node:assert/strict';
import P from '../../demos/turn/play.bend';
import Route from '../../demos/turn/hint-routes.bend';
const count=h=>({Three:0,Two:1,One:2,Empty:3}[h.budget.$.split('.').at(-1)]);
const press=(p,c)=>P.key(c,false,P.key(c,true,p));
const spots=xs=>{const out=[];while(xs.$==='Con'){out.push(xs.head);xs=xs.tail;}return out;};
for(let level=0;level<26;level++){
 let p=P.create(level),hints=p.hints;
 for(const spot of spots(Route.route(level))){
  const pose={...p,body:{...p.body,position:spot.position},plane:spot.plane,turns:spot.order-1,hints};
  const next=press(pose,104),used=Math.min(3,spot.order);
  assert.equal(count(next.hints),used);
  if(spot.order<=3)assert.equal(next.hints.target,spot.order);
  assert.deepEqual({...next,hints:pose.hints},pose,'hints do not move the body, change clocks, or use turns');
  assert.deepEqual(press(next,104),next,'re-reading the same hint is free');
  hints=next.hints;
 }
 if(level<3){const q=press(p,104);assert.equal(count(q.hints),0);assert.equal(q.hints.note,100);}
 const held=P.key(104,true,p);assert.deepEqual(P.key(104,true,held),held,'autorepeat never spends another hint');
 const frozen={...p,pace:1},shown=press(frozen,104);assert.equal(shown.pace,1,'a hint does not release frozen time');
 const reset=P.reset({...p,hints});assert.deepEqual(reset.hints,hints,'restart preserves used hints and current marker');
 assert.equal(count(P.load((level+1)%26,reset).hints),0,'a new chapter gets three fresh hints');
}
console.log('PASS: 26 chapters, three uses, repeated hints, no-rotation levels, pure state, frozen time, restart, and chapter changes.');
