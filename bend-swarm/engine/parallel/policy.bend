import Base

# Host-side choices only. Destructure before entering any fork tree.
# Binning is independent because a GPU rasterizer need not build its index there.
type Policy is Data:
  Policy{simulation: Bool, geometry: Bool, binning: Bool, raster: Bool, post: Bool, simulation_depth: Nat}
def all(+gpu: Bool, depth: Nat) -> Policy:
  Policy{gpu,gpu,gpu,gpu,gpu,Bool.pick(Nat,gpu,depth,0n)}
def cloth(+gpu: Bool) -> Policy:
  Policy{False{},gpu,gpu,gpu,gpu,0n}
def hybrid() -> Policy:
  Policy{False{},False{},False{},True{},True{},0n}
def supported(+available: Bool, p: Policy) -> Policy:
  Policy{+s,g,b,r,f,d} = p
  Policy{available && s,available && g,available && b,available && r,available && f,Bool.pick(Nat,available && s,d,0n)}

# Runtime metadata only, including --gpu off and CPU-only builds.
def available() -> IO(U32):
  import "./policy.c"
  import "./policy.js"
def resolve(p: Policy) -> IO(Policy):
  do IO<Policy>:
    enabled : U32 <- available()
    return supported(U32.is_ne(enabled,0),p)
