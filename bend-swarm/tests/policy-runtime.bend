import Base
import ../engine/parallel/policy.bend as Policy
import ../engine/profile/frame.bend as Profile

# No bangs: this executable is a genuine CPU-only build even on a GPU host.
def main() -> IO(Unit):
  do IO<Unit>:
    p : Policy.Policy <- Policy.resolve(Policy.all(True{},10n))
    IO.print(Profile.csv(Profile.Sample{p,0,0,0,0,0}))
