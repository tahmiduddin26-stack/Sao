# Research: a Sakamoto Days style Roblox game

Date: 19 November 2026. Working title: **Clocked Out**. This name is a placeholder.

**Decided (19 Nov 2026):** hook = "A retired hitman runs a corner store, and everything on the shelves is a weapon." UI theme = **Ink Panel**.

## 1. The source in one page

**Sakamoto Days** is a manga by Yuto Suzuki that runs in Weekly Shonen Jump (2020 to 2026). The anime is made by TMS Entertainment and streams on Netflix.

- **Premise:** Taro Sakamoto was the most feared hitman alive. He fell in love, retired, got married, had a daughter and gained a lot of weight. Now he runs a small neighbourhood convenience store. When a huge bounty is put on his head, every assassin in the country comes to his shop. He fights them all without breaking his promise to his wife: **no killing**.
- **Tone:** action comedy with a family at its heart. The violence is fast and cartoonish. The jokes come from the gap between a quiet shopkeeper and absurd fighting skill.
- **Signature combat:** he fights with whatever is nearby: a pen, a can of beans, a mop, a shopping bag, a shelf, a car. Fights move through the space the way Jackie Chan fights do. Reviewers single out this "anything is a weapon" choreography as the show's identity.
- **The body gag:** he is heavy and calm most of the time. When he gets serious, he briefly slims down into his old hitman form.
- **Cast archetypes (for game design only):** a young ex-hitman who reads minds and becomes the hero's sidekick, a mafia heiress who uses a drunken-fist style, a sniper with a pet bird, a cheerful scheming rival, a split-personality villain, and an elite circle of top-ranked assassins who serve the assassins' association.
- **Arc shapes:** shop defence, a bounty hunt across town, an amusement park, a death-row prison break, a laboratory, an assassin academy entrance exam with a plane fight, and a long-running infiltration.

### Timing (this matters for launch)

| Date | Event |
| --- | --- |
| 22 to 23 Nov 2026 | Manga ends with chapter 284 (31 volumes) |
| 18 Jan 2027 | Anime Season 2 premieres on TV Tokyo and streams worldwide on Netflix (JCC infiltration arc, the young Sakamoto backstory) |

Search interest will spike twice in the next two months. **Recommended target: a playable launch before 18 January 2027**, with an update timed to the second half of Season 2.

### Competition on Roblox

- There is no official Sakamoto Days game on Roblox. A character from the series appears as a unit in Anime Reborn, a general anime tower-defence game.
- Shueisha has started licensing Jump series to Roblox (Gintama and Black Clover). An official Sakamoto Days game is possible, so a project that copies the series directly risks a takedown.
- Off Roblox, there is an official mobile puzzle game (Dangerous Puzzle, Japan, April 2025), an announced mobile RPG, and small fan games on itch.io.

## 2. The IP line (read this first)

Copying the series directly would mean using its names, characters, faces, logo, music or exact scenes. That puts the game at risk of a DMCA takedown, which deletes the place along with its revenue and players, and of losing the Roblox account. I can't build a direct copy.

**Recommendation:** build an **original game in the same genre**. Keep the things that make the anime fun: a retired hitman, a shop as home base, everyday objects as weapons, a no-kill rule, a growing bounty, an elite assassin circle and absurd action comedy. Every name, character and design must be our own. Fans will still recognise the vibe, and the game stays ours to keep and monetise. If an official licence ever becomes possible, this design can take one.

## 3. What carries over from Sword Blox Online

Most of the sao2 base is game-agnostic, so the new game forks it rather than starting from zero.

| sao2 module | In the new game |
| --- | --- |
| `DataService` (session locks, receipts, failed-load save block) | Copied unchanged, with a new `DATASTORE_NAME` |
| `MonetizationService`, `AdminService`, `Analytics`, `DailyService`, `SettingsService` | Copied, with new product lists |
| `QuestService` + `QuestLint` (seven quest rules) | Copied. Quests become **Jobs**, and the seven rules still apply |
| `FloorService` + `Config.FLOORS` + `WorldBuilder` | Becomes `DistrictService` + `Config.DISTRICTS`: each district is an arc with a boss |
| `ProgressionService` (levels, stat points) | Kept. Stats become Power / Speed / Instinct |
| Ledger menu shell, UI kit, Motion, Toasts, Banners, Router | Kept. Re-themed, with tabs renamed |
| Sword Skills, SP segments, MP, spells | Replaced by prop combat, the Focus meter and Instinct |
| Floors 1 to 100 climb | Replaced by the bounty rank climb (see 4.6) |

Roughly 60% of the 6.5k lines carry over. The new work is combat, props, the shop and the bounty system.

## 4. Pillars mapped to mechanics

### 4.1 Anything is a weapon (core pillar)

The world is full of physics props. Walk over a prop and press the pick-up key to wield it, or throw it. Every prop belongs to a **class**, and the class sets its moveset, so we can add hundreds of props without animating each one.

| Class | Examples | Light / heavy | Throw | Special |
| --- | --- | --- | --- | --- |
| Pocket | pen, chopsticks, keys, ruler | fast jabs that **pin** enemies | flick, causes a short stagger | Disarm |
| Blunt | can, frying pan, bottle, kettle | combo of 3, heavy knockdown | arcing lob | Ricochet off walls |
| Reach | mop, broom, umbrella, pole | sweeping, hits groups | spear throw | Vault (movement) |
| Big | chair, cart, sign, vending machine | slow, wide, armour-breaking | bowling roll | Shield block |
| Soft | shopping bag, towel, apron | grab and spin | net throw that slows | Sling (adds power to the next throw) |

- **Durability:** props break after N hits. The game always wants you to grab the next thing, which recreates the anime's flow.
- **Catch:** a well-timed parry catches a thrown prop or projectile and gives it back to you as a free weapon.
- **Environment takedowns:** a prompt appears near shelves, fridges, doors and vending machines (kick the shelf over, slam the door).
- **Style score:** variety beats spam. Using a new prop class in a combo multiplies the reward.

### 4.2 Off duty / Serious (the body gag as a mechanic)

Every character has a **Focus** meter that fills from clean hits, catches and dodges.

- **Off duty (default):** heavier, slower and tankier, with a little damage reduction. This is the comedy state.
- **Serious (Focus full):** the character turns sleek for 12 seconds, with higher speed, a dash cancel, unique finishers and a stylised screen tint. This is the hype state.

It gives every fight a rhythm of build, pop and climax, and it shows up well in clips.

### 4.3 The promise (no-kill rule)

Enemies are **knocked out**, never killed. KO'd enemies are zip-tied and handed to "the cleanup crew", which gives a bonus. This fits Roblox's mild-violence rating (no blood, no deaths, tranquillizer or rubber rounds for any guns) and keeps the tone right.

### 4.4 The Shop (home base and idle loop)

Every player owns a **corner store**, a personal plot like a tycoon. Customers come in to buy, stock runs out, and you restock and upgrade shelves, fridges, signs and the counter. Some customers are **assassins in disguise**: a tell in their animation shows it, the store goes into a lockdown fight, and your own shelves become the weapon rack.

- Restocking feeds the combat loop: what you stock is the weapon pool for home fights.
- Store upgrades are permanent progression and the main cosmetic sink.
- Visiting other players' stores and the shop leaderboard give the social side.

### 4.5 Crew (party plus companion archetypes)

These are original characters built on the anime's roles. You recruit them through Jobs, and they fight beside you as NPCs or as your loadout ability:

| Archetype | Ability |
| --- | --- |
| The Reader (telepath) | Shows enemy attack intent half a second early, a telegraph overlay |
| The Marksman (sniper with a pet) | Marks a target. A delayed rubber round staggers it |
| The Drunken Fist | Erratic dodge window, then counter-strikes |
| The Showman (cheerful rival) | Decoy clone that pulls aggro |

Real players party up using the sao2 party design.

### 4.6 Bounty (the climb that replaces 100 floors)

Your **bounty** goes up as you win and drops on a KO. It sets your **rank tier**, and rank tiers unlock districts:

1. Shopping street (tutorial, shop defence)
2. Downtown bounty hunt
3. Amusement park
4. Maximum-security prison break
5. Underground lab
6. Assassin academy entrance exam (includes a fight on an aircraft)
7. The Eleven: the elite circle, one boss per week in rotation

Each district is a `Config.DISTRICTS` entry. It has its own hub, open area, an instanced Job run and a boss with phases, each phase built around a prop gimmick.

**Hunter events:** while you're online, hunter squads sized to your bounty tier sometimes raid your store. **Bounty Board PvP:** opt-in duels. Beating a higher bounty takes a share of it.

## 5. Loops and numbers (first pass)

| Loop | Length | Contents |
| --- | --- | --- |
| Fight | 30 to 60 s | Grab, combo, catch, Serious, KO |
| Shift | 5 to 8 min | Restock, serve, defend against a disguised assassin |
| Session | 15 to 40 min | Shift, then a Job in a district, then a boss attempt |
| Day | daily | Streak, 3 Jobs, Hunter event |
| Week | weekly | Eleven boss rotation, bounty leaderboard reset |

- First 60 seconds: spawn in your store, and a "customer" pulls a knife. A pen glows on the counter, so you grab it and the first fight is under way.
- Stats: Power (damage, prop durability), Speed (move speed, combo speed), Instinct (catch window, Focus gain). That's 3 points per level, reusing `Config.xpToNext`.
- Currency: **Cash** (earned in the shop and from Jobs). No paid currency.

## 6. Monetisation (no paid power over the climb)

| Type | Item | Draft |
| --- | --- | --- |
| Pass | 2x Cash | 199 |
| Pass | 2x XP | 199 |
| Pass | Auto Restock | 249 |
| Pass | VIP Shelf (exclusive prop skins) | 149 |
| Pass | Tailored Suit (Serious-mode cosmetic) | 299 |
| Product | Cash pack (scales with progress) | 25 to 399 |
| Product | Lucky Delivery (rare prop drops, 15 min) | 49 |
| Product | Server-wide Big Sale (2x Cash for everyone, stacks per purchase) | 99 |
| Product | Bounty Shield (no bounty loss on the next KO) | 35 |

## 7. Retention

Playtime gifts (1, 3, 5, 8, 12, 16, 20 min), a 7-day streak, codes, a global bounty leaderboard on an in-world board, 20-player servers, the weekly Eleven rotation, and seasonal events timed to Season 2 episode drops.

## 8. Controls

| Action | PC | Gamepad | Touch |
| --- | --- | --- | --- |
| Light / heavy | LMB / RMB | X / Y | Attack button (tap / hold) |
| Pick up / drop | E | RB | Grab button |
| Throw | Q | RT | Throw button |
| Dodge | Space (in combat), Shift | B | Dodge button |
| Catch / parry | F | LB | Parry button |
| Go Serious | R (when full) | LT + RT | Focus meter tap |
| Crew ability | 1 to 2 | D-pad | Crew button |
| Ledger | Tab | Start | Menu |

## 9. Theme candidates

- **Price Tag:** the UI looks like receipts, price stickers and shop signage. Cream paper, ink black and a stamp red. It is warm and funny and fits the shop identity.
- **Ink Panel:** the UI looks like manga pages. Black and white with screentone, one red accent and panel-cut transitions. It is stylish and fits the action best.
- **Lanternsteel (current sao2):** reuse it as is. This is the fastest option, but it reads as fantasy, not as a street-level comedy.

## 10. Risks

- **IP:** handled by staying original (section 2). No characters, names, logo or music from the series, and nothing taken from its key art.
- **Combat feel is the whole game.** Build it first in a greybox and playtest before any content.
- **Physics props at scale:** cap the live props in each district, have the server own every hit, keep visual-only debris on the client, and pool props.
- **The deadline is tight** (8 weeks to Season 2). MVP scope: districts 1 to 2, 5 prop classes, the shop, bounty, 2 crew and 1 Eleven boss.

## Sources

- [What's on Netflix: Season 2 date](https://www.whats-on-netflix.com/news/anime/sakamoto-days-season-2-netflix-release-date/)
- [ComicBook: Season 2 date ahead of the Jump finale](https://comicbook.com/anime/news/sakamoto-days-season-2-confirms-release-date-ahead-of-shonen-jump-finale-watch-trailer/)
- [Soap Central: Season 2 trailer](https://www.soapcentral.com/anime/news-sakamoto-days-season-2-trailer-confirms-january-18-release-date-cast)
- [Purebreak: manga ends at chapter 284](https://www.purebreak.com/news/dans-5-jours-ce-manga-aux-18-millions-dexemplaires-en-circulation-va-sarreter-au-chapitre-284-2-mois-avant-la-saison-2-de-son-anime/266793)
- [Otakukart: 18 million copies](https://otakukart.com/sakamoto-days-reaches-276-chapters-and-18-million-sales-across-28-volumes-as-manga-nears-its-ending/)
- [Den of Geek: the everyday weapons](https://www.denofgeek.com/tv/sakamoto-days-taro-sakamoto-creative-weapon-choices/)
- [But Why Tho: episode 17 review](https://butwhytho.net/2025/08/sakamoto-days-episode-17-review)
- [Wikipedia: Sakamoto Days](https://en.wikipedia.org/wiki/Sakamoto_Days)
- [Pro Game Guides: the unit in Anime Reborn](https://progameguides.com/roblox/how-to-get-secret-unit-retired-assassin-sakamoto-in-anime-reborn)
- [Complex: Shueisha licensing to Roblox](https://www.complex.com/pop-culture/a/treyalston/gintama-roblox-game-waka-black-clover)
- [Anime Corner: official mobile game](https://animecorner.me/sakamoto-days-launches-first-smartphone-game-in-spring-2025-pre-registrations-open/)
