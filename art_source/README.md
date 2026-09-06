# Blender source assets

These original models are editable in Blender 4.5 LTS. Runtime models are exported
to `assets/models/` as GLB files. `.gdignore` keeps the source scenes out of Godot's
import/export pipeline, so players and build machines do not need Blender.

- `pistol_viewmodel.blend`: graphite/coral pistol, padded gloves and sleeves.
- `living_room.blend`: rounded turquoise sofa and walnut coffee table, plus a
  studio camera and lights used only for the Blender preview.

Rebuild from the repository directory in PowerShell:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' --background --factory-startup --python tools/build_pistol.py
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' --background --factory-startup --python tools/build_living_room.py -- --no-preview
```

Rebuilding regenerates the source scenes and GLBs from the scripts, so preserve
manual Blender edits separately or incorporate them into the generator first.
Omit `-- --no-preview` to also render the furniture studio preview into `artifacts/`.
All models use metre units and export to Godot's Y-up, -Z-forward coordinates.

The pistol exports named `Slide`, `Muzzle`, `SightFront`, and `SightRear` nodes.
Its first-person render pass handles equip motion and slide recoil, and keeps the
hands visible near apartment walls. The sofa/table replace visible meshes only;
the original Godot collision shapes remain in use on both maps.
