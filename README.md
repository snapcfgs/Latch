# Latch

Competitive arena FPS for Roblox, made by Sven.  
Multi-mode arena (1v1–4v4, FFA, TDM, Gun Cycle, Beginner), shared loadouts, and six Operators with actives + light passives. Built as a **Rojo + Luau** MVP with seamless **PC + mobile** controls.

Inspired by arena FPS games such as Rivals — original operators, weapons, maps, and IP only.

## Requirements

- [Rojo](https://rojo.space/) 7.x (`aftman install` / `rojo --version`)
- Roblox Studio
- Optional: [Aftman](https://github.com/LPGhatguy/aftman) — pins in `aftman.toml`

## Open in Studio (Rojo)

```bash
cd game
rojo serve
```

In Roblox Studio:

1. Install the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/) if needed.
2. Open a new place (or empty baseplate).
3. Click **Connect** in the Rojo plugin (default `localhost:34872`).
4. Play (F5) — server builds lobby (`LatchArena`), remotes, and ambient bots on start.

`default.project.json` maps `src/` → `ReplicatedStorage` (Shared / Config / Util), `ServerScriptService`, `StarterPlayer`, `StarterGui`. No Wally/Knit — custom bootstrap only.

## Success criteria — Solo Play reviewer path

A reviewer should be able to complete this path in Studio without code changes:

1. **Lobby bots** — 6–12 ambient bots wander between queue pads / waypoints.
2. **Operator / loadout / skin** — pick an Operator (card row); set loadout 1–4; optional skin/wrap swatches (unlock via Shop Debug if needed).
3. **Queue 1v1** — menu or blue pad → bot fill in **~3s**.
4. **Map vote** — 3 maps, 8s; bots may cast votes; map loads.
5. **Operator lock** — 8s lock → countdown → rounds **first-to-5**.
6. **Recap → Tokens** — match recap shows K/D/damage + Tokens / XP / Pass XP → return to lobby.
7. **Shop / Pass** — hub tabs or kiosks; Studio **Debug** grants (Starter Bundle, Tokens, unlock all, Prime, Pass XP).
8. **Queue 2v2** — bot fill in **~4s** to 4 fighters.
9. **Mobile emulator** — Test → Device Emulator → confirm FIRE / ADS / JUMP / SLIDE / ABILITY / RELOAD / SWAP / BOARD / LOOK ZONE.

## How solo Play works (end-to-end)

Solo Studio Play is a **real match vs AI**, not a practice sandbox.

1. You join the lobby. `LobbyBuilder` builds plaza, queue pads, shop/pass/contract/career kiosks, operator alcove. `BotService` keeps **6–12** lobby wanderers.
2. Pick Operator + loadout (persisted via `DataService` when available). Queue from the **right mode menu** or walk onto a **colored pad** (ProximityPrompt / touch).
3. `MatchService` waits `Modes.FillSeconds`, then fills empty slots with match bots (`FillTarget` / team sizes). 1v1 ≈ **3s**; 2v2 ≈ **4s**.
4. **Map vote** (3 random maps, last-played down-weighted, 8s) → `MapService` loads the winner and parks the lobby.
5. **Operator + loadout lock** (8s) → countdown → fight. Round modes end a round when one team has **0 alive** (humans + bots). No empty-team skip.
6. Mid-match human join replaces the **lowest-difficulty** stand-in; HUD announces via `StandInReplaced` / `Announce`.
7. Match end → **recap** (humans + bots) with Token/XP grants → lobby restored; match bots despawn; lobby bots return.

Bot names look like `Volt#4821`. Difficulties: **Recruit / Standard / Sweat** (`Config/Bots.lua`). Beginner 2v2 forces **Recruit**. Combat uses the same `WeaponService:ServerFire` / `AbilityService:ServerUse` paths as players.

## Controls

### PC

| Input | Action |
|-------|--------|
| **Mouse1** | Fire / melee / throw (by equipped) |
| **RMB** | ADS |
| **1–4** | Primary / secondary / melee / utility |
| **E** | Cycle weapon |
| **R** | Reload |
| **Q** | Operator ability |
| **Shift** | Sprint |
| **C / Ctrl** | Crouch (crouch while sprinting = **slide**) |
| **Space** | Jump (slide-cancel into jump keeps momentum) |
| **Tab** | Scoreboard (humans + bots) |
| **Esc** | Free mouse (Studio playtests) |

### Mobile (Studio Device Emulator or phone)

Same rules and netcode. On-screen (safe-area padded): **FIRE**, **ADS**, **JUMP**, **SLIDE**, **ABILITY**, **RELOAD**, **SWAP**, **BOARD**, **RUN**, plus a right-side **LOOK ZONE**. Touch chrome hides when keyboard is present and touch is not.

**Real phone:** publish / Team Create sync → join from the Roblox mobile app → drag the look zone to aim.

## Modes (`Config/Modes.lua`)

| Mode | Win rule | Bot fill (approx) |
|------|----------|-------------------|
| **1v1** | First to **5** rounds | 3s → 2 |
| **2v2** | First to **5** rounds | 4s → 4 |
| **3v3** | First to **5** rounds | 5s → 6 |
| **4v4** | First to **5** rounds | 6s → 8 |
| **FFA** | First to **7** elims · respawn **3s** | 5s → FillTarget **4** (max 8) |
| **TDM** | Team score to **30** · respawn **3s** | 6s → FillTarget **6** |
| **Gun Cycle** | Finish fixed weapon list · respawn **3s** | 5s → FillTarget **4** |
| **Beginner 2v2** | First to 5 · Recruit bots · damage taken **−15%** | 4s → 4 |
| **Casual Mix** | Resolves to random 2v2 / FFA / TDM / Gun Cycle | 5s → FillTarget **4** |

## Operators (6)

| Operator | Active | Passive |
|----------|--------|---------|
| **Skid** | Friction dash (server-capped distance) | Longer slide |
| **Anchor** | Cover plate (~4s) | Reduced self Frag knock |
| **Splice** | One-way panel (~5s) — allies walk **and** shoot through | Quieter crouch |
| **Jolt** | Mark / Highlight reveal | Faster reload after melee hit |
| **Fuse** | Sticky delayed pop (sphere damage) | Frag fuse **−0.3s** |
| **Warden** | Vision pulse (hostiles ≤40 studs, 4s) | +10 armor while planted (still 0.6s) |

Balance: `Config/Operators.lua`.

## Maps (6) — code-built Parts only

| Map | Size | Feel |
|-----|------|------|
| **Splityard** | Small | Twin warehouses, mid crate lane |
| **Voltage** | Small | Neon rooftops, thin bridges |
| **Hollow** | Medium | Indoor atrium + mezzanines (Splice-friendly) |
| **Dredge** | Medium | Dry dock — long AR lines + tight corridors |
| **Glassline** | Medium | Office atrium, non-breakable glass Parts |
| **Ridge** | Large | Outdoor canyon (3v3/4v4 room) |

Pre-match **map vote**: 3 options, 8s, bot votes for variety. Config: `Config/Maps.lua`.

## Weapons (shared loadout)

| Slot | Roster |
|------|--------|
| **Primary** | Pulse AR, Coil SMG, Longscope, Breach Shotgun, Cycle Burst |
| **Secondary** | Sidearm, Machine Pistol, Stub Revolver |
| **Melee** | Blade, Crowbar, Bat |
| **Utility** | Frag, Flash Can, Smoke Can, Stim Cap |

Default: **Pulse AR / Sidearm / Blade / Frag** (ids `AssaultRifle` / `Pistol` / `Knife` / `FragGrenade`). ADS shrinks server spread; Breach Shotgun = 8 pellets; Stim = +30 HP / 2s, **1/round**.

## Currencies & progression

| Currency | Use |
|----------|-----|
| **Latch Tokens** | Shop weapons / skins / wraps |
| **Scrap** | Case duplicates (sink TBD) |
| **Pass XP** | Battle Pass tiers (not account XP) |
| **Account XP** | Levels (`Monetization.LevelXpRequired` = 100) |
| **Skin Tickets** | Open Skin Case Alpha / Beta |

**Match grants** (`ProgressionService`): win **25** Tokens + **50** XP · loss **10** + **25** · +2 Tokens/kill (cap +20) · +5 XP/kill · +1 XP per 50 damage.

**Battle Pass — Season 01 "Live Wire"** (40 tiers, Free + Prime): **20 Pass XP = 1 tier**. Per match: +1 Pass XP per round won (round modes) **or** +1 per elim (FFA/TDM/Gun Cycle), plus +1 per **45s** match time (cap +20/match). Roughly 20 round wins ≈ 1 tier, or ~15 min continuous ≈ 1 tier.

**Contracts:** 3 dailies from `Config/Contracts.lua`. Live DataStore: UTC day refresh. Studio / in-memory: **30 min** or new session.

**Shop Debug** (Studio, `IS_MONETIZATION_LIVE = false`): Starter Bundle (Coil SMG + Neon Coil + 200 Tokens), Unlock all weapons, Tokens, Skin Tickets, Prime Pass, Pass XP, free case open. No real Robux prompts while the flag is false.

## Anti-cheat / netcode (Phase 7)

Light server validation — keep feel responsive; do **not** rubber-band slides.

- **Fire rate:** `WeaponService` rejects shots faster than `1/FireRate` with ~**15%** slop (`AntiCheatUtil`).
- **Abilities:** cooldown table authoritative; Skid dash speed/duration clamped to `DashMaxDistance`.
- **Damage:** client never reports damage amounts — server raycast / overlap only. Bots share the same fire path.
- **Movement:** `SlideState` is notify-only; no slide rubber-banding. Exploit-level teleports only if checks are added later.

See headers in `WeaponService` / `AbilityService` and `AntiCheatUtil.lua`.

## Architecture

- Custom bootstrap: `Bootstrap.server.lua` / `Bootstrap.client.lua` (no Knit).
- Server: Match, Weapon, Ability, Bot, Map, Data, Progression, Shop, Pass, Contract, Monetization.
- Client controllers: Input, Weapon, Ability, Slide, HUD, Lobby, MapVote, OperatorSelect, Loadout, Shop, Pass, Contracts, Career, Recap, Emote, Audio, Viewmodel.
- Remotes only via `Shared/Remotes.lua` (`Ensure` / `Get`).
- VFX budget: Parts / Beams / Highlights — `Util/VFX.lua`.

## Known remaining gaps (honest)

- Bot AI is competent but not tournament-level (no grenade throws / deep peeks).
- Ranked / ELO not shipped.
- Ready Together party sync is a soft lobby stub.
- First-person zoom is a simple camera distance clamp; viewmodel is a tinted Part stub.
- Audio is silent Sound stubs + Output prints (no toolbox asset IDs).
- Killcam skipped — death recap line only.
- Scrap sink / full cosmetics marketplace polish still later.
- DataStores fall back to in-memory in Studio; live place needs published DataStore access.

## License / assets

Placeholder Parts only. No copyrighted third-party assets. One “inspired by” line above; no other third-party trademarks in strings or comments.
