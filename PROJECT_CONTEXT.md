# Project Context: N-body Metal experiments

## Purpose

I made this project to learn how a particle-based N-body simulation could run on the GPU using Apple's Metal stack, and to connect the compute work to a visible, real-time result. The repository grew into several small variants so I could explore different initial conditions, a basic versus tiled force kernel, and console benchmarking versus a MetalKit viewer.

The repository itself does not record a formal assignment brief, original project dates, or a specific performance target. This context describes the goals inferred from the implementations and avoids attributing a more specific motivation than the source supports.

## Outcome

The project produced six standalone macOS experiments. Together, they demonstrate:

1. **A working compute pipeline design.** C++ creates particle state; Objective-C++ owns Metal devices, buffers, pipelines, command encoders, and dispatch; Metal kernels calculate forces and integrate motion.
2. **A visible simulation path.** Several variants use MetalKit and a point-rendering shader to display the GPU-updated particle positions in a native window.
3. **A measurement path.** Console entry points warm up the simulation and time 300 steps, reporting average, p50, and p95 frame time plus calculated FPS. The code makes it possible to collect performance data on a target Mac.
4. **Multiple initial-condition experiments.** The repository includes a random cloud, a two-arm spiral, and two counter-rotating clusters, making the same simulation pipeline useful for different visual scenarios.
5. **A memory-reuse experiment.** The later tiled force kernel cooperatively loads particle data into threadgroup memory. It aims to reduce repeated global-memory traffic while retaining the all-pairs calculation.

There are no benchmark result files or documented controlled runs in the repository. Therefore, the outcome is the implemented benchmark harness and GPU variants, rather than a substantiated numerical speedup or a verified particle count/FPS result.

## What I learned

The implementation work illustrates several useful lessons:

- GPU computation requires explicit coordination among CPU-side buffer setup, shader function names, pipeline states, threadgroup sizing, and command submission.
- Data reuse matters for GPU performance. Tiling can reduce global-memory traffic, but it does not remove the O(N²) pairwise force work; further scaling would need a different algorithm and measured evidence.
- A compute result is easier to inspect when it has a visual output. The MetalKit viewer turns evolving arrays into a particle display and keeps simulation and rendering as distinct GPU stages.
- Benchmark design affects what a timing means. The console path warms up and reports distribution statistics, but waits for each command buffer and does not include a controlled baseline-versus-tiled comparison or hardware metadata. The displayed values should be treated as machine-specific measurements, not universal results.
- Keeping experiments as separate folders is convenient for preserving iterations, but duplicated files and copied README text make it harder to see which build is the current reference. A next step would be a shared core with clearly named configurations and reproducible benchmark notes.

These are takeaways supported by the code structure and available harness. The repository does not include a separate retrospective or measured comparison.

## Variant map

| Variant | Starting state | Force kernel / output |
| --- | --- | --- |
| `NBody-Metal-MVP-fixed` | Random positions, zero velocity | Baseline all-pairs; console benchmark |
| `NBody-Metal-MVP-with-Viewer` | Random positions, zero velocity | Baseline all-pairs; console benchmark and point viewer |
| `NBody-Metal-MVP-stable-viewer` | Random positions with tangential velocities | Baseline all-pairs; console benchmark and point viewer |
| `NBody-Metal-MVP-optimized` | Random positions with tangential velocities | Tiled all-pairs; console benchmark and point viewer |
| `NBody-Metal-Galaxy-Arms` | Two-arm spiral with tangential velocities | Tiled all-pairs; console benchmark and point viewer |
| `NBody-Metal-Two-Cluster-Merger` | Two counter-rotating clusters | Tiled all-pairs; console benchmark and point viewer |

The names capture the experiments' intent, but there is no shared configuration system. Each folder contains its own copy of the implementation.

## Technical notes

- The simulation is two-dimensional and uses one GPU thread per particle to accumulate interactions with all particles.
- The integration pass updates velocity from acceleration and then advances position. Some later variants apply a small velocity damping factor.
- The force kernel uses softening to keep close interactions finite. This is a numerical stabilizer for this toy simulation, not a full physical model.
- The tiled kernel stages position and mass data in threadgroup memory for reuse by threads in a group. It remains an all-pairs algorithm.
- Shared Metal buffers are used for the simulation state. In the tiled variants, initial data is copied into the simulation buffers with a Metal blit command.
- The viewer draws points from the simulation position buffer. It is a simple visualizer, not a polished product interface.

## Repository state and limitations

The repository history begins with a preservation commit, so it does not capture the original development sequence. The six folders are standalone copies and have inconsistent feature sets. Several existing folder-level README files still describe a generic console project, include paths and sample output that do not match their folder, or claim implementation details not visible in the corresponding code. The new top-level README is the intended entry point; folder-level documentation can be corrected as a separate cleanup.

The code does not include automated tests, CI, saved benchmark reports, or a comparison against a CPU/reference implementation. Results and stability have not been independently validated in this repository. The all-pairs algorithm is intended for exploration at modest scale and will become increasingly expensive as particle count grows.

## Possible next steps

- Select one canonical implementation and explain the other variants as snapshots or configurations.
- Correct each folder README and add screenshots or short clips from a real run.
- Run repeatable baseline and tiled measurements on named Apple hardware, publish the settings and results, and profile with Instruments.
- Add correctness checks against a small CPU reference case and track numerical stability over time.
- Explore a tree-based or other approximation method if the goal shifts from GPU kernel experimentation to much larger particle counts.
