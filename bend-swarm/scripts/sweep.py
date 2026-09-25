#!/usr/bin/env python3
import argparse,csv,json,pathlib
from bench import ROOT,run
p=argparse.ArgumentParser();p.add_argument('--agents',type=int,nargs='+',default=[65536,131072,262144]);p.add_argument('--depths',type=int,nargs='+',default=[8,10,12,14]);p.add_argument('--frames',type=int,default=120);p.add_argument('--warmup',type=int,default=60);p.add_argument('--backend',choices=['cpu','gpu'],default='gpu')
a=p.parse_args();rows=[]
# Run sequentially: concurrent GPU workloads would invalidate the measurements.
for n in a.agents:
    for depth in a.depths:
        try: m=run(n,depth,a.backend,a.warmup,a.frames)
        except RuntimeError as e:
            print(str(e),flush=True)
            continue
        rows.append(dict(agents=n,depth=depth,**{k:v['median'] for k,v in m['summary'].items()}))
if not rows: raise SystemExit('No successful configurations')
with (ROOT/'results'/'sweep.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=rows[0],lineterminator='\n');w.writeheader();w.writerows(rows)
print(json.dumps({n:min((r for r in rows if r['agents']==n),key=lambda r:r['frame_ms']) for n in a.agents if any(r['agents']==n for r in rows)},indent=2))
