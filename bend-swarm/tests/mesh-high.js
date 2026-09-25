import assert from 'node:assert/strict';
import T from './mesh.bend';
const triangles=T.fixture().map(t=>({...t,...Object.fromEntries(['a','b','c'].map(k=>[k,{...t[k],x:t[k].x*2,y:t[k].y*2}]))}));
const r=T.render_high(false,4,triangles);
function pixel(image,x,y,size=1024) {
  if(image.$.endsWith('Pix')) return image.color;
  const h=size/2;return pixel(image[y<h?(x<h?'tl':'tr'):(x<h?'bl':'br')],x%h,y%h,h);
}
let count=0,sum=0;
for(let y=0;y<1024;y++) for(let x=0;x<1024;x++) {
  let z=1000,c=66051;
  for(const t of triangles) {
    const {a,b,c:q,color}=t;if(Math.min(a.z,b.z,q.z)<=.1) continue;
    const den=(b.y-q.y)*(a.x-q.x)+(q.x-b.x)*(a.y-q.y);
    const u=((b.y-q.y)*(x+.5-q.x)+(q.x-b.x)*(y+.5-q.y))/den;
    const v=((q.y-a.y)*(x+.5-q.x)+(a.x-q.x)*(y+.5-q.y))/den,w=1-u-v;
    if(Math.min(u,v,w)<-1e-7) continue;
    const depth=1/(u/a.z+v/b.z+w/q.z);
    if(depth<z-1e-6) {z=depth;c=color;}
    else if(Math.abs(depth-z)<1e-6) c=Math.max(c,color);
  }
  const got=r.fst.pixels[x+y*1024];
  assert.equal(got,c,`high pixel ${x},${y}`);
  assert.equal(pixel(r.snd,x,y),got,'high Image coverage');
  assert.equal(r.fst.background[x+y*1024].depth,1000,'background depth retained');
  assert.equal(r.fst.background[x+y*1024].color,66051,'background color stays immutable');
  count+=got!==66051;sum=(sum+got)>>>0;
}
console.log(`PASS: 1048576 high-resolution pixels and Image ownership; checksum ${sum}, visible ${count}.`);
