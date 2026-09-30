#!/usr/bin/env python3
"""Check the disposable native window fixture, ignoring unrelated user input."""
import csv
from pathlib import Path
import sys

path = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/idle-events.csv')
rows = {row[0]: dict(focused=int(row[1]), visible=int(row[2]), interrupted=int(row[3]),
                     elapsed_us=int(row[4]), events=row[5].split())
        for row in csv.reader(path.read_text().splitlines())}
for name in ['ready', 'keys', 'drained', 'early-wake', 'background', 'resumed', 'interrupted', 'close']:
    assert name in rows, name
keys = lambda row: [event for event in row['events'] if event.startswith('key:100:')]
assert rows['ready']['focused'] == rows['ready']['visible'] == 1, rows['ready']
assert keys(rows['keys']) == ['key:100:1', 'key:100:0'], rows['keys']
assert keys(rows['drained']) == [], rows['drained']
assert keys(rows['early-wake']) == ['key:100:1', 'key:100:0'], rows['early-wake']
assert 10000 < rows['early-wake']['elapsed_us'] < 500000, rows['early-wake']
assert rows['background']['focused'] == 0, rows['background']
assert rows['background']['visible'] == rows['background']['interrupted'] == 1, rows['background']
assert rows['resumed']['focused'] == 1, rows['resumed']
assert rows['interrupted']['focused'] == rows['interrupted']['interrupted'] == 1, rows['interrupted']
assert rows['interrupted']['elapsed_us'] < 500000, rows['interrupted']
assert 'close' in rows['close']['events'], rows['close']
assert rows['close']['elapsed_us'] < 500000, rows['close']
print('PASS: polling before first presentation, ordered keys, drained queue, early wake, focus loss/resume, interruption retention and close.')
