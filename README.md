# Latch

Competitive arena FPS (Roblox) made by Sven.  
Multi-mode arena (1v1–4v4, FFA, TDM, Gun Cycle, Beginner), shared loadout + Operator abilities. Built as a **Rojo + Luau** MVP with seamless **PC + mobile** controls. Inspired by arena FPS games such as Rivals — original operators, weapons, and IP only.

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

1. Pick an Operator on the left lobby panel (loadout panel also available).
2. **Queue** from the right mode menu **or** walk onto a colored queue pad (ProximityPrompt / touch).
3. Controls:
   - **Mouse1** fire / melee / throw (depends on equipped)
   - **1–4** weapon slots (loadout primary/secondary/melee/utility) · **RMB** ADS
   - **E** cycle weapon · **R** reload · **Q** ability
   - **Shift** sprint · **C / Ctrl** crouch · crouch while sprinting = **slide**
   - **Space** jump

### Solo Studio Play (bots)

Solo Play is a **real match vs AI**, not a practice sandbox. Bot fill timers are per-mode (`Config/Modes.lua` → `FillSeconds` / `FillTarget`):

| Mode | Fill (approx) |
|------|----------------|
| **1v1** | 3s → fill to 2 |
| **2v2 / Beginner 2v2** | 4s → fill to 4 |
| **3v3** | 5s → fill to 6 |
| **4v4 / TDM** | 6s → fill toward team sizes / FillTarget |
| **FFA / Gun Cycle** | 5s → fill to **FillTarget 4** (max 8) |

- Round modes: rounds end when one team has **0 alive** (humans + bots). No empty-team practice skip.
- Lobby keeps **6–12** ambient bots wandering between **queue pads** / waypoints (visual queue join).
- Mid-match human join replaces the lowest-difficulty stand-in; HUD announces it.
- Bot names look like `Volt#4821`. Difficulties: **Recruit / Standard / Sweat** (`Config/Bots.lua`). Beginner mode forces **Recruit**.

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


## Phase 1 — Maps & map vote

Six original code-built arenas (Parts only, no `.rbxm`):

| Map | Size | Feel |
|-----|------|------|
| **Splityard** | Small | Twin warehouses, mid crate lane |
| **Voltage** | Small | Neon rooftops, thin bridges |
| **Hollow** | Medium | Indoor atrium + mezzanines (Splice-friendly) |
| **Dredge** | Medium | Dry dock / shipping — long AR lines + tight corridors |
| **Glassline** | Medium | Office atrium, non-breakable glass Parts |
| **Ridge** | Large | Outdoor canyon (room for 3v3/4v4 later) |

### Match flow (Phase 3)
1. Queue fills (humans and/or bot fill timers)
2. **Map vote** — 3 random maps, **8s**; bots vote for variety; last-played down-weighted
3. Winning map loads via `MapService` (lobby `LatchArena` parked)
4. **Operator + loadout lock** — **8s**
5. Countdown → rounds / continuous match → **match recap** (K/D, damage; Tokens/XP stubs) → lobby

### How to test
1. `rojo serve` + Play Solo
2. Queue 1v1 — after fill, vote UI appears (3 buttons + timer). Click a map or let bots decide.
3. Confirm spawn pads, cover, and kill floor on each map (re-queue to roll different offerings; last map is down-weighted).
4. Bots should roam match waypoints/cover nodes; lobby wanderers return after match end.

Config: `Config/Maps.lua`, `MatchSettings.MapVoteSeconds`. Remotes: `MapVoteStart` / `MapVoteCast` / `MapVoteUpdate` / `MapVoteResult`.



## Phase 2 — Weapons, ADS, shotgun pellets

Full original roster (no marketplace IDs / no Rivals names):

| Slot | Weapons |
|------|---------|
| **Primary** | Pulse AR, Coil SMG, Longscope, Breach Shotgun, Cycle Burst |
| **Secondary** | Sidearm, Machine Pistol, Stub Revolver |
| **Melee** | Blade, Crowbar, Bat |
| **Utility** | Frag, Flash Can, Smoke Can, Stim Cap |

Default loadout: **Pulse AR / Sidearm / Blade / Frag**.

### How to test
1. `rojo serve` + Play Solo — default loadout still works (1–4 / GUN cycle).
2. **ADS**: hold **RMB** (or mobile **ADS** button) — FOV lerps in; server spread shrinks (`Aiming` on `FireWeapon`).
3. **Breach Shotgun**: equip via Loadout panel (lobby left) → fire — 8 server pellets, wider spread, pellet VFX streaks.
4. **Flash Can**: throw utility — enemies in radius get white HUD flash (`FlashEffect`).
5. **Smoke Can**: throw — `VFX.SmokeSphere` fog (Parts/Beams).
6. **Stim Cap**: equip utility + fire — +30 HP over 2s, **1/round** (refill resets).
7. Bots pick random loadouts and fire their equipped primary; kill feed / hitmarkers include bot names.

Config: `Config/Weapons.lua`. Remotes: `SetLoadout`, `FlashEffect`, `KillFeed`. Loadout UI: `LoadoutController` (Phase 4 Token gates later).


## Phase 3 — Modes, lobby, pads, menu queue

### Modes (`Config/Modes.lua`)

| Mode | Win rule | Notes |
|------|----------|-------|
| **1v1 / 2v2 / 3v3 / 4v4** | First to **5** rounds | Team elimination rounds |
| **FFA** | First to **7** eliminations | **Respawn 3s** (fixed rule) |
| **Team Deathmatch** | Team score to **30** | Mid-match respawn 3s |
| **Gun Cycle** | Finish fixed weapon list | Kill advances weapon; respawn 3s |
| **Beginner 2v2** | First to 5 rounds | Bots **Recruit**, damage taken **−15%** |
| **Casual Mix** | (resolved at start) | Random among 2v2 / FFA / TDM / Gun Cycle |

### Lobby
- `LobbyBuilder` builds `LatchArena`: central plaza, shop/pass/contract/leaderboard stubs, operator alcove, **Ready Together** party stub
- **Queue pads** (original colors): 1v1, 2v2, 3v3, 4v4, FFA, Casual Mix — step on / ProximityPrompt to queue
- **LobbyController** mode menu (mobile-friendly; no walking required)
- Lobby bots wander between pads and linger (visual queue join)

### Client
- `LobbyController`, `MatchRecapController`
- Remotes: `MatchRecap`, `RequestLeaveQueue` (via `Remotes.lua` only)

### How to test
1. `rojo serve` + Play Solo
2. Queue **3v3 / 4v4 / FFA / TDM / GunCycle / Beginner** from the right menu (or a pad)
3. Confirm bot fill → map vote → 8s operator lock → match → recap → lobby
4. FFA: confirm 3s respawn and first-to-7; Gun Cycle: weapon advances on elim

## Architecture

- Custom bootstrap (no Knit): `Bootstrap.server.lua` / `Bootstrap.client.lua`
- Server validates damage, fire rate, ability cooldowns, grenade throws
- **BotService** drives AI stand-ins through the same `WeaponService:ServerFire` / `AbilityService:ServerUse` paths as players (`ActorUtil` unifies Player | BotRecord)
- Hitscan guns use server raycasts; Splice panels pierce for allies (see comments in `AbilityService`)
- VFX: Parts / Beams / Highlights only — budget helpers in `Util/VFX.lua`
- Lobby: `LobbyBuilder` / `ArenaBuilder` facade (pads, kiosks, waypoints)
- Match arenas: `MapService` + `Services/Maps/*` (spawns, cover tags, bot waypoints/cover nodes, lighting, kill floor)

## Known MVP gaps

- Bot AI is competent but not tournament-level (no grenade throws / advanced peeks yet)
- Splice blocks **movement** for everyone; only **bullets** are one-way for allies
- Anchor explosive resistance is an attribute stub (no knockback system yet)
- Ranked / ELO still later; Tokens/XP economy is Phase 4
- First-person zoom lock is a simple camera distance clamp
- Lobby bot “emotes” are Billboard stubs

## License / assets

Placeholder Parts only. No copyrighted third-party assets or trademarks beyond a single “inspired by” note for arena FPS.
