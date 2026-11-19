# Sword Blox Online: Design

Source: Development Plan v3 (FLNK Ltd, 19 November 2026). This file is the working summary the code follows. Every number lives in `src/shared/Config.luau`; colours, fonts and timings live in `src/client/UI/Theme.luau`.

Status: base systems built. Combat, models and animations are not built yet (combat will be built from the team's references, models come through the Blender pipeline).

## Pillars

| Pillar | Player promise |
| --- | --- |
| The Climb | 100 floors, each with a town, field, labyrinth and boss. Clearing floor 100 ends the game. |
| Sword Mastery | Posed, timed Sword Skills with chaining. Better players visibly do more. |
| Spellblade | Magic that plugs into swordplay: elemental infusions, quick chants, support spells. |
| Together | Parties, Switch, raid bosses and a Last Attack Bonus worth fighting for. |
| Living Castle | A director that keeps old floors busy with quests, field bosses and events. |

## Core loops

| Loop | Length | Contents |
| --- | --- | --- |
| Fight | 30 to 90 s | Pose, fire, connect, switch, finish |
| Session | 15 to 40 min | Town, field, contract, labyrinth push |
| Day | daily | Streak, 3 contracts, field boss, guild |
| Week | weekly | Raid boss, guild goal, leaderboard reset |
| Season | 4 to 6 weeks | New floor band, Floor Pass, event |

First ten minutes (plan 9): combat inside 30 s, first Sword Skill inside 60 s, no menus before the first fight. Every step is an onboarding funnel event (`Config.ONBOARDING_FUNNEL`).

## Numbers (all in Config)

| What | Rule | Config |
| --- | --- | --- |
| Stat points | 3 per level into STR, AGI, ARC | `STAT_POINTS_PER_LEVEL`, `STATS` |
| XP to next level | `80 + 40 * level^1.35`, no cap | `xpToNext` |
| Skill slots | 2, then +1 at 6, 12, 20, then every 10 (13 at level 100) | `skillSlotsForLevel` |
| Proficiency | 0 to 1,000 per weapon and element, a mod every 50 | `PROFICIENCY_MAX`, `PROFICIENCY_MOD_EVERY` |
| Max HP | `200 + 18 * (level - 1) + 6 * STR` | `BASE_HP`, `HP_PER_LEVEL`, `HP_PER_STR` |
| SP | 4 segments, one per Sword Skill charge | `SP_SEGMENTS` |
| Max MP | `40 + 5 * ARC` | `BASE_MP`, `MP_PER_ARC` |
| Bag | 60 slots, 120 with Bigger Bank | `BAG_CAPACITY*` |
| Respawn | 4 s at the current floor town, no penalty yet | `RESPAWN_DELAY`, `DEATH_XP_LOSS_FRACTION` |

## Floors as data (plan 7.4)

Each floor is a `Config.FLOORS` entry: name, town, biome, boss, colours and greybox size. `WorldBuilder` builds every floor at runtime (one place for now, floors spaced on the X axis). Milestone floors are 1, every 10th and the quarter points. Floors 1 to 10 are listed; bands ship by appending entries.

Art swap: put a Model named after the floor code (`F01`) in `ServerStorage.FloorKits` and it replaces the greybox. Optional children: SpawnLocation `Spawn`, parts `TeleportGate`, `QuestBoard`, `LabyrinthEntrance`.

Progress: clearing a floor boss calls `FloorService.markCleared`, which unlocks the next floor, moves the server-wide front line and shows the Floor Cleared banner.

## Quests (plan 8)

Every quest must pass the seven rules, enforced by `QuestLint` at server boot:

1. A person, a problem, a turn.
2. A verb that is not "kill N".
3. Rooted in its floor.
4. Teaches or tests a system.
5. A reward that matters (not only XP and Gold).
6. A consequence.
7. 5 to 15 minutes.

Floor 1 ships with a main chain and five side quests from the plan's archetypes. Steps advance only from the server through `QuestService.advance`, so combat, crafting and dialogue can plug in later without changing quest data.

## Economy (plan 10)

Gold (name to be decided) from mobs, quests, contracts and selling; sinks are repairs, upgrades, crafting, housing, market tax and teleport fees. Upgrade crystals from dismantling. Every source and sink logs an economy event. No paid currency for power.

## Monetisation (plan 11)

Never sells the climb. No loot boxes or paid random items. Passes and products are listed in Config with draft prices; an ID of 0 means not created yet, and Studio simulates the purchase so flows can be tested. Receipts are stored in the profile so nothing is granted twice.

| Type | Product | Draft price |
| --- | --- | --- |
| Pass | Bigger Bank | 149 |
| Pass | Second Loadout | 199 |
| Pass | Hardcore Slot | 249 |
| Pass | Wardrobe Pack | 299 |
| Product | Respec Scroll | 75 |
| Product | Server Blessing (server-wide XP, 30 min, stacks) | 99 |
| Product | Revive Token | 35 |
| Product | Dye Slot | 25 |
| Season | Floor Pass | 399 |
| Subscription | Adventurer's Charter | 49 / month |

## Retention (plan 12)

Built now: daily streak with a 7-step reward track, server-wide front line, quest tracker. Planned: three daily contracts from the quest director, field boss timers, weekly raid, guilds, party finder, notifications (one per day, opt-in, personal and actionable).

## UI theme: Lanternsteel (plan 23 to 29)

Forged steel plates lit by a single lantern. Square corners, 1 px hairlines, no shadows, gradients or blur.

| Token | Hex | Job |
| --- | --- | --- |
| Ink | #0E0F10 | Scrims, tooltips |
| Steel | #16181A | Panel base |
| Plate | #23272B | Rows, slots, selected tab |
| Rule | #3A4046 | Hairlines and dividers |
| Bone | #ECE8DF | Text and icons |
| Lantern | #E8A93B | Skill energy, active and selected, primary button |
| Vigor | #6DBE7B | HP, positive |
| Tide | #6CB4DE | MP |
| Ember | #D9573F | Danger, low HP, boss HP |

Rarity: Common #A8A39A, Fine #7DBE74, Rare #5E9FD6, Heroic #D2774A, Legendary #E8C24A.

Type: Michroma for display (caps), Titillium Web 600/700 for body, Roboto Mono for every number.

Motion tokens: micro 80 ms, quick 140 ms, base 220 ms, slow 320 ms, exit at 0.7x, settle 220 ms Back Out (reward toasts only), stagger 25 ms up to 8 items, offsets 8 px small and 24 px panels, press scale 0.96. Reduce Motion turns slides into fades. Fades never use CanvasGroup.

Menus: one shell called the Ledger with tabs Character, Skills, Bag, Quests, Map, Party, Guild, Shop, Settings.

## Controls

| Action | PC | Gamepad | Touch |
| --- | --- | --- | --- |
| Ledger | Tab or M | Start | Menu button |
| Back / close | Esc or Backspace | B | Close button or tap outside |
| World prompts | E | X | Tap prompt |
| Admin panel (admins only) | Backquote | | |
| Basic attack, Sword Skills, spells, dodge, Switch, crystal | arrive with combat | | |

## Sound slots

`ui_hover`, `ui_open`, `ui_close`, `ui_tab`, `ui_confirm`, `ui_error`, `ui_purchase`, `reward_common`, `reward_rare`, `reward_legendary`, `connect_window`, `switch`, `floor_clear`, `level_up`. Paste asset IDs into `Config.SOUNDS`.

## Open questions (plan 22)

- Keep "Sword Blox Online" as is, add a subtitle, or adjust it?
- Original names for the castle, world and soft currency.
- Art direction: cel-shaded, stylised low-poly or realistic?
- Camera: lock-on, free aim, or both?
- Death: soft penalty, revive window, optional Hardcore slot?
- Magic: chant, builder, infusion, or the hybrid?
- Flight later in the climb, or none?
- PvP: duels only, or open PvP on some floors?
- Quest voice: serious, light-hearted, or mixed by floor?
- Launch band size and live-ops cadence.
