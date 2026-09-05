# Local soundtrack generation

ACE-Step lives in `ACE-Step-1.5/`, with dependencies in its `.venv` and downloaded
weights in `checkpoints/`. The folder is excluded from the game repository and
Godot asset imports.

From the game folder, run in PowerShell:

```powershell
& .\ACE-Step-1.5\.venv\Scripts\python.exe .\tools\generate_flush_funk.py
```

Use `--seed 112906` to audition another variation. The default seed is `112905`.
The script writes a WAV and generation metadata under
`artifacts/music/flush-funk/`. These are auditions; a requested tempo and duration
do not guarantee beat alignment or a seamless loop. Listen and edit before using
a track in the game.

The configuration uses ACE-Step v1.5 Turbo, one instrumental at a time, and no
language-model generation. The main model stays on the RTX 5060 while auxiliary
models use CPU offload. No server needs to remain running after generation.
