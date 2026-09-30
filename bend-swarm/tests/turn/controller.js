import assert from 'node:assert/strict';
import P from '../../demos/turn/play.bend';
import F from '../../demos/turn/physics.bend';
import L from '../../demos/turn/levels.bend';

// Reproducible keyboard controller for authored solution plans. It only sends
// normal game input; it never writes player coordinates or bypasses collisions.
const axes=[[0,1,2],[1,2,0],[2,0,1]],planes=['model.XY','model.YZ','model.ZX'];
const xyz=q=>[q.x,q.y,q.z],pi=p=>planes.indexOf(p.plane.$),local=p=>axes[pi(p)].map(i=>xyz(p.body.position)[i]);
const ground=p=>F.ground(p.level,p.plane,p.body.position);
const press=(p,c)=>P.key(c,false,P.key(c,true,p));
function tick(p,keys,jump=false,turn=false){
 const old=p.body.position;
 for(const [bit,c] of [[1,97],[2,100],[8,115]])p=P.key(c,!!(keys&bit),p);
 if(jump)p=press(p,32);if(turn)p=press(p,114);
 p=P.step(p);
 assert.ok(F.nearby(old,p.body.position),'keyboard replay obeys the per-tick movement bound');
 assert.ok(F.bounded(p.body.position),'settling stays inside the world');
 if(F.settled(p.body))assert.ok(F.clear(p.level,p.plane,p.body.position),'normal movement never overlaps a projected wall');
 return p;
}
export function macro(p,action){
 const trace=[];let turned=false;
 const frame=(keys=0,jump=false,turn=false)=>{p=tick(p,keys,jump,turn);trace.push({keys,jump,turn});};
 if(action==='R'||action==='JR'){
  if(action==='JR'){if(!ground(p))return null;frame(0,true);for(let i=0;i<23;i++)frame();}
  // A projected ring requires the whole body inside its cell. Correct a
  // small landing offset with ordinary left/right input before pressing R.
  for(let i=0;i<8&&!P.can_turn(p)&&F.settled(p.body);i++){
   const part=local(p)[0]%1024;
   if(part>=256&&part<=768)break;
   frame(part<256?2:1);
  }
  // Preserve the authored launch poses: free-camera turns formerly advanced
  // 12 or 13 physics ticks. Now take those ordinary ticks before freezing.
  if(!L.ring_count(p.level)){
   const ticks=Math.floor(((p.turns*12)%20+252)/20),until=p.time+ticks;
   while(p.time<until&&!P.arrived(p))frame();
  }
  if(!P.can_turn(p))return null;frame(0,false,true);turned=true;
  while(p.turn&&!P.arrived(p))frame();
  // A fresh Down tap releases time without a simulation step on that input
  // frame. The authored routes intentionally settle between their turns.
  if(P.frozen(p)&&!P.arrived(p)){frame(8);frame();}
 }else if(action.jump){if(!ground(p))return null;frame(0,true);}
 const from=local(p)[0],target=typeof action==='object'?Math.max(512,Math.min(9728,(Math.floor(from/1024)+.5+action.dx)*1024)):from;
 let still=0,last='';
 for(let i=0;i<480&&!P.arrived(p);i++){
  const dx=target-local(p)[0],v=p.body.vx-2048,stop=v*v/12+Math.abs(v)*.5+10;
  let key=Math.abs(dx)<25?0:Math.sign(dx)===Math.sign(v)&&Math.abs(dx)<stop?0:dx>0?2:1;
  if(turned)key=0;
  frame(key);
  const now=xyz(p.body.position).join(',');still=now===last?still+1:0;last=now;
  if(p.pace===0&&F.settled(p.body)&&ground(p)&&p.body.vx===2048&&(Math.abs(dx)<36||still>8))break;
 }
 if(!F.clear(p.level,p.plane,p.body.position))throw new Error('overlap');
 return {p,trace};
}
