import assert from 'node:assert/strict';
import M from './parallel.bend';
import R from '../engine/parallel/reduce.bend';
import S from '../engine/parallel/scan.bend';
for(const n of [1,2,8,32,128]) for(const depth of [0n,1n,3n,10n]) {
  const a=Array.from({length:n},(_,i)=>i+1);
  assert.deepEqual(M.mapped(depth,[...a]),a.map(x=>x*2));
  const r=R.sum(depth,n,[...a]); assert.equal(r.total,n*(n+1)/2); assert.deepEqual(r.array,a);
  const s=S.exclusive(n,[...a],Array(n).fill(0));
  assert.deepEqual(s.offsets,a.map((_,i)=>i*(i+1)/2)); assert.equal(s.total,r.total);
}
// Odd active range: capacity is still 8, only 5 slots participate.
assert.equal(R.sum(2n,5,[1,2,3,4,5,99,99,99]).total,15);
console.log('PASS: map/reduce/exclusive scan, boundary depths and partial active ranges.');
