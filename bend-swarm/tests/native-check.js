import assert from 'node:assert/strict';
import fs from 'node:fs';
import {oracle,compare} from './boids-reference.js';
import W from '../demos/swarm/world.bend';
const w=W.empty(7n,128);
for(let i=0;i<128;i++) {
  w.px[i]=(1020+i%8)%1024; w.py[i]=(1020+Math.floor(i/8))%1024;
  w.vx[i]=i%5*3-6; w.vy[i]=i%7*2-6;
}
const want=oracle(w);
const got=[];
for(const backend of ['cpu','gpu']) {
  const lines=fs.readFileSync(`results/native-${backend}.csv`,'utf8').trim().split('\n');
  assert.equal(lines.length,128);
  const out=W.empty(7n,128);
  lines.forEach((line,i)=>line.split(',').map(Number).forEach((x,j)=>out[['px','py','vx','vy'][j]][i]=x));
  compare(out,want,.0003); got.push(out);
}
compare(...got,.0002);
console.log('PASS: native CPU and Metal agree with the independent oracle; position/velocity tolerance 0.0003.');
