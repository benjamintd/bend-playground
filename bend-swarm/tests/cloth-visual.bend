import Base
import ../demos/cloth/world.bend as W
import ../demos/cloth/view.bend as V
import ../engine/render/mesh.bend as M

def projected() -> V.Projection:
  V.triangles_run(False{},7938,V.Projection{W.create(5n),Array.new(M.Triangle,14n,M.blank()),32,True{}})
