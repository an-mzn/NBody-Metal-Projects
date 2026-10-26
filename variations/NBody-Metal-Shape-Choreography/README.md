# Shape Choreography — variation 12

Run `./run 12` from the repository root, then choose **Starting shape** in the
startup dialog. Variation 12 builds on Variation 11's music analysis, preloaded
tracks, lead-driven flow, gravity, Kelvin colours, recording, and controls.

| Starting shape | Geometry and initial flow |
| --- | --- |
| Double Torus (default) | Two thick, interlocked rings in perpendicular planes, with opposing circulation. |
| Trefoil Knot | A continuous tube woven into a three-loop knot, with flow along the knot. |
| Spiral Vortex | Four thick spiral arms rising through depth, with flow along each arm. |
| Folded Ribbon | A broad, thin ribbon folded vertically and given a half twist, with lengthwise flow. |
| Two Clusters | Two separated spherical clouds with internal spin and a shared orbit around their midpoint. |

Press **S** to reopen setup and change the shape. The current choice is retained
when reopening setup; **R** restarts that shape. Loading a new track also retains
the shape. The same seed produces the same initial particles. The opening camera
is tilted and pulled back to show the shapes' depth and crossings.

These are starting geometries and velocities, not rigid constraints. Gravity and
music can bend, merge, or disperse them; their topology is not preserved forever.
Two softened central potentials bind every particle: a 12% central mass over a
0.65-unit core and an 18% diffuse mass over a 2-unit halo. Both follow the gravity
control and music scaling. Velocity drag remains disabled.

Visible particle positions now come directly from the gravity simulation.
There are no music-driven drawing offsets, prescribed rotations, emission fades,
particle recycling, or reserved core groups. Every particle keeps its identity
and evolves through acceleration, velocity, and position integration. Particles
can still move out of the camera view or be hidden behind nearer particles.

Music selects the sustained lead across vocals, drums, bass, guitar, piano, and
other instruments, using a shared energy scale and a 1.3-second passage context.
Centered smoothing supports slow attacks and sustained riffs. The lead envelope
strengthens the actual core and halo attraction from 1× to 1.9×; total energy and
bass add a smaller modulation to overall gravity. Silence retains baseline
gravity and particles coast according to their existing velocities. The user's
gravity slider scales all these forces. Music changes forces, so the resulting
motion has physical inertia rather than instant graphical synchronization.
This remains an artistic gravity simulation with changing external potentials,
not an isolated system with conserved energy. Sax and other instruments can
share the “other” stem, so the chosen lead is still an approximation.

Analysis uses the v3 cache; existing separated audio is reused when refreshing
older analysis, so prepared tracks do not require another Demucs separation.
Playback samples the prepared signals at the audio clock's current audible time,
using the render timestamp, elapsed host time, and reported output latency. There
is no fixed lookahead offset or causal smoothing delay. Centered smoothing spreads
transitions slightly before and after an event while keeping isolated peaks aligned.
Playback completion waits for audio to be played back rather than only consumed.
Synthetic 44.1/48 kHz sounds at 1, 5, and 9 seconds were located within 4 ms of
their source timestamps; all 14 prepared signal envelopes retained their peak
positions. This verifies analysis and smoothing, not physical speaker-to-screen
synchronization, which also depends on display scheduling and device latency.

Kelvin colours use each simulated particle’s actual 3D distance from the centre.
The extended 5.6-unit reference scale accommodates particles scattered by gravity: the centre starts
at 1,000 K, the normal outer extent is about 12,000 K, and more distant particles
continue gradually toward 40,000 K. This avoids the old 2.7-unit blue cutoff and
keeps colours tied to a stable distance scale rather than changing each frame.
These are illustrative colour temperatures, not simulated physical heat.

The sampled 3D gravity calculation uses up to 3,000 stratified sources, with
jitter within each stratum to avoid selecting just one ring or cluster.
This is a visual simulation, not a guaranteed equilibrium: music, custom
gravity settings, integration error, and sampled forces can still change its
shape or eject particles over time.

Build locally with `./build.sh`.

## Controls

- **Space**: pause or resume the simulation and audio. It starts paused.
- **R**: restart the selected starting shape (paused).
- **Option-R**: start or stop an `.mp4` recording with audio.
- **Control-Command-F**: toggle full screen.
- **C**: reset the camera.
- **1**: start the repeating aerial camera tour; manual camera input stops it.
- Left-drag to orbit, two-finger/right-drag to pan, and scroll to zoom.
## Startup setup

Simulation speed defaults to **1.6×**, 60% faster than the previous default.
Use the setup speed slider (0.25×–2×) to adjust it; audio playback speed is unchanged.

The viewer opens with a setup card. Choose a particle count from 100 to 100,000 (30,000 by default); music-enabled variations also let you select an audio track before launch. Particle size is adjustable from 0.5× to 3× (default 1×); you can change the track later from the File menu.

## Instrument analysis

Variation 12 uses local Demucs `htdemucs_6s` separation before playback.
Install its isolated Python runtime once from the repository root:

```sh
./variations/NBody-Metal-Shape-Choreography/Tools/setup_instruments.sh
./run 12
```

Select a track as usual. Variation 11 separates and analyses the full track before playback. Preparation runs in the background; playback stays
paused until it finishes. A centred loading panel shows an animated activity
bar during preparation; when it disappears, press Space to play. The window
title also says “Ready — press Space”. The first track downloads the model weights. CPU separation processes
the complete song. First-time preparation can take several minutes per song;
subsequent opens reuse the cached results. Audio is processed locally, and the original full track is played and recorded unchanged.

The six estimated parts control bounded visual deformations:

| Part | Response |
| --- | --- |
| Vocals | Flowing rotation about X |
| Drums | Radial pulses from detected hits |
| Bass | Rotation about Z |
| Guitar | Rotation about Y |
| Piano | Vertical waves from note attacks |
| Other accompaniment | Gentle depth waves and Y rotation |

The existing whole-track energy still modulates gravity; frequency bands,
beat and passage changes add smaller supporting motions. Each stem is analysed
and scaled independently, with quiet stems attenuated relative to the mix
to reduce responses to faint leakage. These are expressive controls rather than a
comparison of the instruments' absolute volumes. Separation is approximate:
sounds can leak between parts, especially piano. It does not distinguish every
instrument or individual performers.

Completed stems and the finished per-frame analysis are cached under
`~/Library/Caches/NBody/Instruments`, keyed by the complete audio contents, model, and full-track processing
configuration. Reopening a prepared track reuses both, skipping separation and
analysis. Reloads reuse them. Delete that folder to reclaim disk space or force separation again. The Python environment
lives at `~/Library/Application Support/NBody/instruments`. Setup uses Apple's
Python 3.9 with pinned Demucs 4.0.1 / PyTorch 2.2.2 dependencies; no ffmpeg is
needed because macOS decodes the input. Separation errors show a dialog with
the diagnostic log location and do not silently fall back to frequency bands.

Model details and known limitations: https://github.com/facebookresearch/demucs

## Adding preloaded tracks

Put local audio files in the repository root `tracks/` folder. The folder is
ignored by Git so songs are not added to commits. Add each desired filename to
`trackNames` in the music variations’ `Source/LaunchPrompt.hpp` files to show it
in their setup dropdown. Supported file types include MP3, M4A, WAV, AIFF, CAF,
AAC, and FLAC. Choose a track in the dropdown or use “Choose your own…” for a
file elsewhere. Each full track is separated locally on first use and cached
under `~/Library/Caches/NBody/Instruments`; later loads reuse its stems and
analysis.
