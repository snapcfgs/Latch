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

1. Pick an **Operator** on the left card row; set **Loadout** (strip 1–4 shows skin/wrap swatches).
2. Check the top **player banner** (level · wrap · win streak) and hub tabs: **Shop / Pass / Contracts / Career**.
3. Lobby **emote** row (bottom) — 6 stubs (bob + billboard).
4. **Queue** from the right mode menu **or** walk onto a colored queue pad (ProximityPrompt / touch).
5. Controls:
   - **Mouse1** fire / melee / throw (depends on equipped)
   - **1–4** weapon slots (primary/secondary/melee/utility) · **RMB** ADS
   - **E** cycle weapon · **R** reload · **Q** ability
   - **Shift** sprint · **C / Ctrl** crouch · crouch while sprinting = **slide**
   - **Space** jump
   - **Tab** scoreboard (humans + bots) mid-match
   - **Esc** frees mouse (Studio playtests)

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
3. Play. On-screen buttons (safe-area padded): **FIRE**, **ADS**, **JUMP**, **SLIDE**, **ABILITY**, **RELOAD**, **SWAP**, **BOARD** (scoreboard), **RUN**, plus a right-side **LOOK ZONE**.
4. Touch chrome is hidden when keyboard is present and touch is not (desktop).

### Real phone

1. Publish the place (or use Team Create / Studio sync to a published experience).
2. Join from the Roblox mobile app.
3. Use the on-screen controls; look by dragging the upper-right look zone.

## Operators

| Operator | Active | Passive |
|----------|--------|---------|
| **Skid** | Friction dash + trail | Longer slide |
| **Anchor** | Cover plate (~4s) | Explosive knock resist (self Frag) |
| **Splice** | One-way panel (~5s) — allies walk **and** shoot through | Quieter crouch |
| **Jolt** | Mark / Highlight reveal | Faster reload after melee hit |
| **Fuse** | Sticky delayed pop (sphere damage) | Frag fuse −0.3s |
| **Warden** | 4s vision pulse (hostiles ≤40 studs) | +10 armor while planted (still 0.6s) |

Balance numbers live in `src/ReplicatedStorage/Config/Operators.lua`.


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
5. Countdown → rounds / continuous match → **match recap** (K/D, damage, Tokens/XP) → lobby

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

Config: `Config/Weapons.lua`. Remotes: `SetLoadout`, `FlashEffect`, `KillFeed`. Loadout UI: `LoadoutController` (Token unlock gates).


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



## Phase 4 — Progression, shop, battle pass, contracts

### Currencies
| Currency | Use |
|----------|-----|
| **Latch Tokens** | Buy weapons / skins / wraps in Shop |
| **Scrap** | From case duplicates (sink TBD) |
| **Pass XP** | Battle Pass tiers (not account XP) |
| **Account XP** | Levels (`Monetization.LevelXpRequired` = 100) |
| **Skin Tickets** | Open Skin Case Alpha / Beta |

### Match grants (`ProgressionService`)
- **Win** 25 Tokens + 50 XP · **Loss** 10 Tokens + 25 XP
- +2 Tokens/kill (cap +20) · +5 XP/kill · +1 XP per 50 damage
- Stats + daily contract progress updated on match end

### Battle Pass — Season 01 "Live Wire"
- **20 Pass XP = 1 tier** (40 tiers, Free + Prime tracks)
- Per match Pass XP: **+1 per round won** (round modes) **or +1 per elim** (FFA/TDM/Gun Cycle), plus **+1 per 45s** of match time (cap +20/match)
- Roughly: **20 round wins ≈ 1 tier**, or **~15 minutes** of continuous play ≈ 1 tier

### Contracts
- 3 dailies from `Config/Contracts.lua`
- **Live (DataStore):** refresh on UTC day change
- **Studio / in-memory:** refresh after **30 minutes** or new session (`Contracts.StudioRefreshSeconds`)

### Monetization
- `Config/Monetization.lua` → **`IS_MONETIZATION_LIVE = false`**
- No real Robux `Prompt*` charges while false
- Studio **Shop → Debug** tab (or DebugGrant remote):
  - **Starter Bundle** — Coil SMG + Neon Coil skin + 200 Tokens
  - Unlock all weapons / Tokens / Skin Tickets / Prime Pass / Pass XP / free case open

### How to test
1. `rojo serve` + Play Solo
2. Queue **1v1** — finish a match → recap shows **Tokens / XP** > 0; profile syncs
3. Open **Shop** (kiosk west side, or lobby menu **Shop** button) → Debug → Starter Bundle / Unlock all
4. **Loadout** — locked guns show 🔒 until unlocked; starters always available
5. **Pass** kiosk — claim free tiers after Pass XP; Debug → Prime + Pass XP to test Prime track
6. **Contracts** kiosk — progress after matches; claim when complete
7. Cases: grant Skin Tickets (Debug) → Cases tab → open (pity: Rare+ by 10th open; duplicates → Scrap)

### Config / services
- Config: `Cosmetics.lua`, `BattlePass.lua`, `Contracts.lua`, `Monetization.lua`
- Server: `DataService`, `ProgressionService`, `ShopService`, `PassService`, `ContractService`, `MonetizationService`
- Client: `ShopController`, `PassController`, `ContractController`, `ViewmodelController` (recolor stub)
- Remotes: `ProfileSync`, `RequestProfile`, `ShopBuy`, `ShopResult`, `OpenCase`, `EquipCosmetic`, `PassClaim`, `PassResult`, `ContractClaim`, `ContractRefresh`, `ContractResult`, `DebugGrant`, `PromptPurchase`

## Architecture

- Custom bootstrap (no Knit): `Bootstrap.server.lua` / `Bootstrap.client.lua`
- Server validates damage, fire rate, ability cooldowns, grenade throws
- **BotService** drives AI stand-ins through the same `WeaponService:ServerFire` / `AbilityService:ServerUse` paths as players (`ActorUtil` unifies Player | BotRecord)
- Hitscan guns use server raycasts; Splice panels: allies walk+shoot through, enemies blocked (CollisionGroups + NoCollisionConstraint — see `AbilityService`)
- VFX: Parts / Beams / Highlights only — budget helpers in `Util/VFX.lua`
- Lobby: `LobbyBuilder` / `ArenaBuilder` facade (pads, kiosks, waypoints)
- Match arenas: `MapService` + `Services/Maps/*` (spawns, cover tags, bot waypoints/cover nodes, lighting, kill floor)

## Phase 5 — Operators + combat/movement polish

### New operators
- **Fuse** / **Warden** (see table above). Bots pick from full `OperatorOrder`.

### Combat fixes
- **Splice**: `LatchSpliceEnemy` panel + `NoCollisionConstraint` for allies; hitscan pierce unchanged. Documented in `AbilityService` header.
- **Anchor**: Frag explosions apply knock; self knock scaled by `LatchExplosiveKnockReduction`.
- **Viewmodel**: `ViewmodelController` builds a local camera Part (skin/wrap tint) in combat.
- **Death recap**: `DeathRecap` remote → HUD line e.g. `Nox [Coil SMG] 18m head`.

### Movement
- Slide cancel into jump (keep momentum)
- Bunny-hop prevention (`BunnyHopSpeedCap` / chain window)
- Landing spread penalty **200ms** (`LandingSpreadDegrees`)

### How to test
1. `rojo serve` + Play Solo — pick Fuse / Warden from operator panel
2. Fuse: Q sticks a charge → delayed pop; equip Frag and confirm shorter fuse
3. Warden: Q highlights nearby bots; stand still 0.6s → planted armor (tank a shot)
4. Splice: ally bot / second client walks through panel; enemies blocked; ally bullets pierce
5. Anchor + Frag at feet — reduced self knock vs other operators
6. First-person combat — tinted viewmodel gun visible; die → death recap string
7. Slide+Jump cancel; spam jump on land → speed capped; fire on land → wider spread briefly


## Phase 6 — UI / HUD / juice polish

### Lobby hub
- Operator **card row** with accent stripes; loadout **strip 1–4** + skin/wrap swatches
- Queue buttons + clearer pad prompts; hub tabs **Shop / Pass / Contracts / Career**
- Player banner: **level**, equipped **wrap**, **win streak** (`ProfileSync`)
- **EmoteController** — 6 Cosmetics emote stubs (CFrame bob + Billboard)

### In-match HUD
- Crosshair style/gap by weapon + ADS; health, ammo, utility count
- Ability **radial** cooldown; round score + **team living pips** (humans + bots)
- Kill feed capped at **5** lines; damage numbers kept
- **Tab** / mobile **BOARD** scoreboard (players + bots)
- Mobile chrome: FIRE, ADS, JUMP, SLIDE, ABILITY, RELOAD, SWAP, BOARD, LOOK ZONE (safe-area)

### Match end
- Recap scoreboard (bots + humans); Tokens / XP / Pass bar tweens
- **Rematch** → `RequestRematch` (same mode, bot refill after recap)

### Audio
- `Config/Sounds.lua` + `AudioController` — placeholder Sound stubs (**no toolbox IDs**)
- Wired: fire, hit, ability, UI click (pitch-varied; silent + print fallback)

### How to test
1. `rojo serve` + Play Solo — lobby feels like a hub (banner, tabs, emotes, queue)
2. Device emulator — confirm all touch buttons + look zone padded
3. Mid-match **Tab** scoreboard; finish match → rematch queues same mode
4. Output window shows `[Latch:Audio] beep …` stubs when firing / clicking

## Known MVP gaps

- Bot AI is competent but not tournament-level (no grenade throws / advanced peeks yet)
- Ranked / ELO still later
- First-person zoom lock is a simple camera distance clamp
- Lobby bot ambient emotes remain simple; player emotes are Phase 6 stubs
- Killcam optional (skipped); death recap line only

## License / assets

Placeholder Parts only. No copyrighted third-party assets or trademarks beyond a single “inspired by” note for arena FPS.
