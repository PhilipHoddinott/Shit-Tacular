# Shit-Tacular

![Shit-Tacular cartoon cover](assets/github/social-preview.jpg)

A first-person, last-player-standing game set inside an apartment. Battle three AI roommates in single-player, or host a direct-IP multiplayer match for 2–8 people.

**[Play Shit-Tacular on GitHub Pages](https://philiphoddinott.github.io/Shit-Tacular/)** · **[View the source on GitHub](https://github.com/PhilipHoddinott/Shit-Tacular)**

> The browser version currently supports single-player. Multiplayer uses ENet over UDP and requires the native desktop version of the game.

## How to play

Open `project.godot` in Godot 4.7.2 and press **F6** or **F5**. If you have the prepared Windows playtest folder, you can instead double-click `PLAY_GAME.bat`.

You can also launch the project from PowerShell:

```powershell
.\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe --path .
```

Choose 1, 2, 3, or 5 lives per player from the main menu. Every combatant begins with 100 health. Your death returns you directly to the main menu, even if you have lives remaining; choose Single Player to start a fresh game. Bots respawn while lives remain. In multiplayer, death leaves the match; if the host dies, the hosted session closes. The last player standing wins.

Players and bots regenerate **2 health per second after 5 seconds without taking damage**, up to 100 health. Taking another hit restarts the delay. Healing stops on death or when the round ends; multiplayer healing is controlled by the host.

Hold right mouse to zoom while aiming; release it to return to normal view. Rifle zoom is stronger than pistol, shotgun, or bazooka zoom, and mouse sensitivity scales with magnification. Original synthesized spatial effects cover gunfire, impacts, explosions, toilet flushes, weapon rewards, and the rainbow power-up. Sounds are shared with multiplayer peers and require no downloads.

Each unique toilet flush awards a random weapon: pistol, shotgun, rifle, or bazooka. Flush all three to trigger **TRIPLE-SHIT!** and lock in the glowing rainbow rifle, which cycles colors and deals 40 damage per bullet for the rest of the round, including after respawning.

## Controls

| Control | Action |
| --- | --- |
| `WASD` | Move |
| `Shift` | Sprint |
| `Space` | Jump |
| Left mouse | Fire the equipped weapon |
| Hold right mouse | Aim / zoom (stronger magnification for rifles) |
| `E` | Flush a toilet, sit in a dining chair, or stand up |
| `Escape` | Release or recapture the mouse |
| `R` | Restart after the round ends |

## Multiplayer playtest

All players must use the same native version of the game. One player hosts the match and shares the address shown in the lobby with everyone else.

### Host a match

1. Open **Multiplayer** and enter your player name.
2. Choose the total number of human players, from 2–8.
3. For an internet match, leave **Automatically open the UDP port** enabled.
4. Select **Create Lobby**.
5. Use **Copy LAN** for players on the same network, or **Copy Internet** for remote players, then send the copied `IP:port` address to them.
6. When everyone has joined, select **Start Match**.

### Join a match

1. Open **Multiplayer** and enter your player name.
2. Paste the host's complete `IP:port` address into **Host IP**.
3. Select **Join** and wait in the lobby for the host to start the match.

### Connection notes

- Multiplayer uses ENet over UDP. The default port is `7000`.
- **Copy LAN** is for computers on the same Wi-Fi or wired network.
- **Copy Internet** becomes available after the host's router accepts the automatic UPnP port mapping.
- If automatic setup fails, allow the game through the host computer's firewall and manually forward the selected **UDP** port to that computer.
- Some double-NAT and carrier-grade NAT connections cannot accept direct connections. Those networks will need a VPN-style workaround or the planned relay service.

The host is authoritative: clients send their controls to the host, and the host resolves movement, shots, damage, lives, respawns, and the winner. Game state is synchronized back to clients 20 times per second.

## Playtest logs

The Windows build keeps the current session log and up to ten older logs. They include Godot and system information along with important game, lobby, connection, UPnP, death, respawn, and round events.

After a crash or connection problem:

1. Restart the game.
2. Select **Open Crash Logs** on the main menu.
3. Send the newest `.log` file to the developer with a short description of what happened.

If the game fails before reaching the menu, run `PLAY_GAME_DIAGNOSTIC.bat` and send the `startup-diagnostic.log` file from the folder it opens. On Windows, the normal log location is `%APPDATA%\Godot\app_userdata\Shit-Tacular\logs`.

Logs may contain player names and network addresses, so review them before sharing outside the playtest group. Native engine crashes may have a limited backtrace without matching debug symbols, but script errors and the gameplay or network events leading up to the failure should still be recorded.

## Project notes

The apartment uses a doubled horizontal footprint for wider rooms and less crowded firefights. The supplied floor-plan PNG is the default floor. It includes room-specific wall colors, wall panels and bathroom wall tiles, baseboards, ceiling trim, doorway casings, ceiling fixtures, fabric upholstery, detailed cabinets, furniture and small decor, fake window light, a wall-mounted television, four sittable dining chairs, and a very judgmental bathroom mirror. Furniture and wall surface textures are generated deterministically in Godot, with mipmaps, and require no asset downloads. Use `--qa-floorplan-capture` for the overhead layout check.

The GitHub-ready 1280×640 social preview is stored at `assets/github/social-preview.jpg`, with its full-resolution generated source beside it.

## Roadmap

1. Playtest and tune the host-authoritative ENet multiplayer prototype.
2. Improve art, sound, bot navigation, and round presentation.
3. Add room codes, NAT traversal/relay support, and clearer connection diagnostics.
4. Package Windows builds for wider playtesting.
