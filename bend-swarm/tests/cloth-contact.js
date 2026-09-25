import assert from 'node:assert/strict';
import C from '../demos/cloth/contact.bend';
import V from '../engine/core/vec3.bend';
const p=(x,y,z)=>({$:'Point',x,y,z});
const a=p(-1,0,-1),b=p(1,0,-1),c=p(0,0,1);
// Cross the middle of a face, far from every vertex: old particle-only
// collision cannot detect this, even with arbitrarily precise arithmetic.
let push=C.face(p(0,-.01,0),p(0,.02,0),a,b,c,a,b,c);
assert.ok(push.delta.y>.02 && push.weight===1);
assert.equal(C.face(p(2,-.01,0),p(2,.02,0),a,b,c,a,b,c).weight,0,'outside finite triangle');
assert.equal(C.face(p(0,.1,0),p(0,.12,0),a,b,c,a,b,c).weight,0,'separated');
push=C.face(p(0,.01,0),p(0,-.02,0),a,b,c,a,b,c);
assert.ok(push.delta.y<-.02,'two-sided contact');
push=C.face(p(0,.01,0),p(0,.02,0),p(-1,.02,-1),p(1,.02,-1),p(0,.02,1),a,b,c);
assert.ok(push.delta.y>.02,'moving triangle');
const edge=C.edge(p(-1,-.01,0),p(1,-.01,0),p(0,0,-1),p(0,0,1),p(-1,.02,0),p(1,.02,0),p(0,0,-1),p(0,0,1));
assert.ok(edge.delta.y>0,'crossing edges with no nearby endpoints');
for(const points of [[a,a,b,b],[a,b,a,b],[a,b,p(-1,0,0),p(1,0,0)]]) {
 const r=C.edge(...points,...points);assert.ok([r.delta.x,r.delta.y,r.delta.z,r.weight].every(Number.isFinite));
}
assert.ok(Math.abs(V.length(V.limited(p(0,0,0),p(10,0,0),.02))-.02)<1e-6,'bounded drag motion');
console.log('PASS: moving two-sided vertex/face and crossing edge contact, finite bounds, degenerate geometry and bounded motion.');
