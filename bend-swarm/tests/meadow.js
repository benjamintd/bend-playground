import assert from 'node:assert/strict';
import S from '../demos/meadow/scene.bend';
import Wind from '../engine/fields/wind.bend';
import V from '../engine/geometry/curve.bend';
import Camera from '../engine/render/camera.bend';
import Player from '../engine/platform/player.bend';
const p=(x,y,z)=>({$:'Point',x,y,z});
const c={$:'Controls',time:0,strength:.55,mx:100,mz:100,power:0};
for(let i=0;i<4096;i++) {
  const r=S.root(i);
  assert.ok(Math.abs(Math.hypot(r.x,r.z)-4.2*Math.sqrt((i+.5)/4096))<.000002);
}
for(const i of [0,256,2048,4095]) {
  let b={$:'Blade',x:0,z:0,vx:0,vz:0};
  const root=S.root(i),h=S.height(i);
  for(let frame=0;frame<1200;frame++) {
    const controls={...c,time:frame/60,power:frame>300&&frame<600?1:0,mx:0,mz:0};
    b=S.forced(root,Wind.sample(root.x,root.z,frame/60),controls,b);
    for(const k of ['x','z','vx','vz']) assert.ok(Number.isFinite(b[k]));
    assert.ok(Math.hypot(b.x,b.z)<.901,'bounded bend under gust');
    const base=S.position(i,b,0);
    for(const k of ['x','y','z']) assert.ok(Math.abs(base[k]-root[k])<1e-6,'root stays attached');
    const tip=S.position(i,b,1);assert.ok(tip.y>h*.7&&tip.y<=h+1e-6);
  }
}
const a=p(0,0,0),b=p(1,2,0),d=p(2,0,0);
for(const k of ['x','y','z']) {assert.equal(V.quadratic(a,b,d,0)[k],a[k]);assert.equal(V.quadratic(a,b,d,1)[k],d[k]);}
const center=V.quadratic(a,b,d,.5);assert.equal(center.x,1);assert.equal(center.y,1);
const camera=S.camera();
for(const [x,y] of [[0,0],[512,512],[1024,1024],[137,842]]) {
  const ray=Camera.ray_value(camera,x,y);
  const projected=Camera.project_value(camera,Camera.along_value(camera,ray,7),1);
  assert.ok(Math.abs(projected.x-x)<.001&&Math.abs(projected.y-y)<.001);
  assert.ok(Math.abs(projected.z-7)<.00001,'ray distance parameter uses camera depth');
}
const input={$:'Input',gpu:false,paused:false,reset:false,quit:false,hud:false,preset:1,seed:42,mx:0,my:0,power:0,time:1,antialias:true,defocus:false,high:false};
const event=(e,i=input)=>Player.event(i,e,1/800,1/600);
const down=event({$:'Mouse',x:200,y:300,button:0,down:true});
assert.equal(down.mx,.25);assert.equal(down.my,.5);assert.equal(down.power,1);
assert.equal(event({$:'Mouse',x:200,y:300,button:1,down:true}).power,-1);
assert.equal(event({$:'Mouse',x:200,y:300,button:0,down:false},down).power,0);
assert.equal(event({$:'Key',code:97,down:true}).antialias,false);
assert.equal(event({$:'Key',code:100,down:true}).defocus,true);
const quality=event({$:'Key',code:113,down:true});assert.equal(quality.high,true);assert.equal(quality.reset,false);assert.equal(quality.time,1);
assert.equal(Player.next({...input,paused:true}).time,1);
console.log('PASS: 20-second grass spring/gust stability, anchored roots, bounded tips and reusable curve endpoints.');
