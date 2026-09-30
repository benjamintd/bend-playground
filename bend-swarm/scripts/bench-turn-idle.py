#!/usr/bin/env python3
"""Native window/idle CPU comparison. Builds/tests must be stopped first."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
binary = root / 'build/turn-idle-bench'
records = []
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--case', action='append', choices=['idle','menu','background','hidden','minimized'])
args=parser.parse_args()
# Alternate the order across cases. Each process opens and closes its own window.
for index, case in enumerate(args.case or ['idle', 'menu', 'background', 'hidden', 'minimized']):
    for version in (['before', 'after'] if index % 2 == 0 else ['after', 'before']):
        output = subprocess.check_output([str(binary), '--gpu', 'off', '--threads', '8', '--', version, case],
                                         cwd=root, text=True, timeout=30).strip()
        wall, cpu, frames, loops, ticks, active = map(int, output.split(','))
        row = dict(case=case, version=version, wall_us=wall, process_cpu_us=cpu,
                   cpu_percent=cpu/wall*100, frames=frames, iterations=loops,
                   simulation_ticks=ticks, final_active=bool(active), frames_per_second=frames/(wall/1e6))
        if version == 'after' and case in ['idle', 'menu']:
            row['foreground_sample_valid'] = bool(active) and (case == 'menu' or 24 < row['frames_per_second'] < 33)
        records.append(row)
        print(json.dumps(row), flush=True)
        result = {'description': 'Native windows, 8 CPU threads, same renderer and simulation. Before reproduces the original unconditional 60 Hz loop; after invokes Turn\'s current poll/check loop. CPU percent is whole-process user+system CPU time / wall time (100% = one core). Startup/first render excluded. These are CPU-time proxies for energy, not watts or battery measurements. The background case keeps the game window visible but unfocused using an inert second window; hidden/minimized cases exercise OS lifecycle states. Other desktop work and the user\'s old Turn process were not stopped.',
                  'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(), 'runs': records}
        (root/'results/turn-idle-performance.json').write_text(json.dumps(result, indent=2)+'\n')
        if version == 'after':
            if case in ['menu','background','hidden','minimized']:
                assert frames <= 1, row
                assert cpu/wall < .05, row
            if case in ['background','hidden','minimized']:
                assert ticks == 0, row
                assert not active, row
        else:
            assert frames > 100, row
