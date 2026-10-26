#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

ROOT="$(cd ../.. && pwd)"
source "$ROOT/build_progress.sh"

viewer_only=0
if [[ "${1:-}" == "--viewer" ]]; then
  viewer_only=1
elif [[ $# -gt 0 ]]; then
  echo "Usage: ./build.sh [--viewer]" >&2
  exit 2
fi
BUILD_TOTAL=5
if [[ "$viewer_only" -eq 0 ]]; then BUILD_TOTAL=6; fi

# Check for Metal tool
if ! xcrun --sdk macosx --find metal >/dev/null 2>&1; then
  echo "Metal tool not found. Run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "  xcodebuild -downloadComponent MetalToolchain"
  exit 1
fi

# Compile shader libs
run_build_step "Compile N-body shader" xcrun -sdk macosx metal -c Shaders/nbody.metal -o Shaders/nbody.air
run_build_step "Link N-body shader library" xcrun -sdk macosx metallib Shaders/nbody.air -o Shaders/nbody.metallib
run_build_step "Compile particle shader" xcrun -sdk macosx metal -c Shaders/points.metal -o Shaders/points.air
run_build_step "Link particle shader library" xcrun -sdk macosx metallib Shaders/points.air -o Shaders/points.metallib

# Build console app
if [[ "$viewer_only" -eq 0 ]]; then
  run_build_step "Build console app" clang++ -std=c++17 -fobjc-arc \
    -framework Metal -framework Foundation \
    Source/Renderer.mm Source/Sim.cpp main.mm \
    -o NBody
fi

# Build MetalKit windowed app
run_build_step "Build viewer app" clang++ -std=c++17 -fobjc-arc \
  -framework Cocoa -framework Metal -framework MetalKit -framework Foundation \
  -framework AVFoundation -framework CoreMedia -framework ScreenCaptureKit -framework Accelerate -framework UniformTypeIdentifiers \
  Source/Renderer.mm Source/Sim.cpp Source/MusicAnalysis.mm Source/InstrumentAnalysis.mm App/AppDelegate.mm \
  -o NBodyApp

echo "Build complete."
echo "Console: ./NBody [N]"
echo "Window : ./NBodyApp"
