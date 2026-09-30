import assert from 'node:assert/strict';
import T from './policy.bend';
import P from '../engine/parallel/policy.bend';
import F from '../engine/profile/frame.bend';
import App from '../demos/cloth/main.bend';
import Player from '../engine/platform/player.bend';
for (let bits=0;bits<32;bits++) {
  const flags=Array.from({length:5},(_,i)=>!!(bits&(1<<i)));
  const p={$:'Policy',simulation:flags[0],geometry:flags[1],binning:flags[2],raster:flags[3],post:flags[4],simulation_depth:10n};
  assert.deepEqual(P.supported(false,p),P.all(false,0n),'CPU runtime clears every stage and solver depth');
  assert.deepEqual(P.supported(true,p),{...p,simulation_depth:flags[0]?10n:0n},'independent stage choices survive');
}
assert.equal(P.cloth(true).simulation,false,'interactive cloth never opts into the slow GPU solver');
assert.deepEqual(P.hybrid(),{$:'Policy',simulation:false,geometry:false,binning:false,raster:true,post:true,simulation_depth:0n});
const sample={$:'Sample',policy:P.hybrid(),simulation_us:100,geometry_us:200,binning_us:300,raster_us:400,post_us:500};
assert.equal(F.render(sample),1400); assert.equal(F.work(sample),1500);
const columns=F.csv_header().split(',');const values=F.csv(sample).split(',').map(Number);
assert.equal(columns.length,values.length);assert.deepEqual(values,[0,0,0,1,1,100,200,300,400,500,1500]);
assert.deepEqual(Player.summary({$:'Measured',simulation_us:10,render_us:20,count:4096,profile:sample}),{$:'Tuple',fst:10,snd:{$:'Tuple',fst:20,snd:4096}});
const controls={$:'Controls',gpu:true,paused:false,reset:false,quit:false,wind:true,hud:true,mx:200,my:230,picking:false,grab:528,grab_depth:7.2,scale_x:.5,scale_y:.5,high:true,aa:true,dof:true};
for (const us of [0,123,16667,10000000,0xffffffff]) {
  const large={...sample,simulation_us:us,geometry_us:us,binning_us:us,raster_us:us,post_us:us};
  for (const text of [App.profile_label(controls,large),T.meadow_label(large)]) {
    assert.ok(text.split('\n').length<=16,'profiler fits 16 HUD rows');
    assert.ok(text.split('\n').every(line=>line.length<=16),'profiler fits 16 HUD columns even during a stall');
  }
}
console.log('PASS: all 32 stage policies, CPU fallback, profiler CSV/accounting and HUD bounds.');
