import assert from 'node:assert/strict';
import fs from 'node:fs';
import {oracle,compare} from './boids-reference.js';
import W from '../demos/swarm/world.bend';
const edges=[8,256,512,1024], colors=[4389850,16757081];
function initial() {
  const w=W.empty(4n,16);
  for(let i=0;i<16;i++) {
    const along=(edges[Math.floor(i/2)%4]-.25+(i%2)*.5)%1024, across=100+Math.floor(i/2)*64;
    w.px[i]=i<8?along:across; w.py[i]=i<8?across:along;
    w.vx[i]=i<8?40:0; w.vy[i]=i<8?0:40;
  }
  return w;
}
const outputs=[];
for(const backend of ['cpu','gpu']) {
  const rows=fs.readFileSync(`build/crossings-${backend}.csv`,'utf8').trim().split('\n').map(s=>s.split(',').map(Number));
  assert.equal(rows.length,120*16);
  let want=initial(); const frames=[];
  for(let frame=1;frame<=120;frame++) {
    want=oracle(want);
    const actual=W.empty(4n,16), pixels=new Map();
    for(const row of rows.slice((frame-1)*16,frame*16)) {
      const [f,id,x,y,vx,vy]=row;
      assert.equal(f,frame); assert.ok(id>=0 && id<16);
      actual.px[id]=x; actual.py[id]=y; actual.vx[id]=vx; actual.vy[id]=vy;
      const key=Math.floor(x)+1024*Math.floor(y);
      pixels.set(key,Math.max(pixels.get(key)??395279,colors[id%2]));
    }
    compare(actual,want,.012);
    for(const [,id,x,y,,,color,imageColor] of rows.slice((frame-1)*16,frame*16)) {
      const expected=pixels.get(Math.floor(x)+1024*Math.floor(y));
      assert.equal(color,expected,`${backend} frame ${frame} agent ${id}: pixel buffer`);
      assert.equal(imageColor,expected,`${backend} frame ${frame} agent ${id}: displayed image tree`);
    }
    if(frame===1) for(let i=0;i<16;i+=2) {
      const pos=i<8?actual.px[i]:actual.py[i];
      assert.ok(i%8===6 ? pos<1 : pos>edges[Math.floor(i/2)%4],`agent ${i} must cross its boundary`);
    }
    frames.push(actual);
  }
  outputs.push(frames);
}
for(let f=0;f<120;f++) compare(outputs[0][f],outputs[1][f],.003);
console.log('PASS: 120 native CPU/Metal frames agree with the independent oracle and retain visible pixels across cells, quadrants, and world wrapping.');
