#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Check for Metal tool
if ! xcrun --sdk macosx --find metal >/dev/null 2>&1; then
  echo "Metal tool not found. Run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "  xcodebuild -downloadComponent MetalToolchain"
  exit 1
fi

# Compile shader libs
xcrun -sdk macosx metal -c Shaders/nbody.metal -o Shaders/nbody.air
xcrun -sdk macosx metallib Shaders/nbody.air -o Shaders/nbody.metallib
xcrun -sdk macosx metal -c Shaders/points.metal -o Shaders/points.air
xcrun -sdk macosx metallib Shaders/points.air -o Shaders/points.metallib

# Build console app
clang++ -std=c++17 -fobjc-arc \
  -framework Metal -framework Foundation \
  Source/Renderer.mm Source/Sim.cpp main.mm \
  -o NBody

# Build MetalKit windowed app
clang++ -std=c++17 -fobjc-arc \
  -framework Cocoa -framework Metal -framework MetalKit -framework Foundation \
  Source/Renderer.mm Source/Sim.cpp App/AppDelegate.mm \
  -o NBodyApp

echo "Build complete."
echo "Console: ./NBody [N]"
echo "Window : ./NBodyApp"
