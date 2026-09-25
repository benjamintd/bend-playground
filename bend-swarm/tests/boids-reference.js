import assert from 'node:assert/strict';
import W from '../demos/swarm/world.bend';
import B from '../demos/swarm/boids.bend';
const wrap = x => x - Math.floor(x / 1024) * 1024;
const delta = x => x - Math.floor(x / 1024 + .5) * 1024;
const limit = (x,y,max) => { const s=Math.min(1,max/Math.sqrt(x*x+y*y+.000001)); return [x*s,y*s]; };
export function oracle(w) {
  const out=structuredClone(w);
  for(let i=0;i<w.count;i++) {
    let sx=0,sy=0,ax=0,ay=0,cx=0,cy=0,n=0;
    for(let j=0;j<w.count;j++) {
      const dx=delta(w.px[j]-w.px[i]),dy=delta(w.py[j]-w.py[i]),d2=dx*dx+dy*dy;
      if(i!==j && d2<64) {
        const f=d2<9?1/(d2+.05):0;
        sx-=dx*f; sy-=dy*f; ax+=w.vx[j]; ay+=w.vy[j]; cx+=dx; cy+=dy; n++;
      }
    }
    const inv=1/Math.max(n,1),active=n?1:0;
    const [fx,fy]=limit(18*sx+active*(2*(ax*inv-w.vx[i])+4*cx*inv),18*sy+active*(2*(ay*inv-w.vy[i])+4*cy*inv),80);
    const rawX=w.vx[i]+fx*.016666667, rawY=w.vy[i]+fy*.016666667;
    const rawSpeed=Math.hypot(rawX,rawY);
    const targetSpeed=Math.max(20,Math.min(60,rawSpeed));
    const [vx,vy]=rawSpeed<=.000001 ? [20,0] : [rawX/rawSpeed*targetSpeed,rawY/rawSpeed*targetSpeed];
    out.px[i]=wrap(w.px[i]+vx*.016666667); out.py[i]=wrap(w.py[i]+vy*.016666667); out.vx[i]=vx; out.vy[i]=vy;
  }
  return out;
}
export function fixture(n,seed) {
  const w=W.empty(BigInt(Math.log2(n)),n);
  let s=seed;
  const rnd=()=>((s=(Math.imul(s,1664525)+1013904223)>>>0)/2**32);
  for(let i=0;i<n;i++) {
    // Dense clusters and torus seams; most agents have real neighbors.
    w.px[i]=Math.fround(wrap((i%2?1020:16)+rnd()*12));
    w.py[i]=Math.fround(wrap((i%3?1020:16)+rnd()*12));
    w.vx[i]=Math.fround((rnd()-.5)*120); w.vy[i]=Math.fround((rnd()-.5)*120);
  }
  return w;
}
export function compare(a,b,tol=.0002) {
  assert.equal(a.count,b.count); assert.equal(a.capacity,b.capacity);
  for(const f of ['px','py','vx','vy']) for(let i=0;i<a.count;i++)
    assert.ok(Math.abs(a[f][i]-b[f][i])<=tol,`${f}[${i}] ${a[f][i]} vs ${b[f][i]}`);
}
for(const n of [8,32,128]) for(let seed=1;seed<=8;seed++) {
  const w=fixture(n,seed), want=oracle(w);
  const out=B.reference(n,structuredClone(w),W.empty(BigInt(Math.log2(n)),n));
  compare(out.snd,want);
  compare(out.fst,w,0);
}
console.log('PASS: brute-force Bend agrees with independent JS oracle (24 dense / periodic scenes).');

// Propulsion must recover from zero / tiny velocity and preserve a usable heading.
for(const [vx,vy] of [[0,0],[1e-10,-1e-10],[3,4],[-30,40],[90,-120]]) {
  const r=B.cruising(vx,vy), speed=Math.hypot(r.fst,r.snd);
  assert.ok(Number.isFinite(speed) && speed>=20-.0001 && speed<=60+.0001);
  if(Math.hypot(vx,vy)>.000001) assert.ok(Math.abs(vx*r.snd-vy*r.fst)<.01,'retain heading');
}
console.log('PASS: bounded cruising speed and deterministic stationary recovery.');
