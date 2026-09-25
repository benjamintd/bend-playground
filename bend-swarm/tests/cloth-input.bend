import Base
import ../demos/cloth/main.bend as App
import ../demos/cloth/frame.bend as F
import ../demos/cloth/simulation.bend as S
import ../engine/render/mesh.bend as M

def result(r: F.Frame & App.Controls) -> U32:
  (_,App.Controls{_,_,_,_,_,_,_,_,_,grab,_,_,_,_}) = r
  grab
def tested(r: Result<String,S.State>, es: List<Event>) -> U32:
  match r:
    case Fail{_}: 999999
    case Done{s}:
      result(App.events_frame(es,(F.Frame{s,Array.new(M.Triangle,11n,M.blank()),M.empty(),Array.new(U32,18n,0),Array.new(M.Fragment,0n,M.Fragment{0.0,0}),Pix{0},0,0},
        App.Controls{False{},False{},False{},False{},True{},False{},0.0,0.0,False{},4294967295,7.5,0.5,0.5,False{}})))
def batch(es: List<Event>) -> U32:
  tested(S.create(5n),es)
