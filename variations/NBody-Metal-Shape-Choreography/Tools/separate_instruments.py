"""Separate locally with Demucs; stdout is only the completed stem directory."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

SOURCES = ('vocals', 'drums', 'bass', 'guitar', 'piano', 'other')
MODEL = 'htdemucs_6s'


def separate(track):
    digest = hashlib.sha256()
    digest.update(b'nbody-demucs-4.0.1-6s-full-track-v1')
    with track.open('rb') as audio:
        for block in iter(lambda: audio.read(1024 * 1024), b''):
            digest.update(block)
    cache = Path.home() / 'Library/Caches/NBody/Instruments' / digest.hexdigest()
    if (cache / 'complete.json').exists() and all((cache / (s + '.wav')).is_file() for s in SOURCES):
        return cache
    cache.mkdir(parents=True, exist_ok=True)
    # macOS decodes the same formats as the viewer, without requiring ffmpeg.
    with tempfile.TemporaryDirectory(prefix='nbody-instruments-') as temporary:
        decoded = Path(temporary) / 'track.wav'
        subprocess.run(['/usr/bin/afconvert', str(track), str(decoded), '-f', 'WAVE', '-d', 'LEI16@44100', '-c', '2'], check=True, stdout=sys.stderr)
        subprocess.run([sys.executable, '-m', 'demucs', '-n', MODEL, '-d', 'cpu', '--shifts', '0', '--float32', '--clip-mode', 'clamp', '-o', temporary, str(decoded)], check=True, stdout=sys.stderr)
        output = Path(temporary) / MODEL / 'track'
        for source in SOURCES:
            (output / (source + '.wav')).replace(cache / (source + '.wav'))
    marker = cache / 'complete.tmp'
    marker.write_text(json.dumps({'model': MODEL, 'sources': SOURCES, 'scope': 'full-track'}))
    marker.replace(cache / 'complete.json')
    return cache


if __name__ == '__main__':
    try:
        print(separate(Path(sys.argv[1]).resolve()), flush=True)
    except Exception as error:
        print('Instrument separation failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
