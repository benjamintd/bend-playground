import Base
import ../engine/render/mesh.bend as M
import ../engine/render/finish.bend as Finish
import ../engine/render/post.bend as Post
import ./image-check.bend as Check

def vertex(x: F32, y: F32) -> M.Vertex:
  M.Vertex{x,y,2.0,1.0}
def quad(+i: U32, +left: F32, +top: F32, +right: F32, +bottom: F32, +color: U32, a: Array<M.Triangle>) -> Array<M.Triangle>:
  Array.set(M.Triangle,Array.set(M.Triangle,a,i,M.Triangle{vertex(left,top),vertex(right,top),vertex(right,bottom),color}),
    (i + 1 : U32),M.Triangle{vertex(left,top),vertex(right,bottom),vertex(left,bottom),color})
def backdrop(x: U32, y: U32) -> M.Fragment:
  M.Fragment{1000.0,0}
def built(r: Array<M.Triangle> & M.Index) -> M.Drawing & Image:
  (tris,M.Index{_,offsets,_,ids,_}) = r
  M.render_level(~2n,True{},M.Drawing{tris,offsets,ids,Array.new(U32,22n,0),
    M.backdrop_level(~2n,~backdrop,Array.new(M.Fragment,23n,M.Fragment{0.0,0}))},Pix{0})
def rendered() -> M.Drawing & Image:
  built(M.build_level(~2n,True{},4,quad(2,100.25,256.0,100.75,1792.0,16711680,
    quad(0,512.0,512.0,1536.0,1536.0,16777215,Array.new(M.Triangle,2n,M.blank()))),M.empty()))
def coverage_built(gpu: Bool, r: Array<M.Triangle> & M.Index) -> M.Drawing & Image:
  (tris,M.Index{_,offsets,_,ids,_}) = r
  Finish.draw_level(~1n,gpu,Post.Settings{True{},False{},10.0,4.0},M.Drawing{tris,offsets,ids,Array.new(U32,20n,0),
    M.backdrop_level(~1n,~backdrop,Array.new(M.Fragment,21n,M.Fragment{0.0,0}))},Pix{0})
def coverage_rendered(+gpu: Bool) -> M.Drawing & Image:
  coverage_built(gpu,M.build_level(~1n,gpu,4,quad(2,50.1,128.0,50.35,896.0,16711680,
    quad(0,256.0,256.0,768.0,768.0,16777215,Array.new(M.Triangle,2n,M.blank()))),M.empty()))
def coverage_again(gpu: Bool, r: M.Drawing & Image) -> M.Drawing & Image:
  (drawing,image) = r
  Finish.draw_level(~1n,gpu,Post.Settings{True{},False{},10.0,4.0},drawing,image)
def pixel(i: U32, r: Array<U32> & U32) -> IO(Array<U32>):
  (p,c) = r
  do IO<Array<U32>>:
    Unit <- IO.print("pixel," ++ U32.show(i) ++ "," ++ U32.show(c))
    return p
def report(r: Check.Check) -> IO(Unit):
  Check.Check{_,count,errors} = r
  IO.print("image," ++ U32.show(count) ++ "," ++ U32.show(errors))
def check(+size: U32, r: M.Drawing & Image) -> IO(Unit):
  (M.Drawing{_,_,_,p,_},image) = r
  do IO<Unit>:
    p : Array<U32> <- pixel((size * (size / 2) + size / 2 : U32),Array.get(U32,p,(size * (size / 2) + size / 2 : U32)))
    p : Array<U32> <- pixel((size * (size / 2) + size * 50 / 1024 : U32),Array.get(U32,p,(size * (size / 2) + size * 50 / 1024 : U32)))
    p : Array<U32> <- pixel(0,Array.get(U32,p,0))
    report(Check.image(image,size,size,0,0,Check.Check{p,0,0}))
def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- check(2048,rendered())
    Unit <- check(1024,Finish.resolve(~1n,True{},True{},rendered()))
    Unit <- check(1024,coverage_again(False{},coverage_rendered(False{})))
    check(1024,coverage_again(True{},coverage_rendered(True{})))
