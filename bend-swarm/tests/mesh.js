import assert from 'node:assert/strict';
import M from '../engine/render/mesh.bend';
import T from './mesh.bend';
const triangles=T.fixture();
function color(x,y) {
  let z=1000,c=66051;
  for(const t of triangles) {
    const {a,b,c:q,color}=t;if(Math.min(a.z,b.z,q.z)<=.1) continue;
    const den=(b.y-q.y)*(a.x-q.x)+(q.x-b.x)*(a.y-q.y);
    if(Math.abs(den)<.00001) continue;
    const u=((b.y-q.y)*(x-q.x)+(q.x-b.x)*(y-q.y))/den;
    const v=((q.y-a.y)*(x-q.x)+(a.x-q.x)*(y-q.y))/den;
    const w=1-u-v;if(Math.min(u,v,w)<-1e-7) continue;
    const depth=1/(u/a.z+v/b.z+w/q.z);
    if(depth<z-1e-6) {z=depth;c=color;}
  }
  return c;
}
const result=T.render(false,4,triangles);
function pixel(image,x,y,size=512) {
  if(image.$.endsWith('Pix')) return image.color;
  const half=size/2;return pixel(image[y<half?(x<half?'tl':'tr'):(x<half?'bl':'br')],x%half,y%half,half);
}
let verified=0;
for(let y=0;y<512;y++) for(let x=0;x<512;x++) {
  // Shared diagonal lies exactly on both triangles; either equal-depth color is valid.
  const got=result.fst.pixels[x+y*512],want=color(x+.5,y+.5);
  if(x+y!==511 || want===65280 || want===66051) assert.equal(got,want,`${x},${y}`);
  assert.equal(pixel(result.snd,x,y),got,'Image and pixels agree');verified++;
}
assert.equal(M.bounds({$:'Triangle',a:{$:'Vertex',light:1,x:-20,y:5,z:1},b:{$:'Vertex',light:1,x:-10,y:20,z:1},c:{$:'Vertex',light:1,x:-1,y:0,z:1},color:0}).width,0);
console.log(`PASS: ${verified} depth-tested mesh pixels, overlap, triangle edges, rejected geometry, tile ownership and Image output.`);

// Smooth lighting interpolates continuously while retaining flat-color fixtures.
const smooth={$:'Triangle',a:{$:'Vertex',x:0,y:0,z:2,light:.2},b:{$:'Vertex',x:100,y:0,z:2,light:1},c:{$:'Vertex',x:0,y:100,z:2,light:.6},color:0xffffff};
for(const [x,y] of [[10,10],[30,10],[10,30],[40,40]]) {
  const sample=M.sample(x,y,smooth,{$:'Fragment',depth:1000,color:0});
  const channel=Math.floor(255*(.2+x/100*.8+y/100*.4));
  for(const shift of [0,8,16]) assert.ok(Math.abs(((sample.color>>>shift)&255)-channel)<=1,'interpolated vertex lighting');
}
