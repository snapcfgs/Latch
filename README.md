# Latch

Competitive arena FPS (Roblox) made by Sven.  
Fast 1v1 / 2v2, first to 5 rounds, shared loadout + Operator abilities. Built as a **Rojo + Luau** MVP with seamless **PC + mobile** controls. Inspired by arena FPS games such as Rivals — original operators, weapons, and IP only.

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
4. Play (F5) — the server builds the mirrored arena, remotes, and bots on start.

Project file: `default.project.json` maps `src/` → `ReplicatedStorage`, `ServerScriptService`, `StarterPlayer`, `StarterGui`.

## How to play (PC)

1. Pick an Operator on the lobby panel.
2. **Queue 1v1** or **Queue 2v2**.
3. Controls:
   - **Mouse1** fire / melee / throw (depends on equipped)
   - **1–4** weapon slots (AR, Pistol, Knife, Frag)
   - **E** cycle weapon · **R** reload · **Q** ability
   - **Shift** sprint · **C / Ctrl** crouch · crouch while sprinting = **slide**
   - **Space** jump

### Solo Studio Play (Phase 0 bots)

Solo Play is a **real first-to-5 match vs AI**, not a practice sandbox:

| Mode | Fill rule |
|------|-----------|
| **1v1** | After **3s** without a second human, a bot opponent is added and the match starts |
| **2v2** | After **4s**, remaining slots are filled with bots |

- Rounds end when one team has **0 alive** (humans + bots). There is no “empty team B” practice skip.
- Lobby keeps **6–12** ambient bots wandering between spawn pads / waypoints.
- If a human joins mid-fill or early match, they **replace the lowest-difficulty** stand-in on a team; HUD prints a stand-in replaced announcement.
- Bot names look like `Volt#4821`. Difficulties: **Recruit / Standard / Sweat** (`Config/Bots.lua`).

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
- **BotService** drives AI stand-ins through the same `WeaponService:ServerFire` / `AbilityService:ServerUse` paths as players (`ActorUtil` unifies Player | BotRecord)
- Hitscan guns use server raycasts; Splice panels pierce for allies (see comments in `AbilityService`)
- VFX: Parts / Beams / Highlights only — budget helpers in `Util/VFX.lua`
- Arena waypoints: `ArenaBuilder` places an invisible grid for bot pathing

## Known MVP gaps

- Bot AI is competent but not tournament-level (no grenade throws / advanced peeks yet)
- Splice blocks **movement** for everyone; only **bullets** are one-way for allies
- Anchor explosive resistance is an attribute stub (no knockback system yet)
- No dedicated shotgun / 4v4 / ranked
- First-person zoom lock is a simple camera distance clamp
- Lobby bot “emotes” are Billboard stubs

## License / assets

Placeholder Parts only. No copyrighted third-party assets or trademarks beyond a single “inspired by” note for arena FPS.
