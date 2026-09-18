# Latch — Roblox Arena Shooter (MVP Spec)

## Concept
Competitive arena FPS inspired by Roblox Rivals (Nosniy Games): fast 1v1–4v4 duels, first to 5 rounds, loadouts (primary/secondary/melee/utility), slide + jump movement. Differentiator: each player picks an **Operator** with one active ability + one light passive. Guns win fights; abilities create openings. Deliberately light VFX (short-lived meshes/beams/UI, no particle storms).

## Tech stack
- Rojo project (`default.project.json`) targeting Roblox Luau
- Modern Luau style: `--!strict`, ModuleScripts, clear client/server split
- Prefer Knit or a simple custom service framework if Knit adds friction — a clean custom bootstrap is fine for MVP
- No paid assets required; placeholder meshes/parts for weapons and abilities

## Repo layout (suggested)
```
src/
  ReplicatedStorage/
    Shared/          -- constants, remotes config, types
    Config/          -- weapons, operators, match settings
  ServerScriptService/
    Services/        -- MatchService, WeaponService, AbilityService, Movement validation
  StarterPlayer/
    StarterPlayerScripts/
      Controllers/   -- input, camera helpers, ability UX, HUD
  StarterGui/        -- HUD ScreenGui (or create at runtime)
  Workspace/         -- Arena placeholder map (or generate via script)
README.md            -- how to open with Rojo + Roblox Studio
aftman.toml / wally.toml if useful
```

## Match loop (MVP)
1. Lobby placeholder (can be a simple spawn area + UI "Queue 1v1" / "Queue 2v2")
2. Match starts → first to 5 round wins
3. Round: eliminate all enemies on the opposing team; survivors win the round
4. Between rounds: short freeze/reset, refill ammo/health, keep operator
5. Modes for MVP: **1v1** and **2v2** only (4v4 can stub later)

## Movement
- Walk, sprint (or Roblox default run), crouch, **slide** (crouch while sprinting), jump
- Server-authoritative where it matters; client prediction OK for slide feel
- Keep explosive jump stubs optional for later; not required in first pass

## Weapons (shared across operators)
Minimal set — tune later:
1. Assault Rifle (primary) — mid range, full auto
2. Pistol (secondary)
3. Knife (melee) — fast swing, small lunge optional
4. Frag Grenade (utility) — simple projectile, light explosion VFX (sphere + fade, no particles)

Implement hit detection server-side (raycast for hitscan guns). Damage numbers readable in HUD.

## Operators
Each: `Id`, `DisplayName`, `ActiveAbility`, `Passive`, cooldowns, simple VFX hooks.

### Skid
- Active: short friction dash forward (cooldown ~8s)
- Passive: slightly longer slide distance
- VFX: thin Part trail / Beam that despawns quickly

### Anchor
- Active: deploy a brief cover plate (Part wall, ~4s lifetime, cooldown ~12s)
- Passive: reduced self-knock from own explosives (stub if explosives limited)
- VFX: solid Part spawn/despawn, no particles

### Splice
- Active: one-way shoot-through panel (~5s); allies/owner can shoot through, enemies blocked (use CollisionGroup or CanQuery tricks carefully — document approach)
- Passive: quieter footsteps while crouched (reduce footstep volume / omit client cue)
- VFX: semi-transparent Part + simple highlight

### Jolt
- Active: sticky mark on hit target — brief outline/highlight through walls (~3s reveal, cooldown ~10s)
- Passive: slightly faster reload after a melee hit (short buff window)
- VFX: Highlight instance or simple BillboardGui ping — no lightning particle storms

## Performance rules (enforce in code comments + VFX helpers)
- Cap concurrent ability VFX instances
- Prefer Parts, Beams, Highlights, BillboardGui over ParticleEmitters
- Short lifetimes; pool/reuse where easy
- No camera shake spam, no full-screen bloom

## Map (MVP)
One mirrored small arena:
- Two identical spawn sides
- Mid cover blocks, one high platform each side, clear sightlines for AR + close corners for shotgun later
- Build with Parts in Workspace or a Module that constructs the map on server start
- Name spawn locations clearly (`SpawnA`, `SpawnB`)

## UI (MVP)
- Crosshair
- Health
- Ammo
- Ability cooldown indicator
- Round score (e.g. 2–1)
- Operator select before match (simple buttons)

## Out of scope for first PR / first commit set
- Ranked / ELO
- Monetization / skins shop
- Full lobby cosmetics
- 4v4 / FFA / Gun Game
- Complex animation packs
- Voice / party systems

## Success criteria
1. Rojo project syncs cleanly; README explains Studio + Rojo workflow
2. Player can slide, shoot the AR/pistol, melee, throw grenade
3. Operator select works; each of 4 abilities does something useful and networked
4. 1v1 first-to-5 match loop runs with round resets
5. Arena map exists and is playable
6. Code is organized, typed (`--!strict` where practical), and comments note VFX budget

## Implementation notes
- Use RemoteEvents/RemoteFunctions carefully; validate all ability/weapon requests on server
- Anti-cheat light: rate-limit ability use, validate dash distance, validate grenade spawn
- Prefer modular configs so balancing numbers live in Config modules, not buried in scripts

## Cross-platform (HARD REQUIREMENT)
- Seamless mobile + PC: touch controls and keyboard/mouse
- Same damage, ability rules, and netcode on both platforms
- Abstract input (ContextActionService / input map); large touch targets; HUD safe-area aware
- Prefer light VFX for mid-range mobile performance
