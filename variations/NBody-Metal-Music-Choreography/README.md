# Music Choreography and Depth — variation 8

Run `./run 8` from the repository root, then choose an audio track. File → Open Audio… changes the track. Control+C or closing the window quits and stops playback.

The track is analyzed before playback with Apple's Accelerate FFT. Overlapping centered windows produce a spectral frame roughly every 11 ms at 44.1/48 kHz. Stereo channels are analyzed independently to prevent phase cancellation. The map includes:

- 32 logarithmic frequency bands, bass/midrange/treble energy, and spectral brightness.
- Adaptive spectral-flux onsets that emphasize new sounds over continuous texture.
- 12 pitch classes and two-second spectral context on each side of transitions.
- A global tempo estimate with confidence, reinforcing actual attacks near its estimated beat.
- Track-relative normalization, spectral noise rejection, and accent decay envelopes that preserve brief hits between display frames.

Bass drives depth movement, midrange drives arm twists, onsets and beat-aligned attacks drive ripples, and passage contrasts add slower twists and vertical motion. These are signal-based estimates: pitch classes are not chord recognition, transitions are not labeled choruses, and the global tempo can be uncertain for rubato or changing tempos. Motion follows the audio sample clock with latency compensation and a small lead.

Particles start in two warped spiral arms with substantial depth, forming a 3D cloud rather than a thin disk. Positions, velocities, and gravity operate in X, Y, and Z; depth is no longer a synthetic per-particle layer. Gravity is stronger and velocity drag is lower so particles carry farther through their motion. Perspective projection, depth-dependent size and brightness, and a user-controlled orbit camera reveal the layered spiral. Particle color follows an approximate blackbody Kelvin scale by distance from the 3D centre, from red in the core to blue at the outskirts. Musical displacements are bounded and do not add explosive velocity.

The viewer retains 30,000 particles. Tiled gravity uses up to 2,048 evenly distributed, mass-weighted source particles per step, reducing the 30,000-particle interaction count from 900 million to roughly 61 million. This is an approximation of full all-pairs gravity. Simulation timing follows elapsed audio time with a bounded integration step and a limit on queued GPU work. Attack-driven tangential ripples fade toward the centre so they do not push the central particles outward into a hollow ring. Performance depends on the GPU. The original music variation remains version 7.

Drag with the left mouse button to orbit, hold a two-finger trackpad click and drag to pan the scene in the camera plane, scroll to move closer or farther away, and double-click or press C to reset the camera. The camera stays where you leave it. Perspective projection and depth testing provide parallax and particle occlusion.

Build locally with `./build.sh`.

Musical motion uses coordinated twists and depth bends rather than independent fast particle oscillations. Particle sprites have soft circular edges with alpha blending to reduce pixel shimmer. Velocity damping is based on integration time rather than frame count.
## Controls

- **Space**: pause or resume the simulation. It starts paused.
- **R**: restart the simulation from its initial state (paused).
- **Option-R**: choose an `.mp4` destination to begin recording the current window as it is. It does not restart playback, simulation, or camera motion. Press **Option-R** again to stop and save a partial recording; capture also stops when the track ends.
- **Control-Command-F**: toggle full screen.
- **C**: reset the camera.
- **1**: start a smooth, repeating 36-second aerial camera tour. Mouse drag or scroll returns to manual camera control.

Audio playback starts or resumes with the simulation.
## Startup setup

The viewer opens with a setup card. Choose a particle count from 100 to 100,000 (30,000 by default); music-enabled variations also let you select an audio track before launch. Particle size is adjustable from 0.5× to 3× (default 1×); you can change the track later from the File menu.
