# BUILD-PHASES.md — Junk or Jackpot

Fourteen phases in four milestones. Each phase has a goal, a scope, a hard "do not build" list, and exit criteria you can verify by playing. **A phase is not done until every exit criterion passes and the regression checklist for all prior phases still passes.**

Specification: `junk-or-jackpot-GDD.md`. Section references below point into it.

---

## How to use this

One phase per session, or per few sessions. At the start of a session:

> Read CLAUDE.md and BUILD-PHASES.md. We are on Phase N. Build only Phase N. Stop when its exit criteria are met and tell me how to test it.

At the end of a phase, run the tests yourself in Studio. If something fails, report the observed behaviour — not a guess at the cause:

> Phase N test 3 failed. I did X, expected Y, got Z instead. Fix it and tell me what was wrong.

Do not advance until every box is ticked. The whole point of phasing is that a bug found in Phase 4 is ten minutes of work; the same bug found in Phase 12 is a day.

---

# MILESTONE A — Foundations (Phases 0–3)
*Goal: a grey brick you can dig up, sell, and still own after a restart.*

---

## Phase 0 — Scaffold and data

**Goal:** every folder, every constant, every data table in place. Zero gameplay.

**Build:**
- Folder structure per GDD §12.1 (create all folders, even empty ones)
- `Main.server.lua` — requires services in explicit order, currently an empty list
- `Config.lua` — every constant from GDD §13, exactly as written
- `ZoneTable.lua` — all 5 zones per GDD §3 (name, unlock cost, requirement, dig time, value multiplier, open cost, grade mix)
- `GradeTable.lua` — the four rarity tables per GDD §4.2 *(scaffold only — owner fills the weights)*
- `HintTable.lua` — grade → hint distributions per GDD §4.7
- `ItemTable.lua` — all 60 items per GDD §4.6 *(scaffold only — owner fills)*
- `BucketEV.lua` — the 5×3 blind offer lookup per GDD §5.3

**Do not build:** any service, any remote, any UI, any part in the workspace.

**Exit criteria:**
- [ ] Game starts with no errors in the output window
- [ ] In the command bar, `require(game.ReplicatedStorage.Modules.Config).BLIND_RATIO` returns `0.7`
- [ ] `require(game.ReplicatedStorage.Modules.ItemTable)` returns a table with exactly 60 entries
- [ ] Every one of the four grade tables in `GradeTable.lua` sums to exactly 10000 (write a throwaway command-bar loop to check — this catches typos that would silently skew every roll in the game)
- [ ] Every zone's grade mix in `ZoneTable.lua` sums to exactly 100

---

## Phase 1 — Dig interaction

**Goal:** hold a key, get a brick.

**Build:**
- One baseplate, one trash mound, one dig spot Part with a ProximityPrompt (3.0s hold, from `ZoneTable`)
- `DigService` — handles `RequestDig`, spawns a grey Part welded to the player's hand
- `RequestDig` remote with server-side cooldown validation (`digTime + DIG_COOLDOWN_GRACE`)
- A temporary DESTROY button that deletes the held lump

**Do not build:** hints, grades, coins, selling, UI beyond the one button.

**Exit criteria:**
- [ ] Holding E for the full duration spawns a grey lump in your hands
- [ ] Releasing E early spawns nothing
- [ ] You cannot hold a second lump while holding one
- [ ] DESTROY removes it and you can dig again
- [ ] **Break test:** fire `RequestDig` twice in a row from the command bar. Second call is rejected server-side, no second lump appears.

---

## Phase 2 — Persistence

**Goal:** a number that survives a restart. Built before anything depends on it, deliberately.

**Build:**
- ProfileStore installed and wired
- `PlayerDataService` — load on join, release on leave, autosave every 60s
- Profile template exactly as GDD §11, including `dataVersion = 1`
- A temporary command-bar function to set `coins` manually

**Do not build:** earning coins, spending coins, any other profile field logic.

**Exit criteria:**
- [ ] Join, set coins to 500 via the command bar, leave, rejoin — coins are still 500
- [ ] Force-quit Studio mid-session (close the window, don't stop the game), rejoin — coins are preserved from the last autosave
- [ ] Output shows a profile load message on join and a release message on leave
- [ ] Two players in a Studio test server have independent, non-colliding profiles

> **Do not move past this phase until it is bulletproof.** Data loss after launch is unrecoverable and kills a game permanently. Spend the extra hour here.

---

## Phase 3 — Economy and selling

**Goal:** dig, sell, coins go up, coins persist.

**Build:**
- `EconomyService` with `AddCoins(player, amount, reason)` and `RemoveCoins(player, amount, reason)`, both logging the reason
- Coins on the leaderstats
- Replace DESTROY with a SELL button granting a flat 40 coins
- `CoinsChanged` remote firing to the client on every balance change

**Do not build:** blind pricing, open cost, items, hints.

**Exit criteria:**
- [ ] Dig → sell → leaderstats coins increase by exactly 40
- [ ] Coin total persists across a rejoin
- [ ] `RemoveCoins` refuses to take a player below zero and returns `false`
- [ ] Every balance change prints a line naming the reason
- [ ] **Break test:** fire `RequestSellBlind` with no lump held. Nothing happens, no coins granted, no error thrown.

**Regression check:** Phases 1–2 criteria all still pass.

---

# MILESTONE B — The core mechanic (Phases 4–6)
*Goal: the actual game exists.*

---

## Phase 4 — Grade roll and hints

**Goal:** every lump is secretly graded, and leaks three noisy clues.

**Build:**
- `LumpService.rollGrade(player, zone)` — uniform roll, luck transform `u^(1/(1+L))`, cumulative grade selection per GDD §4.8 steps 1–3
- `LumpService.generateHints(grade)` — three independent draws from `HintTable`
- Active lump stored **server-side** per player: grade, zone, hints, hintScore, lumpId
- Hints sent to the client and displayed under the lump as three words
- Luck read from the profile and clamped to `LUCK_CAP`

**Do not build:** the tier roll, item selection, blind pricing, open cost.

**Exit criteria:**
- [ ] Every dig shows three readings, e.g. `SOLID · COLD · DULL`
- [ ] Command-bar loop of 10,000 grade rolls at L=0 produces roughly 40/38/18/4 (±1.5%)
- [ ] Same loop at L=1.0 produces visibly more Promising and Charged, and Dud drops to roughly 20%
- [ ] Force a Dud in code and dig 20 times — hints skew heavily toward Low
- [ ] Force a Charged and dig 20 times — hints skew heavily toward High
- [ ] **Break test:** the client cannot read the grade. Search the client scripts for the word "grade" — it should not appear. Check the remote payload contains hints only.

---

## Phase 5 — The decision

**Goal:** the differentiator. Two buttons, real math behind them.

**Build:**
- Blind offer computed server-side from `BucketEV[zone][bucket]` × `BLIND_RATIO`, per GDD §5.3
- Open cost from `OPEN_COST_RATIO × BlendedEV[zone]`, per GDD §5.4
- `effectiveOpenCost = openCost × profile.coinMultiplier` — **wire this now even though `coinMultiplier` is always 1 until Phase 13.** Retrofitting it later is how the balance leak in GDD §10.1 ships by accident.
- Two-button prompt showing both numbers
- `RequestSellBlind` → grants the blind offer, clears the lump
- `RequestOpen` → deducts the fee, rolls tier from the grade's rarity table, picks an item uniformly from that tier's items in the current zone
- `freeOpensLeft` countdown from 3, open cost displayed as 0 while it lasts
- Reveal UI: item name, rarity, rarity colour, value

**Do not build:** catalogue, inventory, keep/sell, shelf. Revealed items sell automatically for now.

**Exit criteria:**
- [ ] Zone 1 blind offers read exactly 40 (LOW), 140 (MID), 525 (HIGH) — check each bucket by digging until you see all three
- [ ] Open cost reads 45 after the three free opens are used
- [ ] The first three opens of a fresh profile cost nothing
- [ ] Command-bar loop: 10,000 opens at Zone 1 produce tier frequencies matching GDD §4.4 Zone 1 column (±0.5% on the common tiers)
- [ ] Opening with insufficient coins is refused, with a clear message
- [ ] **Break test:** fire `RequestOpen` with a `lumpId` you made up. Rejected, no coins deducted, no item granted.
- [ ] **Break test:** fire `RequestOpen` twice with the same valid `lumpId`. Second call rejected.

**Regression check:** Phases 1–4 all still pass.

> **Stop and play for 20 minutes here.** This is the whole game. If choosing between the two buttons isn't interesting with grey bricks and no catalogue, no amount of Phase 6–14 work will save it. If it *is* interesting, everything after this is decoration and you're building the right thing.

---

## Phase 6 — Catalogue and inventory

**Goal:** finding a new thing feels different from finding the same thing again.

**Build:**
- Catalogue writes on reveal, data shape exactly per GDD §8.1
- `catalogueCount` cached and kept in sync
- Catalogue UI: 60 slots, silhouettes for unfound, full detail on found
- Inventory: revealed items go to inventory, not auto-sold
- KEEP / SELL prompt after every reveal
- `RequestSellItem` with index validation

**Do not build:** shelf placement, milestone rewards, shelf slots.

**Exit criteria:**
- [ ] First time you find an item, the catalogue slot fills and the reveal says NEW
- [ ] Second time, `count` increments and it does not say NEW
- [ ] `bestValue` updates only when you find a higher-value roll of the same item
- [ ] Catalogue survives a rejoin
- [ ] Unfound items show as silhouettes with the name hidden
- [ ] **Break test:** `RequestSellItem` with index 999. Rejected, no coins granted.

---

# MILESTONE C — Progression and social (Phases 7–11)
*Goal: reasons to keep playing and reasons other players matter.*

---

## Phase 7 — Upgrades and Zone 2

**Goal:** buying something visibly changes how the game plays.

**Build:**
- `UpgradeService` — Steel and Reinforced shovels per GDD §7.1, with prerequisite checks
- Dig time multiplier applied server-side
- Luck recalculated on every upgrade from all sources, clamped to `LUCK_CAP`
- Zone 2 dig region, gated on 25,000 coins **and** 5 catalogue entries
- Zone teleport or region gating
- Shop UI

**Do not build:** Zones 3–5, Powered/Excavator shovels, shelf slots.

**Exit criteria:**
- [ ] Steel Shovel costs 8,000 and reduces dig time to 2.25s
- [ ] Reinforced costs 100,000, reduces to 1.8s, and raises Luck to 0.15
- [ ] You cannot buy Reinforced without owning Steel
- [ ] Zone 2 is refused at 25,000 coins with only 4 catalogue entries
- [ ] Zone 2 blind offers read 125 / 435 / 1,630 and open cost reads 125
- [ ] Zone 2 drops items that cannot appear in Zone 1
- [ ] Upgrades persist across a rejoin
- [ ] **Break test:** fire `RequestBuyUpgrade` for tier 4 while on tier 1. Rejected.

---

## Phase 8 — Announcements

**Goal:** other players' luck becomes visible.

**Build:**
- `AnnounceService` — Epic+ threshold, message format per GDD §9.1
- Rate limiting: max 1 per player per 60s, max 6 per server per minute
- Mythic gets the gold border and distinct sound; Relic bypasses the rate limit entirely

**Do not build:** MessagingService cross-server (that's Phase 14), Hall of Finds.

**Exit criteria:**
- [ ] Force an Epic roll — a chat line appears with the exact GDD §9.1 format
- [ ] Force 10 Epics in 30 seconds from one player — only one announcement fires
- [ ] Force a Mythic during a rate-limit cooldown — it announces anyway
- [ ] Good/Rare pulls produce no announcement

---

## Phase 9 — The blind-sale bin

**Goal:** the highest value-per-line feature in the game. Do not cut it.

**Build:**
- Server-scoped bin table, 12 slots FIFO, never persisted, cleared on shutdown
- Blind-sold lumps push to the bin with grade, zone, hints, price, seller name and id
- Bin UI showing hints, price (2× seller's blind price), zone, seller name — **and nothing else**
- `RequestBuyBin` — validates `sellerId ~= buyerId`, not expired, buyer can afford it
- Purchase rolls immediately using the stored grade; no second open fee
- Result announced in chat naming both players, regardless of rarity
- 180-second expiry

**Do not build:** persistence of the bin across servers, any bin history.

**Exit criteria:**
- [ ] Two-player Studio test: player A sells blind, the lump appears in player B's bin at exactly 2× A's payout
- [ ] Player A cannot see their own lump as purchasable
- [ ] Player B buys it, gets an item, chat names both players
- [ ] Player A's coin balance does not change when B buys
- [ ] A 13th blind sale pushes the oldest lump out of the bin
- [ ] Lumps disappear from the bin after 180 seconds
- [ ] **Break test:** the bin payload sent to the client contains no grade and no resolved item. Inspect the remote payload directly.
- [ ] **Break test:** player A fires `RequestBuyBin` on their own lump id. Rejected.

**Regression check:** Phases 1–8 all still pass.

---

## Phase 10 — Shelf and warehouse

**Goal:** status becomes visible and permanent.

**Build:**
- Shared warehouse with 24 numbered plots, assigned on join
- 12 base display slots, expandable with coins per GDD §7.3 (`1000 × 1.7^n`)
- `RequestPlaceShelf` / remove — placing removes the item from sellable inventory
- Shelf state replicated to every client in the server
- Hovering another player's item shows name, rarity, value, owner

**Do not build:** shelf income, mall rent, cross-server shelves.

**Exit criteria:**
- [ ] Placing an item on the shelf removes it from inventory and you can no longer sell it
- [ ] Two-player test: player B can walk to player A's plot and read every item on it
- [ ] Shelf contents persist across a rejoin
- [ ] Slot 13 costs 1,700 and slot 14 costs 2,890
- [ ] **Break test:** `RequestPlaceShelf` into slot 40 while owning 12. Rejected.

---

## Phase 11 — Zones 3–5 and remaining shovels

**Goal:** the full progression curve.

**Build:**
- Zones 3, 4, 5 with their gates, regions, BucketEV rows and open costs
- Powered Shovel and Excavator, including the Excavator's 2-lumps-per-dig
- All remaining items unlocked in their correct zone pools

**Do not build:** prestige, seasonal pools.

**Exit criteria:**
- [ ] Each zone's blind offers and open cost match the GDD §5.3 and §5.4 tables exactly
- [ ] Zone gates refuse entry when either the coin cost or the catalogue requirement is unmet
- [ ] Excavator produces exactly 2 lumps per dig, each independently rolled
- [ ] All 60 items are reachable — write a command-bar loop that rolls 200,000 times across all zones and confirms every item id appears at least once
- [ ] Zone 5 blind offers read 1,720 / 6,500 / 18,100 and open cost reads 2,800

---

# MILESTONE D — Retention, money, ship (Phases 12–14)

---

## Phase 12 — Retention systems

**Build:**
- `DailyService` — Golden Lump, 20-hour cooldown, Charged grade rerolled until Rare or better
- Catalogue milestones at 10/25/40/60 — coins per GDD §5.2, +0.03 Luck each
- `LeaderboardService` — weekly Best Find on OrderedDataStore, Monday 00:00 UTC reset
- Relic Shards: 1 per Mythic, 10 per Relic, +0.02 Luck each, capped at +0.40

**Exit criteria:**
- [ ] Golden Lump claimable once, then locked for 20 hours; manipulate `lastGoldenLump` to test
- [ ] Golden Lump never produces Scrap, Common, or Good — loop it 500 times to confirm
- [ ] Hitting 10 catalogue entries pays 5,000 coins and raises Luck by 0.03, exactly once
- [ ] A Mythic pull grants exactly 1 Relic Shard; a Relic grants 10
- [ ] Luck stops rising after 20 shards
- [ ] Best Find board shows the correct top value and resets on the week boundary

---

## Phase 13 — Monetization

**Build:** all six gamepasses and six dev products per GDD §10.

**Exit criteria:**
- [ ] **`effectiveOpenCost` doubles when 2× Coins is active.** Verify by owning the pass and reading the open cost — Zone 1 must show 90, not 45. This is the balance leak from GDD §10.1 and it is the single most important test in this phase.
- [ ] Scanner adds a 4th hint and the bucket table extends to LOW 0–2 / MID 3–5 / HIGH 6–8
- [ ] Lucky Charm raises Luck by exactly 0.10 and stacks correctly with shovel and shard luck, still clamped at `LUCK_CAP`
- [ ] Auto-Dig repeats the dig but still requires a tap for the decision
- [ ] Zone Skip waives the coin cost but **not** the catalogue requirement
- [ ] Big Shelf grants exactly 10 extra slots
- [ ] Passes persist and re-apply correctly on rejoin

---

## Phase 14 — Hardening and ship

**Build:**
- Rate limiting on every remote (`MAX_REMOTE_PER_SEC`)
- `TelemetryService` — log every decision as `{userId, zone, hintScore, choice, timestamp}` per GDD §6.5
- MessagingService for cross-server Relic announcements
- Reveal sound design
- Icon and thumbnail — **show the two buttons, not the lump**
- Final pass: search every service file for numeric literals and move any survivors to `Config.lua`

**Exit criteria:**
- [ ] Spamming any remote 50×/second is throttled and does not corrupt state
- [ ] Telemetry rows land and can be read back
- [ ] A Relic in one server announces in all servers
- [ ] Grep every file under `Services/` for digits — no gameplay number appears outside `Config.lua` or a data module
- [ ] Full playthrough from a fresh profile to Zone 3 with no errors in output

---

# Regression checklist

Run this at the end of every phase from Phase 5 onward. Takes about four minutes.

1. Fresh profile: dig, see hints, both buttons show correct numbers for the current zone
2. Sell blind → coins increase by the displayed offer exactly
3. Open → coins decrease by the displayed cost exactly, an item appears
4. New item → catalogue fills; duplicate → count increments
5. Rejoin → coins, catalogue, upgrades, zone, shelf all preserved
6. Two-player: announcements fire, bin works, shelves are visible to each other
7. Output window is clean — no warnings, no errors

---

# Order dependencies

Do not reorder these. Each depends on the one before it.

```
0 Scaffold
└ 1 Dig
  └ 2 Persistence          ← everything downstream writes to the profile
    └ 3 Economy            ← the only coin mutator
      └ 4 Grade + hints    ← the hidden layer everything reads
        └ 5 THE DECISION   ← the game. stop and play here.
          ├ 6 Catalogue
          ├ 7 Upgrades + Zone 2
          │ └ 11 Zones 3-5
          ├ 8 Announcements
          │ └ 9 Bin        ← needs announcements
          └ 10 Shelf
            └ 12 Retention
              └ 13 Monetization
                └ 14 Ship
```
