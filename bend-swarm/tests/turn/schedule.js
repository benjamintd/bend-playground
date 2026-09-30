import assert from 'node:assert/strict';
import S from '../../demos/turn/schedule.bend';
import P from '../../demos/turn/play.bend';
import Cadence from '../../engine/platform/cadence.bend';
const normalized=value=>JSON.parse(JSON.stringify(value,(key,v)=>key==='$'?v.split('.').pop():v));
const list=xs=>xs.reduceRight((tail,head)=>({$:'Con',head,tail}),{$:'Nil'});
const input=(active,events,p,dirty=false)=>S.input(list(events),active,{fst:p,snd:dirty});
const key=(code,down)=>({$:'Key',code,down});
const start=P.create(0),menu=P.toggle(start);
assert.equal(S.period(start),33334);
for(const p of [P.key(100,true,start),P.command(114,start),{...start,body:{...start.body,vy:2100}},
 {...start,body:{...start.body,escape:12}},{...start,body:{...start.body,buffer:12}},{...start,finished:1}]){
 assert.equal(S.period(p),16667,'motion, held input, buffering, turning and completion retain 60 Hz');
}
for(const focused of [false,true])for(const visible of [false,true]){
 const active=S.active({$:'Activity',focused,visible,interrupted:false});assert.equal(active,focused&&visible);
 if(!active)for(const p of [start,menu]){
  assert.equal(Cadence.due(active,true,S.period(p),10000000),false,'inactive windows never render, even when dirty');
  assert.equal(Cadence.wait_ms(active,true,S.period(p),10000000),1000);
 }
}
assert.equal(Cadence.due(true,false,S.period(menu),10000000),false,'static menus retain their previous frame');
assert.equal(Cadence.wait_ms(true,false,S.period(menu),10000000),1000);
assert.equal(Cadence.due(true,true,S.period(menu),0),true,'menu input or resume redraws immediately');
assert.equal(Cadence.wait_ms(true,true,S.period(menu),0),0);
assert.equal(Cadence.due(true,false,S.period(start),33333),false);
assert.equal(Cadence.due(true,false,S.period(start),33334),true);
assert.equal(Cadence.wait_ms(true,false,S.period(start),33000),1,'round waits up instead of busy polling');
let p=P.key(100,true,P.key(32,true,start));p.accumulator=.7;
const held=structuredClone(p),paused=S.elapsed(false,true,200,p);
assert.equal(paused.keys,0);assert.equal(paused.accumulator,0);assert.equal(paused.body.buffer,0);
assert.deepEqual(paused.body.position,held.body.position);assert.equal(paused.time,held.time);
const resumed=S.elapsed(true,false,200,paused);
assert.deepEqual(resumed,paused,'resume does not simulate time spent in the background');
assert.deepEqual(normalized(S.elapsed(true,true,1/30,resumed)),normalized(P.tick(1/30,resumed)),'active physics remains fixed-step');
assert.deepEqual(input(false,[key(100,true),key(114,true)],paused).fst,paused,'background input cannot move or turn');
assert.equal(input(false,[{$:'Close'}],paused).fst.quit,true,'close still works while inactive');
assert.equal(input(true,[{$:'Move',x:10,y:20},{$:'Mouse',x:10,y:20,button:0,down:true}],menu).snd,false,'unused pointer activity does not redraw menus');
const picked=input(true,[key(63235,true),key(63235,false)],menu);
assert.equal(picked.snd,true);assert.notEqual(picked.fst.selection,menu.selection);
assert.equal(picked.fst.keys,0,'event order and key releases are preserved');
assert.equal(S.elapsed(false,true,100,P.command(114,start)).turn,P.command(114,start).turn,'camera turns freeze while inactive');
console.log('PASS: foreground/background/occlusion policy, static menus, idle pacing, ordered input, held-key reset and resume without catch-up.');

assert.equal(S.continuous({$:'Activity',focused:true,visible:true,interrupted:true}),false,
  'an intervening focus loss is retained even if the app is already active again');

const frozen=P.steps(BigInt(P.rotation_ticks()),P.command(114,start));
assert.equal(S.period(frozen),0,'frozen time retains a static frame until input');
assert.equal(S.period(P.command(100,frozen)),16667,'the fade renders at 60 Hz');
assert.equal(S.period(P.command(114,frozen)),16667,'a chained camera turn still animates');
