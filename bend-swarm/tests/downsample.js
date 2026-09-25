import assert from 'node:assert/strict';
import D from '../engine/render/downsample.bend';
assert.equal(D.average(0xffffff,0xffffff,0,0),0x7f7f7f);
assert.equal(D.average(0xff0000,0xff0000,0,0),0x7f0000);
assert.equal(D.average(0x123456,0x123456,0x123456,0x123456),0x123456);
assert.equal(D.color({$:'Qua',tl:{$:'Pix',color:0xff0000},tr:{$:'Pix',color:0},bl:{$:'Pix',color:0xff0000},br:{$:'Pix',color:0}}),0x7f0000);
console.log('PASS: exact four-sample coverage resolve and constant-color preservation.');
