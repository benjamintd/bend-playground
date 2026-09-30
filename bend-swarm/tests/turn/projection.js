import assert from 'node:assert/strict';
import B from '../../engine/render/batch.bend';
import G from '../../demos/turn/model.bend';
import L from '../../demos/turn/levels.bend';
import P from '../../demos/turn/play.bend';
import C from '../../demos/turn/projection.bend';
import W from '../../demos/turn/world.bend';
import V from '../../demos/turn/view.bend';
const point=(x,y,z)=>({$:'model.Point',x,y,z}),xyz=q=>[q.x,q.y,q.z];
const planes=['XY','YZ','ZX'].map(name=>({$:`model.${name}`}));
const axis=[2,0,1],blank=()=>(B.create(32768));
const press=(p,key)=>P.key(key,false,P.key(key,true,p));
const mesh=p=>{const g=V.scenery(C.camera(p.plane,V.progress(p.turn)),p.level,blank());return g.triangles.slice(0,g.count)};
let cubes=0,faces=0,cycles=0;
for(let level=0;level<L.count();level++){
  const occupied=new Set();
  for(let i=0;i<1000;i++){
    const q=point(i%10,Math.floor(i/10)%10,Math.floor(i/100));
    assert.deepEqual(xyz(W.cell(i)),xyz(q),'voxel ID maps to a fixed world position');
    if(L.solid(level,q))occupied.add(xyz(q).join(','));
  }
  for(const key of occupied){
    const q=point(...key.split(',').map(Number));cubes++;
    for(let f=0;f<6;f++){
      const plane=planes[Math.floor(f/2)],side=f%2,normal=axis[Math.floor(f/2)];
      const next=xyz(q);next[normal]+=side?-1:1;
      assert.equal(W.exposed(level,q,plane,side),!occupied.has(next.join(',')),'omit only internal faces');
      const g=V.wall_face(true,C.camera(planes[0],0),plane,side,q,blank());
      assert.equal(g.count,4,'one full unit face and its inset paint');
      const vertices=g.triangles.slice(0,2).flatMap(t=>[t.a,t.b,t.c]).map(v=>[(v.x/2-256)/30+4.5,(282-v.y/2)/30+4.5,900/v.z-30+4.5]);
      for(let a=0;a<3;a++){
        const lo=xyz(q)[a]+(a===normal?(side?-.5:.5):-.5);
        const hi=xyz(q)[a]+(a===normal?(side?-.5:.5):.5);
        assert.ok(Math.abs(Math.min(...vertices.map(v=>v[a]))-lo)<1e-5,'face starts on the actual voxel boundary');
        assert.ok(Math.abs(Math.max(...vertices.map(v=>v[a]))-hi)<1e-5,'face ends on the actual voxel boundary');
      }
      faces++;
    }
  }
  for(const plane of planes){
    let p=P.create(level);p.plane=plane;
    const start=mesh(p),position=xyz(p.body.position);
    // A renderer pose fixture, independent of automatic intersection settling.
    // Exercise movement and all three canonical cameras.
    for(let turn=0;turn<3;turn++){
      p.body.position=point(1024*(turn+1)+512,2048+turn*317,8192-turn*1031);
      p.plane=planes[(planes.findIndex(v=>v.$===p.plane.$)+1)%3];
      p.turn=0;
    }
    assert.equal(p.plane.$,plane.$);assert.notDeepEqual(xyz(p.body.position),position);
    assert.deepEqual(mesh(p),start,'three camera turns with movement restore every scenery triangle exactly');
    const full=V.scene(p,blank());
    assert.deepEqual(full.triangles.slice(0,start.length),start,'the live scene draws the same immutable world mesh');
    // Changing any hidden coordinate must never select another set of blocks.
    for(const depth of [0,4,9]){
      const other=structuredClone(p);other.body.position={...other.body.position,x:512+depth*1024,y:512,z:512+(9-depth)*1024};
      assert.deepEqual(mesh(other),start); // HUD/character geometry is already covered by the integration frame above.
    }
    cycles++;
  }
}
// At each intermediate orientation, count independent exposed, camera-facing
// faces. This catches missing geometry and accidentally duplicated slice grids.
for(let level=0;level<L.count();level++)for(const plane of planes)for(const phase of [0,.2,.5,.8,1]){
  const camera=C.camera(plane,phase);let expected=0;
  for(let i=0;i<1000;i++){
    const q=W.cell(i);if(!L.solid(level,q))continue;
    for(let f=0;f<6;f++){
      const facePlane=planes[Math.floor(f/2)],side=f%2;
      if(V.face_visible(camera,facePlane,side)&&W.exposed(level,q,facePlane,side))expected++;
    }
  }
  assert.equal(V.scenery(camera,level,blank()).count,expected*4);
}
console.log(`PASS: ${cubes} fixed full cubes, ${faces} exact unit faces, ${cycles} moving three-turn cycles, and complete world meshes at ${L.count()*15} camera poses.`);
