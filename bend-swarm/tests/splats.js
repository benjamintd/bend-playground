import assert from 'node:assert/strict';
import T from './splats.bend';
import R from '../engine/render/splats.bend';
const f=T.fixture(),done=T.render(false);assert.ok(done.$.endsWith('Done'));
const result=done.value;const pixels=result.snd.snd.fst;
const delta=x=>x-Math.floor(x/1024+.5)*1024;
let count=0;
for(let y=0;y<1024;y++) for(let x=0;x<1024;x++) {
  const c=[4,6,12];
  for(const p of f) {
    const dx=delta(x+.5-p.x),dy=delta(y+.5-p.y),d2=dx*dx+dy*dy;
    const core=Math.max(0,1-d2/16),coverage=Math.max(0,Math.min(1,4.5-Math.sqrt(d2)));
    const light=coverage*1.55*(.1+.9*core*core);
    if(light<=.001) continue;
    [16,8,0].forEach((shift,k)=>c[k]=Math.min(255,c[k]+Math.min(255,Math.floor(((p.color>>>shift)&255)*light))));
  }
  const got=pixels[x+y*1024];
  for(const [k,shift] of [16,8,0].entries()) assert.ok(Math.abs(((got>>>shift)&255)-c[k])<=1,`${x},${y},channel ${k}`);
  count+=got!==263692;
}
assert.ok(count>200&&count<700,'localized splats with wrapped edges');
assert.equal(R.add(R.add(0xcccccc,0x404040),0x101010),R.add(0xcccccc,R.add(0x404040,0x101010)),'saturation is order independent');
console.log(`PASS: 1048576 additive sprite pixels against independent coverage oracle; ${count} lit pixels across tiles and torus seams.`);
