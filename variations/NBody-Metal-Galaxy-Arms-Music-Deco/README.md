# Galaxy Arms Music Deco

Music-driven gravity changes with 30,000 particles and full tiled all-pairs gravity. Short detected musical sections alternate 3.5× / 0.35× gravity; major sections alternate 7× / 0.08×. Analysis updates cues during playback, with a 0.55 second look-ahead. Motion follows the audio player clock. Particle color is fixed antique gold on black.

Launch with `./run 7` from the repository root. Use **File → Open Audio…** to change the track. Closing the viewer exits the app and stops audio.

Build from this folder with `./build.sh`.
## Controls

- **Space**: pause or resume the simulation. It starts paused.
- **R**: restart the simulation from its initial state (paused).
- **Control-Command-F**: toggle full screen.
- **1**: start a slow automatic camera movement; manual camera input stops it.
- Left-drag to rotate, right-drag to pan, scroll to zoom, and double-click or press **C** to reset the camera.

Audio playback starts or resumes with the simulation.
## Startup setup

The viewer opens with a setup card. Choose a particle count from 100 to 100,000 (30,000 by default); music-enabled variations also let you select an audio track before launch. Particle size is adjustable from 0.5× to 3× (default 1×); you can change the track later from the File menu.
