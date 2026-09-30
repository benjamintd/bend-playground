#!/usr/bin/env python3
"""Measure active Cloth routing and real-window presentation, sequentially."""
import argparse
import csv
import datetime
import hashlib
import io
import json
import math
import statistics
import subprocess

from bench import ROOT, machine_info, source_hash


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', help='Saved pre-fix cloth-frame binary (2.0.27 numeric CLI)')
    parser.add_argument('--window', action='store_true', help='Include finite native window runs')
    parser.add_argument('--window-default', action='store_true', help='CPU drawing with Metal available, matching the app launcher')
    parser.add_argument('--tag', default='cloth-interactive')
    args = parser.parse_args()
    if not args.tag or '/' in args.tag:
        parser.error('tag must be a filename')
    meta = {
        'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        **machine_info(), 'bend_version': (ROOT / '.bend-version').read_text().splitlines(),
        'source_sha256': source_hash(), 'threads': 10, 'warmup': 120, 'samples': 600,
        'physics_vertices': 1024, 'substeps': 2, 'substep_dt': 1 / 120,
        'scene': 'Active drape with wind; no grab, pause or user input; restarted for each run.',
        'scope': 'Headless routing comparison alternates order; GPU physics can diverge numerically. '
                 'Window runs include HUD, presentation and 60 Hz pacing, and request two substeps '
                 'per frame. No concurrent builds, tests or demo runs from this task.',
        'runs': [],
    }
    path = ROOT / 'results' / (args.tag + '.json')

    def run(label, binary, gpu, argv, kind):
        binary = (ROOT / binary).resolve()
        command = [str(binary), '--gpu', gpu, '--threads', '10', '--', *argv]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=300)
        name = args.tag + '-' + label + '.csv'
        (ROOT / 'results' / name).write_text(result.stdout)
        rows = list(csv.DictReader(io.StringIO(result.stdout)))
        entry = {'label': label, 'kind': kind, 'command': command, 'csv': name,
                 'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
                 'date': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                 'returncode': result.returncode, 'stderr': result.stderr}
        entry['observed_samples'] = len(rows)
        entry['status'] = 'complete' if result.returncode == 0 and len(rows) == 600 else 'incomplete'
        gpu_file = binary.with_name(binary.name + '.gpu')
        entry['gpu_sha256'] = hashlib.sha256(gpu_file.read_bytes()).hexdigest() if gpu_file.exists() else None
        meta['runs'].append(entry)
        if result.returncode or len(rows) != 600:
            path.write_text(json.dumps(meta, indent=2) + '\n')
            raise RuntimeError(f'{label}: failed or wrong sample count ({len(rows)})')
        entry['summary'] = {}
        for key in rows[0]:
            values = sorted(int(row[key]) / 1000 for row in rows)
            entry['summary'][key.replace('_us', '_ms')] = {
                'median': statistics.median(values), 'p95': values[math.ceil(.95 * len(values)) - 1],
            }
        path.write_text(json.dumps(meta, indent=2) + '\n')
        print(label, entry['summary'], flush=True)

    if args.before:
        for pair in range(2):
            for before in ([True, False] if pair == 0 else [False, True]):
                run(f'pair{pair}-' + ('before' if before else 'after'),
                    args.before if before else 'build/cloth-frame', 'on',
                    ['5', '10', '120', '600'] if before else ['hybrid', '5', 'raw', '120', '600'],
                    'headless')
    if args.window:
        for mode, size, effect in [('cpu', 'standard', 'raw'), ('hybrid', 'standard', 'aa'),
                                   ('hybrid', 'high', 'aa'), ('hybrid', 'high', 'dof')]:
            run('window-' + '-'.join([mode, size, effect]), 'build/cloth-window',
                'off' if mode == 'cpu' else 'on', [mode, size, effect], 'window')
    if args.window_default:
        run('window-default', 'build/cloth-window', 'on', ['cpu', 'standard', 'raw'], 'window')


if __name__ == '__main__':
    main()
