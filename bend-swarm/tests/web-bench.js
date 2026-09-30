import Cloth from '../web/adapters/cloth.bend';
import Meadow from '../web/adapters/meadow.bend';
import Camera from '../web/adapters/camera.bend';
import Life from '../web/adapters/life.bend';
import Swarm from '../web/adapters/swarm.bend';
import fs from 'node:fs';
const unwrap=r=>{if(r.$==='Fail')throw new Error(r.message);return r.value;};
const reports=[];
for(const id of ['cloth','meadow','monochrome','voxels','life','swarm']){
 let state=id==='cloth'?unwrap(Cloth.create()):id==='meadow'?Meadow.create():['monochrome','voxels'].includes(id)?Camera.create(id==='voxels'):id==='life'?unwrap(Life.create(42)):unwrap(Swarm.create());
 const times=[];for(let i=0;i<12;i++){
  const start=performance.now();
  state=id==='cloth'?unwrap(Cloth.frame(i/120,true,0xffffffff,256,256,7.5,true,state)):id==='meadow'?Meadow.frame(i/60,1,0,.5,.5,false,state):['monochrome','voxels'].includes(id)?Camera.frame(1/60,state):id==='life'?unwrap(Life.frame(1,42,512,512,0,state)):unwrap(Swarm.frame(512,512,0,state));
  times.push(performance.now()-start);
 }
 const sorted=times.slice(2).sort((a,b)=>a-b);const report={id,medianMs:sorted[5],maxMs:Math.max(...times),samples:times};reports.push(report);console.log(report);
}
fs.writeFileSync(process.argv[2]||'build/web-bench.json',JSON.stringify(reports,null,2)+'\n');
