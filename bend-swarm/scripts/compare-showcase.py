#!/usr/bin/env python3
"""Compare saved native demo binaries sequentially, alternating run order."""
import argparse
import csv
import datetime
import hashlib
import io
import json
import math
import statistics
import subprocess
from pathlib import Path

from bench import ROOT, machine_info, source_hash


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summary(rows):
    result = {}
    for column in rows[0]:
        values = sorted(int(row[column]) / 1000 for row in rows)
        result[column.replace('_us', '_ms')] = {
            'median': statistics.median(values),
            'p95': values[math.ceil(.95 * len(values)) - 1],
        }
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--before-source-sha256', required=True)
    parser.add_argument('--demo', choices=['life', 'meadow', 'cloth'], required=True)
    parser.add_argument('--backend', choices=['cpu', 'gpu'], required=True)
    parser.add_argument('--effects', choices=['raw', 'aa', 'dof'], default='aa')
    parser.add_argument('--quality', choices=['standard', 'high'], default='standard')
    parser.add_argument('--pairs', type=int, default=3)
    parser.add_argument('--control', action='store_true', help='Run the baseline twice first (A/A).')
    parser.add_argument('--tag', required=True)
    args = parser.parse_args()
    if args.pairs < 1 or not args.tag or Path(args.tag).name != args.tag:
        parser.error('pairs must be positive and tag must be a filename')
    if args.demo == 'life' and args.effects == 'dof':
        parser.error('Particle Life has no depth of field')
    if args.demo == 'cloth' and args.effects != 'raw':
        parser.error('The cloth benchmark supports only --effects raw')
    binaries = {'before': args.before.resolve(), 'after': args.after.resolve()}
    meta = {
        'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        **machine_info(),
        'bend_version': (ROOT / '.bend-version').read_text().splitlines(),
        'source_sha256': {'before': args.before_source_sha256, 'after': source_hash()},
        'binaries': {name: {
            'path': str(path), 'sha256': digest(path),
            'gpu_sha256': digest(Path(str(path) + '.gpu')) if Path(str(path) + '.gpu').exists() else None,
        } for name, path in binaries.items()},
        'demo': args.demo, 'backend': args.backend, 'effects': args.effects,
        'resolution': (512 if args.demo == 'cloth' else 1024) * (2 if args.quality == 'high' else 1),
        'scene': {'substeps': 2, 'substep_dt': 1 / 120, 'physics_vertices': 1024} if args.demo == 'cloth' else {'seed': 42, 'preset': 1},
        'threads': 10, 'warmup': 120, 'samples': 600,
        'scope': 'Headless full frame including old Image reclamation; excludes window/HUD/display. '
                 'Sequential processes, alternating pair order. Each run restarts the same seeded scene. '
                 'GPU simulation may diverge numerically; these are evolving scenes, not frozen render-only probes.',
        'runs': [],
    }
    target = ROOT / 'results' / (args.tag + '.json')
    schedule = [('control', 0, 'before'), ('control', 1, 'before')] if args.control else []
    for pair in range(args.pairs):
        for label in (['before', 'after'] if pair % 2 == 0 else ['after', 'before']):
            schedule.append(('pair', pair, label))
    for kind, pair, label in schedule:
        command = [str(binaries[label]), '--gpu', 'on' if args.backend == 'gpu' else 'off',
                   '--threads', '10', '--']
        if args.demo == 'cloth':
            command += ['6' if args.quality == 'high' else '5', '10' if args.backend == 'gpu' else '0', '120', '600']
        else:
            command += [args.backend, args.effects]
            if args.quality == 'high':
                command.append('high')
        run = {'kind': kind, 'pair': pair, 'label': label, 'command': command,
               'date': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        process = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=300)
        run.update(returncode=process.returncode, stderr=process.stderr)
        csv_name = f'{args.tag}-{kind}{pair}-{label}.csv'
        (ROOT / 'results' / csv_name).write_text(process.stdout)
        run['csv'] = csv_name
        rows = list(csv.DictReader(io.StringIO(process.stdout)))
        meta['runs'].append(run)
        if process.returncode or len(rows) != 600:
            target.write_text(json.dumps(meta, indent=2) + '\n')
            raise RuntimeError(f'Failed run: {run}')
        run['summary'] = summary(rows)
        target.write_text(json.dumps(meta, indent=2) + '\n')
        print(f'{kind} {pair} {label}: {run["summary"]}', flush=True)
    meta['median_of_run_medians'] = {
        label: {stage: statistics.median(run['summary'][stage]['median'] for run in meta['runs']
                                        if run['kind'] == 'pair' and run['label'] == label)
                for stage in ('simulation_ms', 'render_ms', 'frame_ms')}
        for label in ('before', 'after')
    }
    target.write_text(json.dumps(meta, indent=2) + '\n')
    print(json.dumps(meta['median_of_run_medians'], indent=2))


if __name__ == '__main__':
    main()
