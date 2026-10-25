#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Compile Metal to metallib
xcrun -sdk macosx metal -c Shaders/nbody.metal -o Shaders/nbody.air
xcrun -sdk macosx metallib Shaders/nbody.air -o Shaders/nbody.metallib

# Build console app (Objective-C++ + C++)
clang++ -std=c++17 -fobjc-arc \
    -framework Metal -framework Foundation \
    Source/Renderer.mm Source/Sim.cpp main.mm \
    -o NBody

echo "Build complete. Run ./NBody [N]  (default N=50000)"
