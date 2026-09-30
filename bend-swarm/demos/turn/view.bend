import Base
import ./model.bend as G
import ./levels.bend as L
import ./play.bend as P
import ./physics.bend as F
import ./tempo.bend as T
import ./hints.bend as H
import ./hint-routes.bend as HintRoute
import ../../engine/core/math.bend as Math
import ../../engine/render/mesh.bend as M
import ../../engine/render/batch.bend as B
import ./font.bend as Font
import ./style.bend as S
import ./projection.bend as C
import ./world.bend as World

def resolution(v: M.Vertex) -> M.Vertex:
  M.Vertex{x,y,z,l} = v
  M.Vertex{(x * 2.0 : F32),(y * 2.0 : F32),z,l}
def triangle(a: M.Vertex, b: M.Vertex, c: M.Vertex, color: U32, g: B.Batch) -> B.Batch:
  B.push(M.Triangle{resolution(a),resolution(b),resolution(c),color},g)
def quad(+a: M.Vertex, b: M.Vertex, +c: M.Vertex, d: M.Vertex, +color: U32, g: B.Batch) -> B.Batch:
  triangle(a,c,d,color,triangle(a,b,c,color,g))
def rect_at(+depth: F32, +x: F32, +y: F32, w: F32, h: F32, color: U32, g: B.Batch) -> B.Batch:
  +right = (x + w : F32)
  +bottom = (y + h : F32)
  quad(M.Vertex{x,y,depth,1.0},M.Vertex{right,y,depth,1.0},M.Vertex{right,bottom,depth,1.0},M.Vertex{x,bottom,depth,1.0},color,g)
def rect(x: F32, y: F32, w: F32, h: F32, +color: U32, g: B.Batch) -> B.Batch:
  rect_at(Math.pick((color > 5000000 : U32),1.5,2.0),x,y,w,h,color,g)
def box_local(+c: C.Camera, +p: G.Plane, +q: C.V, +rx: F32, +ry: F32, +rz: F32, +color: U32, g: B.Batch) -> B.Batch:
  C.V{+x,+y,+z} = q
  +a = C.project(c,C.world(p,C.V{(x - rx : F32),(y - ry : F32),(z - rz : F32)}))
  +b = C.project(c,C.world(p,C.V{(x + rx : F32),(y - ry : F32),(z - rz : F32)}))
  +d = C.project(c,C.world(p,C.V{(x + rx : F32),(y + ry : F32),(z - rz : F32)}))
  +e = C.project(c,C.world(p,C.V{(x - rx : F32),(y + ry : F32),(z - rz : F32)}))
  +f = C.project(c,C.world(p,C.V{(x - rx : F32),(y - ry : F32),(z + rz : F32)}))
  +h = C.project(c,C.world(p,C.V{(x + rx : F32),(y - ry : F32),(z + rz : F32)}))
  +i = C.project(c,C.world(p,C.V{(x + rx : F32),(y + ry : F32),(z + rz : F32)}))
  +j = C.project(c,C.world(p,C.V{(x - rx : F32),(y + ry : F32),(z + rz : F32)}))
  quad(f,h,i,j,color,quad(a,b,d,e,M.shaded(color,0.5),quad(a,b,h,f,M.shaded(color,0.65),
    quad(e,d,i,j,M.shaded(color,0.85),quad(a,e,j,f,M.shaded(color,0.6),quad(b,d,i,h,M.shaded(color,0.75),g))))))
def box(+c: C.Camera, +p: G.Plane, q: C.V, rx: F32, ry: F32, rz: F32, color: U32, g: B.Batch) -> B.Batch:
  box_local(c,p,C.local(p,q),rx,ry,rz,color,g)
# Fine painted seams sit ON the cube faces; they never shrink a solid voxel.
def decal_vertex(v: M.Vertex) -> M.Vertex:
  M.Vertex{x,y,z,l} = v
  # Camera-depth bias avoids coplanar shimmer without changing world geometry.
  M.Vertex{x,y,(z - 0.002 : F32),l}
def surface(+c: C.Camera, +p: G.Plane, +x: F32, +y: F32, +z: F32, w: F32, h: F32, color: U32, g: B.Batch) -> B.Batch:
  +right = (x + w : F32)
  +top = (y + h : F32)
  quad(decal_vertex(C.project(c,C.world(p,C.V{x,y,z}))),decal_vertex(C.project(c,C.world(p,C.V{right,y,z}))),
    decal_vertex(C.project(c,C.world(p,C.V{right,top,z}))),decal_vertex(C.project(c,C.world(p,C.V{x,top,z}))),color,g)
def face_frame(+c: C.Camera, +p: G.Plane, q: C.V, +r: F32, +width: F32, +color: U32, g: B.Batch) -> B.Batch:
  C.V{+x,+y,+z} = q
  surface(c,p,(x - r : F32),(y - r : F32),z,(r * 2.0 : F32),width,color,
    surface(c,p,(x - r : F32),(y + r - width : F32),z,(r * 2.0 : F32),width,color,
    surface(c,p,(x - r : F32),(y - r : F32),z,width,(r * 2.0 : F32),color,
    surface(c,p,(x + r - width : F32),(y - r : F32),z,width,(r * 2.0 : F32),color,g))))
def face_center(q: C.V) -> C.V:
  C.V{x,y,z} = q
  C.V{x,y,(z + 0.5 : F32)}
def cube_frames(+c: C.Camera, +q: C.V, +r: F32, +width: F32, +color: U32, g: B.Batch) -> B.Batch:
  face_frame(c,G.XY{},face_center(C.local(G.XY{},q)),r,width,color,
    face_frame(c,G.YZ{},face_center(C.local(G.YZ{},q)),r,width,color,
    face_frame(c,G.ZX{},face_center(C.local(G.ZX{},q)),r,width,color,g)))
# Only shared internal faces and back-facing faces are omitted. The selected
# movement plane and the character's position never select the world geometry.
def face_visible(+c: C.Camera, +p: G.Plane, +side: U32) -> Bool:
  a = C.depth(C.rotated(c,C.world(p,C.V{0.0,0.0,0.0})))
  b = C.depth(C.rotated(c,C.world(p,C.V{0.0,0.0,Math.pick(U32.is_eq(side,0),1.0,F32.neg(1.0))})))
  (b - a > 0.00001 : F32)
def wall_face_local(+c: C.Camera, +p: G.Plane, +side: U32, color: U32, q: C.V, g: B.Batch) -> B.Batch:
  C.V{+x,+y,z} = q
  +depth = (z + Math.pick(U32.is_eq(side,0),0.5,F32.neg(0.5)) : F32)
  +color = M.shaded(color,Math.pick(U32.is_eq(side,0),World.light(p),0.5))
  # A full unit face, with its inset paint on the same plane. This has
  # four triangles instead of a face plus four separate border strips.
  surface(c,p,(x - 0.488 : F32),(y - 0.488 : F32),depth,0.976,0.976,color,
    quad(C.project(c,C.world(p,C.V{(x - 0.5 : F32),(y - 0.5 : F32),depth})),
      C.project(c,C.world(p,C.V{(x + 0.5 : F32),(y - 0.5 : F32),depth})),
      C.project(c,C.world(p,C.V{(x + 0.5 : F32),(y + 0.5 : F32),depth})),
      C.project(c,C.world(p,C.V{(x - 0.5 : F32),(y + 0.5 : F32),depth})),
      S.mix(color,S.cream(),0.3),g))
def wall_face(show: Bool, +c: C.Camera, +p: G.Plane, side: U32, +q: G.Point, g: B.Batch) -> B.Batch:
  match show:
    case False{}: g
    case True{}: wall_face_local(c,p,side,S.wall(q),C.local(p,C.point(q)),g)
def wall_faces(+n: Nat, +c: C.Camera, +level: U32, +q: G.Point, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +i = U32.from_nat(k)
      +p = World.face_plane(i)
      +side = (i % 2 : U32)
      wall_faces(k,c,level,q,wall_face(face_visible(c,p,side) && World.exposed(level,q,p,side),c,p,side,q,g))
def voxel(solid: Bool, c: C.Camera, level: U32, q: G.Point, g: B.Batch) -> B.Batch:
  match solid:
    case False{}: g
    case True{}: wall_faces(6n,c,level,q,g)
def world_geometry(+n: Nat, +c: C.Camera, +level: U32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +q = World.cell(U32.from_nat(k))
      world_geometry(k,c,level,voxel(L.solid(level,q),c,level,q,g))
def depth(q: G.Point) -> U32:
  G.Point{_,_,z} = q
  z
def slice(p: G.Plane, q: G.Point) -> U32:
  depth(G.local(p,q))
def body_position(plane: G.Plane, q: G.Point) -> C.V:
  G.Point{x,y,z} = q
  C.world(plane,C.V{(U32.to_f32(x) / 1024.0 - 0.5 : F32),(U32.to_f32(y) / 1024.0 - 0.5 : F32),
    (U32.to_f32(z) / 1024.0 - 0.5 : F32)})
def front(plane: G.Plane, q: C.V) -> C.V:
  C.V{x,y,z} = q
  C.world(plane,C.V{x,y,(z + 0.26 : F32)})
def eyes(+c: C.Camera, +p: G.Plane, q: C.V, g: B.Batch) -> B.Batch:
  C.V{+x,+y,+z} = q
  box(c,p,C.world(p,C.V{(x - 0.065 : F32),(y + 0.035 : F32),(z + 0.29 : F32)}),0.026,0.028,0.006,S.cream(),
    box(c,p,C.world(p,C.V{(x + 0.065 : F32),(y + 0.035 : F32),(z + 0.29 : F32)}),0.026,0.028,0.006,S.cream(),g))
def player(+c: C.Camera, p: P.Play, g: B.Batch) -> B.Batch:
  P.Play{_,+plane,+body,_,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
  +pos = body_position(plane,G.local(plane,F.position(body)))
  eyes(c,plane,C.local(plane,pos),box(c,plane,front(plane,C.local(plane,pos)),0.18,0.09,0.018,1911604,
    box(c,plane,pos,0.25,0.25,0.25,Math.word(F.settled(body),S.amber(),S.mint()),g)))
# The complete exit voxel carries the same luminous markings on all three visible faces.
def goal(+c: C.Camera, t: F32, g: B.Batch) -> B.Batch:
  +glow = S.mix(S.mint(),S.cream(),(0.2 + S.pulse((t * 2.0 : F32)) * 0.4 : F32))
  cube_frames(c,C.V{9.0,9.0,9.0},0.5,0.025,glow,
    cube_frames(c,C.V{9.0,9.0,9.0},0.35,0.018,glow,
    cube_frames(c,C.V{9.0,9.0,9.0},0.18,0.025,S.mint(),
    box(c,G.XY{},C.V{9.0,9.0,9.0},0.5,0.5,0.5,1787198,g))))
def seal_mesh(+c: C.Camera, q: C.V, +color: U32, g: B.Batch) -> B.Batch:
  C.V{+x,+y,+z} = q
  +a = C.project(c,C.V{(x - 0.22 : F32),y,z})
  +b = C.project(c,C.V{x,(y + 0.22 : F32),z})
  +d = C.project(c,C.V{(x + 0.22 : F32),y,z})
  +e = C.project(c,C.V{x,(y - 0.22 : F32),z})
  +f = C.project(c,C.V{x,y,(z + 0.22 : F32)})
  +h = C.project(c,C.V{x,y,(z - 0.22 : F32)})
  triangle(a,b,f,color,triangle(b,d,f,M.shaded(color,0.85),triangle(d,e,f,M.shaded(color,0.7),triangle(e,a,f,color,
    triangle(a,b,h,M.shaded(color,0.5),triangle(b,d,h,color,triangle(d,e,h,color,triangle(e,a,h,color,g))))))))
# A sparse cage keeps the whole 10-cube readable during a turn.
def cage(+n: Nat, +c: C.Camera, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +i = U32.from_nat(k)
      +axis = (i / 4 : U32)
      +a = Math.pick(U32.is_eq(U32.and(i,1),0),F32.neg(0.55),9.55)
      +b = Math.pick(U32.is_eq(U32.and(i,2),0),F32.neg(0.55),9.55)
      +plane = Bool.pick(G.Plane,U32.is_eq(axis,0),G.XY{},Bool.pick(G.Plane,U32.is_eq(axis,1),G.YZ{},G.ZX{}))
      cage(k,c,box(c,plane,C.world(plane,C.V{4.5,a,b}),5.05,0.012,0.012,2703436,g))
# Proportional outline lettering uses the engine's ordinary mesh coverage.
def right_text(+s: String, right: F32, y: F32, +size: F32, color: U32, g: B.Batch) -> B.Batch:
  Font.text(s,(right - Font.measure(s,size) : F32),y,size,color,g)
def centered_text(+s: String, center: F32, y: F32, +size: F32, color: U32, g: B.Batch) -> B.Batch:
  Font.text(s,(center - Font.measure(s,size) * 0.5 : F32),y,size,color,g)
def plane_name(p: G.Plane) -> String:
  match p:
    case G.XY{}: "XY"
    case G.YZ{}: "YZ"
    case G.ZX{}: "ZX"
def hidden_axis(p: G.Plane) -> String:
  match p:
    case G.XY{}: "Z"
    case G.YZ{}: "X"
    case G.ZX{}: "Y"
def coords(q: G.Point) -> String:
  G.Point{x,y,z} = q
  U32.show(x) ++ " / " ++ U32.show(y) ++ " / " ++ U32.show(z)
# Screen-space accents use the same mesh pass, with explicit depth.
def line(+x: F32, +y: F32, +u: F32, +v: F32, +width: F32, +z: F32, color: U32, g: B.Batch) -> B.Batch:
  +dx = (u - x : F32)
  +dy = (v - y : F32)
  +length = F32.max(0.001,F32.sqrt((dx * dx + dy * dy : F32)))
  +nx = (F32.neg(dy) * width / length * 0.5 : F32)
  +ny = (dx * width / length * 0.5 : F32)
  quad(M.Vertex{(x + nx : F32),(y + ny : F32),z,1.0},M.Vertex{(u + nx : F32),(v + ny : F32),z,1.0},
    M.Vertex{(u - nx : F32),(v - ny : F32),z,1.0},M.Vertex{(x - nx : F32),(y - ny : F32),z,1.0},color,g)
def diamond(+x: F32, +y: F32, +r: F32, +z: F32, color: U32, g: B.Batch) -> B.Batch:
  quad(M.Vertex{x,(y - r : F32),z,1.0},M.Vertex{(x + r : F32),y,z,1.0},
    M.Vertex{x,(y + r : F32),z,1.0},M.Vertex{(x - r : F32),y,z,1.0},color,g)
def seal_marker(v: M.Vertex, g: B.Batch) -> B.Batch:
  M.Vertex{x,y,_,_} = v
  diamond(x,y,2.0,4.0,S.amber(),g)
def seal_item(show: Bool, +c: C.Camera, q: G.Point, g: B.Batch) -> B.Batch:
  match show:
    case False{}: g
    case True{}:
      +v = C.point(q)
      seal_marker(C.project(c,v),seal_mesh(c,v,S.amber(),g))
def seals(+n: Nat, +c: C.Camera, +level: U32, +mask: U32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +i = U32.from_nat(k)
      seals(k,c,level,mask,seal_item(Bool.not(P.down(mask,L.flag(i))),c,L.seal(level,i),g))
def arc(+n: Nat, +cx: F32, +cy: F32, +rx: F32, +ry: F32, +start: F32, +span: F32, +width: F32, +z: F32, +color: U32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +a = (start + U32.to_f32(U32.from_nat(k)) / 64.0 * span : F32)
      +b = (a + span / 64.0 : F32)
      arc(k,cx,cy,rx,ry,start,span,width,z,color,
        line((cx + F32.cos(a) * rx : F32),(cy + F32.sin(a) * ry : F32),
        (cx + F32.cos(b) * rx : F32),(cy + F32.sin(b) * ry : F32),width,z,color,g))
def violet() -> U32: 12030463
def ring_face(+n: Nat, +c: C.Camera, +p: G.Plane, +q: C.V, +color: U32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      C.V{+x,+y,+z} = q
      +a = (U32.to_f32(U32.from_nat(k)) * 0.39269908 : F32)
      +b = (a + 0.39269908 : F32)
      ring_face(k,c,p,q,color,quad(
        C.project(c,C.world(p,C.V{(x + F32.cos(a) * 0.38 : F32),(y + F32.sin(a) * 0.38 : F32),z})),
        C.project(c,C.world(p,C.V{(x + F32.cos(b) * 0.38 : F32),(y + F32.sin(b) * 0.38 : F32),z})),
        C.project(c,C.world(p,C.V{(x + F32.cos(b) * 0.34 : F32),(y + F32.sin(b) * 0.34 : F32),z})),
        C.project(c,C.world(p,C.V{(x + F32.cos(a) * 0.34 : F32),(y + F32.sin(a) * 0.34 : F32),z})),color,g))
def ring_marker(v: M.Vertex, +color: U32, g: B.Batch) -> B.Batch:
  M.Vertex{+x,+y,_,_} = v
  Font.text("R",(x - 1.4 : F32),(y - 1.8 : F32),0.45,color,
    arc(64n,x,y,5.5,5.5,0.0,6.283185,0.5,4.0,color,g))
def rings(+n: Nat, +c: C.Camera, +plane: G.Plane, +level: U32, +position: G.Point, +ready: Bool, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +q = L.ring(level,U32.from_nat(k))
      +v = C.point(q)
      +color = Math.word(L.same_projection(G.local(plane,q),G.local(plane,position)) && ready,S.cream(),violet())
      rings(k,c,plane,level,position,ready,ring_marker(C.project(c,v),color,
        ring_face(16n,c,G.XY{},v,color,ring_face(16n,c,G.YZ{},C.local(G.YZ{},v),color,
        ring_face(16n,c,G.ZX{},C.local(G.ZX{},v),color,g)))))
def stars(+n: Nat, +t: F32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +i = U32.from_nat(k)
      +x = (28.0 + Math.random(i,417) * 456.0 : F32)
      +y = (142.0 + F32.mod((Math.random(i,729) * 290.0 + t * 0.9 : F32),290.0) : F32)
      +pulse = S.pulse((t * 0.5 + U32.to_f32(i) : F32))
      stars(k,t,diamond(x,y,(0.4 + pulse * 0.55 : F32),120.0,S.mix(2636115,6912650,pulse),g))
def orbit(on: Bool, phase: F32, g: B.Batch) -> B.Batch:
  match on:
    case False{}: g
    case True{}:
      arc(64n,256.0,282.0,204.0,170.0,F32.neg(1.57),(phase * 6.283185 : F32),1.1,70.0,S.mint(),
        arc(64n,256.0,282.0,204.0,170.0,0.0,6.283185,0.55,80.0,2838615,g))
def flare(v: M.Vertex, size: F32, color: U32, g: B.Batch) -> B.Batch:
  M.Vertex{x,y,z,_} = v
  diamond(x,y,size,z,color,g)
def portal_sparks(+n: Nat, +c: C.Camera, +t: F32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +a = (U32.to_f32(U32.from_nat(k)) * 0.785398 + t * 0.5 : F32)
      portal_sparks(k,c,t,flare(C.project(c,C.V{(9.0 + F32.cos(a) * 0.75 : F32),
        (9.0 + F32.sin(a) * 0.75 : F32),(9.0 + F32.sin((a * 2.0 : F32)) * 0.4 : F32)}),1.2,S.mint(),g))
def locator_vertex(v: M.Vertex, g: B.Batch) -> B.Batch:
  M.Vertex{x,y,_,_} = v
  arc(64n,x,y,7.5,7.5,0.0,6.283185,0.7,5.0,S.amber(),g)
def locator(on: Bool, c: C.Camera, p: P.Play, g: B.Batch) -> B.Batch:
  match on:
    case False{}: g
    case True{}:
      P.Play{_,+plane,+body,_,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
      locator_vertex(C.project(c,body_position(plane,G.local(plane,F.position(body)))),g)
def celebrate(+n: Nat, +age: F32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +i = U32.from_nat(k)
      +a = (U32.to_f32(i) * 2.39996 : F32)
      +radius = (35.0 + age * (80.0 + Math.random(i,34) * 100.0) : F32)
      celebrate(k,age,diamond((256.0 + F32.cos(a) * radius : F32),
        (282.0 + F32.sin(a) * radius * 0.7 + age * age * 25.0 : F32),
        (1.4 - age * 0.8 : F32),0.8,Math.word(U32.is_eq((i % 2 : U32),0),S.mint(),S.amber()),g))
def progress(+turn: U32) -> F32:
  Math.pick(U32.is_eq(turn,0),0.0,(U32.to_f32((turn - 1 : U32)) / U32.to_f32(P.rotation_ticks()) : F32))
def plane_index(p: G.Plane) -> U32:
  match p:
    case G.XY{}: 0
    case G.YZ{}: 1
    case G.ZX{}: 2
def chip(+label: String, +x: F32, +on: Bool, g: B.Batch) -> B.Batch:
  Font.text(label,(x + 10.0 : F32),110.0,0.9,Math.word(on,S.mint(),S.muted()),
    rect(x,103.0,31.0,20.0,Math.word(on,1918785,1054754),
    rect(x,122.0,31.0,0.7,Math.word(on,S.mint(),2173748),g)))
def chapters(+n: Nat, +level: U32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k:
      +i = U32.from_nat(k)
      +spacing = (126.0 / U32.to_f32(L.count()) : F32)
      chapters(k,level,rect((347.0 + U32.to_f32(i) * spacing : F32),78.0,(spacing - 1.5 : F32),2.0,
        Math.word((i <= level : U32),S.mint(),2570306),g))
def normal_controls(+level: U32, +ready: Bool, settling: Bool, g: B.Batch) -> B.Batch:
  Font.text("A D",41.0,460.0,1.0,S.cream(),Font.text("MOVE",83.0,460.0,1.0,S.muted(),
    Font.text("SPACE / UP",154.0,460.0,0.9,S.cream(),Font.text("JUMP",220.0,460.0,1.0,S.muted(),
    Font.text("R",329.0,460.0,1.0,Math.word(U32.is_eq(L.ring_count(level),0),S.mint(),violet()),
    Font.text(Bool.pick(String,settling,"SETTLING VIEW",Bool.pick(String,U32.is_eq(L.ring_count(level),0),"ROTATE WORLD",Bool.pick(String,ready,"RING READY","FIND A RING"))),354.0,460.0,1.0,S.cream(),
    rect(32.0,454.0,39.0,20.0,1910324,rect(148.0,454.0,65.0,20.0,1910324,
    rect(321.0,454.0,24.0,20.0,1918785,g)))))))))
def number(+n: U32) -> String:
  Bool.pick(String,(n < 10 : U32),"0","") ++ U32.show(n)
def time_controls(pace: U32, level: U32, ready: Bool, settling: Bool, g: B.Batch) -> B.Batch:
  match pace:
    case 0: normal_controls(level,ready,settling,g)
    case 1:
      Font.text("TIME FROZEN",32.0,460.0,1.1,S.mint(),
        right_text("R AGAIN / MOVE OR JUMP TO RESUME",480.0,463.0,0.8,S.cream(),
        rect(32.0,479.0,448.0,1.5,S.mint(),g)))
    case _:
      +speed = T.rate(pace)
      Font.text("TIME RESUMING",32.0,460.0,1.1,S.mint(),
        right_text(U32.show((speed / 100 : U32)) ++ "." ++ number((speed % 100 : U32)) ++ " X",480.0,460.0,1.4,S.mint(),
        rect(32.0,479.0,(4.48 * U32.to_f32(speed) : F32),1.5,S.mint(),rect(32.0,479.0,448.0,1.5,2570306,g))))
def controls(turning: Bool, phase: F32, pace: U32, level: U32, ready: Bool, settling: Bool, g: B.Batch) -> B.Batch:
  match turning:
    case True{}:
      Font.text("ROTATING / TIME FROZEN",32.0,460.0,1.0,S.mint(),
        right_text("0.00 X",480.0,459.0,1.4,S.mint(),
        rect(32.0,479.0,(448.0 * phase : F32),1.5,S.mint(),rect(32.0,479.0,448.0,1.5,2570306,g))))
    case False{}: time_controls(pace,level,ready,settling,g)

def victory(done: Bool, +level: U32, age: U32, +seals: U32, +turns: U32, g: B.Batch) -> B.Batch:
  match done:
    case False{}: g
    case True{}:
      celebrate(28n,(U32.to_f32(age) / 120.0 : F32),
        centered_text(Bool.pick(String,L.last(level),"ALL WORLDS ALIGNED","PERSPECTIVE FOUND"),256.0,263.0,1.45,S.cream(),
        centered_text(Bool.pick(String,L.last(level),"N TO BEGIN AGAIN","NEXT CHAPTER..."),256.0,297.0,0.85,S.mint(),
        centered_text("SEALS " ++ U32.show(L.seal_total(seals)) ++ "/" ++ U32.show(L.seal_count(level)) ++ "  TURNS " ++ U32.show(turns) ++ "/" ++ U32.show(L.par(level)),256.0,282.0,0.9,
          Math.word(U32.is_eq(seals,L.all_seals(level)) && (turns <= L.par(level) : U32),S.mint(),S.muted()),
        rect(143.0,251.0,226.0,59.0,859673,rect(143.0,249.0,226.0,1.0,S.mint(),g))))))
def difficulty_color(level: U32) -> U32:
  Math.word((L.difficulty(level) >= 3 : U32),S.amber(),S.mint())
# A hint is a screen-space target in the active projection, hidden while the
# camera turns. Coordinates come from successful continuous keyboard replays.
def hint_color() -> U32: 8641513
def hint_marker_local(q: G.Point, airborne: Bool, g: B.Batch) -> B.Batch:
  G.Point{x,y,_} = q
  +sx = (256.0 + (U32.to_f32(x) / 1024.0 - 5.0) * 30.0 : F32)
  +sy = (282.0 - (U32.to_f32(y) / 1024.0 - 5.0) * 30.0 : F32)
  +color = hint_color()
  centered_text(Bool.pick(String,airborne,"JUMP / R","R HERE"),sx,(sy - 22.0 : F32),0.8,color,
    rect((sx - 10.0 : F32),(sy - 10.0 : F32),20.0,1.0,color,
    rect((sx - 10.0 : F32),(sy + 9.0 : F32),20.0,1.0,color,
    rect((sx - 10.0 : F32),(sy - 10.0 : F32),1.0,20.0,color,
    rect((sx + 9.0 : F32),(sy - 10.0 : F32),1.0,20.0,color,g)))))
def hint_marker(spot: HintRoute.Spot, plane: G.Plane, g: B.Batch) -> B.Batch:
  HintRoute.Spot{_,q,_,airborne} = spot
  hint_marker_local(G.local(plane,q),airborne,g)
def hint_marker_if(show: Bool, spot: HintRoute.Spot, plane: G.Plane, g: B.Batch) -> B.Batch:
  match show:
    case False{}: g
    case True{}: hint_marker(spot,plane,g)
def hint_markers(spots: List<HintRoute.Spot>, +plane: G.Plane, +target: U32, g: B.Batch) -> B.Batch:
  match spots:
    case Nil{}: g
    case +spot <> rest:
      HintRoute.Spot{p,_,order,_} = spot
      hint_markers(rest,plane,target,hint_marker_if(U32.is_eq(order,target) && H.same_plane(plane,p),spot,plane,g))
def hint_overlay(show: Bool, level: U32, plane: G.Plane, target: U32, g: B.Batch) -> B.Batch:
  match show:
    case False{}: g
    case True{}: hint_markers(HintRoute.route(level),plane,target,g)
def hint_copy(note: U32, used: U32, pending: Bool, level: U32) -> String:
  match note:
    case 100: "HINT / NO MORE R NEEDED ON THIS ROUTE. REACH THE EXIT."
    case 101: "HINT / OFF THE SOLUTION ROUTE. RESTART TO FOLLOW IT."
    case _: Bool.pick(String,pending,"HINT / REACH THE BLUE MARK, THEN R. JUMP IF IT IS IN THE AIR.",
      Bool.pick(String,U32.is_eq(used,3),"ALL THREE HINTS USED / BACKSPACE TO RESTART.",L.hint(level)))
def hud(+p: P.Play, g: B.Batch) -> B.Batch:
  P.Play{+level,+plane,+body,+turn,_,_,+turns,_,_,_,age,+mask,_,_,_,pace,+hints} = p
  H.Hints{_,+target,note} = hints
  +pending = (target > turns : U32)
  +q = F.cells(F.position(body))
  victory(P.arrived(p),level,age,mask,turns,controls(U32.is_ne(turn,0),progress(turn),pace,level,P.can_turn(p),Bool.not(F.settled(body)),
    Font.text("TURN",29.0,29.0,5.2,S.cream(),
    Font.text("A MATTER OF PERSPECTIVE",33.0,77.0,0.9,S.muted(),
    Font.text("CHAPTER " ++ number((L.index(level) + 1 : U32)) ++ " / " ++ U32.show(L.count()),347.0,34.0,0.85,S.mint(),
    Font.text(L.title(level),347.0,51.0,1.05,S.cream(),
    Font.text(L.difficulty_name(L.difficulty(level)),347.0,66.0,0.8,difficulty_color(level),chapters(U32.to_nat(L.count()),L.index(level),
    chip("XY",32.0,U32.is_eq(plane_index(plane),0),chip("YZ",72.0,U32.is_eq(plane_index(plane),1),chip("ZX",112.0,U32.is_eq(plane_index(plane),2),
    Font.text("SEALS " ++ U32.show(L.seal_total(mask)) ++ " / " ++ U32.show(L.seal_count(level)),166.0,110.0,0.75,S.amber(),
    right_text("EXIT / ANY DEPTH",480.0,110.0,0.85,S.mint(),
    Font.text(coords(q),32.0,429.0,0.85,S.muted(),
    right_text(U32.show(turns) ++ " TURNS / PAR " ++ U32.show(L.par(level)),480.0,429.0,0.85,S.muted(),
    Font.text(hint_copy(note,H.count(hints),pending,level),32.0,440.0,0.8,S.muted(),
    Font.text("TAB  CHAPTERS",32.0,488.0,0.95,S.mint(),
    Font.text("H  HINT " ++ U32.show((3 - H.count(hints) : U32)) ++ "/3",177.0,488.0,0.9,8641513,
    right_text("BACKSPACE / DELETE  RESTART",480.0,488.0,0.95,S.cream(),
    rect(32.0,95.0,448.0,0.5,2570306,hint_overlay(pending && U32.is_eq(turn,0),level,plane,target,g)))))))))))))))))))))
def chapter_card(+i: U32, +selected: U32, +completed: U32, g: B.Batch) -> B.Batch:
  +level = L.at(i)
  +x = (32.0 + U32.to_f32((i % 3 : U32)) * 152.0 : F32)
  +y = (119.0 + U32.to_f32((i % P.page_size() / 3 : U32)) * 47.0 : F32)
  +on = U32.is_eq(i,selected)
  Font.text(number((i + 1 : U32)),(x + 8.0 : F32),(y + 8.0 : F32),0.75,Math.word(on,S.mint(),S.muted()),
    Font.text(L.title(level),(x + 26.0 : F32),(y + 8.0 : F32),0.95,S.cream(),
    Font.text(L.difficulty_name(L.difficulty(level)) ++ " / PAR " ++ U32.show(L.par(level)),(x + 8.0 : F32),(y + 25.0 : F32),0.8,difficulty_color(level),
    rect(x,y,144.0,39.0,Math.word(on,1918785,1054754),
    rect(x,(y + 38.0 : F32),144.0,1.0,Math.word(on || P.down(completed,L.flag(level)),S.mint(),2570306),g)))))
def chapter_cards(+n: Nat, +start: U32, +selected: U32, +completed: U32, g: B.Batch) -> B.Batch:
  match n:
    case 0n: g
    case 1n+k: chapter_cards(k,start,selected,completed,chapter_card((start + U32.from_nat(k) : U32),selected,completed,g))
def menu_scene(p: P.Play, batch: B.Batch) -> B.Batch:
  P.Play{_,_,_,_,_,_,_,_,_,_,_,_,_,+selected,completed,pace,hints} = p
  +level = L.at(selected)
  +start = P.page_start(selected)
  Font.text("CHAPTERS",32.0,32.0,3.8,S.cream(),
    Font.text(U32.show(L.count()) ++ " WORLDS / TAKE YOUR OWN ROUTE",33.0,76.0,0.85,S.muted(),
    Font.text(Bool.pick(String,U32.is_eq(start,0),"EVERY VISIBLE WALL IS SOLID. DEPTH DOES NOT MATTER.","TURNING ROOMS / ALIGN WITH A VIOLET RING TO ROTATE"),32.0,98.0,0.9,
      Math.word(U32.is_eq(start,0),S.amber(),violet()),
    chapter_cards(U32.to_nat(U32.min(P.page_size(),(L.count() - start : U32))),start,selected,completed,
    Font.text(L.hint(level),32.0,423.0,1.0,S.cream(),
    Font.text("SEALS " ++ U32.show(L.seal_count(level)) ++ " / TARGET " ++ U32.show(L.par(level)) ++ " TURNS",32.0,443.0,0.9,S.mint(),
    Font.text("Q E PAGE " ++ U32.show((start / P.page_size() + 1 : U32)) ++ "/" ++ U32.show(P.page_count()),32.0,463.0,0.9,S.mint(),
    Font.text("ARROWS CHOOSE / ENTER PLAY / TAB BACK",32.0,484.0,1.0,S.muted(),B.clear(batch)))))))))
def backdrop_color(+x: U32, +y: U32) -> M.Fragment:
  +dx = ((U32.to_f32(x) - 512.0) / 512.0 : F32)
  +dy = ((U32.to_f32(y) - 560.0) / 512.0 : F32)
  +halo = (1.0 / (1.0 + dx * dx * 3.0 + dy * dy * 2.0) : F32)
  +grain = (Math.random((x + y * 1024 : U32),137) * 1.6 : F32)
  M.Fragment{1000.0,S.rgb((5.0 + halo * 7.0 + grain : F32),(9.0 + halo * 13.0 + grain : F32),(17.0 + halo * 20.0 + grain : F32))}
def background(x: U32, y: U32) -> M.Fragment:
  backdrop_color(x,y)
# Immutable scenery is a function of level and camera only. The independent
# entry point is exercised with moving, three-turn controller replays.
def scenery(c: C.Camera, level: U32, batch: B.Batch) -> B.Batch:
  world_geometry(1000n,c,level,B.clear(batch))
def game_scene(+p: P.Play, batch: B.Batch) -> B.Batch:
  P.Play{+level,+plane,+body,+turn,_,ticks,_,_,_,_,_,mask,_,_,_,pace,hints} = p
  +c = C.camera(plane,progress(turn))
  +t = (U32.to_f32(ticks) / 120.0 : F32)
  hud(p,locator(True{},c,p,player(c,p,rings(U32.to_nat(L.ring_count(level)),c,plane,level,F.cells(F.position(body)),P.can_turn(p),
    seals(U32.to_nat(L.seal_count(level)),c,level,mask,portal_sparks(8n,c,t,goal(c,t,cage(12n,c,
    orbit(U32.is_ne(turn,0),progress(turn),stars(48n,t,scenery(c,level,batch)))))))))))
def selected_scene(menu: Bool, p: P.Play, batch: B.Batch) -> B.Batch:
  match menu:
    case True{}: menu_scene(p,batch)
    case False{}: game_scene(p,batch)
def scene(+p: P.Play, batch: B.Batch) -> B.Batch:
  P.Play{_,_,_,_,_,_,_,_,_,_,_,_,menu,_,_,pace,hints} = p
  selected_scene(menu,p,batch)
