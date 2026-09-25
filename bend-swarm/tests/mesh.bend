import Base
import ../engine/render/mesh.bend as M

def background(x: U32, y: U32) -> M.Fragment:
  M.Fragment{1000.0,66051}

def built(gpu: Bool, r: Array<M.Triangle> & M.Index) -> M.Drawing & Image:
  (tris,M.Index{_,offsets,_,ids,_}) = r
  M.render(gpu,M.Drawing{tris,offsets,ids,Array.new(U32,18n,0),M.backdrop(~False{},~background,Array.new(M.Fragment,18n,M.Fragment{0.0,0}))},Pix{0})

def render(+gpu: Bool, n: U32, tris: Array<M.Triangle>) -> M.Drawing & Image:
  built(gpu,M.build(gpu,n,tris,M.empty()))

def built_high(gpu: Bool, r: Array<M.Triangle> & M.Index) -> M.Drawing & Image:
  (tris,M.Index{_,offsets,_,ids,_}) = r
  M.render_size(~True{},gpu,M.Drawing{tris,offsets,ids,Array.new(U32,20n,0),M.backdrop(~True{},~background,Array.new(M.Fragment,20n,M.Fragment{0.0,0}))},Pix{0})
def render_high(+gpu: Bool, n: U32, tris: Array<M.Triangle>) -> M.Drawing & Image:
  built_high(gpu,M.build_quality(True{},gpu,n,tris,M.empty()))

def fixture() -> Array<M.Triangle>:
  Array.set(M.Triangle,Array.set(M.Triangle,Array.set(M.Triangle,Array.set(M.Triangle,
    Array.new(M.Triangle,2n,M.blank()),0,
    M.Triangle{M.Vertex{128.0,128.0,4.0,1.0},M.Vertex{384.0,128.0,4.0,1.0},M.Vertex{128.0,384.0,4.0,1.0},16711680}),1,
    M.Triangle{M.Vertex{384.0,128.0,4.0,1.0},M.Vertex{384.0,384.0,4.0,1.0},M.Vertex{128.0,384.0,4.0,1.0},255}),2,
    M.Triangle{M.Vertex{200.0,160.0,2.0,1.0},M.Vertex{320.0,240.0,2.0,1.0},M.Vertex{180.0,280.0,2.0,1.0},65280}),3,
    M.Triangle{M.Vertex{0.0,0.0,F32.neg(1.0),1.0},M.Vertex{512.0,0.0,F32.neg(1.0),1.0},M.Vertex{0.0,512.0,F32.neg(1.0),1.0},16777215})

def fixture_high() -> Array<M.Triangle>:
  Array.set(M.Triangle,Array.set(M.Triangle,Array.set(M.Triangle,Array.set(M.Triangle,
    Array.new(M.Triangle,2n,M.blank()),0,
    M.Triangle{M.Vertex{256.0,256.0,4.0,1.0},M.Vertex{768.0,256.0,4.0,1.0},M.Vertex{256.0,768.0,4.0,1.0},16711680}),1,
    M.Triangle{M.Vertex{768.0,256.0,4.0,1.0},M.Vertex{768.0,768.0,4.0,1.0},M.Vertex{256.0,768.0,4.0,1.0},255}),2,
    M.Triangle{M.Vertex{400.0,320.0,2.0,1.0},M.Vertex{640.0,480.0,2.0,1.0},M.Vertex{360.0,560.0,2.0,1.0},65280}),3,
    M.Triangle{M.Vertex{0.0,0.0,F32.neg(1.0),1.0},M.Vertex{1024.0,0.0,F32.neg(1.0),1.0},M.Vertex{0.0,1024.0,F32.neg(1.0),1.0},16777215})
