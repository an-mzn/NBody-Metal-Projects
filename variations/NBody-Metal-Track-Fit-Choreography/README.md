# Track-Fit Choreography — variation 11

Run `./run 11` from the repository root. This builds on Variation 10 while
preserving its music import, camera, colors, recording, and startup controls.

Particles start in four thick orbital bands with tetrahedrally spaced spin
axes. Particles in each band circulate together; the combined cloud extends
across XYZ instead of sharing one plane. A small inclination spread gives
each band thickness. Initial speed scales with radius and particle count to
approximately support the cloud against gravity. These are initial conditions:
the existing 3D gravitational force evolves every particle freely afterward.
Initial central orbital speeds receive up to a 10% boost, tapering to the
original speed at the initial cloud edge. Velocity drag remains disabled to
preserve orbital support. Two softened central gravitational potentials add an
inward pull to every simulated particle: a 12% central mass over a 0.65-unit core
and an 18% diffuse mass over a 2-unit halo. The broader halo maintains attraction
outside the core. Both stay finite at the origin, decay outward without a cutoff,
and follow the gravity control and music scaling.

Music follows the strongest separated part in each passage, using a shared
energy reference across vocals, drums, bass, guitar, piano, and other instruments.
The lead receives the strongest movement, while quieter parts recede. Priorities
change continuously through centered smoothing of the prepared track to avoid
sudden jumps without delaying musical peaks.
Each time a track is loaded, its six parts receive shuffled continuous flows:
circular sweeps, vertical rolls, depth orbits, diagonal spirals, outer-layer
swirls, and corkscrews. Orientation and pace also vary per load. The prepared
audio strengths control travel speed: stronger sounds carry particles onward,
quieter sounds slow them down, and silence holds their accumulated progress.
Falling volume does not retract an offset or reverse a gesture. Rotations preserve
the cloud's radius rather than repeatedly stretching and relaxing it. Choices
stay fixed during playback and restart; reloading gives a new choreography.
In layered passages, combined instrument strengths remain limited to 120% of
the strongest unscaled response to keep competing parts restrained.
Sax, brass, strings, and synths can share the “other” stem: this is prominence
estimation across six groups, not individual instrument recognition or a
guarantee of what a listener perceives as the melody.
A passage lead is selected from 1.3 seconds of surrounding stem levels, with
hysteresis to resist brief background spikes. Its continuous loudness envelope
controls the outward speed of a stable, scattered sixth of the particles. Slow attacks and
sustained notes remain expressive; no sharp peak, rise threshold, or cooldown
is required. A track-relative range suppresses quiet tails, and centered 100 ms
smoothing preserves slow phrase contours while crossfading between lead groups.
A stable 40% of particles remain in the simulated central cloud and do not
receive outward emission offsets or emission fades. They still orbit and respond
to gravity and musical circulation. This keeps the gravitational core visible
throughout playback; remaining particles carry the outward musical movement.
Outward travel is accumulated, so fading notes slow particles without retracting
them. Particles fade out before resetting their travel and reappear afterward;
randomized travel lengths stagger these invisible resets. Each particle group
also follows one subtle group rotation. A stronger common orbit, driven by the
integrated lead expression, carries all particles around the centre. This restores
a visible central response to the main phrase, including slow and sustained riffs,
while group-specific rotations run at 28% of their previous speed.
This estimates the lead from sustained loudness, which can still differ from
the melody a listener picks out in a dense mix.
Separate beat and treble displacement pulses are disabled to avoid a secondary
back-and-forth movement.
Music also changes simulation gravity using the prioritized drum and bass signals.
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

Kelvin colours use the final 3D distance after outward travel. The scale covers
the initial radius plus the longest travel path (4.95 units): the centre starts
at 1,000 K, the normal outer extent is about 12,000 K, and more distant particles
continue gradually toward 40,000 K. This avoids the old 2.7-unit blue cutoff and
keeps colours tied to a stable distance scale rather than changing each frame.
These are illustrative colour temperatures, not simulated physical heat.

The deformation has no preferred flat plane. The sampled 3D gravity calculation
uses up to 3,000 sources spread across all four interleaved groups.
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

Variation 11 uses local Demucs `htdemucs_6s` separation before playback.
Install its isolated Python runtime once from the repository root:

```sh
./variations/NBody-Metal-Track-Fit-Choreography/Tools/setup_instruments.sh
./run 11
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
