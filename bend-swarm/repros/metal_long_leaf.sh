#!/bin/sh
# Current minimal workload repro; reduction to a stand-alone tiny Bend kernel
# remains open. This starts no window and modifies no compiler/runtime source.
set -eu
cd "$(dirname "$0")/.."
exec ./build/boids-frame --gpu on --threads 10 -- 18 10 30 90
