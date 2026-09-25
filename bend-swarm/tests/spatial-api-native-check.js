import assert from 'node:assert/strict';
import fs from 'node:fs';
import {masks} from './spatial-api.js';
const p={$:'Points',x:[],y:[],z:[]};
for(let i=0;i<32;i++) {p.x.push(i*17%31/4-4);p.y.push(i*11%29/4-4);p.z.push(i*7%37/4-4);}
const cases=[[[4,4,0],32,2.4,false],[null,32,2.4,false],[[2,1,2],13,10,true],[[2,1,2],0,0,true]];
const raw=[];
for(const backend of ['cpu','gpu']) {
  const rows=fs.readFileSync(`build/spatial-api-${backend}.csv`,'utf8').trim().split('\n');
  assert.equal(rows.length,cases.length*33);raw.push(rows);
  for(let k=0;k<cases.length;k++) {
    const [span,n,radius,inc]=cases[k], expected=masks(p,n,radius,inc,span);
    const [checks,accepted]=rows[k*33].split(',').map(Number);
    assert.equal(accepted,expected.accepted);assert.ok(checks<=n*n);
    assert.deepEqual(rows.slice(k*33+1,k*33+33).map(Number),expected.out,`${backend} case ${k}`);
  }
}
assert.deepEqual(raw[0],raw[1]);
console.log('PASS: native CPU and Metal generic spatial queries match all-pairs membership and visit counts.');
