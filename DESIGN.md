# Clocked Out: Design

**Hook:** A retired hitman runs a corner store, and everything on the shelves is a weapon.

This is an original action-comedy brawler in the retired-assassin genre. All names, characters and art are our own, and nothing is taken from any existing series. The research behind it is in `docs/research-retired-hitman.md`. Every number lives in `src/shared/Config.luau`. Colours, fonts and timings live in `src/client/UI/Theme.luau`.

Status: the base systems carried over from the previous prototype (data, monetisation, admin, jobs, menus). This pass adds prop combat, Focus and Serious mode, knockouts, enemies, the store and bounty. Animations and meshes come later through the Blender pipeline. Until then, props are coded placeholders.

## Pillars

| Pillar | Player promise |
| --- | --- |
| Anything is a weapon | Every prop in the world can be grabbed, swung and thrown. Each class has its own moves. Props break, so you keep improvising. |
| Off duty / Serious | You start slow and heavy. Clean play fills Focus, and a full meter turns you sleek, fast and lethal-looking for 12 s. |
| The promise | Nobody dies. Enemies get knocked out and zip-tied, and cleaner knockouts pay more. |
| The store | Your corner store is home base. Customers buy, shelves empty, and some customers are assassins in disguise. |
| Bounty | Wins raise your bounty and a knockout cuts it. Bounty rank unlocks districts and brings tougher hunters. |

## Core loop

1. Spawn in your store. A "customer" draws a knife. A pen glows on the counter.
2. Grab the prop, beat the attacker, catch the knife they throw and throw it back. The attacker is knocked out and you earn Cash, XP and bounty.
3. Restock the shelves, which sets the weapons for your next home fight. Serve customers for Cash.
4. Take a Job in a district: a 5 to 15 minute run against hunters, ending in a boss.
5. Spend Cash on store upgrades and allocate stat points. Higher bounty unlocks the next district.

Target fight cycle: 30 to 60 s. Session: 15 to 40 min.

First minute: you're in combat within 10 s. No menus before the first knockout. Every step is an onboarding funnel event (`Config.ONBOARDING_FUNNEL`).

## Numbers (all in Config)

| What | Rule | Config |
| --- | --- | --- |
| Stat points | 3 per level into POW, SPD, INS | `STAT_POINTS_PER_LEVEL`, `STATS` |
| XP to next level | `80 + 40 * level^1.35` | `xpToNext` |
| Max HP | `120 + 10 * (level - 1) + 4 * POW` | `BASE_HP`, `HP_PER_LEVEL`, `HP_PER_POW` |
| Damage | `prop.damage * move.mult * (1 + 0.02 * POW)`, x1.5 in Serious | `damageFor` |
| Walk speed | Off duty 14, Serious 24, +0.08 per SPD | `WALK_*` |
| Focus | 0 to 100. Hit +6, catch +20, perfect dodge +12, getting hit -8 | `FOCUS_*` |
| Serious | 12 s, damage x1.5, dash cancels | `SERIOUS_*` |
| Catch window | `0.22 + 0.004 * INS` s after a parry press | `catchWindow` |
| KO reward | Cash, XP and bounty by enemy tier. Style multiplier up to x2 | `ENEMIES`, `STYLE_*` |
| Bounty | Rises on KO. Being knocked out loses 10% | `BOUNTY_*` |
| Respawn | 4 s in your store | `RESPAWN_DELAY` |

## Props

Props are data in `Config.PROP_CLASSES` (moveset) and `Config.PROPS` (each item). The class sets the moves, so adding a prop is just a data entry.

| Class | Light / heavy | Throw | Special |
| --- | --- | --- | --- |
| Pocket | fast jabs | flick, short stagger | pins on the 3rd hit |
| Blunt | 3-hit combo, heavy knockdown | arcing lob | ricochets |
| Reach | wide sweep | spear throw | hits groups |
| Big | slow, armour-breaking | bowling roll | blocks while held |
| Soft | grab and spin | net, slows | next throw +50% |

Props spawn at `PropSpawn` points in the store and the districts and respawn on a timer. Live props are capped per district.

Art swap: put a model named after the prop id in `ReplicatedStorage.Assets.Props`. If it's missing, the coded placeholder is used.

## World as data

`Config.DISTRICTS` is the climb. Each entry sets a name, the bounty needed, its enemies, its boss, colours and greybox size. `WorldBuilder` builds every district at runtime on the X axis, plus a row of store plots (one per player, up to 20). Art swap: a Model named after the district code (`D01`) in `ServerStorage.DistrictKits`.

| Code | District | Bounty to enter | Boss |
| --- | --- | --- | --- |
| D01 | Hinode Shopping Street | 0 | Butcher Gouda |
| D02 | Downtown Crossing | 25,000 | The Twin Couriers |
| D03 | Kiramori Funland | 120,000 | Ringmaster Pell |
| D04 | Blackwater Correctional | 400,000 | Warden Okubo |
| D05 | Sublevel Lab 9 | 1,200,000 | Dr. Silt |
| D06 | Academy Entrance Exam | 3,500,000 | Proctor Vane |
| D07 | The Eleven | 10,000,000 | weekly rotation |

## Jobs (quests)

Jobs keep the seven rules from before, and `QuestLint` checks them at boot:

1. A person, a problem, a turn.
2. A verb that is not "kill N".
3. Rooted in its district.
4. Teaches or tests a system.
5. A reward that matters (not only XP and Cash).
6. A consequence.
7. 5 to 15 minutes.

## Economy

Cash comes from knockouts, serving customers, Jobs and the daily streak. It's spent on store upgrades, shelf stock, cosmetics and stat respecs. There's no paid currency for power.

## Monetisation

Nothing is sold that skips the bounty climb. There are no loot boxes. An ID of 0 means the item isn't created on Roblox yet, and Studio simulates the purchase.

| Type | Product | Draft price |
| --- | --- | --- |
| Pass | 2x Cash | 199 |
| Pass | 2x XP | 199 |
| Pass | Auto Restock | 249 |
| Pass | VIP Shelf (exclusive prop skins) | 149 |
| Pass | Tailored Suit (Serious-mode look) | 299 |
| Product | Cash pack (scales with level) | 49 |
| Product | Lucky Delivery (rare props, 15 min) | 49 |
| Product | Big Sale (server-wide 2x Cash, 30 min, stacks) | 99 |
| Product | Bounty Shield (next KO costs no bounty) | 35 |

## Retention

Playtime gifts (1, 3, 5, 8, 12, 16, 20 min, biggest last), a 7-day streak, codes, a global bounty leaderboard on an in-world board, 20-player servers, the weekly boss rotation in The Eleven, and events timed to the anime season.

## UI theme: Ink Panel

The UI looks like comic panels: paper faces with 3 px ink borders and a hard ink drop shadow (the menu shadow is red so it pops on the dimmed backdrop). Halftone dot corners, ink splats, brush-stroke title slabs, tilted stickers, and chunky buttons that press down into their shadow. Everything is drawn with plain frames, so no image uploads are needed. Corners are square, and there are no gradients or blur.

| Token | Hex | Job |
| --- | --- | --- |
| Shade | #0A0A0A | Scrims behind menus |
| Paper | #F3EFE6 | Panel base |
| Tone | #DCD6CA | Rows, slots, bar tracks, selected tab |
| Line | #141414 | 2 px panel borders and dividers |
| Ink | #141414 | Text, icons, HP fill |
| Red | #D7261E | The one accent: Focus, Serious, active and selected states, primary button |
| Danger | #9E1B16 | Destructive buttons, low HP |

Prop rarity is shown by border weight and a tone pattern, not colour: Common, Fine, Rare, Signature.

Type: Bangers for display text (caps, manga headline), Builder Sans Bold for body, Roboto Mono for numbers. There's no emoji in the UI and no em dashes in copy.

Motion: the same tokens as before. Hits use impact frames: a 2-frame white or red flash and a speed-line overlay, both off with Reduce Motion.

Menus: one shell called the Ledger, drawn as a comic page, with five chunky tabs (ME, STORE, JOBS, MAP, SHOP) and Settings behind a small button. It is built for kids: one big number or one big button per panel, two or three words of copy, controls shown as key caps, never a paragraph where a sticker will do.

## Controls

| Action | PC | Gamepad | Touch |
| --- | --- | --- | --- |
| Light attack | Left click | X | Attack button (tap) |
| Heavy attack | Right click | Y | Attack button (hold) |
| Grab / drop prop | E | RB | Grab button |
| Throw | Q | RT | Throw button |
| Dodge | Left Shift | B | Dodge button |
| Catch / parry | F | LB | Parry button |
| Go Serious | R (when Focus is full) | LT | Focus meter |
| Ledger | Tab or M | Start | Menu button |
| Back / close | Esc | B (menu open) | Close button |
| World prompts (serve, restock, travel) | G | D-pad up | Tap prompt |
| Admin panel (admins only) | Backquote | | |

## Sound slots

`ui_hover`, `ui_open`, `ui_close`, `ui_tab`, `ui_confirm`, `ui_error`, `ui_purchase`, `reward_common`, `reward_rare`, `level_up`, `swing_light`, `swing_heavy`, `hit_light`, `hit_heavy`, `prop_break`, `throw`, `catch`, `dodge`, `ko`, `serious_on`, `serious_off`, `register`, `restock`, `bounty_up`. Paste asset IDs into `Config.SOUNDS`.

## Open questions

- Final name: is "Clocked Out" the one?
- Art direction: cel-shaded toon outline (recommended for Ink Panel) or plain low-poly?
- Crew companions: AI fighters or loadout abilities only?
- PvP: opt-in bounty duels only, or open PvP in some districts?
