#!/usr/bin/env python3
"""Summarize the stage profiler CSV (host elapsed time, not device timestamps)."""
import argparse
import csv
import math
import statistics
from pathlib import Path


def summarize(path):
    with Path(path).open() as stream:
        rows = [{key: int(value) for key, value in row.items()} for row in csv.DictReader(stream)]
    if not rows:
        raise ValueError("the capture contains no measured frames")
    stages = ["simulation", "geometry", "binning", "raster", "post"]
    choices = ["sim_gpu", "geometry_gpu", "binning_gpu", "raster_gpu", "post_gpu"]
    for row in rows:
        if any(value < 0 for value in row.values()):
            raise ValueError("timings and flags must be nonnegative")
        if any(row[key] not in (0, 1) for key in choices):
            raise ValueError("backend flags must be 0 or 1")
        if sum(row[s + "_us"] for s in stages) != row["work_us"] or row["work_us"] > row["frame_us"]:
            raise ValueError("stage accounting does not agree with frame time")
        row["other_us"] = row["frame_us"] - row["work_us"]
    print(f"{len(rows)} measured frames from {path}")
    print("Host elapsed milliseconds; frame excludes CSV output and window presentation.")
    print(f"{'Stage':<13} {'Backend':<8} {'Median':>9} {'P95':>9} {'Max':>9}")
    for stage in stages + ["work", "other", "frame"]:
        values = sorted(row[stage + "_us"] / 1000 for row in rows)
        backend = ""
        if stage in stages:
            selected = {row[choices[stages.index(stage)]] for row in rows}
            backend = {frozenset({0}): "CPU", frozenset({1}): "GPU"}.get(frozenset(selected), "mixed")
        print(f"{stage:<13} {backend:<8} {statistics.median(values):9.3f} {values[math.ceil(.95 * len(values)) - 1]:9.3f} {values[-1]:9.3f}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture")
    args = parser.parse_args()
    try:
        summarize(args.capture)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.error(str(error))
