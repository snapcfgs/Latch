# Latch — Design Spec (shipped MVP)

## Concept

Competitive arena FPS: fast 1v1–4v4 (plus FFA / TDM / Gun Cycle / Beginner), first-to-5 round duels as the core loop, shared loadouts (primary / secondary / melee / utility), slide + jump movement. Differentiator: each player picks an **Operator** (one active + one light passive). Guns win fights; abilities create openings. Deliberately light VFX (short-lived Parts / Beams / Highlights / UI — no particle storms).

Inspired by arena FPS games such as Rivals — original Latch operators, weapons, maps, and IP only.

## Tech stack

- Rojo (`default.project.json`) → Roblox Luau
- `--!strict` ModuleScripts; custom bootstrap (no Knit / Wally required)
- Placeholder Parts only — no paid / marketplace meshes required
- Tooling pin: `aftman.toml` (Rojo)

## Repo layout

```
game/
  default.project.json
  aftman.toml
  README.md
  DESIGN_SPEC.md
  src/
    ReplicatedStorage/
      Shared/     -- Constants, Remotes, Types
      Config/     -- Weapons, Operators, Modes, Maps, Bots, Monetization, Pass, Contracts, Cosmetics, Sounds, MatchSettings
      Util/       -- VFX
    ServerScriptService/
      Bootstrap.server.lua
      Services/   -- Match, Weapon, Ability, Bot, Map(+Maps/*), Data, Progression, Shop, Pass, Contract, Monetization, ActorUtil, AntiCheatUtil, LobbyBuilder, ArenaBuilder
    StarterPlayer/StarterPlayerScripts/
      Bootstrap.client.lua
      Controllers/ -- Input, Weapon, Ability, Slide, HUD, Lobby, MapVote, Operator*, Loadout, Shop, Pass, Contract, Career, Recap, Emote, Audio, Viewmodel
    StarterGui/   -- optional; most HUD built at runtime
```

## Match loop

1. Lobby (`LobbyBuilder`) — pads + mode menu; ambient lobby bots
2. Queue fill (`Modes.FillSeconds` / `FillTarget`) → **map vote** (8s) → **operator+loadout lock** (8s) → countdown
3. Round modes: eliminate opposing team; first to **5** round wins
4. Continuous: FFA (first to 7, respawn 3s) / TDM (team score 30, respawn 3s) / Gun Cycle (weapon list, respawn 3s)
5. Match recap (Tokens / XP / Pass XP) → rematch optional → lobby

Solo Play fills empty slots with AI bots so Studio always runs a real match.

## Movement

- Walk, sprint, crouch, **slide** (crouch while sprinting), jump
- Client prediction for slide feel; server does **not** rubber-band slides
- Slide cancel into jump (keep momentum); bunny-hop horizontal speed cap; landing spread penalty ~200ms
- Frag knock exists; Anchor reduces self knock (not a full explosive-jump kit)

## Weapons

Shared across operators. Defaults keep stable ids (`AssaultRifle`, `Pistol`, `Knife`, `FragGrenade`).

- Hitscan: server raycast; ADS reduces spread; shotgun = multi-pellet rays
- Body multipliers via `Weapons.BodyMultiplier`
- Utilities: Frag (explosion + knock), Flash (HUD), Smoke (VFX sphere), Stim (+30 HP / 2s, 1/round)
- Loadout gated by `UnlockedWeapons` (starters always free)

## Operators

| Id | Active | Passive |
|----|--------|---------|
| Skid | Friction dash (max distance server-clamped) | Longer slide |
| Anchor | Cover plate ~4s | Self explosive knock resist |
| Splice | One-way panel ~5s; allies walk+shoot through | Quieter crouch |
| Jolt | Mark / Highlight ~3s | Faster reload after melee |
| Fuse | Sticky delayed pop | Frag fuse −0.3s |
| Warden | Vision pulse ≤40 studs / 4s | +10 armor while planted 0.6s |

Splice: CollisionGroup `LatchSpliceEnemy` + ally `NoCollisionConstraint`; hitscan pierce via `LatchSpliceTeam` (see `AbilityService` header).

## Maps & lobby

Six code-generated arenas (`MapService` / `Services/Maps/*`): Splityard, Voltage, Hollow, Dredge, Glassline, Ridge.  
Each: SpawnA/SpawnB, cover tags, bot waypoints/cover nodes, kill floor, lighting hints.

Lobby: plaza, colored queue pads, shop/pass/contract/career kiosks, operator alcove, Ready Together **soft stub**, ambient bots on pads.

## Modes

See `Config/Modes.lua` — 1v1/2v2/3v3/4v4 (rounds to 5), FFA, TDM, Gun Cycle, Beginner2v2 (Recruit, −15% damage taken), Casual Mix (random casual resolve).

## Progression & economy

- **Profile** (`DataService`): Tokens, Scrap, SkinTickets, Xp/Level, UnlockedWeapons, EquippedLoadout, Cosmetics, Pass, Contracts, Stats, CasePity. DataStore `LatchPlayer_v1` when available; in-memory Studio fallback.
- **Grants:** win 25 / loss 10 Tokens + XP; kill/damage bonuses; Pass XP formula in README / `BattlePass.lua` / `ProgressionService.ComputePassXp`.
- **Shop / cases / cosmetics:** Featured + weapons + skins + wraps; Skin Case Alpha/Beta; pity 10 → Rare+; duplicates → Scrap.
- **Pass:** Season 01 "Live Wire", 40 tiers, Free + Prime; 20 Pass XP = 1 tier.
- **Contracts:** 3 dailies; UTC day live / 30m Studio refresh.
- **Monetization:** `IS_MONETIZATION_LIVE = false` — Prompt* no-ops; Studio `DebugGrant` for Starter Bundle etc.

## UI

Lobby hub (operator cards, loadout strip + skin/wrap swatches, queue menu, hub tabs, player banner level/wrap/streak, emote stubs).  
In-match: crosshair by weapon/ADS, health, ammo, ability radial, round score + living pips, kill feed (5), Tab scoreboard, death recap line, mobile safe-area chrome.  
Recap: scoreboard + reward bar tweens + Rematch.

## Netcode / anti-cheat (Phase 7)

Light server authority:

1. Rate-limit `FireWeapon` / melee by weapon `FireRate` with ~15% slop
2. Ability cooldown + Skid max dash distance server-side
3. Ignore client-reported damage — server raycast / overlap only
4. Bot shots use the same `ServerFire` / `ServerUse` validation as players
5. Do not rubber-band slides; movement checks stay minimal

Helpers: `AntiCheatUtil.lua`. Documented in `WeaponService` / `AbilityService` headers.

## Performance rules

- Cap concurrent ability VFX; prefer Parts / Beams / Highlights / BillboardGui over ParticleEmitters
- Short lifetimes; pool/reuse where easy
- No camera-shake spam / full-screen bloom storms

## Cross-platform (hard requirement)

Same damage, abilities, and netcode on PC and mobile. Abstract input; large touch targets; HUD safe-area aware. Light VFX for mid-range phones.

## Out of scope / known gaps

- Ranked / ELO
- Real party sync (Ready Together stub only)
- Tournament-level bot AI (no bot grenades yet)
- Killcam; full animation packs; voice chat
- Live Robux products (flagged off); Scrap sink polish
- Toolbox audio IDs (stubs only)

## Success criteria (shipped)

1. Rojo syncs; README covers Studio + Rojo + Solo Play path
2. Slide, shoot, ADS, melee, utilities, six operators networked
3. Full mode set with bot fill; map vote; first-to-5 (or continuous win rules)
4. Six original maps load from vote
5. Progression: Tokens/XP/Pass/Contracts/Shop Debug in Studio
6. PC + mobile emulator controls
7. Phase 7 validation hardened; docs match the shipped game
