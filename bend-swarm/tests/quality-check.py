import csv, math
from pathlib import Path
expected_quality=[['pixel','2098176','16777215'],['pixel','2097252','16711680'],['pixel','0','0'],['image','4194304','0'],
 ['pixel','524800','16777215'],['pixel','524338','8323072'],['pixel','0','0'],['image','1048576','0']]
expected_quality += [['pixel','524800','16777215'],['pixel','524338','4128768'],['pixel','0','0'],['image','1048576','0']]*2
# Independent additive coverage oracle at doubled resolution, evaluating only
# potentially touched pixels but including the complete background in sums.
fixture=[(.25,.5,5304258),(1023.8,1023.8,16758619),(7.9,8.1,15429309),(511.9,512.1,6921215),
 (514,514,15982954),(7.1,7.8,9927665),(1.2,1.5,5304258),(1022.5,1.8,16758619)]
base=[4,6,12];pixels={}
for x,y,color in fixture:
 cx,cy=2*x,2*y
 for py in range(math.floor(cy-9),math.ceil(cy+9)):
  for px in range(math.floor(cx-9),math.ceil(cx+9)):
   d2=(px+.5-cx)**2+(py+.5-cy)**2
   coverage=max(0,min(1,8.5-math.sqrt(d2)));core=max(0,1-d2/64)
   light=coverage*1.55*(.1+.9*core*core)
   if light<=.001:continue
   value=pixels.setdefault((px%2048,py%2048),base.copy())
   for k,shift in enumerate([16,8,0]):value[k]=min(255,value[k]+min(255,math.floor(((color>>shift)&255)*light)))
sums=[v*4194304+sum(c[k]-v for c in pixels.values()) for k,v in enumerate(base)]
count=sum(c!=base for c in pixels.values())
for backend in ['cpu','gpu']:
 assert list(csv.reader(Path(f'build/quality-{backend}.csv').open()))==expected_quality
 rows=list(csv.reader(Path(f'build/splats-high-{backend}.csv').open()))
 assert rows[1]==['image','4194304','0']
 got=list(map(int,rows[0][1:]));assert got[3]==count,(backend,got[3],count)
 assert all(abs(a-b)<512 for a,b in zip(got[:3],sums)),(backend,got,sums)
 assert Path(f'build/life-image-{backend}.csv').read_text().strip()=='1048576,0'
print(f'PASS: CPU/Metal 2048 raster, 4-sample thin-line resolve, complete Image ownership and {count} doubled-resolution wrapped sprite pixels.')
