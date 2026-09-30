import assert from 'node:assert/strict';
import fs from 'node:fs';
import P from '../../demos/turn/play.bend';
import L from '../../demos/turn/levels.bend';
import {macro} from './controller.js';
const catalog=JSON.parse(fs.readFileSync('demos/turn/catalog.json','utf8')).levels;
const plans=JSON.parse(fs.readFileSync('tests/turn/projected-plans.json','utf8'));
const xyz=q=>[q.x,q.y,q.z],planes=['model.XY','model.YZ','model.ZX'],axes=[[0,1],[1,2],[2,0]];
const reports=[];
let source='import Base\nimport ./replay.bend as C\nimport ../../demos/turn/model.bend as M\n\n# Keyboard witnesses for projected collisions, 120 wall-clock ticks/second.\n';
for(let level=0;level<L.count();level++){
 let p=P.create(level),trace=[];
 for(const action of plans[level]){
  if(P.arrived(p))break;
  const r=macro(p,action);assert.ok(r,`level ${level}: authored action ${JSON.stringify(action)} is available`);
  p=r.p;trace.push(...r.trace);
 }
 assert.ok(P.arrived(p),`level ${level}: live keyboard route reaches the projected exit`);
 assert.ok(axes[planes.indexOf(p.plane.$)].every(a=>Math.abs(xyz(p.body.position)[a]-9728)<=256),'exit center lies inside the body');
 assert.equal(p.seals,L.all_seals(level),`level ${level}: all optional seals`);
 assert.ok(p.turns<=L.par(level),`level ${level}: optional turn target`);
 const runs=[];for(const t of trace){const last=runs.at(-1);if(last&&last.keys===t.keys&&!t.jump&&!t.turn)last.ticks++;else runs.push({...t,ticks:1});}
 source+=`def level${level}() -> List<C.Run>:\n  [${runs.map(r=>`C.Run{${r.ticks}n,${r.keys},${r.jump?'True':'False'}{},${r.turn?'True':'False'}{}}`).join(',')} ]\n`;
 source+=`def expected${level}() -> M.Point: M.Point{${xyz(p.body.position).join(',')}}\n`;
 reports.push({level:level+1,title:L.title(level),ticks:trace.length,seconds:trace.length/120,jumps:trace.filter(r=>r.jump).length,turns:p.turns,seals:p.seals,runs,position:xyz(p.body.position),plane:planes.indexOf(p.plane.$)});
}
source+='def route(level: U32) -> List<C.Run>:\n  match level:\n'+catalog.map(r=>`    case ${r.id}: level${r.id}()\n`).join('')+'    case _: level0()\n';
source+='def expected(level: U32) -> M.Point:\n  match level:\n'+catalog.map(r=>`    case ${r.id}: expected${r.id}()\n`).join('')+'    case _: expected0()\n';
if(process.argv.includes('--write'))fs.writeFileSync('tests/turn/routes.bend',source);
else assert.equal(fs.readFileSync('tests/turn/routes.bend','utf8'),source,'native keyboard witnesses are current');
fs.writeFileSync('build/turn-continuous-solutions.json',JSON.stringify(reports,null,2)+'\n');
console.log(reports.map(({runs,...r})=>r));
