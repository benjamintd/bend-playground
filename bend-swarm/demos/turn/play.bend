import Base
import ./model.bend as M
import ./physics.bend as F
import ./levels.bend as L
import ./tempo.bend as T
import ./hints.bend as H
import ./hint-routes.bend as HintRoute
import ../../engine/core/math.bend as Math

type Play is Data:
  Play{level: U32, plane: M.Plane, body: F.Body, turn: U32, slow: U32,
    time: U32, turns: U32, keys: U32, quit: Bool, accumulator: F32, finished: U32,
    seals: U32, menu: Bool, selection: U32, completed: U32,pace: U32,hints: H.Hints}
def rotation_ticks() -> U32: 84
def make(+level: U32, completed: U32) -> Play:
  Play{level,M.XY{},F.initial(),0,0,0,0,0,False{},0.0,0,0,False{},L.index(level),completed,0,H.empty()}
def create(level: U32) -> Play: make(level,0)
def frozen(p: Play) -> Bool:
  Play{_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
  T.frozen(pace)
def load(level: U32, p: Play) -> Play:
  Play{_,_,_,_,_,_,_,_,_,_,_,_,_,_,completed,pace,hints} = p
  make(level,completed)
def arrived(p: Play) -> Bool:
  Play{_,plane,+body,_,_,_,_,_,_,_,finished,_,_,_,_,pace,hints} = p
  (finished > 0 : U32) || (F.settled(body) && F.exit(plane,F.position(body)))
def down(keys: U32, bit: U32) -> Bool: U32.is_ne(U32.and(keys,bit),0)
def bit(code: U32) -> U32:
  match code:
    case 97: 1
    case 100: 2
    case 119: 4
    case 115: 8
    case 32: 16
    case 114: 32
    case 63234: 64
    case 63235: 128
    case 63232: 256
    case 63233: 512
    case 9: 1024
    case 13: 2048
    case 27: 4096
    case 113: 8192
    case 101: 16384
    case 104: 32768
    case _: 0
def with_key(p: Play, +mask: U32, pressed: Bool) -> Play:
  Play{l,plane,b,t,s,clock,v,+keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
  Play{l,plane,b,t,s,clock,v,Math.word(pressed,U32.or(keys,mask),U32.and(keys,U32.not(mask))),q,acc,f,seals,menu,selection,completed,pace,hints}
def jump(p: Play) -> Play:
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
  Play{l,plane,F.request(b),t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints}
def rotate_if(ok: Bool, p: Play) -> Play:
  match ok:
    case False{}: p
    case True{}:
      Play{+l,+plane,b,_,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
      Play{l,plane,b,1,0,clock,(v + 1 : U32),keys,q,acc,f,seals,menu,selection,completed,1,hints}
# A turn ring admits the complete projected half-cell body. Hidden depth
# never prevents touching a visible ring. Embedded turns settle afterwards.
def centered_axis(+n: U32) -> Bool:
  +part = (n % 1024 : U32)
  (part >= 256 : U32) && (part <= 768 : U32)
def centered(q: M.Point) -> Bool:
  M.Point{x,y,_} = q
  centered_axis(x) && centered_axis(y)
def can_turn(p: Play) -> Bool:
  Play{+l,+plane,+body,_,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
  +q = F.position(body)
  # Once a valid turn begins, select any view before releasing time. This
  # also permits crossing an embedded intermediate view or leaving a ring's
  # silhouette; movement ends the chain and restores normal ring admission.
  T.frozen(pace) || ((U32.is_eq(L.ring_count(l),0) || (L.turn_allowed(l,plane,F.cells(q)) && centered(M.local(plane,q))))
    && F.settled(body) && F.clear(l,plane,q))
def rotate(+p: Play) -> Play:
  Play{_,_,_,turn,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
  rotate_if(U32.is_eq(turn,0) && can_turn(p) && Bool.not(arrived(p)),p)
def toggle(p: Play) -> Play:
  Play{+l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,_,completed,pace,hints} = p
  Play{l,plane,b,t,s,clock,v,U32.and(keys,1024),q,acc,f,seals,Bool.not(menu),L.index(l),completed,pace,hints}
def choose(delta: U32, p: Play) -> Play:
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,((selection + delta) % L.count() : U32),completed,pace,hints}
def page_size() -> U32: 18
def page_count() -> U32: ((L.count() + page_size() - 1) / page_size() : U32)
def page_start(selection: U32) -> U32: (selection / page_size() * page_size() : U32)
def choose_page(delta: U32, p: Play) -> Play:
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,+selection,completed,pace,hints} = p
  +page = ((selection / page_size() + delta) % page_count() : U32)
  +next = U32.min((L.count() - 1 : U32),(page * page_size() + selection % page_size() : U32))
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,next,completed,pace,hints}
def quit(p: Play) -> Play:
  Play{l,plane,b,t,s,clock,v,keys,_,acc,f,seals,menu,selection,completed,pace,hints} = p
  Play{l,plane,b,t,s,clock,v,keys,True{},acc,f,seals,menu,selection,completed,pace,hints}
# Revealing a view never advances time, moves the body, or consumes a turn.
def reveal_hint(p: Play) -> Play:
  Play{+l,+plane,+b,t,s,clock,+v,keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,H.request(H.next(HintRoute.route(l),plane,F.position(b),v,HintRoute.ending(l)),hints)}
def hint_if(ready: Bool, p: Play) -> Play:
  match ready:
    case False{}: p
    case True{}: reveal_hint(p)
def hint(+p: Play) -> Play:
  Play{_,_,_,turn,_,_,_,_,_,_,_,_,_,_,_,_,_} = p
  hint_if(U32.is_eq(turn,0),p)
def preserve_hints(old: Play, p: Play) -> Play:
  Play{_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,hints} = old
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,_} = p
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints}

def reset(+p: Play) -> Play:
  Play{l,_,_,_,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
  preserve_hints(p,load(l,p))
def continue_game(+p: Play) -> Play:
  Play{l,_,_,_,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
  Bool.pick(Play,arrived(p),load(L.next(l),p),p)
def selected(+p: Play) -> Play:
  Play{_,_,_,_,_,_,_,_,_,_,_,_,_,selection,_,pace,hints} = p
  load(L.at(selection),p)
def menu_command(code: U32, p: Play) -> Play:
  match code:
    case 9: toggle(p)
    case 27: toggle(p)
    case 13: selected(p)
    case 32: selected(p)
    case 63234: choose((L.count() - 1 : U32),p)
    case 63235: choose(1,p)
    case 63232: choose((L.count() - 3 : U32),p)
    case 63233: choose(3,p)
    case 97: choose((L.count() - 1 : U32),p)
    case 100: choose(1,p)
    case 119: choose((L.count() - 3 : U32),p)
    case 115: choose(3,p)
    case 113: choose_page((page_count() - 1 : U32),p)
    case 101: choose_page(1,p)
    case _: p
def game_command(code: U32, p: Play) -> Play:
  match code:
    case 32: jump(p)
    case 119: jump(p)
    case 63232: jump(p)
    case 114: rotate(p)
    case 104: hint(p)
    case 9: toggle(p)
    case 127: reset(p)
    case 8: reset(p)
    case 49: load(L.at(0),p)
    case 50: load(L.at(1),p)
    case 51: load(L.at(2),p)
    case 52: load(L.at(3),p)
    case 53: load(L.at(4),p)
    case 54: load(L.at(5),p)
    case 55: load(L.at(6),p)
    case 56: load(L.at(7),p)
    case 57: load(L.at(8),p)
    case 110: continue_game(p)
    case 27: quit(p)
    case _: p
def resume(on: Bool, p: Play) -> Play:
  match on:
    case False{}: p
    case True{}:
      Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
      Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,T.release(pace),hints}
def move_key(code: U32) -> Bool: down(bit(code),991)
def routed(menu: Bool, +code: U32, p: Play) -> Play:
  match menu:
    case True{}: menu_command(code,p)
    case False{}: game_command(code,resume(move_key(code),p))
def command(code: U32, +p: Play) -> Play:
  Play{_,_,_,_,_,_,_,_,_,_,_,_,menu,_,_,pace,hints} = p
  routed(menu,code,p)
def edge(fresh: Bool, code: U32, p: Play) -> Play:
  match fresh:
    case False{}: p
    case True{}: command(code,p)
def key(+code: U32, +pressed: Bool, +p: Play) -> Play:
  Play{_,_,_,_,_,_,_,keys,_,_,_,_,_,_,_,pace,hints} = p
  edge(pressed && Bool.not(down(keys,bit(code))),code,with_key(p,bit(code),pressed))
def event(e: Event, p: Play) -> Play:
  match e:
    case Close{}: quit(p)
    case Key{code,pressed}: key(code,pressed,p)
    case _: p
def events(es: List<Event>, p: Play) -> Play:
  match es:
    case Nil{}: p
    case e <> rest: events(rest,event(e,p))
# The tempo decides whether one fixed physics step is due. It never changes
# velocities or the collision step size when fading time back in.
def simulate(on: Bool, l: U32, plane: M.Plane, +keys: U32, b: F.Body) -> F.Body:
  match on:
    case False{}: b
    case True{}: F.step(l,plane,F.Input{down(keys,65),down(keys,130),down(keys,520)},b)
# Seals use the same projected contact rule as the exit and rings.
def overlap(+center: U32, cell: U32) -> Bool:
  +lo = (cell * 1024 : U32)
  (center + 255 >= lo : U32) && (center < lo + 1280 : U32)
def touches(q: M.Point, target: M.Point) -> Bool:
  M.Point{x,y,_} = q
  M.Point{a,b,_} = target
  overlap(x,a) && overlap(y,b)
def gathered(+n: Nat, +level: U32, +plane: M.Plane, +q: M.Point, mask: U32) -> U32:
  match n:
    case 0n: mask
    case 1n+k:
      +i = U32.from_nat(k)
      gathered(k,level,plane,q,U32.or(mask,Math.word(touches(M.local(plane,q),M.local(plane,L.seal(level,i))),L.flag(i),0)))
def collect(p: Play) -> Play:
  Play{+l,+plane,+b,t,s,clock,v,keys,q,acc,f,+seals,menu,selection,completed,pace,hints} = p
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,Math.word(F.settled(b),gathered(U32.to_nat(L.seal_count(l)),l,plane,F.position(b),seals),seals),menu,selection,completed,pace,hints}
def finish_turn(done: Bool, p: Play) -> Play:
  match done:
    case False{}: p
    case True{}:
      Play{+l,+plane,b,_,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
      Play{l,M.cycle(plane),F.rotated(l,M.cycle(plane),b),0,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints}
def advance(ready: Bool, +p: Play) -> Play:
  match ready:
    case False{}: p
    case True{}:
      Play{l,_,_,_,_,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
      load(L.next(l),p)
def completion(done: Bool, p: Play) -> Play:
  match done:
    case False{}: p
    case True{}:
      Play{+l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
      +elapsed = U32.min(120,(f + 1 : U32))
      advance((elapsed >= 120 : U32) && Bool.not(L.last(l)),
        Play{l,plane,b,t,s,clock,v,keys,q,acc,elapsed,seals,menu,selection,U32.or(completed,L.flag(l)),pace,hints})
# The camera uses wall time; physics and world effects freeze until a fresh
# movement press. An input during the camera animation queues the fade.
def motion_frame(+p: Play, pulse: T.Pulse) -> Play:
  Play{+l,+plane,b,+turn,slow,clock,v,+keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
  T.Pulse{+run,phase,next_pace} = pulse
  +turning = U32.is_ne(turn,0)
  collect(finish_turn(turning && (turn >= rotation_ticks() : U32),
    Play{l,plane,simulate(run && Bool.not(arrived(p)),l,plane,keys,b),Math.word(turning,(turn + 1 : U32),0),phase,
      (clock + Bool.to_u32(run) : U32),v,keys,q,acc,f,seals,menu,selection,completed,next_pace,hints}))
def motion_step(+p: Play) -> Play:
  Play{_,_,_,turn,slow,_,_,_,_,_,_,_,_,_,_,pace,hints} = p
  motion_frame(p,T.pulse(U32.is_ne(turn,0),pace,slow))
def completed_motion(+p: Play) -> Play:
  completion(arrived(p),p)
def active_step(menu: Bool, +p: Play) -> Play:
  match menu:
    case True{}: p
    case False{}: completed_motion(motion_step(p))
def step(+p: Play) -> Play:
  Play{_,_,_,_,_,_,_,_,_,_,_,_,menu,_,_,pace,hints} = p
  active_step(menu,p)
def steps(n: Nat, p: Play) -> Play:
  match n:
    case 0n: p
    case 1n+k: steps(k,step(p))
def tick_active(+dt: F32, p: Play) -> Play:
  Play{l,plane,b,t,s,clock,v,keys,q,acc,f,seals,menu,selection,completed,pace,hints} = p
  +total = (acc + F32.clamp(dt,0.0,0.25) * 120.0 : F32)
  +n = F32.to_u32(total)
  steps(U32.to_nat(n),Play{l,plane,b,t,s,clock,v,keys,q,(total - U32.to_f32(n) : F32),f,seals,menu,selection,completed,pace,hints})
def tick_if(menu: Bool, dt: F32, p: Play) -> Play:
  match menu:
    case True{}: p
    case False{}: tick_active(dt,p)
def tick(dt: F32, +p: Play) -> Play:
  Play{_,_,_,_,_,_,_,_,_,_,_,_,menu,_,_,pace,hints} = p
  tick_if(menu,dt,p)

