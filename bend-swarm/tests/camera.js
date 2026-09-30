import assert from 'node:assert/strict';
import C from '../engine/camera.bend';
import Controls from '../engine/camera_controls.bend';
import P from '../engine/render/project.bend';
import B from '../engine/render/batch.bend';
import M from '../engine/render/mesh.bend';
const point=(x,y,z)=>({$:'Point',x,y,z});
const close=(a,b,e=2e-4)=>assert.ok(Math.abs(a-b)<e,`${a} != ${b}`);
const xyz=(a,b,e)=>['x','y','z'].forEach(k=>close(a[k],b[k],e));
const vp=C.viewport(800,600,1024,768);
const prepared=c=>{const r=C.prepare(c,vp);assert.equal(r.$,'Some');return r.value;};
// Bend Maybe uses field value; keep the actual public shape visible in tests.
const base=C.look_at(C.perspective(60,.05,100),point(3,2,8),point(0,0,0),point(0,1,0));

const list=xs=>xs.reduceRight((tail,head)=>({$:'Con',head,tail}),{$:'Nil'});
const array=xs=>{const out=[];while(xs.$==='Con'){out.push(xs.head);xs=xs.tail;}return out;};
for(const lens of [C.perspective(60,.05,100),C.orthographic(12,.05,100)]) {
  const camera=C.offset(C.look_at(lens,point(3,2,8),point(0,0,0),point(0,1,0)),.08,-.04);
  const view=prepared(camera);
  for(const depth of [.1,1,9,70]) for(const [x,y] of [[0,0],[512,384],[1000,700],[50,730]]) {
    const world=C.unproject_at_depth(view,x,y,depth), screen=C.project(view,world);
    close(screen.x,x,.015);close(screen.y,y,.015);close(screen.depth,depth);
    const ray=C.screen_ray(view,x,y),d=ray.direction;
    close(Math.hypot(d.x,d.y,d.z),1);
    const t=(world.x-ray.origin.x)*d.x+(world.y-ray.origin.y)*d.y+(world.z-ray.origin.z)*d.z;
    xyz(C.ray_at(ray,t),world);
    close(C.project(view,C.ray_at(ray,ray.minimum)).depth,.05);
    close(C.project(view,C.ray_at(ray,ray.maximum)).depth,100,.001);
  }
  const a=C.screen_ray(view,0,0),b=C.screen_ray(view,1024,768);
  if(view.orthographic) {xyz(a.direction,b.direction);assert.notDeepEqual(a.origin,b.origin);}
  else {xyz(a.origin,b.origin);assert.notDeepEqual(a.direction,b.direction);}
}
assert.equal(C.prepare(C.perspective(0,.1,100),vp).$,'None');
assert.equal(C.prepare(C.perspective(60,2,1),vp).$,'None');
assert.equal(C.prepare(C.perspective(60,0,100),vp).$,'None');
assert.equal(C.prepare(C.zoom(base,0),vp).$,'None');
assert.equal(C.prepare(base,C.viewport(0,600,1024,768)).$,'None');
assert.equal(C.prepare(C.look_at(base,point(0,0,0),point(0,0,0),point(0,1,0)),vp).$,'None');
assert.equal(C.prepare(C.look_at(base,point(NaN,0,0),point(0,0,0),point(0,1,0)),vp).$,'None');
const pole=prepared(C.look_at(base,point(0,3,0),point(0,0,0),point(0,1,0)));
close(Math.hypot(pole.right.x,pole.right.y,pole.right.z),1);
xyz(C.pointer(vp,400,300).value,point(512,384,0));
assert.equal(C.pointer(vp,801,300).$,'None');
xyz(C.pointer({$:'Viewport',x:50,y:100,width:800,height:600,pixels_x:2048,pixels_y:1536},450,400).value,point(1024,768,0));
// Independent interpolation: a depth gradient gives affine ortho Z, reciprocal perspective Z.
const a={$:'Vertex',x:0,y:0,z:1,light:.2},b={$:'Vertex',x:100,y:0,z:4,light:.8},c={$:'Vertex',x:0,y:100,z:8,light:1};
for(const ortho of [true,false]) {
  const hit=M.sample_camera(25,25,M.projected(a,b,c,0xffffff,ortho),{$:'Fragment',depth:100,color:0});
  const depth=ortho?3.5:1/(.5+.25/4+.25/8);
  close(hit.depth,depth);
  const light=ortho?.5*.2+.25*.8+.25:(.5*.2+.25*.8/4+.25/8)*depth;
  close(hit.color&255,Math.floor(light*255),1.01);
}
// Every clipped vertex must satisfy all six planes, with attribute interpolation.
const view=prepared(C.look_at(C.perspective(70,.25,12),point(0,0,0),point(0,0,1),point(0,1,0)));
const vertex=(x,y,z,light=1)=>({$:'Vertex',point:point(x,y,z),light});
let count=0;
for(const tri of [
  [vertex(-1,-1,.1),vertex(2,-1,3),vertex(0,2,3)],
  [vertex(-20,0,3),vertex(2,-2,3),vertex(0,2,20)],
  [vertex(-2,-2,3),vertex(2,-2,3),vertex(0,2,3)],
  [vertex(-1,-1,-3),vertex(2,-1,-3),vertex(0,2,-3)]
]) {
  const clipped=array(P.clip(6n,0,view,list(tri)));
  for(const v of clipped) for(let i=0;i<6;i++) {
    const plane=C.plane(view,i),n=plane.fst,p=v.point;
    assert.ok(n.x*p.x+n.y*p.y+n.z*p.z+plane.snd>-.001,'all clipped vertices inside');
  }
  count+=clipped.length;
}
assert.ok(count>6);
const overlap=C.intersects_bounds(view,point(-1,-1,2),point(1,1,4));
assert.equal(overlap,true);assert.equal(C.intersects_bounds(view,point(-1,-1,-20),point(1,1,-18)),false);
// Bounded orbit pitch/distance and elapsed-time movement, independent of pause.
const orbit={$:'Orbit',target:point(0,0,0),yaw:0,pitch:0,distance:10};
const motion={$:'Motion',yaw:1,pitch:0,dolly:0,pan_x:0,pan_y:0};
close(Controls.orbit_step(orbit,motion,.5).yaw,.5);
const fly={$:'Fly',eye:point(0,0,0),yaw:0,pitch:0};
xyz(Controls.fly_step(fly,0,0,4,0,0,.5).eye,point(0,0,2));
console.log('PASS: camera projection/ray round trips, clipping, interpolation, lens/pose validation, viewport mapping, controls and bounds.');
// Flat white remains binary despite varying depths and F32 barycentrics.
for(const ortho of [false,true]) for(const [x,y] of [[25,25],[.3,.3],[17.13,51.24]]) {
  const triangle=M.projected({...a,light:1},{...b,light:1,z:1},{...c,light:1,z:7},0xffffff,ortho);
  assert.equal(M.sample_camera(x,y,triangle,{$:'Fragment',depth:100,color:0}).color,0xffffff);
}
assert.equal(C.prepare(C.perspective(60,.00000001,100),vp).$,'None');
assert.equal(C.prepare(C.perspective(60,.1,2e6),vp).$,'None');
const distant=prepared(C.look_at(base,point(1e8,1e8,1e8),point(1e8+100,1e8,1e8),point(0,1,0)));
const remoteRay=C.screen_ray(distant,512,384);
close(Math.hypot(remoteRay.direction.x,remoteRay.direction.y,remoteRay.direction.z),1);
assert.ok(Number.isFinite(remoteRay.maximum));
// The public triangle path clips, triangulates and grows its reusable batch.
const worldTri={$:'Triangle',a:vertex(-.2,-.2,.1),b:vertex(-2,1,3),c:vertex(2,1,3),color:0xffffff};
let batch=B.create(1024);
for(let i=0;i<600;i++) batch=P.triangle(view,worldTri,batch);
assert.ok(batch.count>1024);assert.ok(batch.capacity>=batch.count);
for(const t of batch.triangles.slice(0,batch.count)) for(const v of [t.a,t.b,t.c]) {
  assert.ok(v.z>=.25-1e-5&&v.z<=12+1e-5);
  assert.ok(v.x>=-.001&&v.x<=1024.001&&v.y>=-.001&&v.y<=768.001);
}
const storage=batch.triangles;batch=B.clear(batch);assert.equal(batch.count,0);assert.equal(batch.triangles,storage);
console.log('PASS: exact flat colors, large-origin rays, renderer lens limits and public clipping/batch growth/reuse.');
assert.equal(C.prepare(C.look_at(base,point(1e25,0,0),point(-1e25,0,0),point(0,1,0)),vp).$,'None','overflowing pose lengths are rejected');
// Pointer mapping and camera preparation share the viewport contract.
for(const invalid of [
  {...vp,pixels_x:0}, {...vp,pixels_y:-1}, {...vp,pixels_x:Infinity},
  {...vp,width:NaN}, {...vp,height:Infinity}, {...vp,x:NaN}, {...vp,y:Infinity}
]) {
  assert.equal(C.prepare(base,invalid).$,'None');
  assert.equal(C.pointer(invalid,400,300).$,'None');
}
assert.equal(C.pointer(vp,NaN,300).$,'None');
assert.equal(C.pointer(vp,400,Infinity).$,'None');
const huge=C.pointer(C.viewport(1e29,1e29,1e29,1e29),5e28,5e28).value;
assert.ok(Number.isFinite(huge.x)&&Number.isFinite(huge.y),'normalize logical coordinates before scaling to avoid intermediate overflow');
close(huge.x/5e28,1,1e-5);
for(const [camera,viewport] of [
  [C.offset(base,1e29,0),vp],
  [base,C.viewport(1,1,1e29,1e29)],
  [C.zoom(C.orthographic(1e29,.1,100),.001),C.viewport(1,1,1e-20,1e-20)],
  [C.zoom(C.orthographic(1e20,.1,100),.001),C.viewport(1,1,1,1e-10)]
]) assert.equal(C.prepare(camera,viewport).$,'None','reject non-invertible or overflowing derived views');
const normalized=value=>JSON.parse(JSON.stringify(value,(key,v)=>key==='$'?v.split('.').pop():v));
assert.deepEqual(normalized(C.prepare_unchecked(base,vp)),normalized(prepared(base)),'explicit trusted path agrees with checked preparation');
assert.equal(C.prepare(C.orthographic(2,.1,10),C.viewport(1,1,1e-25,1e-25)).$,'None',
  'reject side-plane normals whose squared length underflows and loses culling radius');
console.log('PASS: shared viewport validation, overflow-safe pointer mapping and finite/invertible prepared views.');
