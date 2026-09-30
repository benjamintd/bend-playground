import Base
import ./mesh.bend as M
import ./batch.bend as B
import ../core/time.bend as Time
import ../parallel/policy.bend as Policy
import ../profile/frame.bend as Profile

# Supported interface: width, create, resize, draw; Target and Frame own buffers.
# Reusable targets for a moving camera with a constant backdrop. A procedural
# world-space backdrop must be regenerated after changing the prepared view.
type Target is Type:
  Target{index: M.Index, pixels: Array<U32>, fragments: Array<M.Fragment>, level: U32, background: U32}
def width(level: U32) -> U32:
  U32.shln(512,U32.to_nat(U32.min(level,2)))
def allocate(+level: U32, +background: U32, index: M.Index) -> Target:
  +depth = U32.to_nat((18 + level * 2 : U32))
  Target{index,Array.new(U32,depth,background),Array.new(M.Fragment,Nat.add(depth,1n),M.Fragment{1.0e9,background}),level,background}
def create(level: U32, background: U32) -> Target:
  allocate(U32.min(level,2),background,M.empty())
def resize_changed(change: Bool, +level: U32, target: Target) -> Target:
  match change:
    case False{}: target
    case True{}:
      Target{index,_,_,_,background} = target
      allocate(level,background,index)
def resize(+level: U32, target: Target) -> Target:
  Target{index,pixels,fragments,+was,background} = target
  resize_changed(U32.is_ne(was,U32.min(level,2)),U32.min(level,2),Target{index,pixels,fragments,was,background})
type Frame is Type:
  Frame{target: Target, batch: B.Batch, image: Image, profile: Profile.Sample}
def finished(level: U32, background: U32, n: U32, capacity: U32, counts: Array<U32>, cursors: Array<U32>, cap: U32,
  policy: Policy.Policy, sim: U32, geometry: U32, bin: U32, raster: U32, r: M.Drawing & Image) -> Frame:
  (M.Drawing{tris,offsets,ids,pixels,fragments},image) = r
  Frame{Target{M.Index{counts,offsets,cursors,ids,cap},pixels,fragments,level,background},B.Batch{tris,n,capacity},image,Profile.Sample{policy,sim,geometry,bin,raster,0}}
def binned(~level: Nat, +gpu: Bool, background: U32, n: U32, capacity: U32, sim: U32, geometry: U32, start: Nat,
  pixels: Array<U32>, fragments: Array<M.Fragment>, old: Image, r: Array<M.Triangle> & M.Index) -> IO(Frame):
  (tris,M.Index{counts,offsets,cursors,ids,cap}) = r
  do IO<Frame>:
    +middle : Nat <- Time.micros()
    result : M.Drawing & Image = M.render_camera_level(~level,gpu,M.Drawing{tris,offsets,ids,pixels,fragments},old)
    end : Nat <- Time.micros()
    return finished(U32.from_nat(level),background,n,capacity,counts,cursors,cap,
      Policy.Policy{False{},False{},False{},gpu,False{},0n},sim,geometry,Time.elapsed(start,middle),Time.elapsed(middle,end),result)
def draw_level(~level: Nat, +gpu: Bool, sim: U32, geometry: U32, b: B.Batch, target: Target, old: Image) -> IO(Frame):
  B.Batch{tris,+n,capacity} = b
  Target{index,pixels,fragments,_,background} = target
  do IO<Frame>:
    start : Nat <- Time.micros()
    binned(~level,gpu,background,n,capacity,sim,geometry,start,pixels,fragments,old,M.build_level(~level,False{},n,tris,index))
def draw_selected(level: U32, gpu: Bool, sim: U32, geometry: U32, b: B.Batch, target: Target, old: Image) -> IO(Frame):
  match level:
    case 0: draw_level(~0n,gpu,sim,geometry,b,target,old)
    case 1: draw_level(~1n,gpu,sim,geometry,b,target,old)
    case _: draw_level(~2n,gpu,sim,geometry,b,target,old)
# The target is the only resolution source. Runtime fallback is resolved here
# so library callers cannot report Metal work while running with --gpu off.
def draw(gpu: Bool, sim: U32, geometry: U32, b: B.Batch, target: Target, old: Image) -> IO(Frame):
  Target{index,pixels,fragments,+level,background} = target
  do IO<Frame>:
    available : U32 <- Policy.available()
    draw_selected(level,gpu && U32.is_ne(available,0),sim,geometry,b,Target{index,pixels,fragments,level,background},old)
