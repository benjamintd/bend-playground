import assert from 'node:assert/strict';
import P from '../engine/render/post.bend';
import {defocus} from './post-reference.js';
const settings=(aa,dof,focus=10,aperture=6)=>({$:'Settings',aa,dof,focus,aperture});
assert.equal(P.radius(settings(true,true),10),0);
assert.equal(P.radius(settings(true,true),20),3);
assert.equal(P.radius(settings(true,true),1),3);
assert.equal(P.radius(settings(true,false),20),0);
assert.equal(P.address(8,0,-3,-3),64);
assert.equal(P.address(8,63,3,3),127);
assert.equal(P.edge_color(0xffffff,0,0xffffff,0xffffff,0xffffff),0xdfdfdf);
assert.equal(P.edge_color(0x606060,0x616161,0x606060,0x616161,0x606060),0x606060);
const source=Array.from({length:128},(_,i)=>({$:'Fragment',depth:10,color:i<64?0x123456:0xff0000}));
source[64+2+2*8]={$:'Fragment',depth:2,color:0xffffff};
const saved=structuredClone(source);
const r=P.gather(8,3+3*8,1,10,{fst:source,snd:{$:'Sum',r:0,g:0,b:0,weight:0}});
assert.equal(r.snd.weight,15,'reject a foreground sample across the depth discontinuity');
assert.equal(P.resolved(0,r.snd),0xff0000,'foreground white cannot bleed into far red');
assert.deepEqual(r.fst,saved,'postprocess never changes source color/depth');
for(const width of [512,1024,2048]) {
  assert.equal(P.radius_pixels(width,settings(false,true),20),3*width/1024,'blur has the same screen-space radius at every resolution');
  assert.equal(P.radius_pixels(width,settings(false,true),10),0,'focus plane stays sharp');
}
// Fractional radii, borders, high contrast, and a foreground occlusion edge.
const width=16;
const get=(x,y)=>({depth:x<8?10:20,color:(x+y)%2?0x203040:0xffffff});
const fragments=Array.from({length:512},(_,i)=>({$:'Fragment',...get(i%16,Math.floor((i%256)/16))}));
const original=structuredClone(fragments);
let checked=0;
for(const radius of [0,.01,.2,.749,.751,1.499,1.501,2,3,6])
 for(const y of [0,1,7,8,14,15]) for(const x of [0,1,6,7,8,9,14,15]) {
  const c=get(x,y),s=P.gather(width,x+y*width,radius/Math.sqrt(2),c.depth,{fst:fragments,snd:{$:'Sum',r:0,g:0,b:0,weight:0}});
  const got=P.resolved(c.color,s.snd), expected=defocus(get,width,x,y,radius);
  [16,8,0].forEach((shift,k)=>assert.ok(Math.abs(((got>>>shift)&255)-expected[k])<=1,`${x},${y} radius ${radius}`));
  checked++;
 }
assert.deepEqual(fragments,original,'bilinear filtering preserves source fragments');
const impulse=Array.from({length:512},(_,i)=>({$:'Fragment',depth:10,color:i%256===136?0xffffff:0}));
const brightness=r=>P.resolved(0,P.gather(16,136,r/Math.sqrt(2),10,{fst:impulse,snd:{$:'Sum',r:0,g:0,b:0,weight:0}}).snd)&255;
assert.equal(brightness(0),255);
assert.ok(Math.abs(brightness(.749)-brightness(.751))<=1,'no blur-onset pop');
assert.ok(Math.abs(brightness(1.499)-brightness(1.501))<=1,'no integer-radius pop');
assert.ok(brightness(.2)>brightness(.5)&&brightness(.5)>brightness(1),'blur develops continuously');
console.log(`PASS: ${checked} bilinear depth-aware filter probes, continuous blur, focus and resolution invariance.`);
