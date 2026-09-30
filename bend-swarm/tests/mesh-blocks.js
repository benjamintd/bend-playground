import assert from 'node:assert/strict';
import M from '../engine/render/mesh.bend';
import T from './mesh.bend';
import G from './mesh-blocks.bend';

const triangles = T.fixture();
triangles.push({$: 'Triangle',
  a: {$: 'Vertex', x: 100, y: 100, z: 1.5, light: .2},
  b: {$: 'Vertex', x: 400, y: 100, z: 3, light: 1},
  c: {$: 'Vertex', x: 100, y: 400, z: 2, light: .6}, color: 0xfedcba});
triangles.push({...triangles[0], color: 0xffff00}); // equal-depth tie
triangles.push({...triangles[4], b: triangles[4].c, c: triangles[4].b});
const saved = structuredClone(triangles);
const background = [1000, 1, 2, 4].map((depth, i) => ({$: 'Fragment', depth, color: 0x102030 + i}));
let probes = 0;
for (const order of [[0, 1, 2, 3, 4, 5, 6], [6, 5, 4, 3, 2, 1, 0]]) {
  const ids = [0, 0, ...order, 0];
  for (const count of [0, 1, 3, 7]) {
    for (let y = 95.5; y < 405; y += 11) for (let x = 95.5; x < 405; x += 13) {
      const result = M.block_query(BigInt(count), 2, x, y, {
        $: 'BlockQuery', triangles, ids, ...Object.fromEntries(['a', 'b', 'c', 'd'].map((k, i) => [k, background[i]])),
      });
      for (const [i, key] of ['a', 'b', 'c', 'd'].entries()) {
        const expected = M.query(BigInt(count), 2, x + i % 2, y + Math.floor(i / 2), {
          $: 'Query', triangles, ids, result: background[i],
        }).result;
        assert.deepEqual(result[key], expected, `block ${x},${y}, sample ${key}, count ${count}`);
        probes++;
      }
      assert.deepEqual(result.ids, ids);
    }
  }
}
assert.deepEqual(triangles, saved, 'triangle reads remain immutable');
console.log(`PASS: ${probes} batched/scalar fragments, distinct per-pixel backgrounds, perspective depth, lighting, ties, winding and partial candidate ranges.`);

const result = G.render(triangles.length, [...triangles, M.blank()]);
for (let y = 0; y < 512; y++) for (let x = 0; x < 512; x++) {
  const i = x + y * 512, bg = {$: 'Fragment', depth: 1 + x / 256 + y / 512, color: x * 257 + y};
  let expected = bg;
  for (const triangle of triangles) expected = M.sample(x + .5, y + .5, triangle, expected);
  assert.equal(result.fst.pixels[i], expected.color, `gradient pixel ${x},${y}`);
  for (const key of ['color', 'depth']) {
    assert.equal(result.fst.background[i][key], bg[key], 'static background remains immutable');
    assert.equal(result.fst.background[262144 + i][key], expected[key], 'resolved block depth/color stays at its own pixel');
  }
}
console.log('PASS: 262144 raster pixels and retained depth values over an independently varying background.');
