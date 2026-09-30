import P from '../../demos/turn/play.bend';
import V from '../../demos/turn/view.bend';
import B from '../../engine/render/batch.bend';
let p=P.create(0),batch=B.create(32768),times=[];
for(let i=0;i<120;i++){
 p=P.tick(1/60,p);const start=performance.now();batch=V.scene(p,batch);times.push(performance.now()-start);
}
times.sort((a,b)=>a-b);console.log({triangles:batch.count,median:times[60],p95:times[114],triangle:batch.triangles[0]});
