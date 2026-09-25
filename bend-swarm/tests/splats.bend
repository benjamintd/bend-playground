import Base
import ../engine/render/splats.bend as R
import ../engine/spatial.bend as Spatial
import ../engine/spatial/layout.bend as L

def read(+i: U32, a: Array<R.Splat>) -> Array<R.Splat> & R.Splat:
  Array.get(R.Splat,a,i)
def point(r: Array<R.Splat> & R.Splat) -> Array<R.Splat> & L.Point:
  (a,R.Splat{x,y,_}) = r
  (a,L.Point{x,y,0.0})
def position(+i: U32, a: Array<R.Splat>) -> Array<R.Splat> & L.Point:
  point(Array.get(R.Splat,a,i))
def built(~high: Bool, gpu: Bool, r: Result<String,Spatial.Snapshot(R.space(),Array<R.Splat>)>) -> Result<String,Array<R.Splat> & Spatial.Index(R.space()) & Array<U32> & Image>:
  match r:
    case Fail{e}: Fail{e}
    case Done{snapshot}: Done{R.draw_level(~Bool.pick(Nat,high,1n,0n),~Array<R.Splat>,~read,~Array.join(R.Splat),gpu,R.Settings{True{},4.0,1.55},snapshot,Array.new(U32,Bool.pick(Nat,high,22n,20n),0),Pix{0})}
def created(~high: Bool, +gpu: Bool, a: Array<R.Splat>, r: Result<String,Spatial.Index(R.space())>) -> Result<String,Array<R.Splat> & Spatial.Index(R.space()) & Array<U32> & Image>:
  match r:
    case Fail{e}: Fail{e}
    case Done{index}: built(~high,gpu,Spatial.build(~R.space(),~Array<R.Splat>,~position,~Array.join(R.Splat),gpu,3n,8,a,index))
def fixture() -> Array<R.Splat>:
  Array.set(R.Splat,Array.set(R.Splat,Array.set(R.Splat,Array.set(R.Splat,Array.set(R.Splat,Array.set(R.Splat,Array.set(R.Splat,Array.set(R.Splat,
    Array.new(R.Splat,3n,R.Splat{0.0,0.0,0}),0,R.Splat{0.25,0.5,5304258}),1,R.Splat{1023.8,1023.8,16758619}),2,R.Splat{7.9,8.1,15429309}),
    3,R.Splat{511.9,512.1,6921215}),4,R.Splat{514.0,514.0,15982954}),5,R.Splat{7.1,7.8,9927665}),6,R.Splat{1.2,1.5,5304258}),7,R.Splat{1022.5,1.8,16758619})
def render(gpu: Bool) -> Result<String,Array<R.Splat> & Spatial.Index(R.space()) & Array<U32> & Image>:
  created(~False{},gpu,fixture(),Spatial.create(~R.space(),3n))

def render_high(gpu: Bool) -> Result<String,Array<R.Splat> & Spatial.Index(R.space()) & Array<U32> & Image>:
  created(~True{},gpu,fixture(),Spatial.create(~R.space(),3n))
