import Base
import ../engine/render/mesh.bend as M

def background(x: U32, y: U32) -> M.Fragment:
  M.Fragment{1000.0,66051}

def built(gpu: Bool, r: Array<M.Triangle> & M.Index) -> M.Drawing & Image:
  (tris,M.Index{_,offsets,_,ids,_}) = r
  M.render(~background,gpu,M.Drawing{tris,offsets,ids,Array.new(U32,18n,0)},Pix{0})

def render(+gpu: Bool, n: U32, tris: Array<M.Triangle>) -> M.Drawing & Image:
  built(gpu,M.build(gpu,n,tris,M.empty()))

def fixture() -> Array<M.Triangle>:
  Array.set(M.Triangle,Array.set(M.Triangle,Array.set(M.Triangle,Array.set(M.Triangle,
    Array.new(M.Triangle,2n,M.blank()),0,
    M.Triangle{M.Vertex{128.0,128.0,4.0},M.Vertex{384.0,128.0,4.0},M.Vertex{128.0,384.0,4.0},16711680}),1,
    M.Triangle{M.Vertex{384.0,128.0,4.0},M.Vertex{384.0,384.0,4.0},M.Vertex{128.0,384.0,4.0},255}),2,
    M.Triangle{M.Vertex{200.0,160.0,2.0},M.Vertex{320.0,240.0,2.0},M.Vertex{180.0,280.0,2.0},65280}),3,
    M.Triangle{M.Vertex{0.0,0.0,F32.neg(1.0)},M.Vertex{512.0,0.0,F32.neg(1.0)},M.Vertex{0.0,512.0,F32.neg(1.0)},16777215})
