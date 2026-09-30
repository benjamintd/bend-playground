import assert from 'node:assert/strict';
import fs from 'node:fs';
import C from '../../demos/turn/collision.bend';
import F from '../../demos/turn/physics.bend';
const levels=JSON.parse(fs.readFileSync('demos/turn/catalog.json','utf8')).levels;
const axes=[[0,1,2],[1,2,0],[2,0,1]],names=['XY','YZ','ZX'];
const point=q=>({$:'model.Point',x:q[0],y:q[1],z:q[2]}),xyz=q=>[q.x,q.y,q.z];
let targets=0;
for(const row of levels)for(let p=0;p<3;p++){
 const [a,b,c]=axes[p],plane={$:`model.${names[p]}`};
 const solid=new Set(row.blocks.map(q=>q[a]+q[b]*10));
 const world=(x,y,z)=>{const q=[];q[a]=x;q[b]=y;q[c]=z;return q;};
 for(let y=0;y<10;y++)for(let x=0;x<10;x++){
  let target=[x,y];
  if(solid.has(x+y*10)){
   target=null;
   for(let v=y-1;v>=0;v--)if(!solid.has(x+v*10)){target=[x,v];break;}
   if(!target){let cost=Infinity;for(let i=99;i>=0;i--){const u=i%10,v=Math.floor(i/10),d=Math.abs(u-x)+Math.abs(v-y);if(!solid.has(i)&&d<cost){target=[u,v];cost=d;}}}
  }
  for(const depth of [0,4,9])assert.deepEqual(xyz(C.cell(row.id,plane,point(world(x,y,depth)))),world(...target,depth),'explicit escape table matches independent downward/nearest-air oracle at all depths');
  const q=point(world(x*1024+512,y*1024+512,4608));
  const body={$:'Body',position:q,vx:2048,vy:2048,coyote:0,buffer:0,escape:0};
  const turned=F.rotated(row.id,plane,body);
  assert.deepEqual(turned.position,q,'turn resolution never teleports');
  if(solid.has(x+y*10)){
   assert.deepEqual([(turned.escape-1)%16384,Math.floor((turned.escape-1)/16384)],target.map(n=>n*1024+512),'live subcell resolver agrees with every cell-space certificate');targets++;
  }else assert.equal(turned.escape,0,'free cells need no correction');
 }
}
console.log(`PASS: all 7800 projected cells at three hidden depths match the independent oracle; ${targets} live escape targets match the proved cell table.`);
