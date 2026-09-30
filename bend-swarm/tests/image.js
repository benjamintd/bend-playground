import assert from 'node:assert/strict';
import T from './image.bend';
const pixels=Array.from({length:4096},(_,i)=>(Math.imul(i,2654435761)>>>8)&0xffffff);
function check(image,size,x,y) {
  if(image.$==='Pix') {
    assert.equal(size,1,'unrolled tiles contain one leaf per pixel');
    assert.equal(image.color,pixels[x+y*64],`pixel ${x},${y}`);
    return;
  }
  assert.equal(image.$,'Qua');
  const h=size/2;
  for(const [i,child] of ['tl','tr','bl','br'].entries()) check(image[child],h,x+(i%2)*h,y+Math.floor(i/2)*h);
}
for(const size of [2,4,8,16,32]) for(const [x,y] of [[0,0],[3,7],[64-size,64-size]]) {
  const result=T.tile(size,x,y,[...pixels]);
  assert.deepEqual(result.fst,pixels,'image assembly preserves the caller-owned buffer');
  check(result.snd,size,x,y);
}
console.log('PASS: shared statically unrolled 2/4/8/16/32 pixel tiles, row stride, corners and buffer preservation.');
