import C from '../web/adapters/cloth.bend';
import fs from 'node:fs';
let state=C.create().value;const report={};
for(const run of [false,true]){const times=[];for(let i=0;i<10;i++){const start=performance.now();state=C.frame(i/120,true,0xffffffff,256,256,7.5,run,state).value;times.push(performance.now()-start);}report[run?'physicsAndGeometry':'geometry']=times;}
fs.writeFileSync(process.argv[2]||'build/web-cloth-profile.json',JSON.stringify(report,null,2)+'\n');console.log(report);
