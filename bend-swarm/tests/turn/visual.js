import assert from 'node:assert/strict';
import B from '../../engine/render/batch.bend';
import L from '../../demos/turn/levels.bend';
import P from '../../demos/turn/play.bend';
import V from '../../demos/turn/view.bend';
import C from '../../demos/turn/projection.bend';
import Mesh from '../../engine/render/mesh.bend';

// Exercise the densest scenes and confirm the engine batch grows safely.
let maxTriangles=0,frames=0;
for(let level=0;level<L.count();level++)for(const plane of ['XY','YZ','ZX'])for(const [turn,pace] of [[0,0],[1,1],[22,1],[43,1],[64,1],[84,1],[0,1],[0,2],[0,31],[0,61]]){
  const p=P.create(level);p.plane={$:`model.${plane}`};p.turn=turn;p.pace=pace;p.time=420;p.turns=2;
  p.body.position={...p.body.position,x:9728,y:9472,z:9728};
  p.finished=60;
  const before=structuredClone(p),g=V.scene(p,B.create(32768));
  assert.deepEqual(p,before,'rendering leaves game state untouched');
  assert.ok(g.count>1000&&g.count<32768,'scene fits owned triangle buffer');
  for(const triangle of g.triangles.slice(0,g.count)){
    assert.ok(triangle&&Number.isInteger(triangle.color)&&triangle.color>=0&&triangle.color<=0xffffff);
    for(const v of [triangle.a,triangle.b,triangle.c]){
      assert.ok([v.x,v.y,v.z,v.light].filter(n=>n!==undefined).every(Number.isFinite),'finite projected geometry');
      assert.ok(v.z>0,'decorative depth is valid');
    }
  }
  maxTriangles=Math.max(maxTriangles,g.count);frames++;
}
for(let selection=0;selection<L.count();selection++){
 const p=P.create(L.at(selection));p.menu=true;p.selection=selection;p.completed=2**L.count()-1;
 const g=V.scene(p,B.create(32768));
 assert.ok(g.count<32768,'all chapter cards fit the owned triangle buffer');
 for(const t of g.triangles.slice(0,g.count))for(const v of [t.a,t.b,t.c]){
  assert.ok(Number.isFinite(v.x)&&Number.isFinite(v.y)&&v.z>0);
  assert.ok(v.x>=0&&v.x<=1024&&v.y>=0&&v.y<=1024,'picker stays on screen');
 }
 maxTriangles=Math.max(maxTriangles,g.count);frames++;
}
assert.notEqual(V.background(0,0).color,V.background(512,560).color,'backdrop has a soft spatial gradient');
for(const menu of [false,true]) {
  const p=P.create(L.at(L.count()-1));p.menu=menu;p.selection=L.count()-1;
  const grown=V.scene(p,B.create(1)),reserved=V.scene(p,B.create(32768));
  assert.ok(grown.count>1024&&grown.capacity>=grown.count);
  assert.deepEqual(grown.triangles.slice(0,grown.count),reserved.triangles.slice(0,reserved.count),
    'world and font geometry survive growth unchanged');
  const reused=V.scene(p,grown);
  assert.equal(reused.count,reserved.count,'scene clears the previous frame before appending');
  assert.deepEqual(reused.triangles.slice(0,reused.count),reserved.triangles.slice(0,reserved.count));
}
// A point on a face must have the same depth whether projected directly or
// interpolated by the engine. Otherwise smaller painted quads shimmer.
const point=(x,y,z)=>({$:'V',x,y,z});
for(const phase of [.1,.25,.5,.75,.9]){
  const camera=C.camera({$:'model.XY'},phase);
  const a=C.project(camera,point(3.5,3.5,.5)),b=C.project(camera,point(4.5,3.5,.5)),c=C.project(camera,point(4.5,4.5,.5));
  const p=C.project(camera,point(4.2,3.8,.5));
  const hit=Mesh.sample(p.x,p.y,{$:'Triangle',a,b,c,color:0xffffff},{$:'Fragment',depth:1000,color:0});
  assert.ok(Math.abs(hit.depth-p.z)<.0001,'orthographic depth agrees across face tessellations');
}
console.log(`PASS: ${frames} decorated scenes, finite geometry, unchanged game state; peak ${maxTriangles}/32768 triangles.`);
