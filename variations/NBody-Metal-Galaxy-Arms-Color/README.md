# Galaxy Arms • Color Edition

Radial teal, violet, and pink particle colors highlight the spiral structure. The simulation kernel, initialization, and particle count are copied from the original variation.

Build and run from this folder with `./build.sh` and `./NBodyApp`.

# NBody-Metal-MVP (Console)

Minimal **Metal compute** N-body MVP for Apple Silicon. No UI; it dispatches two kernels (forces + integrate) and prints FPS/latency.

## Requirements
- macOS with Xcode command line tools
- Apple Silicon GPU (M1/M2/M3)
- `xcrun`, `clang++` in PATH

## Build
```bash
cd NBody-Metal-MVP
./build.sh
```

## Run
```bash
./NBody            # default N=50000
./NBody 100000     # try 100k (may drop FPS on fanless machines)
```

Sample output:
```
Metal N-Body (N=50000)
Avg frame: 16.4 ms (FPS 61.0)  p50: 16.2 ms  p95: 19.8 ms
```

## Notes
- Uses **MTLResourceStorageModeShared** (unified memory) for simplicity.
- Threadgroup size is derived from each pipeline’s `threadExecutionWidth`.
- This is the brute-force MVP (O(N^2)). Swap in Barnes–Hut later if desired.
- For profiling, use **Xcode Instruments → Metal System Trace**.

## Visualize particles (MetalKit window)
```bash
./NBodyApp
```
- Shows white point sprites on a dark background.
- Positions are in clip-space ([-1,1]) for simplicity.
- Simulation still runs on the GPU; rendering is a separate pass.


## Optimisation
- Uses a **tiled all-pairs** kernel with `threadgroup` memory and **Private** buffers for better bandwidth.
## Controls

- **Space**: pause or resume the simulation. It starts paused.
- **R**: restart the simulation from its initial state (paused).
- **Control-Command-F**: toggle full screen.
- **1**: start a slow automatic camera movement; manual camera input stops it.
- Left-drag to rotate, right-drag to pan, scroll to zoom, and double-click or press **C** to reset the camera.
## Startup setup

The viewer opens with a setup card. Choose a particle count from 100 to 100,000 (30,000 by default); music-enabled variations also let you select an audio track before launch. Particle size is adjustable from 0.5× to 3× (default 1×); you can change the track later from the File menu.
