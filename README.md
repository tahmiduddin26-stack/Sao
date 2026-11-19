# Clocked Out

A retired hitman runs a corner store, and everything on the shelves is a weapon. It's an action-comedy brawler for Roblox: a Rojo project, server-authoritative, with every number tunable from one Config. `DESIGN.md` has the game rules the code follows, and `docs/research-retired-hitman.md` has the research behind them.

## Run it

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. It pins Rojo 7.7.1.
2. Run `rojo serve`. The project serves on port 23604.
3. In Studio, open the Rojo plugin, set the port to 23604, press Connect, then press Play.
4. To save in Studio, turn on Game Settings > Security > Enable Studio Access to API Services. Without it the game still runs, but it shows a "Progress will not save" toast and never writes.

## What is built

| Area | Where | Notes |
| --- | --- | --- |
| Config | `src/shared/Config.luau` | Every number: prop classes and props, enemies, districts, store, bounty, products, codes, rate limits |
| Profiles | `DataService` | Session locks, blocked saves after a failed load, receipts, backoff retries, autosave |
| Progression | `ProgressionService` | XP, levels, stat points (POW, SPD, INS), Cash, max HP |
| World | `WorldBuilder` | Seven greybox districts and twenty store plots, all built from Config |
| Props | `PropService` | Spawning, grab and hold, durability, throwing, the shared projectile stepper |
| Combat | `CombatService` | Light and heavy combos, throws, dodge i-frames, parry and catch, Focus, Serious mode with the body-scale change, style |
| Enemies | `EnemyService` | R15 rigs, AI with wind-up tells, knife throwers, bosses with an enrage phase, knockouts (nobody dies), district rosters |
| Bounty | `BountyService` | KO rewards, bounty loss on KO, Bounty Shield, global leaderboard board |
| Store | `StoreService` | Your store: shelves as weapon racks, restock, customers, disguised assassins, upgrades, the counter pen |
| Districts | `DistrictService` | Travel, area tracking, unlock by best bounty, boss clears |
| Jobs | `Quests`, `QuestLint`, `QuestService` | Event-driven steps (`notify`), linted at boot, accept, track, abandon |
| Rewards | `RewardsService` | Daily streak, playtime gifts, codes |
| Shop | `MonetizationService` | Passes, products, receipts, Studio simulation for ID 0 |
| Admin | `AdminService`, `AdminPanel` | Studio, owner, group rank 254+ or `ADMIN_IDS`; press backquote in game |
| Analytics | `Analytics` | Onboarding funnel, progression, economy and custom events |
| Theme and kit | `Theme.luau`, `UI.luau` | Ink Panel palette and fonts; comic kit: panel, bigButton, brushTitle, splat, halftone, sticker, keycap, pips |
| Combat client | `src/client/Combat.luau` | PC, gamepad and touch input, aim, grab outline, procedural swings, tells, impact frames, damage numbers |
| HUD | `src/client/Hud.luau` | HP, Focus and Serious timer, Cash, bounty, gifts, Big Sale, area, job tracker, held prop |
| Ledger | `src/client/Ledger/` | ME, STORE, JOBS, MAP and SHOP tabs, plus Settings |

## Art and audio hooks

- **Props:** put a BasePart or MeshPart named after the prop id (for example `frying_pan`) in `ReplicatedStorage.Assets.Props`.
- **Enemies:** put a Model with a Humanoid named after the enemy id (`thug`, `bruiser`, and so on) or `customer` in `ReplicatedStorage.Assets.Enemies`.
- **Districts:** put a Model named `D01` to `D07` in `ServerStorage.DistrictKits`, with optional `PropSpawn`, `EnemySpawn`, `BossSpawn` and `Spawn` parts.
- **Sounds:** paste `rbxassetid://` ids into `Config.SOUNDS`. Empty slots stay silent.

Keep assets in services Rojo doesn't manage (`ServerStorage`, or an `Assets` folder you save in the place), or commit them as `.rbxm`. Anything placed by hand inside `ReplicatedStorage.Shared` is wiped on sync.
