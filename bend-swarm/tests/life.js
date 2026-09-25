import assert from 'node:assert/strict';
import T from './life.bend';
import S from '../demos/life/simulation.bend';
const delta=x=>x-Math.floor(x/1024+.5)*1024;
const hash=x=>{x=(x^(x>>>16))>>>0;x=Math.imul(x,2146121005)>>>0;x=(x^(x>>>15))>>>0;x=Math.imul(x,2221713035)>>>0;return (x^(x>>>16))>>>0;};
const coeff=(preset,seed,a,b)=>preset===0?(a===b?.85:-.45):preset===1?(a===b?.2:(a+1)%6===b?.95:(b+1)%6===a?-.7:-.16):(a===b?.5:(((hash((a*6+b+seed)>>>0)&16777215)/16777216)*2-1)*.9);
export function reference(a,c,i) {
  const p=a[i];let ax=0,ay=0;
  for(let j=0;j<a.length;j++) if(i!==j) {
    const dx=delta(a[j].x-p.x),dy=delta(a[j].y-p.y),d=Math.hypot(dx,dy);
    if(d>32)continue;
    const r=d/32,force=r<.2?(r/.2-1)*2.4:coeff(c.preset,c.seed,i%6,j%6)*Math.max(0,1-Math.abs(2*r-1.2)/.8);
    const m=force*95/Math.max(d,.001);ax+=dx*m;ay+=dy*m;
  }
  const dx=delta(c.mx-p.x),dy=delta(c.my-p.y),pull=c.power*350/Math.sqrt(dx*dx+dy*dy+144);
  let vx=(p.vx+(ax+dx*pull)/60)*.91,vy=(p.vy+(ay+dy*pull)/60)*.91;
  const scale=Math.min(1,90/Math.sqrt(vx*vx+vy*vy+.000001));vx*=scale;vy*=scale;
  return {x:((p.x+vx/60)%1024+1024)%1024,y:((p.y+vy/60)%1024+1024)%1024,vx,vy};
}
for(let preset=0;preset<3;preset++) for(let scene=0;scene<3;scene++) {
  const a=Array.from({length:32},(_,i)=>({$:'Particle',x:scene===0?(i*7.3)%1024:scene===1?(1010+(i%8)*3.1)%1024:40,y:scene===0?500+i%4*3.7:scene===1?(1014+Math.floor(i/8)*4.1)%1024:40,vx:0,vy:0}));
  const saved=structuredClone(a),c={$:'Controls',preset,seed:42,mx:800,my:20,power:scene===2?1:0};
  const result=T.run(false,c,a);assert.ok(result.$.endsWith('Done'));
  const out=result.value.output;assert.deepEqual(result.value.snapshot.source,saved,'snapshot source stays immutable');
  for(let i=0;i<32;i++) {
    const expected=reference(saved,c,i),got=out[i];
    for(const k of ['x','y','vx','vy']) assert.ok(Math.abs(got[k]-expected[k])<.0003,`oracle ${preset}/${scene}/${i}/${k}: ${got[k]} vs ${expected[k]}`);
  }
}
assert.ok(S.coefficient(1,42,0,1)>0&&S.coefficient(1,42,1,0)<0,'chase interaction is deliberately directional');
// The cell grid is an acceleration structure, not part of the force law.
// Translate a dense constellation through cell and torus boundaries; undoing
// that translation must recover exactly the same velocity update.
const cluster=Array.from({length:32},(_,i)=>({$:'Particle',x:480+(hash(i+113)%6400)/100,y:480+(hash(i+741)%6400)/100,vx:(i%3)-1,vy:(i%5)-2}));
const controls={$:'Controls',preset:1,seed:42,mx:0,my:0,power:0};
const base=T.run(false,controls,cluster).value.output;
for(const [dx,dy] of [[.125,.375],[7.9,8.1],[15.75,16.25],[31.9,32.1],[255.25,-247.75],[511.75,512.25]]) {
  const shifted=cluster.map(p=>({...p,x:(p.x+dx+1024)%1024,y:(p.y+dy+1024)%1024}));
  const out=T.run(false,controls,shifted).value.output;
  for(let i=0;i<32;i++) for(const key of ['vx','vy']) assert.ok(Math.abs(out[i][key]-base[i][key])<.0003,`translation ${dx}/${dy}/${i}/${key}`);
}
console.log('PASS: three species-rule presets against independent all-pairs equations, periodic edges, dense and coincident particles, bounded pointer force and source ownership.');
