import assert from 'node:assert/strict';
import B from '../engine/render/batch.bend';

const vertex=(x,y)=>({$:'Vertex',x,y,z:1,light:1});
const triangle=i=>({$:'Triangle',a:vertex(i,0),b:vertex(i+1,0),c:vertex(i,1),color:i});
for(const [requested,capacity] of [[0,1],[1,1],[2,2],[3,4],[1023,1024],[1024,1024],[1025,2048],[32768,32768]]) {
  const b=B.create(requested);
  assert.equal(b.count,0);assert.equal(b.capacity,capacity);assert.equal(b.triangles.length,capacity);
}
let b=B.create(1);
for(let i=0;i<3000;i++) b=B.push(triangle(i),b);
assert.equal(b.count,3000);assert.equal(b.capacity,4096);
for(let i=0;i<b.count;i++) {
  assert.equal(b.triangles[i].color,i,'growth preserves every preceding triangle');
  assert.equal(b.triangles[i].a.x,i);
}
const storage=b.triangles;
b=B.clear(b);
assert.equal(b.count,0);assert.equal(b.capacity,4096);assert.equal(b.triangles,storage);
b=B.push(triangle(37),b);
assert.equal(b.count,1);assert.equal(b.triangles[0].color,37);assert.equal(b.triangles,storage);
console.log('PASS: batch capacity rounding, repeated growth without wrapping, clear and buffer reuse.');
