#!/usr/bin/env python3
"""Measure the native cloth pipeline, preserving raw samples and run metadata."""
import argparse,csv,datetime,hashlib,io,json,math,pathlib,statistics,subprocess
from bench import ROOT,machine_info,source_hash

p=argparse.ArgumentParser()
p.add_argument('--backend',choices=['gpu','cpu'],default='gpu')
p.add_argument('--depth',type=int,default=None)
p.add_argument('--warmup',type=int,default=120)
p.add_argument('--frames',type=int,default=600)
p.add_argument('--tag')
p.add_argument('--quality',choices=['standard','high'],default='standard')
a=p.parse_args()
if a.depth is None: a.depth=0 if a.backend=='cpu' else 10
if not 0<=a.depth<=20 or a.warmup<0 or a.frames<1: p.error('invalid depth, warmup or frames')
binary=ROOT/'build/cloth-frame'
command=[str(binary),'--gpu','on' if a.backend=='gpu' else 'off','--threads','10','--','6' if a.quality=='high' else '5',str(a.depth),str(a.warmup),str(a.frames)]
started=datetime.datetime.now(datetime.timezone.utc).isoformat()
result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=max(300,a.frames*2))
if result.returncode: raise RuntimeError(f'Cloth exited {result.returncode}: {result.stderr}')
rows=list(csv.DictReader(io.StringIO(result.stdout)))
if len(rows)!=a.frames: raise RuntimeError(f'expected {a.frames} samples, got {len(rows)}')
def stats(key):
    values=sorted(int(r[key])/1000 for r in rows)
    return dict(median=statistics.median(values),p95=values[math.ceil(.95*len(values))-1],minimum=min(values),maximum=max(values))
meta=dict(date=started,command=command,**machine_info(),backend=a.backend,threads=10,
    bend_version=(ROOT/'.bend-version').read_text().splitlines(),binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
    source_sha256=source_hash(),vertices=1024,render_vertices=4096 if a.quality=='high' else 1024,
    triangles=7938 if a.quality=='high' else 1922,resolution=[1024,1024] if a.quality=='high' else [512,512],quality=a.quality,substeps=2,substep_dt=1/120,
    constraint_iterations=12,spatial_cells=[32,32,32],spatial_cell_size=.25,contact_thickness=.018,contact_query_radius=3.6/31*2.8+.08,contact_passes=1,
    pins='opposite corners, initial height 1.55 m',wind=1.5,fork_depth=a.depth,warmup=a.warmup,samples=a.frames,
    summary={k.replace('_us','_ms'):stats(k) for k in rows[0]},stderr=result.stderr,
    execution_plan='coarse CPU solver plus 64 contact regions' if a.depth==0 else 'GPU fork plan',
    scope='headless simulation, spatial surface self-contact, mesh projection/binning/raster and old-image reclamation; excludes HUD, window and display')
tag=a.tag or f'cloth-{a.backend}-d{a.depth}-{datetime.datetime.now().strftime("%Y%m%d-%H%M%S")}'
if pathlib.Path(tag).name!=tag: p.error('tag must be a filename without directories')
target=ROOT/'results'/tag
target.with_suffix('.csv').write_text(result.stdout)
target.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps(dict(result=str(target.with_suffix('.json')),summary=meta['summary']),indent=2))
