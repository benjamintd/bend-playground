import assert from 'node:assert/strict';
import fs from 'node:fs';
import {reference} from './life.js';
const rows=fs.readFileSync('build/life-grid-gpu.csv','utf8').trim().split('\n').map(l=>{
  const [id,x,y,vx,vy]=l.split(',').map(Number);return {id,x,y,vx,vy};
});
assert.equal(rows.length,16384);
const before=rows.slice(0,8192),after=rows.slice(8192);
let max=0,probes=0;
for(let i=0;i<8192;i+=17) {
  const expected=reference(before,{preset:1,seed:42,mx:0,my:0,power:0},i);
  for(const k of ['x','y','vx','vy']) {
    let d=Math.abs(after[i][k]-expected[k]);if(k==='x'||k==='y')d=Math.min(d,1024-d);
    max=Math.max(max,d);assert.ok(d<.0004,`all-pairs after 600 steps: ${i}/${k}, error ${d}`);
  }
  probes++;
}
console.log(JSON.stringify({passed:true,particles:8192,steps_before_probe:600,all_pairs_probes:probes,max_absolute_difference:max}));
