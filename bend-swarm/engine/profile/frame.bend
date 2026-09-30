import Base
import ../parallel/policy.bend as Policy

# Elapsed host microseconds, including dispatch/synchronization. These are NOT
# device timestamps. Raw raster time includes fused Image assembly; post is zero.
# GUI/presentation, pacing, reset and resize are outside this work sample.
type Sample is Data:
  Sample{policy: Policy.Policy, simulation_us: U32, geometry_us: U32, binning_us: U32, raster_us: U32, post_us: U32}
def empty() -> Sample:
  Sample{Policy.all(False{},0n),0,0,0,0,0}
def render(s: Sample) -> U32:
  Sample{_,_,g,b,r,p} = s
  (g + b + r + p : U32)
def work(s: Sample) -> U32:
  Sample{_,s,g,b,r,p} = s
  (s + g + b + r + p : U32)
def ms(us: U32) -> String:
  +n = (U32.min(us,9999999) / 100 : U32)
  U32.show((n / 10 : U32)) ++ "." ++ U32.show((n % 10 : U32))
def line(name: String, gpu: Bool, us: U32) -> String:
  name ++ Bool.pick(String,gpu," G "," C ") ++ ms(us) ++ "\n"
def label(+sample: Sample) -> String:
  Sample{Policy.Policy{s,g,b,r,p,_},sim,geo,bin,ras,post} = sample
  "WORK " ++ ms(work(sample)) ++ " MS\n" ++ line("SIM",s,sim) ++ line("GEO",g,geo)
    ++ line("BIN",b,bin) ++ line("RAST",r,ras) ++ line("POST",p,post) ++ "C CPU G GPU\n"
def csv_header() -> String:
  "sim_gpu,geometry_gpu,binning_gpu,raster_gpu,post_gpu,simulation_us,geometry_us,binning_us,raster_us,post_us,work_us"
def csv(+sample: Sample) -> String:
  Sample{Policy.Policy{s,g,b,r,p,_},sim,geo,bin,ras,post} = sample
  U32.show(Bool.to_u32(s)) ++ "," ++ U32.show(Bool.to_u32(g)) ++ "," ++ U32.show(Bool.to_u32(b)) ++ ","
    ++ U32.show(Bool.to_u32(r)) ++ "," ++ U32.show(Bool.to_u32(p)) ++ "," ++ U32.show(sim) ++ ","
    ++ U32.show(geo) ++ "," ++ U32.show(bin) ++ "," ++ U32.show(ras) ++ "," ++ U32.show(post) ++ "," ++ U32.show(work(sample))
