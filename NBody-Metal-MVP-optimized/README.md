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
