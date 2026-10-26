# Volume Choreography — variation 10

Run `./run 10` from the repository root. This expands variation 9 while
preserving its music import, camera, colors, recording, and startup controls.

Particles start in four thick orbital bands with tetrahedrally spaced spin
axes. Particles in each band circulate together; the combined cloud extends
across XYZ instead of sharing one plane. A small inclination spread gives
each band thickness. Initial speed scales with radius and particle count to
approximately support the cloud against gravity. These are initial conditions:
the existing 3D gravitational force evolves every particle freely afterward.
Velocity drag remains disabled to preserve orbital support.

Music applies radius-dependent rotations around all three axes and bounded
radial pulses. The deformation has no preferred flat plane. The sampled 3D
gravity calculation uses up to 3,000 sources spread across all four interleaved groups.
This is a visual simulation, not a guaranteed equilibrium: music, custom
gravity settings, integration error, and sampled forces can still change its
shape or eject particles over time.

Build locally with `./build.sh`.

## Controls

- **Space**: pause or resume the simulation and audio. It starts paused.
- **R**: restart from the spherical initial state (paused).
- **Option-R**: start or stop an `.mp4` recording with audio.
- **Control-Command-F**: toggle full screen.
- **C**: reset the camera.
- **1**: start the repeating aerial camera tour; manual camera input stops it.
- Left-drag to orbit, two-finger/right-drag to pan, and scroll to zoom.
## Startup setup

The viewer opens with a setup card. Choose a particle count from 100 to 100,000 (30,000 by default); music-enabled variations also let you select an audio track before launch. Particle size is adjustable from 0.5× to 3× (default 1×); you can change the track later from the File menu.

## Instrument analysis

Variation 10 now uses local Demucs `htdemucs_6s` separation before playback.
Install its isolated Python runtime once from the repository root:

```sh
./variations/NBody-Metal-Volume-Choreography/Tools/setup_instruments.sh
./run 10
```

Select a track as usual. Variation 10 separates and analyses the full track before playback. Preparation runs in the background; playback stays
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
