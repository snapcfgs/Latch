# Latch

Competitive arena FPS (Roblox) made by Sven.  
Fast 1v1 / 2v2, first to 5 rounds, shared loadout + Operator abilities. Built as a **Rojo + Luau** MVP with seamless **PC + mobile** controls.

## Requirements

- [Rojo](https://rojo.space/) 7.x (`aftman install` / `rojo --version`)
- Roblox Studio
- Optional: [Aftman](https://github.com/LPGhatguy/aftman) for tooling pins

## Open in Studio

```bash
cd game
rojo serve
```

In Roblox Studio:

1. Install the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/) if needed.
2. Open a new place (or empty baseplate).
3. Click **Connect** in the Rojo plugin (default `localhost:34872`).
4. Play (F5) — the server builds the mirrored arena and remotes on start.

Project file: `default.project.json` maps `src/` → `ReplicatedStorage`, `ServerScriptService`, `StarterPlayer`, `StarterGui`.

## How to play (PC)

1. Pick an Operator on the lobby panel.
2. **Queue 1v1** or **Queue 2v2** (solo Studio starts a practice lobby with one player).
3. Controls:
   - **Mouse1** fire / melee / throw (depends on equipped)
   - **1–4** weapon slots (AR, Pistol, Knife, Frag)
   - **E** cycle weapon · **R** reload · **Q** ability
   - **Shift** sprint · **C / Ctrl** crouch · crouch while sprinting = **slide**
   - **Space** jump

## How to playtest mobile

Same rules and netcode; only the input surface changes.

### Studio device emulator

1. In Studio: **Test** → **Device Emulator** (or the device dropdown in the test toolbar).
2. Pick a phone/tablet profile so `UserInputService.TouchEnabled` is true.
3. Play. On-screen buttons appear: **FIRE**, **JUMP**, **SLIDE**, **ABILITY**, **R**, **GUN**, **RUN**, plus a right-side look drag zone.
4. Touch chrome is hidden when keyboard is present and touch is not (desktop).

### Real phone

1. Publish the place (or use Team Create / Studio sync to a published experience).
2. Join from the Roblox mobile app.
3. Use the on-screen controls; look by dragging the upper-right look zone.

## Operators

| Operator | Active | Passive |
|----------|--------|---------|
| **Skid** | Friction dash + trail | Longer slide |
| **Anchor** | Cover plate (~4s) | Explosive knock resist (stub attribute) |
| **Splice** | One-way shoot-through panel (~5s) | Quieter crouch (attribute) |
| **Jolt** | Mark / Highlight reveal | Faster reload after melee hit |

Balance numbers live in `src/ReplicatedStorage/Config/`.

## Architecture

- Custom bootstrap (no Knit): `Bootstrap.server.lua` / `Bootstrap.client.lua`
- Server validates damage, fire rate, ability cooldowns, grenade throws
- Hitscan guns use server raycasts; Splice panels pierce for allies (see comments in `AbilityService`)
- VFX: Parts / Beams / Highlights only — budget helpers in `Util/VFX.lua`

## Known MVP gaps

- No AI bots — solo queue is practice (round won’t end vs empty team B)
- Splice blocks **movement** for everyone; only **bullets** are one-way for allies
- Anchor explosive resistance is an attribute stub (no knockback system yet)
- No dedicated shotgun / 4v4 / ranked
- First-person zoom lock is a simple camera distance clamp

## License / assets

Placeholder Parts only. No copyrighted Rivals assets or names beyond “inspired by” here.
