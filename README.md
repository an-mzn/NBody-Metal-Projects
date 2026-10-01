# N-body simulations with Apple Metal

A set of 2D N-body simulation experiments written in C++, Objective-C++, and Metal Shading Language. The project explores moving an all-pairs gravitational simulation onto Apple GPUs, measuring its frame cost, and making the particle motion visible in a native macOS window.

I built these experiments to understand how GPU compute, memory movement, and rendering fit together in a real-time simulation. The repository preserves several implementation stages and particle scenarios.

## What the project demonstrates

- Each GPU thread calculates the acceleration for one particle by visiting the other particles; a second compute pass updates velocity and position.
- The baseline force calculation is all-pairs, so its work grows quadratically with particle count: O(N²).
- Later variants add a tiled kernel that stages particle positions and masses in Metal threadgroup memory to reuse data during force calculations. This changes memory access patterns, not the all-pairs complexity.
- MetalKit variants render the evolving positions as point sprites while the simulation runs on the GPU.
- Console variants warm up the GPU, time 300 simulation steps, and report average, median (p50), and p95 frame times and derived FPS.
- Different initial conditions explore a basic particle cloud, a two-arm spiral, and two rotating clusters approaching one another.

The code contains a benchmark harness, but the repository does not include a recorded benchmark report or a controlled comparison between kernels. Performance depends on the Mac and GPU used; no specific speedup is claimed here.

## Project variants

| Folder | Focus |
| --- | --- |
| [`NBody-Metal-MVP-fixed/`](NBody-Metal-MVP-fixed/) | Minimal console baseline with random initial positions and zero initial velocity. |
| [`NBody-Metal-MVP-with-Viewer/`](NBody-Metal-MVP-with-Viewer/) | Baseline force kernel plus a MetalKit point-particle viewer. |
| [`NBody-Metal-MVP-stable-viewer/`](NBody-Metal-MVP-stable-viewer/) | Viewer variation with orbit-like initial velocities. |
| [`NBody-Metal-MVP-optimized/`](NBody-Metal-MVP-optimized/) | Tiled force kernel and viewer, with orbit-like initialization. |
| [`NBody-Metal-Galaxy-Arms/`](NBody-Metal-Galaxy-Arms/) | Tiled simulation initialized as a two-arm spiral. |
| [`NBody-Metal-Two-Cluster-Merger/`](NBody-Metal-Two-Cluster-Merger/) | Tiled simulation initialized as two counter-rotating clusters. |

Each folder is a standalone experiment with its own build script and source copies. Some implementation code is duplicated across variants.

## Build and run

Requirements: macOS, Xcode Command Line Tools with the Metal compiler, and an Apple GPU that supports Metal. The windowed variants also require the macOS Cocoa and MetalKit frameworks. These build scripts use `xcrun` and `clang++` directly; there is no Xcode project or cross-platform build.

For example, to build the galaxy-arms console and viewer:

```bash
cd NBody-Metal-Galaxy-Arms
./build.sh
./NBody 50000       # console benchmark; particle count is optional
./NBodyApp           # interactive point-particle viewer
```

The other folders that include an `App/` directory follow the same build and launch pattern. `NBody-Metal-MVP-fixed` builds the console program only. Run each script from its project folder; generated Metal libraries and executables are local build outputs.

## Implementation outline

- `Source/Sim.cpp` creates deterministic starting positions, velocities, and masses.
- `Shaders/nbody.metal` contains the force and integration compute kernels. Tiled variants include both baseline and tiled force functions; the renderer selects the function used by that build.
- `Source/Renderer.mm` creates Metal buffers and compute pipelines, dispatches force and integration passes, and waits for completion for each measured step.
- `App/AppDelegate.mm` sets up a MetalKit window and draws the current positions using `Shaders/points.metal`.
- `main.mm` runs a warm-up and timed console benchmark.

## Scope and limitations

This is a 2D demonstrator using softened forces, simplified integration, and in some variants velocity damping. Its goal is to explore Metal compute, memory reuse, and visualization rather than provide a scientifically validated astrophysics solver. The all-pairs method grows quadratically with particle count, making profiling and algorithmic improvements natural next steps.
