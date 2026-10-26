#!/bin/bash
set -euo pipefail
runtime="$HOME/Library/Application Support/NBody/instruments"
/usr/bin/python3 -m venv "$runtime"
"$runtime/bin/python3" -m pip install --upgrade pip
"$runtime/bin/python3" -m pip install 'numpy<2' 'torch==2.2.2' 'torchaudio==2.2.2' 'demucs==4.0.1' soundfile
"$runtime/bin/python3" -c 'import demucs, torch, torchaudio, soundfile'
echo 'Instrument separation is ready. The model downloads on first use.'
