import assert from 'node:assert/strict';
import C from '../engine/platform/cadence.bend';
for(const active of [false,true])for(const dirty of [false,true])
for(const period of [0,1,1000,16667,33334,1000000,0xffffffff])
for(const age of [0,1,16666,16667,33334,1000000,0xffffffff]) {
 const due=active&&(dirty||(period!==0&&age>=period));
 const delay=active?(dirty?0:period?Math.min(1000,Math.ceil(Math.max(0,period-age)/1000)):1000):1000;
 assert.equal(C.due(active,dirty,period,age),due);
 assert.equal(C.wait_ms(active,dirty,period,age),delay);
}
console.log('PASS: cadence static/animated/dirty/inactive decisions, rounded waits, overdue frames and U32 extremes.');
