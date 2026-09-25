import Base
import ./world.bend as W
import ../../engine/core/math.bend as M
import ../../engine/parallel/regions.bend as Region

type Forces is Data:
  Forces{sx: F32, sy: F32, ax: F32, ay: F32, cx: F32, cy: F32, neighbors: U32, checks: Nat}

def zero() -> Forces:
  Forces{0.0,0.0,0.0,0.0,0.0,0.0,0,0n}

def delta(+d: F32) -> F32:
  (d - F32.floor((d / 1024.0 + 0.5 : F32)) * 1024.0 : F32)

def accepted(yes: Bool, +dx: F32, +dy: F32, +d2: F32, vx: F32, vy: F32, f: Forces) -> Forces:
  match yes:
    case False{}:
      Forces{sx,sy,ax,ay,cx,cy,n,k} = f
      Forces{sx,sy,ax,ay,cx,cy,n,(1n+k)}
    case True{}:
      Forces{sx,sy,ax,ay,cx,cy,n,k} = f
      +weight = M.pick((d2 < 9.0 : F32), (1.0 / (d2 + 0.05) : F32), 0.0)
      Forces{(sx - dx * weight : F32),(sy - dy * weight : F32),(ax + vx : F32),
        (ay + vy : F32),(cx + dx : F32),(cy + dy : F32),(n + 1 : U32),(1n+k)}

def add(same: Bool, self: W.Sample, neighbor: W.Sample, f: Forces) -> Forces:
  W.Sample{x,y,_,_} = self
  W.Sample{nx,ny,vx,vy} = neighbor
  +dx = delta((nx - x : F32))
  +dy = delta((ny - y : F32))
  +d2 = (dx * dx + dy * dy : F32)
  accepted((d2 < 64.0 : F32) && Bool.not(same),dx,dy,d2,vx,vy,f)

# Same force equation for brute-force and spatial paths. Only candidate
# enumeration differs. Every read observes the old world; output is separate.
def read_force(same: Bool, self: W.Sample, f: Forces, r: W.World & W.Sample) -> W.World & Forces:
  (w,other) = r
  (w,add(same,self,other,f))

def brute(n: Nat, +j: U32, +self_id: U32, +self: W.Sample, r: W.World & Forces) -> W.World & Forces:
  match n:
    case 0n: r
    case 1n+p:
      (w,f) = r
      brute(p,(j + 1 : U32),self_id,self,read_force(U32.is_eq(self_id,j),self,f,W.read(j,w)))

def limited(+x: F32, +y: F32, limit: F32) -> F32 & F32:
  +scale = F32.min(1.0,(limit / F32.sqrt((x * x + y * y + 0.000001 : F32)) : F32))
  ((x * scale : F32),(y * scale : F32))

def integrate_velocity(+x: F32, +y: F32, r: F32 & F32) -> W.Sample:
  (+vx,+vy) = r
  W.Sample{M.wrap((x + vx * 0.016666667 : F32)),M.wrap((y + vy * 0.016666667 : F32)),vx,vy}

def integrate_accel(x: F32, y: F32, vx: F32, vy: F32, r: F32 & F32) -> W.Sample:
  (ax,ay) = r
  integrate_velocity(x,y,limited((vx + ax * 0.016666667 : F32),(vy + ay * 0.016666667 : F32),60.0))

def integrate(self: W.Sample, f: Forces, mx: F32, my: F32, power: F32) -> W.Sample:
  W.Sample{+x,+y,+vx,+vy} = self
  Forces{sx,sy,ax,ay,cx,cy,+n,_} = f
  +inv = (1.0 / U32.to_f32(U32.max(n,1)) : F32)
  +active = M.pick(U32.is_eq(n,0),0.0,1.0)
  +dx = delta((mx - x : F32))
  +dy = delta((my - y : F32))
  +pull = (power / F32.sqrt((dx * dx + dy * dy + 64.0 : F32)) : F32)
  integrate_accel(x,y,vx,vy,limited(
    (18.0 * sx + active * (2.0 * (ax * inv - vx) + 4.0 * cx * inv) + dx * pull : F32),
    (18.0 * sy + active * (2.0 * (ay * inv - vy) + 4.0 * cy * inv) + dy * pull : F32),80.0))

def reference_write(i: U32, self: W.Sample, out: W.World, mx: F32, my: F32, power: F32,
  r: W.World & Forces) -> W.World & W.World:
  (old,f) = r
  (old,W.write(i,out,integrate(self,f,mx,my,power)))

def reference_self(+i: U32, +n: U32, out: W.World, mx: F32, my: F32, power: F32,
  r: W.World & W.Sample) -> W.World & W.World:
  (old,+self) = r
  reference_write(i,self,out,mx,my,power,brute(U32.to_nat(n),0,i,self,(old,zero())))

def reference_loop(fuel: Nat, +i: U32, +n: U32, +mx: F32, +my: F32, +power: F32,
  r: W.World & W.World) -> W.World & W.World:
  match fuel:
    case 0n: r
    case 1n+p:
      (old,out) = r
      reference_loop(p,(i + 1 : U32),n,mx,my,power,reference_self(i,n,out,mx,my,power,W.read(i,old)))

def reference(+n: U32, old: W.World, out: W.World) -> W.World & W.World:
  reference_loop(U32.to_nat(n),0,n,0.0,0.0,0.0,(old,out))

type Lookup is Type:
  Lookup{old: W.World, offsets: Array<U32>, ids: Array<U32>, forces: Forces, self_id: U32}

def lookup_force(self_id: U32, offsets: Array<U32>, ids: Array<U32>, r: W.World & Forces) -> Lookup:
  (w,f) = r
  Lookup{w,offsets,ids,f,self_id}

def candidate_id(+self_id: U32, self: W.Sample, old: W.World, offsets: Array<U32>, f: Forces,
  r: Array<U32> & U32) -> Lookup:
  (ids,+id) = r
  lookup_force(self_id,offsets,ids,read_force(U32.is_eq(self_id,id),self,f,W.read(id,old)))

def candidate(i: U32, self: W.Sample, t: Lookup) -> Lookup:
  Lookup{w,offsets,ids,f,self_id} = t
  candidate_id(self_id,self,w,offsets,f,Array.get(U32,ids,i))

def candidates(n: Nat, +i: U32, +self: W.Sample, t: Lookup) -> Lookup:
  match n:
    case 0n: t
    case 1n+p: candidates(p,(i + 1 : U32),self,candidate(i,self,t))

def cell_end(self_id: U32, +start: U32, self: W.Sample, old: W.World, ids: Array<U32>, f: Forces,
  r: Array<U32> & U32) -> Lookup:
  (offsets,end) = r
  candidates(U32.to_nat((end - start : U32)),start,self,Lookup{old,offsets,ids,f,self_id})

def cell_start(self_id: U32, cell: U32, self: W.Sample, old: W.World, ids: Array<U32>, f: Forces,
  r: Array<U32> & U32) -> Lookup:
  (offsets,start) = r
  cell_end(self_id,start,self,old,ids,f,Array.get(U32,offsets,(cell + 1 : U32)))

def cell(+id: U32, self: W.Sample, t: Lookup) -> Lookup:
  Lookup{old,offsets,ids,f,self_id} = t
  cell_start(self_id,id,self,old,ids,f,Array.get(U32,offsets,id))

def neighborhood(+n: Nat, +cx: U32, +cy: U32, +self: W.Sample, t: Lookup) -> Lookup:
  match n:
    case 0n: t
    case 1n+p:
      +k = U32.from_nat(p)
      +x = U32.and((cx + k % 3 - 1 : U32),127)
      +y = U32.and((cy + k / 3 - 1 : U32),127)
      neighborhood(p,cx,cy,self,cell((x + y * 128 : U32),self,t))

type Buffers is Type:
  Buffers{old: W.World, next: W.World, offsets: Array<U32>, ids: Array<U32>,
    checks: Nat, mx: F32, my: F32, power: F32}

def stepped(i: U32, self: W.Sample, next: W.World, checks: Nat, +mx: F32, +my: F32, +power: F32,
  t: Lookup) -> Buffers:
  Lookup{old,offsets,ids,+f,_} = t
  Forces{_,_,_,_,_,_,_,k} = f
  Buffers{old,W.write(i,next,integrate(self,f,mx,my,power)),offsets,ids,(Nat.add(checks,k)),mx,my,power}

def self_read(+i: U32, next: W.World, offsets: Array<U32>, ids: Array<U32>, checks: Nat,
  +mx: F32, +my: F32, +power: F32, r: W.World & W.Sample) -> Buffers:
  (old,+self) = r
  W.Sample{x,y,_,_} = self
  stepped(i,self,next,checks,mx,my,power,neighborhood(9n,U32.shrn(F32.to_u32(x),3n),
    U32.shrn(F32.to_u32(y),3n),self,Lookup{old,offsets,ids,zero(),i}))

def one(+i: U32, b: Buffers) -> Buffers:
  Buffers{old,next,offsets,ids,checks,mx,my,power} = b
  self_read(i,next,offsets,ids,checks,mx,my,power,W.read(i,old))

def loop(n: Nat, +i: U32, b: Buffers) -> Buffers:
  match n:
    case 0n: b
    case 1n+p: loop(p,(i + 1 : U32),one(i,b))

def leaf(start: U32, n: U32, b: Buffers) -> Buffers:
  Buffers{old,next,offsets,ids,_,mx,my,power} = b
  loop(U32.to_nat(n),start,Buffers{old,next,offsets,ids,0n,mx,my,power})

def join(a: Buffers, b: Buffers) -> Buffers:
  Buffers{aw,an,ao,ai,ac,mx,my,power} = a
  Buffers{bw,bn,bo,bi,bc,_,_,_} = b
  Buffers{W.join(aw,bw),W.join(an,bn),Array.join(U32,ao,bo),Array.join(U32,ai,bi),
    Nat.add(ac,bc),mx,my,power}

def step(depth: Nat, +n: U32, b: Buffers) -> Buffers:
  Region.run(~Buffers,~leaf,~join,Nat.min(depth,U32.log2(n)),0,n,b)

def execute(gpu: Bool, depth: Nat, n: U32, b: Buffers) -> Buffers:
  match gpu:
    case True{}: step!(depth,n,b)
    case False{}: step(depth,n,b)
