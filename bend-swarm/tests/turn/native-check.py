"""Feed JS-recorded inputs to the native Bend controller and compare results.

The Apple clang 17 backend crashes on the compiler-unrolled 120-tick completion
check. Runtime inputs keep that loop compact without changing compiler flags or
the game's implementation. Simulation, completion and assertions run in Bend.
"""
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[2]
reports = json.loads((root / 'build/turn-continuous-solutions.json').read_text())
catalog = json.loads((root / 'demos/turn/catalog.json').read_text())
assert len(reports) == len(catalog['levels'])
for level, report in enumerate(reports):
    assert report['level'] == level + 1
    words = []
    for run in report['runs']:
        assert 0 < run['ticks'] <= 65535 and 0 <= run['keys'] <= 15
        words.append(run['ticks'] | run['keys'] << 16 |
                     int(run['jump']) << 20 | int(run['turn']) << 21)
    args = [level, *report['position'], 120, *words]
    subprocess.run([str(root / 'build/turn-native-test'), '--gpu', 'off',
                    '--threads', '8', '--', *map(str, args)], check=True, cwd=root)
