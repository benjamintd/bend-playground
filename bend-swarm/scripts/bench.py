#!/usr/bin/env python3
"""Run one isolated, native Bend workload; retain raw samples and metadata."""
import argparse,csv,datetime,hashlib,io,json,math,os,pathlib,platform,statistics,subprocess
ROOT=pathlib.Path(__file__).resolve().parent.parent

def source_hash():
    h=hashlib.sha256()
    for p in sorted(ROOT.rglob('*.bend')):
        if '.toolchain' in p.parts or 'build' in p.parts: continue
        h.update(str(p.relative_to(ROOT)).encode()); h.update(p.read_bytes())
    return h.hexdigest()

def machine_info():
    info=dict(os=platform.platform(),cpu=platform.processor() or platform.machine(),gpu='unqueried',memory_gb=None)
    if platform.system()=='Darwin':
        info['cpu']=subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip()
        info['memory_gb']=int(subprocess.check_output(['sysctl','-n','hw.memsize'],text=True))/2**30
        displays=json.loads(subprocess.check_output(['system_profiler','SPDisplaysDataType','-json'],text=True))
        info['gpu']=[{k:g[k] for k in ('sppci_model','sppci_cores','spdisplays_metal') if k in g}
                     for g in displays.get('SPDisplaysDataType',[])]
    return info

def run(agents,depth,backend,warmup,frames,workload='boids',tag=None):
    if agents<1024 or agents>1048576 or agents&(agents-1): raise ValueError('agents must be a power of two from 1024 through 1048576')
    if not 0<=depth<=20 or warmup<0 or frames<1: raise ValueError('invalid depth / warmup / frames')
    binary=ROOT/'build'/('boids-frame' if workload=='boids' else 'points-frame')
    if not binary.exists(): raise RuntimeError('run scripts/build first')
    args=[str(binary),'--gpu','on' if backend=='gpu' else 'off','--threads','10','--',str(agents.bit_length()-1),str(depth),str(warmup),str(frames)]
    started=datetime.datetime.now(datetime.timezone.utc).isoformat()
    result=subprocess.run(args,cwd=ROOT,text=True,capture_output=True,check=False,timeout=max(300,frames*10))
    if result.returncode:
        failure=dict(command=args,date=started,returncode=result.returncode,stderr=result.stderr,stdout=result.stdout,
          source_sha256=source_hash(),binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest())
        (ROOT/'results'/f'failure-{workload}-{backend}-{agents}-d{depth}.json').write_text(json.dumps(failure,indent=2)+'\n')
        raise RuntimeError(f"Bend exited {result.returncode}: {result.stderr}")
    rows=list(csv.DictReader(io.StringIO(result.stdout)))
    if len(rows)!=frames: raise RuntimeError(f'expected {frames} samples, got {len(rows)}')
    data={k:[int(r[k]) for r in rows] for k in rows[0]}
    def stats(xs):
        ys=sorted(xs)
        return dict(mean=statistics.mean(xs),median=statistics.median(xs),p95=ys[math.ceil(.95*len(ys))-1],minimum=min(xs),maximum=max(xs))
    summaries={k.replace('_us','_ms'):stats([v/1000 for v in vs]) for k,vs in data.items() if k.endswith('_us')}
    try: commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError: commit=None
    meta=dict(date=started,git_commit=commit,source_sha256=source_hash(),binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),bend_version=(ROOT/'.bend-version').read_text().splitlines(),
      **machine_info(),
      backend=backend,threads=10,agents=agents,resolution=[1024,1024],world_size=[1024,1024],radius=8,dt=1/60,
      boids_speed_range=[20,60] if workload=='boids' else None,
      fork_depth=depth,leaf_items=agents//2**min(depth,agents.bit_length()-1),render_quadtree_depth=7,tile_size=8,
      warmup=warmup,samples=frames,workload=workload,command=args,summary=summaries,
      scope='headless Bend pipeline; includes previous image reclamation; excludes HUD, Window.frame, display sync and startup',stderr=result.stderr)
    if 'candidates' in data:
        meta['candidates_per_second']=sum(data['candidates'])/(sum(data['simulation_us'])/1e6)
    stem=tag or f'{workload}-{backend}-{agents}-d{depth}-{datetime.datetime.now().strftime("%Y%m%d-%H%M%S")}'
    target=ROOT/'results'/stem; target.parent.mkdir(exist_ok=True)
    target.with_suffix('.csv').write_text(result.stdout)
    target.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(json.dumps({'result':str(target.with_suffix('.json')),'summary':summaries},indent=2),flush=True)
    return meta

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--agents',type=int,default=131072);p.add_argument('--depth',type=int,default=14)
    p.add_argument('--backend',choices=['gpu','cpu'],default='gpu');p.add_argument('--warmup',type=int,default=120)
    p.add_argument('--frames',type=int,default=600);p.add_argument('--workload',choices=['boids','points'],default='boids');p.add_argument('--tag')
    a=p.parse_args();run(a.agents,a.depth,a.backend,a.warmup,a.frames,a.workload,a.tag)
