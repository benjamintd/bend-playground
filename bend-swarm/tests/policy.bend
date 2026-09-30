import Base
import ../engine/platform/player.bend as Player
import ../engine/profile/frame.bend as Profile

def meadow_label(sample: Profile.Sample) -> String:
  Player.details(~"BEND MEADOW",~"",True{},True{},True{},True{},Player.Measured{0,0,4096,sample})
