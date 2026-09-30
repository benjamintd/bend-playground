import Base
import ./model.bend as M
import ./rules.bend as R
import ./resolution-check.bend as Check

law level0_possible:
  exs path: List<R.Beat>
  {R.certified(0,path,M.origin()) == True{} : Bool}
law level0_settling_total:
  {Check.level(0) == True{} : Bool}
law level1_possible:
  exs path: List<R.Beat>
  {R.certified(1,path,M.origin()) == True{} : Bool}
law level1_settling_total:
  {Check.level(1) == True{} : Bool}
law level2_possible:
  exs path: List<R.Beat>
  {R.certified(2,path,M.origin()) == True{} : Bool}
law level2_settling_total:
  {Check.level(2) == True{} : Bool}
law level3_possible:
  exs path: List<R.Beat>
  {R.certified(3,path,M.origin()) == True{} : Bool}
law level3_settling_total:
  {Check.level(3) == True{} : Bool}
law level4_possible:
  exs path: List<R.Beat>
  {R.certified(4,path,M.origin()) == True{} : Bool}
law level4_settling_total:
  {Check.level(4) == True{} : Bool}
law level5_possible:
  exs path: List<R.Beat>
  {R.certified(5,path,M.origin()) == True{} : Bool}
law level5_settling_total:
  {Check.level(5) == True{} : Bool}
law level6_possible:
  exs path: List<R.Beat>
  {R.certified(6,path,M.origin()) == True{} : Bool}
law level6_settling_total:
  {Check.level(6) == True{} : Bool}
law level7_possible:
  exs path: List<R.Beat>
  {R.certified(7,path,M.origin()) == True{} : Bool}
law level7_settling_total:
  {Check.level(7) == True{} : Bool}
law level8_possible:
  exs path: List<R.Beat>
  {R.certified(8,path,M.origin()) == True{} : Bool}
law level8_settling_total:
  {Check.level(8) == True{} : Bool}
law level9_possible:
  exs path: List<R.Beat>
  {R.certified(9,path,M.origin()) == True{} : Bool}
law level9_settling_total:
  {Check.level(9) == True{} : Bool}
law level10_possible:
  exs path: List<R.Beat>
  {R.certified(10,path,M.origin()) == True{} : Bool}
law level10_settling_total:
  {Check.level(10) == True{} : Bool}
law level11_possible:
  exs path: List<R.Beat>
  {R.certified(11,path,M.origin()) == True{} : Bool}
law level11_settling_total:
  {Check.level(11) == True{} : Bool}
law level12_possible:
  exs path: List<R.Beat>
  {R.certified(12,path,M.origin()) == True{} : Bool}
law level12_settling_total:
  {Check.level(12) == True{} : Bool}
law level13_possible:
  exs path: List<R.Beat>
  {R.certified(13,path,M.origin()) == True{} : Bool}
law level13_settling_total:
  {Check.level(13) == True{} : Bool}
law level14_possible:
  exs path: List<R.Beat>
  {R.certified(14,path,M.origin()) == True{} : Bool}
law level14_settling_total:
  {Check.level(14) == True{} : Bool}
law level15_possible:
  exs path: List<R.Beat>
  {R.certified(15,path,M.origin()) == True{} : Bool}
law level15_settling_total:
  {Check.level(15) == True{} : Bool}
law level16_possible:
  exs path: List<R.Beat>
  {R.certified(16,path,M.origin()) == True{} : Bool}
law level16_settling_total:
  {Check.level(16) == True{} : Bool}
law level17_possible:
  exs path: List<R.Beat>
  {R.certified(17,path,M.origin()) == True{} : Bool}
law level17_settling_total:
  {Check.level(17) == True{} : Bool}
law level18_possible:
  exs path: List<R.Beat>
  {R.certified(18,path,M.origin()) == True{} : Bool}
law level18_settling_total:
  {Check.level(18) == True{} : Bool}
law level19_possible:
  exs path: List<R.Beat>
  {R.certified(19,path,M.origin()) == True{} : Bool}
law level19_settling_total:
  {Check.level(19) == True{} : Bool}
law level20_possible:
  exs path: List<R.Beat>
  {R.certified(20,path,M.origin()) == True{} : Bool}
law level20_settling_total:
  {Check.level(20) == True{} : Bool}
law level21_possible:
  exs path: List<R.Beat>
  {R.certified(21,path,M.origin()) == True{} : Bool}
law level21_settling_total:
  {Check.level(21) == True{} : Bool}
law level22_possible:
  exs path: List<R.Beat>
  {R.certified(22,path,M.origin()) == True{} : Bool}
law level22_settling_total:
  {Check.level(22) == True{} : Bool}
law level23_possible:
  exs path: List<R.Beat>
  {R.certified(23,path,M.origin()) == True{} : Bool}
law level23_settling_total:
  {Check.level(23) == True{} : Bool}
law level24_possible:
  exs path: List<R.Beat>
  {R.certified(24,path,M.origin()) == True{} : Bool}
law level24_settling_total:
  {Check.level(24) == True{} : Bool}
law level25_possible:
  exs path: List<R.Beat>
  {R.certified(25,path,M.origin()) == True{} : Bool}
law level25_settling_total:
  {Check.level(25) == True{} : Bool}
