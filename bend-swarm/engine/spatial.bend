import Base
import ./spatial/layout.bend as L
import ./spatial/internal/index.bend as I
import ./spatial/internal/stencil.bend as K

# Public spatial API. See docs/SPATIAL_API.md for callback ownership contracts.
def Index(-space: L.Layout) -> Type:
  I.Index<space>

def Snapshot(-space: L.Layout, -S: Type) -> Type:
  I.Snapshot<space,S>

def Step(-space: L.Layout, -S: Type, -O: Type) -> Type:
  K.Step<space,S,O>

def create(~space: L.Layout, depth: Nat) -> Result<String,Index(space)>:
  I.create(~space,depth)

def build(~space: L.Layout, ~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~join: S -> S -> S, gpu: Bool, depth: Nat, n: U32, source: S, index: Index(space)) -> Result<String,Snapshot(space,S)>:
  I.build(~space,~S,~position,~join,gpu,depth,n,source,index)

def recycle(~space: L.Layout, ~S: Type, snapshot: Snapshot(space,S)) -> S & Index(space):
  I.recycle(~space,~S,snapshot)

def stencil(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O,
  ~join_source: S -> S -> S, ~join_output: O -> O -> O,
  gpu: Bool, depth: Nat, radius: F32, include_self: Bool,
  context: C, source: Snapshot(space,S), output: O) -> Result<String,Step(space,S,O)>:
  K.stencil(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,~join_source,~join_output,
    gpu,depth,radius,include_self,context,source,output)

# Optional application boundary; library functions return errors instead of
# silently clamping counts or query radii. Rejected calls consume their inputs.
def require(~T: Type, result: Result<String,T>) -> IO(T):
  match result:
    case Fail{message}: IO.die(T,2,message)
    case Done{value}: IO.pure(T,value)

type Statistics is Data:
  Statistics{candidates: Nat, neighbors: Nat}

def unpack(~space: L.Layout, ~S: Type, ~O: Type, step: Step(space,S,O)) -> Snapshot(space,S) & O & Statistics:
  K.Step{snapshot,output,checks,neighbors} = step
  (snapshot,output,Statistics{checks,neighbors})

def release(~space: L.Layout, ~S: Type, ~O: Type, step: Step(space,S,O)) -> S & O & Index(space) & Statistics:
  K.Step{I.Snapshot{_,source,index},output,checks,neighbors} = step
  (source,output,index,Statistics{checks,neighbors})
