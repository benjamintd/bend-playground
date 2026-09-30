import Base
import ../camera.bend as C
import ../spatial/layout.bend as L
import ../core/vec3.bend as V
import ./mesh.bend as M
import ./batch.bend as B

# World geometry -> clipped screen triangles. All work happens on the host.
# Polygon allocation is limited to triangles crossing the six view planes.
type Vertex is Data:
  Vertex{point: L.Point, light: F32}
type Triangle is Data:
  Triangle{a: Vertex, b: Vertex, c: Vertex, color: U32}
def vertex(view: C.View, v: Vertex) -> Vertex:
  Vertex{p,l} = v
  Vertex{C.view_point(view,p),l}
def distance(+v: Vertex, normal: L.Point, offset: F32) -> F32:
  Vertex{p,_} = v
  (V.dot(p,normal) + offset : F32)
def lerp(a: Vertex, b: Vertex, +t: F32) -> Vertex:
  Vertex{ap,al} = a
  Vertex{bp,bl} = b
  Vertex{V.lerp(ap,bp,t),F32.lerp(al,bl,t)}
def edge(ain: Bool, bin: Bool, +a: Vertex, +b: Vertex, +da: F32, db: F32, out: List<&2, Vertex>) -> List<&2, Vertex>:
  match ain bin:
    case True{} True{}: b <> out
    case False{} False{}: out
    case True{} False{}: lerp(a,b,(da / (da - db) : F32)) <> out
    case False{} True{}: b <> lerp(a,b,(da / (da - db) : F32)) <> out
def clip_edge(+a: Vertex, +b: Vertex, out: List<&2, Vertex>, +normal: L.Point, +offset: F32) -> List<&2, Vertex>:
  +da = distance(a,normal,offset)
  +db = distance(b,normal,offset)
  edge((da >= 0.0 : F32),(db >= 0.0 : F32),a,b,da,db,out)
def clip_walk(xs: List<&2, Vertex>, +first: Vertex, +previous: Vertex, +normal: L.Point, +offset: F32, out: List<&2, Vertex>) -> List<&2, Vertex>:
  match xs:
    case Nil{}: List.reverse(&2,Vertex,clip_edge(previous,first,out,normal,offset))
    case +v <> rest: clip_walk(rest,first,v,normal,offset,clip_edge(previous,v,out,normal,offset))
def clip_plane(xs: List<&2, Vertex>, p: L.Point & F32) -> List<&2, Vertex>:
  match xs:
    case Nil{}: Nil{}
    case +first <> rest:
      (normal,offset) = p
      clip_walk(rest,first,first,normal,offset,Nil{})
def clip(n: Nat, +i: U32, +view: C.View, xs: List<&2, Vertex>) -> List<&2, Vertex>:
  match n:
    case 0n: xs
    case 1n+k: clip(k,(i + 1 : U32),view,clip_plane(xs,C.plane(view,i)))
def screen_result(light: F32, p: C.Projection) -> M.Vertex:
  C.Projection{x,y,z,_} = p
  M.Vertex{x,y,z,light}
def screen(view: C.View, v: Vertex) -> M.Vertex:
  Vertex{p,l} = v
  screen_result(l,C.project_view(view,p))
def screen_triangle(+view: C.View, a: Vertex, b: Vertex, c: Vertex, color: U32) -> M.Triangle:
  C.View{_,_,_,_,_,_,_,_,_,_,_,o} = view
  M.projected(screen(view,a),screen(view,b),screen(view,c),color,o)
def fan(xs: List<&2, Vertex>, +a: Vertex, +b: Vertex, +view: C.View, +color: U32, out: B.Batch) -> B.Batch:
  match xs:
    case Nil{}: out
    case +c <> rest: fan(rest,a,c,view,color,B.push(screen_triangle(view,a,b,c,color),out))
def polygon(xs: List<&2, Vertex>, view: C.View, color: U32, out: B.Batch) -> B.Batch:
  match xs:
    case a <> b <> rest: fan(rest,a,b,view,color,out)
    case _: out
def visible(p: C.Projection) -> Bool:
  C.Projection{_,_,_,v} = p
  v
def vertex_inside(view: C.View, v: Vertex) -> Bool:
  Vertex{p,_} = v
  visible(C.project_view(view,p))
def triangle_inside(inside: Bool, +view: C.View, a: Vertex, b: Vertex, c: Vertex, color: U32, out: B.Batch) -> B.Batch:
  match inside:
    case True{}: B.push(screen_triangle(view,a,b,c,color),out)
    case False{}: polygon(clip(6n,0,view,[a,b,c]),view,color,out)
def triangle_view(+view: C.View, +a: Vertex, +b: Vertex, +c: Vertex, color: U32, out: B.Batch) -> B.Batch:
  triangle_inside(vertex_inside(view,a) && vertex_inside(view,b) && vertex_inside(view,c),view,a,b,c,color,out)
def triangle(+view: C.View, t: Triangle, out: B.Batch) -> B.Batch:
  Triangle{a,b,c,color} = t
  triangle_view(view,vertex(view,a),vertex(view,b),vertex(view,c),color,out)
def triangles(xs: List<&2, Triangle>, +view: C.View, out: B.Batch) -> B.Batch:
  match xs:
    case Nil{}: out
    case t <> rest: triangles(rest,view,triangle(view,t,out))
