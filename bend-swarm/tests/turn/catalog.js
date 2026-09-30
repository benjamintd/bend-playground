import assert from 'node:assert/strict';
import fs from 'node:fs';
import L from '../../demos/turn/levels.bend';
import Check from '../../demos/turn/resolution-check.bend';
const {levels,order}=JSON.parse(fs.readFileSync('demos/turn/catalog.json','utf8'));
const point=(x,y,z)=>({$:'model.Point',x,y,z});
const proofCells=[];for(let xs=Check.grid();xs.$==='Con';xs=xs.tail){const q=xs.head;assert.equal(q.z,0);proofCells.push(q.x+10*q.y);}
assert.deepEqual(proofCells,Array.from({length:100},(_,i)=>i),'settling law covers every cell of the 10x10 grid');
const layouts=new Set(),projections=new Set();
assert.equal(levels.length,26);assert.equal(L.count(),levels.length);
for(let chapter=0;chapter<L.count();chapter++){
 const id=order[chapter],r=levels[id];assert.equal(L.at(chapter),id);assert.equal(L.index(id),chapter);
 assert.equal(L.next(id),order[(chapter+1)%order.length]);assert.equal(L.last(id),chapter===order.length-1);
 assert.equal(L.title(id),r.title);assert.equal(L.par(id),r.par);assert.equal(L.difficulty(id),r.difficulty);
 assert.equal(L.seal_count(id),r.seals.length);
 assert.equal(L.ring_count(id),r.rings?.length??0);
 for(let i=0;i<(r.rings?.length??0);i++){
  const q=L.ring(id,i);assert.deepEqual([q.x,q.y,q.z],r.rings[i]);
  assert.ok(L.free(id,q),'turn rings are in empty, bounded cells');
 }
 assert.ok(r.difficulty>=1&&r.difficulty<=5,'authored difficulty remains within the displayed scale');
 assert.ok(L.projected_free(id,{$:'model.XY'},point(0,0,0)),'spawn is clear in its starting projection');
 for(let i=0;i<r.seals.length;i++){
  const q=L.seal(id,i);assert.deepEqual([q.x,q.y,q.z],r.seals[i]);
  assert.ok(L.free(id,q),'every optional seal is inside the world and outside walls');
 }
 const projection=JSON.stringify([[0,1],[1,2],[2,0]].map(([a,b])=>[...new Set(r.blocks.map(q=>q[a]+q[b]*10))].sort((a,b)=>a-b)));
 assert.ok(!projections.has(projection),'every world has a distinct set of three silhouettes');projections.add(projection);
 const mask=Array.from({length:1000},(_,i)=>+L.solid(id,point(i%10,Math.floor(i/10)%10,Math.floor(i/100)))).join('');
 assert.ok(!layouts.has(mask),'each level has a distinct physical layout');layouts.add(mask);
}
console.log(`PASS: ${L.count()} distinct layouts, difficulty ratings, distinct projections, chapter cycle, safe seals and turn rings.`);
