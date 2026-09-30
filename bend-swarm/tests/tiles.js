import assert from 'node:assert/strict';
import T from './tiles.bend';
const pix=color=>({$:'Pix',color});
const source={$:'Qua',tl:pix(0xff0000),tr:pix(0x00ff00),bl:pix(0x0000ff),br:pix(0xffffff)};
const colors=[0xff0000,0x00ff00,0x0000ff,0xffffff];
function at(image,size,x,y) {
  if(image.$==='Pix') return image.color;
  const h=size/2;return at(image[['tl','tr','bl','br'][(x>=h?1:0)+(y>=h?2:0)]],h,x%h,y%h);
}
for(const depth of [0,1,2,4]) for(const constant of [true,false]) {
  const width=2**depth, image=constant?pix(0x123456):structuredClone(source);
  const r=T.run(false,BigInt(depth),Array(4096).fill(1234567),image);
  for(let y=0;y<64;y++) for(let x=0;x<64;x++) {
    const expected=constant?0x123456:depth===0?0x7f7f7f:colors[(x>=width/2?1:0)+(y>=width/2?2:0)];
    assert.equal(r.fst[x+y*64],x<width&&y<width?expected:1234567,'single writer and exclusive rectangle');
    if(x<width&&y<width) assert.equal(at(r.snd,width,x,y),expected,'owned image subtree reaches the correct leaf');
  }
}
// Resolve actually reads its Image input, while sharing a larger output buffer.
for(const gpu of [false,true]) {
  const r=T.resolve(gpu,Array(1048576).fill(1234567),structuredClone(source));
  for(let y=0;y<512;y++) for(let x=0;x<512;x++) {
    const expected=colors[(x>=256?1:0)+(y>=256?2:0)];
    assert.equal(r.fst[x+y*512],expected);
    assert.equal(at(r.snd,512,x,y),expected);
  }
  assert.ok(r.fst.slice(262144).every(x=>x===1234567),'resolve preserves unused capacity');
}
console.log('PASS: shared tile tree depth zero, constant and patterned image ownership, single writers, both leaf sizes and resolve capacity preservation.');
