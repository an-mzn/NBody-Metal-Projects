# Sphere Choreography — variation 9

Run `./run 9` from the repository root and choose an audio track. The viewer
starts with 30,000 particles filling a sphere of radius 1.35. Evenly spaced
longitude rings and solid-body initial rotation make the starting state
rotationally symmetric around its spin axis, without random velocity noise.

The sphere then evolves through the project's 3D N-body gravity simulation.
The music analysis drives the same bounded depth bends, arm twists, and attack
ripples used by variation 8. Gravity and music cues affect particle motion;
they do not impose a single rigid transform on the cloud. The tiled force pass
samples evenly around every starting ring to retain rotational symmetry in its
approximate force calculation. Finite particle and source sampling means this
is discrete rotational symmetry, not a perfectly continuous sphere.

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
