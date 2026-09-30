#!/usr/bin/env python3
"""Sequential headless engine comparison; keep other builds/tests stopped."""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import statistics
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('stage', help='capture label, e.g. before or after')
parser.add_argument('binaries', type=Path, help='directory containing profile and points-frame')
parser.add_argument('--warmup', type=int, default=20)
parser.add_argument('--samples', type=int, default=60)
parser.add_argument('--case', action='append', dest='selected', help='run only this named case; repeatable')
args = parser.parse_args()
if args.warmup < 0 or args.samples < 1:
    parser.error('warmup must be nonnegative and samples must be positive')
if not args.stage.replace('-', '').replace('_', '').isalnum():
    parser.error('stage must contain only letters, digits, dashes or underscores')
root = Path(__file__).resolve().parent.parent
prefix = args.binaries.resolve()
cases = [
    ('cloth-cpu-raw', 'profile', 'off', ['cloth', 'cpu', 'raw', 'standard']),
    ('cloth-metal-dof', 'profile', 'on', ['cloth', 'render', 'dof', 'standard']),
    ('meadow-cpu-raw', 'profile', 'off', ['meadow', 'cpu', 'raw', 'standard']),
    ('meadow-cpu-dof', 'profile', 'off', ['meadow', 'cpu', 'dof', 'standard']),
    ('meadow-metal-raw', 'profile', 'on', ['meadow', 'gpu', 'raw', 'standard']),
    ('meadow-metal-dof', 'profile', 'on', ['meadow', 'gpu', 'dof', 'standard']),
    ('points-cpu', 'points-frame', 'off', ['17', '14']),
    ('points-metal', 'points-frame', 'on', ['17', '14']),
]
results = []
if args.selected:
    unknown = set(args.selected) - {case[0] for case in cases}
    if unknown:
        parser.error('unknown cases: ' + ', '.join(sorted(unknown)))
    cases = [case for case in cases if case[0] in args.selected]
for name, binary, gpu, settings in cases:
    output = root / f'results/engine-{args.stage}-{name}.csv'
    exe = prefix / binary
    cli = [*settings, str(args.warmup), str(args.samples)]
    print(args.stage, name, flush=True)
    with output.open('w') as stream:
        subprocess.run([str(exe), '--gpu', gpu, '--threads', '10', '--', *cli],
                       cwd=root, stdout=stream, check=True, timeout=600)
    with output.open() as stream:
        rows = list(csv.DictReader(stream))
    assert len(rows) == args.samples, (name, len(rows), args.samples)
    stats = {}
    for key in rows[0]:
        values = sorted(int(row[key]) for row in rows)
        stats[key] = {'median': statistics.median(values),
                      'p95': values[math.ceil(.95 * len(values)) - 1]}
    results.append({'name': name, 'capture': str(output.relative_to(root)),
                    'binary_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
                    'args': cli, 'gpu': gpu, 'samples': len(rows), 'us': stats})
    (root / f'results/engine-{args.stage}.json').write_text(json.dumps(results, indent=2) + '\n')
