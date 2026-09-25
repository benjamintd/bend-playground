"""Independent finite segment/triangle intersection oracle for native snapshots."""
import sys,math,itertools,json
def sub(a,b):return [x-y for x,y in zip(a,b)]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def hit(p,q,a,b,c):
 d=sub(q,p);e=sub(b,a);f=sub(c,a);h=cross(d,f);det=dot(e,h)
 if abs(det)<1e-10:return False
 s=sub(p,a);u=dot(s,h)/det
 if not 1e-6<u<1-1e-6:return False
 k=cross(s,e);v=dot(d,k)/det;t=dot(f,k)/det
 return v>1e-6 and u+v<1-1e-6 and 1e-6<t<1-1e-6
def intersections(p,side):
 tris=[]
 for y in range(side-1):
  for x in range(side-1):
   a=x+y*side;tris.extend([(a,a+1,a+side+1),(a,a+side+1,a+side)])
 bins={}
 for i,t in enumerate(tris):
  lo=[math.floor(min(p[j][k] for j in t)/.2) for k in range(3)];hi=[math.floor(max(p[j][k] for j in t)/.2) for k in range(3)]
  for cell in itertools.product(*(range(a,b+1) for a,b in zip(lo,hi))):bins.setdefault(cell,[]).append(i)
 pairs=set(); hits=[]
 for ts in bins.values():
  for a,b in itertools.combinations(ts,2):
   if (a,b) in pairs:continue
   pairs.add((a,b));ta,tb=tris[a],tris[b]
   if set(ta)&set(tb):continue
   if any(hit(p[t[i]],p[t[(i+1)%3]],*(p[k] for k in u)) for t,u in [(ta,tb),(tb,ta)] for i in range(3)):hits.append((a,b))
 return hits

if __name__=='__main__':
 rows=[list(map(float,l.split(','))) for l in open(sys.argv[1]) if l.strip()]
 assert len(rows)==20*1024, "expected twenty complete 32x32 snapshots"
 counts=[];maximum=0
 for offset in range(0,len(rows),1024):
  p=rows[offset:offset+1024]
  assert all(math.isfinite(v) for row in p for v in row)
  assert all(y>=-1.60001 and math.hypot(x,y+.25,z)>=1.21998 for x,y,z in p)
  for i,expected in [(0,[-1.8,1.55,-1.8]),(1023,[1.8,1.55,1.8])]:
   assert all(abs(v-e)<1e-6 for v,e in zip(p[i],expected))
  hits=intersections(p,32);counts.append(len(hits))
  for i in range(1024):
   for j in ([i+1] if i%32<31 else [])+([i+32] if i<992 else []):
    maximum=max(maximum,math.dist(p[i],p[j])/(3.6/31))
 assert maximum<1.5, f'Excessive stretch under compliant dragging: {maximum}'
 assert not any(counts),f'Non-adjacent triangle crossings: {counts}'
 print(json.dumps(dict(snapshots=len(counts),intersection_counts=counts,max_structural_stretch=maximum)))
