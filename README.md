# Shit-Tacular

![Shit-Tacular cartoon cover](assets/github/social-preview.jpg)

A first-person last-player-standing game set inside an apartment. The current prototype is a single-player graybox with three AI roommates.

## Play

Open `project.godot` in Godot 4.7.2 and press **F6/F5**, or run:

```powershell
.\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe --path .
```

On Windows, you can also double-click `PLAY_GAME.bat`.

Controls:

- `WASD`: move
- `Shift`: sprint
- `Space`: jump
- Left mouse: fire pistol (24 damage)
- `E`: flush a toilet, sit in a dining chair, or stand back up
- `Escape`: release/capture the mouse
- `R`: restart after the round ends

Every combatant begins with 100 health. Flush all three toilets to trigger **TRIPLE-SHIT!**, recolor the pistol, and increase its damage to 72.

The GitHub-ready 1280x640 social preview is at `assets/github/social-preview.jpg`; the full-resolution generated source is stored beside it.

The supplied apartment plan is rendered directly onto the prototype floor so the 3D walls and hallway routes can be checked against the source drawing while the level is refined.

## Roadmap

1. Validate the apartment layout and single-player combat loop.
2. Improve art, sound, bot navigation, and round presentation.
3. Add host-authoritative ENet multiplayer with direct IP joining.
4. Package Windows builds for playtesting.
