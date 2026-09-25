import Base
import ./world.bend as W
import ./physics.bend as P
import ../../engine/spatial.bend as S

type State is Type:
  State{side: U32, current: W.Positions, previous: W.Positions, scratch: W.Positions,
    index: S.Index(P.space()), checks: Nat, neighbors: Nat}

def created(+side: U32, a: W.Positions, b: W.Positions, out: W.Positions,
  r: Result<String,S.Index(P.space())>) -> Result<String,State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{index}: Done{State{side,a,b,out,index,0n,0n}}

def allocate(+bits: Nat) -> Result<String,State>:
  created(U32.shln(1,bits),W.create(bits),W.create(bits),W.empty(Nat.add(bits,bits)),S.create(~P.space(),Nat.add(bits,bits)))

def create_if(valid: Bool, bits: Nat) -> Result<String,State>:
  match valid:
    case False{}: Fail{"Cloth.create: side depth must be between 1 and 8"}
    case True{}: allocate(bits)

def create(+bits: Nat) -> Result<String,State>:
  create_if(Nat.is_le(1n,bits) && Nat.is_le(bits,8n),bits)

def relaxations(n: Nat, +gpu: Bool, +depth: Nat, +count: U32, r: P.Relaxation) -> P.Relaxation:
  match n:
    case 0n: r
    case 1n+k:
      P.Relaxation{old,next,c} = r
      relaxations(k,gpu,depth,count,P.relax_run(gpu,depth,count,P.Relaxation{next,old,c}))

def collided(side: U32, previous: W.Positions,
  r: W.Positions & W.Positions & S.Index(P.space()) & S.Statistics) -> State:
  (scratch,current,index,S.Statistics{checks,neighbors}) = r
  State{side,current,previous,scratch,index,checks,neighbors}

def project(+gpu: Bool, +depth: Nat, +side: U32, previous: W.Positions,
  index: S.Index(P.space()), r: P.Relaxation) -> IO(State):
  P.Relaxation{scratch,current,c} = r
  do IO<State>:
    snapshot : S.Snapshot(P.space(),W.Positions) <- S.require(~S.Snapshot(P.space(),W.Positions),
      S.build(~P.space(),~W.Positions,~W.read,~W.join,gpu,depth,(side * side : U32),current,index))
    result : S.Step(P.space(),W.Positions,W.Positions) <- S.require(~S.Step(P.space(),W.Positions,W.Positions),
      P.collide(gpu,depth,c,snapshot,scratch))
    return collided(side,previous,S.release(~P.space(),~W.Positions,~W.Positions,result))

def predicted(+gpu: Bool, +depth: Nat, +side: U32, index: S.Index(P.space()), r: P.Prediction) -> IO(State):
  P.Prediction{previous,scratch,current,c} = r
  project(gpu,depth,side,previous,index,
    relaxations(12n,gpu,depth,(side * side : U32),P.Relaxation{scratch,current,c}))

def substep(+gpu: Bool, +depth: Nat, c: P.Controls, state: State) -> IO(State):
  State{+side,current,previous,scratch,index,_,_} = state
  predicted(gpu,depth,side,index,P.predict_run(gpu,depth,(side * side : U32),P.Prediction{current,previous,scratch,c}))

def step(+gpu: Bool, +depth: Nat, +c: P.Controls, state: State) -> IO(State):
  do IO<State>:
    state : State <- substep(gpu,depth,c,state)
    substep(gpu,depth,c,state)
