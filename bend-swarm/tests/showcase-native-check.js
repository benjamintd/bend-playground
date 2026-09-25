import assert from 'node:assert/strict';
import fs from 'node:fs';
import LifeTest from './life.bend';
import {reference} from './life.js';
const rows=backend=>fs.readFileSync(`build/showcase-${backend}.csv`,'utf8').trim().split('\n').map(l=>{const [kind,...values]=l.split(',');return {kind,v:values.map(Number)};});
const cpu=rows('cpu'),gpu=rows('gpu');assert.equal(cpu.length,5214);assert.equal(gpu.length,cpu.length);
const source=LifeTest.fixture();
const rgb=c=>[c>>>16,(c>>>8)&255,c&255];
const fragment=(x,y)=>({depth:x<256?10:20,color:(Math.floor(x/8)+Math.floor(y/8))%2?0x203040:0xffffff});
const get=(x,y)=>fragment(Math.max(0,Math.min(511,x)),Math.max(0,Math.min(511,y)));
const luma=c=>{const [r,g,b]=rgb(c);return .299*r+.587*g+.114*b;};
function expectedPost(i) {
  const x=i%512,y=Math.floor(i/512),center=get(x,y);
  if(x>=256) {
    const samples=[];
    for(let dy=-2;dy<=2;dy+=2) for(let dx=-2;dx<=2;dx+=2) {const n=get(x+dx,y+dy);if(Math.abs(n.depth-center.depth)<2)samples.push(rgb(n.color));}
    return [0,1,2].map(k=>Math.floor(samples.reduce((s,c)=>s+c[k],0)/samples.length));
  }
  const n=get(x,y-1).color,s=get(x,y+1).color,e=get(x+1,y).color,w=get(x-1,y).color;
  const levels=[center.color,n,s,e,w].map(luma),lo=Math.min(...levels),hi=Math.max(...levels);
  if(hi-lo<=Math.max(10,hi*.12))return rgb(center.color);
  const pair=Math.abs(luma(n)-luma(s))>Math.abs(luma(e)-luma(w))?[n,s]:[e,w];
  return rgb(center.color).map((v,k)=>Math.floor(v*.75+(rgb(pair[0])[k]+rgb(pair[1])[k])*.125));
}
let maxGrass=0,maxLife=0;
for(let j=0;j<cpu.length;j++) {
  const a=cpu[j],b=gpu[j];assert.equal(a.kind,b.kind);assert.ok(a.v.every(Number.isFinite)&&b.v.every(Number.isFinite));
  if(a.kind==='grass') {
    assert.equal(a.v[0],b.v[0]);assert.ok(Math.hypot(a.v[1],a.v[2])<=.90001&&Math.hypot(b.v[1],b.v[2])<=.90001);
    for(let k=1;k<5;k++)maxGrass=Math.max(maxGrass,Math.abs(a.v[k]-b.v[k]));
  } else if(a.kind==='life') {
    const [preset,i]=a.v;const expected=reference(source,{$:'Controls',preset,seed:42,mx:0,my:0,power:1},i);
    for(const row of [a,b]) for(const [k,key] of ['x','y','vx','vy'].entries())assert.ok(Math.abs(row.v[k+2]-expected[key])<.0004);
    for(let k=2;k<6;k++)maxLife=Math.max(maxLife,Math.abs(a.v[k]-b.v[k]));
  } else if(a.kind==='post') {
    for(const row of [a,b]) rgb(row.v[1]).forEach((c,k)=>assert.ok(Math.abs(c-expectedPost(row.v[0])[k])<=1,`post ${row.v[0]}, channel ${k}`));
  } else if(a.kind==='splats') {
    assert.equal(a.v[3],257);assert.equal(b.v[3],257);
    for(let k=0;k<3;k++)assert.ok(Math.abs(a.v[k]-b.v[k])<512);
  } else assert.fail(a.kind);
}
assert.ok(maxGrass<.0003);assert.ok(maxLife<.0004);
console.log(JSON.stringify({passed:true,grass_vertices:4096,grass_steps:240,max_grass_cpu_gpu_difference:maxGrass,max_life_cpu_gpu_difference:maxLife,post_oracle_samples:1021,wrapped_splat_lit_pixels:257}));
