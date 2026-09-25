import assert from 'node:assert/strict';
import fs from 'node:fs';
const results=[];
for(const backend of ['cpu','gpu']) {
  const rows=fs.readFileSync(`build/cloth-${backend}.csv`,'utf8').trim().split('\n').map(l=>l.split(',').map(Number));
  assert.equal(rows.length,2176);assert.ok(rows.every(r=>r.length===3 && r.every(Number.isFinite)));
  for(const [side,offset,stretchLimit] of [[8,64,1.12],[32,1152,1.5]]) {
    const mesh=rows.slice(offset,offset+side*side);
    for(const i of [0,side*side-1]) {
      const expected=[i===0?-1.8:1.8,1.55,i===0?-1.8:1.8];
      mesh[i].forEach((v,j)=>assert.ok(Math.abs(v-expected[j])<1e-6,`${backend}: pin ${i}`));
    }
    let sag=false;
    for(const [i,[x,y,z]] of mesh.entries()) {
      assert.ok(y>=-1.60001,'floor penetration');assert.ok(Math.hypot(x,y+.25,z)>=1.21998,'sphere penetration');
      if(y<1) sag=true;
      for(const j of [i%side<side-1?i+1:-1,i+side<side*side?i+side:-1].filter(j=>j>=0)) {
        const length=Math.hypot(...mesh[i].map((v,k)=>v-mesh[j][k]));
        assert.ok(length<3.6/(side-1)*stretchLimit,`${backend}: excessive stretch ${i}/${j}: ${length}`);
      }
    }
    assert.ok(sag,'cloth drapes under gravity');
  }
  results.push(rows);
}
const differences=[];
// Near-exact one-step agreement separates implementation errors from the
// accumulated effects of unordered floating-point self-contact reductions.
for(const [start,count,tolerance] of [[0,64,.00001],[64,64,.002],[128,1024,.00001],[1152,1024,.02]]) {
  let maximum=0;
  for(let i=start;i<start+count;i++) for(let k=0;k<3;k++) maximum=Math.max(maximum,Math.abs(results[0][i][k]-results[1][i][k]));
  assert.ok(maximum<tolerance,`CPU/Metal cloth difference ${maximum}, tolerance ${tolerance}`);
  differences.push(maximum.toPrecision(3));
}
console.log(`PASS: native CPU/Metal 8×8 and 32×32 cloth; one-step and 180-frame differences ${differences.join(', ')} m; pins, contacts and bounded stretch.`);
