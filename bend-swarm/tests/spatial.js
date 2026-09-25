import assert from 'node:assert/strict';
import {fixture,compare} from './boids-reference.js';
import W from '../demos/swarm/world.bend';
import G from '../engine/spatial/grid.bend';
import P from '../demos/swarm/points.bend';
import B from '../demos/swarm/boids.bend';
import Safe from '../engine/spatial/reference.bend';
import Generic from './boids-generic.bend';
for(const n of [8,32,128]) for(let seed=1;seed<=16;seed++) {
  const w=fixture(n,seed), depth=BigInt(Math.log2(n));
  let scene={$:'Scene',world:structuredClone(w),grid:G.empty(depth)};
  scene=P.scatter(false,3n,P.scan(P.histogram(false,3n,scene)));
  const {grid,world}=scene;
  const entries0=Array.from({length:n},(_,id)=>({$:'Entry',cell:G.cell(w.px[id],w.py[id]),id}));
  let input={$:'Nil'};for(const e of entries0.reverse()) input={$:'Con',head:e,tail:input};
  let entries=Safe.organize(input);
  const safe=[];while(entries.$==='Con'){safe.push(entries.head);entries=entries.tail;}
  const actual=grid.ids.slice(0,n).map(id=>({$:'Entry',cell:G.cell(world.px[id],world.py[id]),id}));
  actual.sort((a,b)=>a.cell-b.cell || a.id-b.id);
  assert.deepEqual(actual,safe);

  assert.equal(grid.offsets[16384],n);
  assert.deepEqual([...grid.ids].sort((a,b)=>a-b),Array.from({length:n},(_,i)=>i));
  for(let c=0;c<16384;c++) {
    assert.ok(grid.offsets[c]<=grid.offsets[c+1]);
    for(let slot=grid.offsets[c];slot<grid.offsets[c+1];slot++) {
      const id=grid.ids[slot]; assert.equal(G.cell(world.px[id],world.py[id]),c);
    }
  }
  const reference=B.reference(n,structuredClone(w),W.empty(depth,n)).snd;
  const out=B.execute(false,3n,n,{$:'Buffers',old:world,next:W.empty(depth,n),offsets:grid.offsets,
    ids:grid.ids,checks:0n,mx:0,my:0,power:0});
  compare(out.next,reference); compare(out.old,w,0);
  const generic=Generic.run(n,depth,structuredClone(w));assert.equal(generic.$,'Done');
  compare(generic.value.output,reference);compare(generic.value.snapshot.source,w,0);
  assert.ok(out.checks>=n);
}
console.log('PASS: atomic grid permutation/ranges and spatial vs brute-force step (48 dense / periodic scenes).');
// Coincident distinct agents must still align, and inactive capacity slots must
// never enter the spatial index. Adversarial inputs, not just random scenes.
for(const count of [1,5,13,16]) {
  const w=fixture(16,99);w.count=count;
  w.px.fill(0);w.py.fill(0);w.vx[0]=59;w.vy[0]=0;
  let scene={$:'Scene',world:structuredClone(w),grid:G.empty(4n)};
  scene=P.scatter(false,4n,P.scan(P.histogram(false,4n,scene)));
  assert.equal(scene.grid.offsets[16384],count);
  const want=B.reference(count,structuredClone(w),W.empty(4n,count)).snd;
  const out=B.execute(false,4n,count,{$:'Buffers',old:scene.world,next:W.empty(4n,count),offsets:scene.grid.offsets,
    ids:scene.grid.ids,checks:0n,mx:0,my:0,power:0});
  compare(out.next,want); assert.equal(out.checks,BigInt(count*count));
  const generic=Generic.run(count,4n,structuredClone(w));assert.equal(generic.$,'Done');
  compare(generic.value.output,want);assert.equal(generic.value.checks,BigInt(count*count));
}
console.log('PASS: coincident neighbors and partial active populations.');
