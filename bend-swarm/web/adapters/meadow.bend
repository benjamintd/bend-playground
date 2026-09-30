import Base
import ../../demos/meadow/scene.bend as S
import ../../engine/render/mesh.bend as M

def create() -> S.Geometry:
  S.Geometry{Array.new(S.Blade,12n,S.Blade{0.0,0.0,0.0,0.0}),Array.new(M.Triangle,15n,M.blank())}
def frame(time: F32, preset: U32, power: F32, mx: F32, my: F32, paused: Bool, g: S.Geometry) -> S.Geometry:
  S.Geometry{blades,tris} = g
  S.project(False{},S.Geometry{S.simulate(False{},paused,S.controls(time,preset,power,S.mouse(mx,my)),blades),tris})
def background(x: U32, y: U32) -> M.Fragment: S.background(x,y)
