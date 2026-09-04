# Shit-Tacular

![Shit-Tacular cartoon cover](assets/github/social-preview.jpg)

A first-person last-player-standing game set inside an apartment. The prototype supports a single-player match against three AI roommates and direct-IP multiplayer for 2–8 humans.

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

Choose 1, 2, 3, or 5 lives per player from the main menu. Every combatant begins each life with 100 health and respawns at a random safe apartment location while lives remain. Flush all three toilets to trigger **TRIPLE-SHIT!**, recolor the pistol, and increase its damage to 72; the power-up stays active across respawns for that round.

## Multiplayer

All players need the same version of the game.

1. The host opens **Multiplayer**, enters a name, chooses the total player count, and leaves **Automatically open the UDP port** enabled when hosting over the internet.
2. The host selects **Create Lobby**. If the router accepts UPnP, the lobby displays a public address and enables **Copy Internet**. **Copy LAN** remains available for players on the same network.
3. Each other player opens **Multiplayer**, pastes that value into **Host IP**, enters a name, and selects **Join**. The port is read automatically from the pasted value.
4. When the lobby reaches the chosen player count, the host selects **Start Match**.

On the same Wi-Fi or wired network, the displayed private/LAN address should work directly. For play across the internet, the game asks a compatible UPnP router to forward the chosen port as **UDP**, displays the router's public IP, and removes the mapping when hosting ends. The default is UDP port `7000`.

UPnP may be disabled or unavailable on some routers. If automatic setup fails, manually forward the selected UDP port to the host computer and allow the game through the operating-system firewall. Double NAT and carrier-grade NAT may still require a relay or VPN-style solution even when the local router supports UPnP.

The host is authoritative: clients send controls to the host, while the host resolves movement, shots, damage, lives, respawns, and the winner. Position and gameplay state are synchronized back to clients 20 times per second.

Direct IP is intentionally the first multiplayer milestone because it needs no accounts or hosted service. A later room-code flow should use a small rendezvous/relay service so players do not need to expose an IP address or configure port forwarding.

## Playtest logs

The Windows build keeps the current session log plus up to ten older logs. Logs include Godot and system information along with important game, lobby, connection, UPnP, death, respawn, and round events.

After a crash or connection problem:

1. Restart the game.
2. Select **Open Crash Logs** on the main menu.
3. Send the newest `.log` file from the folder to the developer, together with a short description of what happened.

If the game fails before reaching the menu, run `PLAY_GAME_DIAGNOSTIC.bat` instead and send `startup-diagnostic.log` from the folder it displays. Logs may contain player names and network addresses, so review them before sharing outside the playtest group.

On Windows, the normal log location is `%APPDATA%\Godot\app_userdata\Shit-Tacular\logs`. A native engine crash may have a limited backtrace without matching debug symbols, but script errors and the surrounding gameplay/network events are still recorded.

The apartment includes room-specific wall colors, furniture and small decor, fake window light, a wall-mounted television, four sittable dining chairs, and a very judgmental bathroom mirror.

The GitHub-ready 1280x640 social preview is at `assets/github/social-preview.jpg`; the full-resolution generated source is stored beside it.

The supplied apartment plan is rendered directly onto the prototype floor so the 3D walls and hallway routes can be checked against the source drawing while the level is refined.

## Roadmap

1. Playtest and tune the host-authoritative ENet multiplayer prototype.
2. Improve art, sound, bot navigation, and round presentation.
3. Add room codes, NAT traversal/relay support, and clearer connection diagnostics.
4. Package Windows builds for wider playtesting.
