#!/usr/bin/env python3
"""Capture a complete pure-Bend demo pipeline, with explicit effect settings."""
import argparse,csv,datetime,hashlib,io,json,math,statistics,subprocess
from bench import ROOT,machine_info,source_hash
p=argparse.ArgumentParser()
p.add_argument('--demo',choices=['meadow','life'],required=True)
p.add_argument('--backend',choices=['cpu','gpu'],required=True)
p.add_argument('--effects',choices=['raw','aa','dof'],default='aa')
p.add_argument('--quality',choices=['standard','high'],default='standard')
p.add_argument('--tag',required=True)
a=p.parse_args()
if a.demo=='life' and a.effects=='dof': p.error('Particle Life is 2D and has no depth-of-field mode')
if '/' in a.tag or '\\' in a.tag: p.error('tag must be a filename')
binary=ROOT/'build'/f'{a.demo}-frame'
command=[str(binary),'--gpu','on' if a.backend=='gpu' else 'off','--threads','10','--',a.backend,a.effects]
if a.quality=='high': command.append('high')
meta=dict(date=datetime.datetime.now(datetime.timezone.utc).isoformat(),command=command,**machine_info(),
  bend_version=(ROOT/'.bend-version').read_text().splitlines(),source_sha256=source_hash(),binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
  demo=a.demo,backend=a.backend,effects=a.effects,threads=10,warmup=120,samples=600,count=4096 if a.demo=='meadow' else 8192,quality=a.quality,resolution=[2048,2048] if a.quality=='high' else [1024,1024],raster_resolution=[2048,2048] if a.quality=='high' else [1024,1024],dt=1/60,
  scope='Headless simulation, geometry/index, raster, selected effects and old-image reclamation. Excludes window/HUD/pacing. No tests or builds from this task run concurrently; other desktop demos and background jobs may remain active. This is not an idle-machine benchmark.')
r=subprocess.run(command,cwd=ROOT,text=True,capture_output=True,timeout=300)
if r.returncode: raise RuntimeError(r.stderr)
rows=list(csv.DictReader(io.StringIO(r.stdout)))
if len(rows)!=600: raise RuntimeError(f'Expected 600 samples, got {len(rows)}')
meta['summary']={}
for k in rows[0]:
 v=sorted(int(row[k])/1000 for row in rows)
 meta['summary'][k.replace('_us','_ms')]=dict(median=statistics.median(v),p95=v[math.ceil(.95*len(v))-1],minimum=v[0],maximum=v[-1])
meta['stderr']=r.stderr
base=ROOT/'results'/a.tag
base.with_suffix('.csv').write_text(r.stdout);base.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps(dict(file=str(base.with_suffix('.json')),summary=meta['summary']),indent=2))
