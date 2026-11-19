# Sword Blox Online

A 100-floor sword and magic RPG for Roblox. Rojo project, server-authoritative, everything tunable from one Config. See `DESIGN.md` for the game rules this code follows.

## Run it

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run `rokit install` (pins Rojo 7.7.1).
2. `rojo serve`
3. In Studio, open the Rojo plugin and press Connect, then press Play.
4. For saving in Studio: Game Settings > Security > Enable Studio Access to API Services. Without it the game still runs, shows a "Progress will not save" toast and never writes.

## What is built

| Area | Where | Notes |
| --- | --- | --- |
| Config | `src/shared/Config.luau` | Every number, floors 1 to 10, items, passes, products, rate limits |
| Profiles | `DataService` | Session locks, blocked saves after a failed load, receipts, backoff retries, autosave |
| Progression | `ProgressionService` | XP, levels, stat points (STR, AGI, ARC), gold, materials, HP/SP/MP maxima |
| Floors | `WorldBuilder`, `FloorService` | Greybox floors from Config, teleport gates, travel, unlocks, server front line |
| Characters | `CharacterService` | Spawn after data loads, respawn at the current floor town |
| Quests | `Quests`, `QuestLint`, `QuestService` | Floor 1 main chain and 5 side quests, lint at boot, accept, track, abandon, advance |
| Bag | `InventoryService` | Items, stacks, capacity, equip slots |
| Daily | `DailyService` | UTC streak with a 7-day reward track |
| Shop | `MonetizationService` | Passes, products, receipts, Studio simulation for ID 0 |
| Admin | `AdminService`, `AdminPanel` | Studio, owner, group rank 254+ or `ADMIN_IDS`; press backquote in game |
| Analytics | `Analytics` | Onboarding funnel, progression, economy and custom events |
| Theme | `src/client/UI/Theme.luau` | Lanternsteel palette, fonts, sizes, motion tokens |
| UI kit | `UI.luau`, `Motion.luau`, `Router.luau` | Plate, Button, Tab, Row, Slot, Bar, Chip; enter, exit, press, stagger; one surface open at a time |
| HUD | `src/client/Hud.luau` | Player plate (HP, SP segments, MP), minimap with floor code, menu button, quest tracker, daily chip |
| Ledger | `src/client/Ledger/` | Character, Skills, Bag, Quests, Map, Shop, Settings tabs; Party and Guild placeholders |
| Feedback | `Toasts.luau`, `Banners.luau` | Toast queue (3 max, rewards first), Floor Cleared band, Boss Intro card |

## Not built yet

- Combat (Sword Skills, Connect, Switch, mobs, bosses, damage). It will be built from the team's references.
- Models, item meshes and animations. These come through the Blender pipeline.
- Parties, guilds, trading, the market, the quest director for repeatables, notifications.

## Hooks for what comes next

| When this exists | Call |
| --- | --- |
| A floor boss dies | `FloorService.markCleared(player, floorId, clearSeconds, partySize)` |
| A quest objective happens | `QuestService.advance(player, questId, stepId, amount)` |
| A mob dies | `ProgressionService.addXp`, `ProgressionService.addGold`, `InventoryService.give` |
| Damage is about to apply | `WorldBuilder.isSafe(position)` (towns take no damage) |
| Equipped weapon stats are needed | `InventoryService.equippedDef(player, "Weapon")` |
| A boss fight starts | Fire the `Banner` remote with `{ kind = "BossIntro", name, title }` |

## Adding art from Blender

- Floor kits: a Model named `F01`, `F02` and so on in `ServerStorage.FloorKits` replaces that floor's greybox. Optional named children: SpawnLocation `Spawn`, parts `TeleportGate`, `QuestBoard`, `LabyrinthEntrance`.
- Item meshes: each item in `Config.ITEMS` names its asset in `model`.
- Rojo rebuilds the folders it manages (`ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`). Anything placed by hand inside those is wiped on sync. Keep hand-placed assets in `ServerStorage`, or save them as `.rbxm` under `assets/` and map them in `default.project.json`.

## Conventions

- Every file starts with `--!strict` and a header saying what it owns.
- Server owns all state; the client sends intent through `Remotes` and every handler validates types, rate limits and ownership.
- No UI colour, font or duration is hard-coded outside `Theme.luau`. No emoji in UI. No long dashes in copy.
