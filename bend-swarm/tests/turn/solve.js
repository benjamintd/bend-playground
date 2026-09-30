import assert from 'node:assert/strict';
import fs from 'node:fs';
import L from '../../demos/turn/levels.bend';
import M from '../../demos/turn/model.bend';
import R from '../../demos/turn/rules.bend';
const point=(x,y,z)=>({$:'model.Point',x,y,z});
const planes=['XY','YZ','ZX'];
const dirs=['East','North','West','South'];
const axes=[[0,1],[1,2],[2,0]];
const actions=[{kind:'Rotate'},...['Walk','Jump'].flatMap(kind=>(kind==='Walk'?[0,2]:[0,1,2]).map(d=>({kind,d,direction:dirs[d]}))),{kind:'Wait'}];
const state=([x,y,z,p])=>({$:'model.State',position:point(x,y,z),plane:{$:`model.${planes[p]}`}});
const action=a=>['Rotate','Wait'].includes(a.kind)?{$:`model.${a.kind}`}:{$:`model.${a.kind}`,direction:{$:`model.${a.direction}`}};
const key=s=>s.join(',');
const silhouettes=Array.from({length:L.count()},(_,level)=>axes.map(([a,b])=>{
 const cells=new Set();for(let x=0;x<10;x++)for(let y=0;y<10;y++)for(let z=0;z<10;z++)
  if(L.solid(level,point(x,y,z))){const q=[x,y,z];cells.add(q[a]+10*q[b]);}return cells;
}));
const free=(level,s)=>{const [a,b]=axes[s[3]??0];return s.slice(0,3).every(v=>v>=0&&v<10)&&!silhouettes[level][s[3]??0].has(s[a]+10*s[b]);};
const catalog=JSON.parse(fs.readFileSync('demos/turn/catalog.json','utf8')).levels;
const turnAllowed=(level,s)=>!catalog[level].rings?.length||catalog[level].rings.some(q=>axes[s[3]].every(i=>q[i]===s[i]));
function settle(level,t){
 if(free(level,t))return t;
 const [a,b]=axes[t[3]];
 for(let v=t[b]-1;v>=0;v--){const q=t.slice();q[b]=v;if(free(level,q))return q;}
 let best=t,cost=Infinity;
 for(let i=99;i>=0;i--){const q=t.slice();q[a]=i%10;q[b]=Math.floor(i/10);
  const d=Math.abs(q[a]-t[a])+Math.abs(q[b]-t[b]);
  if(free(level,q)&&d<cost){best=q;cost=d;}
 }return best;
}
// Independent numeric transition oracle; Bend supplies only the wall layout.
function step(level,s,a){
  if(a.kind==='Rotate'){const t=[...s.slice(0,3),(s[3]+1)%3];return turnAllowed(level,s)?settle(level,t):s;}
  const [horizontal,vertical]=axes[s[3]];
  const move=(q,axis,delta)=>{const t=q.slice();t[axis]+=delta;return free(level,t)?t:q;};
  const below=s.slice();below[vertical]--;
  const above=s.slice();above[vertical]++;
  const canJump=a.kind==='Jump'&&!free(level,below)&&free(level,above);
  let t=canJump?above:s;
  if(a.kind!=='Wait'&&a.d!==1)t=move(t,horizontal,a.d===0?1:-1);
  return canJump?t:move(t,vertical,-1);
}
export function solve(level,allowed=()=>true){
  const q=[[0,0,0,0]],seen=new Map([[key(q[0]),null]]);
  for(let i=0;i<q.length;i++){
    const s=q[i];
    if(axes[s[3]].every(a=>s[a]===9)){
      const route=[];let k=key(s);
      while(seen.get(k)){const [prev,a]=seen.get(k);route.push(a);k=prev;}
      return {route:route.reverse(),visited:seen.size};
    }
    for(const a of actions.filter(allowed)){
      const t=step(level,s,a),k=key(t);
      if(!seen.has(k)){seen.set(k,[key(s),a]);q.push(t);}
    }
  }
  return null;
}
// Dijkstra with zero-cost movement: minimize turns, not the action count.
// This catches early exits that bypass a room's central rotation puzzle.
function minimumTurns(level){
  const start=[0,0,0,0],queue=[[0,start]],distance=new Map([[key(start),0]]);
  while(queue.length){
    queue.sort((a,b)=>b[0]-a[0]);const [cost,s]=queue.pop();
    if(distance.get(key(s))!==cost)continue;
    if(axes[s[3]].every(a=>s[a]===9))return cost;
    for(const a of actions){
      const t=step(level,s,a),k=key(t),next=cost+(a.kind==='Rotate');
      if(next<(distance.get(k)??Infinity)){distance.set(k,next);queue.push([next,t]);}
    }
  }
  return null;
}
const list=xs=>xs.reduceRight((tail,head)=>({$:'Con',head:action(head),tail}),{$:'Nil'});
// --witnesses regenerates explicit paths after an unchanged transition rule
// has already passed the exhaustive sweep; certificates are still checked.
const summaries=[];let proof='import Base\nimport ./model.bend as M\nimport ./rules.bend as R\n\n# Shortest action routes, independently searched by tests/turn/solve.js.\n';
for(let level=0;level<L.count();level++){
  assert.ok(free(level,[0,0,0,0]));assert.ok([0,1,2].some(p=>free(level,[9,9,9,p])),'at least one unblocked exit view');
  let open=0,checked=0;
  for(let z=0;z<10;z++)for(let y=0;y<10;y++)for(let x=0;x<10;x++){
    if(L.free(level,point(x,y,z)))open++;
    if(!process.argv.includes('--witnesses'))for(let p=0;p<3;p++)for(const a of actions){
      if(!free(level,[x,y,z,p]))continue;
      const s=[x,y,z,p],want=step(level,s,a),got=R.step(level,state(s),action(a));
      assert.deepEqual([got.position.x,got.position.y,got.position.z,planes.indexOf(got.plane.$.split('/').pop().split('.').pop())],want);
      assert.ok(free(level,want));checked++;
    }
  }
  const withoutRotation=solve(level,a=>a.kind!=='Rotate');
  const withoutJump=solve(level,a=>a.kind!=='Jump');
  const result=solve(level);assert.ok(result,`level ${level}: a cell-space exit route exists`);
  const minTurns=minimumTurns(level);
  assert.ok(minTurns<=L.par(level),`level ${level}: achievable turn target`);
  const route=result.route;
  assert.ok(R.valid(level,list(route),state([0,0,0,0])),'witness uses the actual Bend transition');
  proof+=`def level${level}() -> List<M.Action>:\n  [${route.map(a=>['Rotate','Wait'].includes(a.kind)?`M.${a.kind}{}`:`M.${a.kind}{M.${a.direction}{}}`).join(',')} ]\n`;
  const codeAction=a=>['Rotate','Wait'].includes(a.kind)?`M.${a.kind}{}`:`M.${a.kind}{M.${a.direction}{}}`;
  let cursor=[0,0,0,0];const beats=[];
  for(const a of route){cursor=step(level,cursor,a);beats.push({a,s:cursor});}
  const certificate=beats.reduceRight((tail,b)=>({$:'Con',head:{$:'Beat',action:action(b.a),after:state(b.s)},tail}),{$:'Nil'});
  assert.ok(R.certified(level,certificate,state([0,0,0,0])),'every certificate link follows the actual transition');
  proof+=`def path${level}() -> List<R.Beat>:\n  [${beats.map(({a,s})=>`R.Beat{${codeAction(a)},M.State{M.Point{${s.slice(0,3).join(',')}},M.${planes[s[3]]}{}}}`).join(',')} ]\n`;
  summaries.push({level:level+1,name:L.title(level),open,wall:1000-open,actions:route.length,turns:route.filter(a=>a.kind==='Rotate').length,minTurns,jumps:route.filter(a=>a.kind==='Jump').length,checked,withoutJumpActions:withoutJump?.route.length??null,withoutRotationActions:withoutRotation?.route.length??null,route:route.map(a=>a.kind==='Rotate'?'R':a.kind==='Wait'?'.':`${a.kind==='Jump'?'Space+':''}${['D','W','A','S'][a.d]}`)});
}
if(process.argv.includes('--write'))fs.writeFileSync('demos/turn/solutions.bend',proof);
fs.writeFileSync('build/turn-solutions.json',JSON.stringify(summaries,null,2)+'\n');
console.log(summaries.map(({route,...s})=>s));
