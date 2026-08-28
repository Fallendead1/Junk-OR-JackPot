# JUNK OR JACKPOT — Game Design Document v1.0

**Platform:** Roblox / Luau
**Team:** 1–3, beginner-to-intermediate scripting
**MVP scope:** 7 part-time weeks
**Status:** build spec. Every number below is canonical unless marked as a tunable constant in §13.

> **Revision note vs. earlier design notes.** The flat rarity table from the original outline (45/33/15/5/1.6/0.35/0.05) is not used. It produced a Zone 1 mean of ~500 coins against a median of 75, which makes blind-selling correct in nearly every case and collapses the core decision. Everything here is rebuilt on a hidden **Grade** layer that sits between the dig and the rarity roll. Grade is what the hints leak, Grade is what luck modifies, and Grade is what makes the decision real. All economy figures in this document are derived from and cross-checked against that structure.

---

## 1. High-level overview

**Pitch.** You dig sealed, filthy lumps out of a landfill. Every lump shows you three ambiguous readings — weight, temperature, sheen — and then makes you choose: sell it unopened for a guaranteed price, or pay a fee to open it and find out what you actually had. Most lumps are junk. A few are worth a fortune. You will sell a Relic for 40 coins at some point, and you will never forget it. Coins buy shovels and deeper zones that shift the odds; found items fill a 60-slot catalogue and sit on a shelf other players can walk past.

**Core fantasy, one sentence:** *"I can read these. I know which ones to open."* (They can't, quite. That's the game.)

**Target session length:** 18–25 minutes. Cycle time is 4–5 seconds, so a session is ~250–350 decisions.

**Sessions before hooked:** 3. Session 1 delivers the first Rare and the first server announcement. Session 2 delivers the Steel Shovel and the first deliberate strategy ("I only open Mid-bucket lumps with 3+ high hints"). Session 3 delivers the first Epic and the first catalogue milestone. If a player reaches session 3, retention data on comparable value-discovery games suggests they stay for weeks.

**Full progression length:** ~4.5 hours to max shovel and final zone. Catalogue completion (60/60) is intentionally a 200+ hour chase and is not expected to be completed by most players.

---

## 2. Core gameplay loop

### Moment-to-moment (4–5 seconds)

```
Hold E on a dig spot  →  lump spawns in hands with 3 hint readings
        ↓
Read hints (Weight / Temperature / Sheen, each Low / Mid / High)
        ↓
Choose: [SELL BLIND — fixed offer]  or  [OPEN — fixed fee]
        ↓
If OPEN: reveal animation → item name, rarity, value
        ↓
If new item: catalogue slot fills
        ↓
Choose: KEEP (shelf) or SELL (coins)
        ↓
Repeat
```

### Session loop (18–25 minutes)

Dig ~300 lumps → accumulate coins → afford one meaningful upgrade (a shovel tier or a zone unlock) → the odds visibly shift → dig at the new distribution → hit 1–3 announcements → log off with a catalogue that has more filled slots than when you started.

### Meta loop (days/weeks)

Claim the Daily Golden Lump → chase the specific empty silhouettes in the catalogue → return to lower zones for zone-exclusive items you skipped → climb the weekly Best Find board → accumulate Relic Shards for permanent luck.

### First 60 seconds, click by click

| Time | What happens |
|---|---|
| 0:00 | Spawn facing a trash mound. One glowing dig spot. Prompt reads **[E] DIG**. No tutorial text anywhere on screen. |
| 0:03 | Player holds E for 3.0s. Progress ring fills. |
| 0:06 | A grey lump appears in the player's hands. Three readouts fade in under it: `SOLID · COLD · DULL`. Two buttons: **SELL BLIND — 40** and **OPEN — 45**. |
| 0:09 | Player taps OPEN (curiosity always wins the first one). 45 coins deducted from a balance of 0 — balance goes to −45? **No.** First 3 lumps of a new profile have `openCost = 0`. This is the only tutorial in the game. |
| 0:11 | Reveal: `Cracked Bottle — SCRAP — 11 coins`. Catalogue pips to 1/60. |
| 0:13 | Auto-prompt: **KEEP** or **SELL**. Player sells. Balance 11. |
| 0:18 | Second dig. Hints: `HEAVY · WARM · FAINT`. Free open. `Tin Lunchbox — COMMON — 38`. Balance 49. |
| 0:26 | Third dig. `LIGHT · HOT · SHIMMERING`. Free open. `Silver Locket — GOOD — 180`. Balance 229. Catalogue 3/60. |
| 0:34 | Fourth dig. Free opens are exhausted. The OPEN button now reads **OPEN — 45**. The player has just learned, without being told, that information costs money. |
| 0:40 | Hints read `LIGHT · COLD · DULL`. Blind offer: 40. Open: 45. The player makes the first real decision of the game. |
| 0:50 | Whatever they chose, a server message fires from someone else: `[!] xX_builderman_Xx pulled an EPIC — Sealed Wax Cylinder (8,300 coins) in The Dump!` The player now knows what they're playing for. |
| 0:60 | Fifth dig. Player is hooked or gone. |

---

## 3. Zones

| # | Name | Unlock cost | Unlock requirement | Base dig time | Value multiplier | Open cost | Grade mix (Dud/Plain/Prom/Chg) |
|---|---|---|---|---|---|---|---|
| 1 | The Dump | free | — | 3.0s | 1.0× | 45 | 40 / 38 / 18 / 4 |
| 2 | The Quarry | 25,000 | 5 catalogue entries | 3.5s | 2.2× | 125 | 32 / 40 / 22 / 6 |
| 3 | The Wreck | 150,000 | Steel Shovel + 15 entries | 4.0s | 5.0× | 360 | 24 / 41 / 26 / 9 |
| 4 | The Vault | 900,000 | Reinforced Shovel + 30 entries | 4.5s | 11.0× | 1,000 | 16 / 40 / 31 / 13 |
| 5 | The Crater | 5,000,000 | Powered Shovel + 50 entries | 5.0s | 24.0× | 2,800 | 8 / 36 / 38 / 18 |

**Why unlock requirements exist alongside cost:** a player who buys coin packs can reach Zone 5 in ten minutes, land in a distribution they don't understand, and churn. The catalogue requirement forces a minimum play time in the lower zones regardless of spend, which protects both the new-player experience and your monetization (a bored whale is a refunded whale).

**Why lower zones stay relevant:** 24 of the 60 catalogue items drop only in Zones 1–2. A player chasing 60/60 must go back. This gives Zone 1 permanent purpose and prevents the "dead starter area" problem.

**Cycle time** = dig time × shovel multiplier + 2.0s (decision + reveal + keep/sell). The 2.0s figure is measured from the interaction design, not assumed; if reveal animations run longer than 1.2s, cut them, because cycle time directly divides all income figures in §5.

---

## 4. Item and rarity system

### 4.1 The two-stage roll

The game does **not** roll rarity directly. It rolls a hidden **Grade** first, and the Grade selects which rarity table to use. This is the single most important structural decision in the design.

```
DIG
 ↓
Roll GRADE  (zone grade-mix, modified by player Luck)   → Dud / Plain / Promising / Charged
 ↓
Generate 3 HINTS from the Grade (noisy — this is what the player sees)
 ↓
[player decides]
 ↓
If OPEN: Roll TIER from the Grade's rarity table
 ↓
Pick ITEM uniformly from that tier's items available in the current zone
```

Grade exists so that hints can be *informative but not conclusive*. Without it, hints would either be noise (no skill) or a direct readout of the item (no gamble).

### 4.2 Grade → rarity weights (global, all zones)

Weights out of 10,000.

| Tier | Dud | Plain | Promising | Charged |
|---|---|---|---|---|
| Scrap | 7,500 | 4,500 | 1,500 | 0 |
| Common | 2,300 | 4,000 | 4,200 | 2,500 |
| Good | 180 | 1,300 | 3,200 | 4,200 |
| Rare | 18 | 180 | 900 | 2,400 |
| Epic | 2 | 19 | 180 | 750 |
| Mythic | 0 | 1 | 18 | 130 |
| Relic | 0 | 0 | 2 | 20 |
| **Total** | **10,000** | **10,000** | **10,000** | **10,000** |

### 4.3 Tier value bands (before zone multiplier)

| Tier | Value band | Midpoint (used in all EV math) | Colour |
|---|---|---|---|
| Scrap | 5 – 20 | 12.5 | `#6B6B6B` |
| Common | 30 – 120 | 75 | `#FFFFFF` |
| Good | 150 – 500 | 325 | `#4EC94E` |
| Rare | 600 – 1,800 | 1,200 | `#3B82F6` |
| Epic | 2,500 – 9,000 | 5,750 | `#A855F7` |
| Mythic | 15,000 – 60,000 | 37,500 | `#F59E0B` |
| Relic | 150,000 – 400,000 | 275,000 | `#EF4444` |

Final item value = band value × zone multiplier. All items in §4.6 are authored to hold their tier's mean within ±10% per zone, so the EV math below is accurate to within ~5%.

### 4.4 Derived blended rarity odds

Blending the grade tables by each zone's grade mix gives the actual odds a player experiences.

| Tier | Zone 1 | Zone 2 | Zone 3 | Zone 4 | Zone 5 |
|---|---|---|---|---|---|
| Scrap | 49.80% | 43.32% | 37.13% | 30.42% | 21.90% |
| Common | 32.96% | 33.51% | 33.75% | 33.36% | 31.63% |
| Good | 13.10% | 16.06% | 18.87% | 22.16% | 26.71% |
| Rare | 3.34% | 4.51% | 5.83% | 7.52% | 10.32% |
| Epic | 0.704% | 0.966% | 1.281% | 1.702% | 2.416% |
| Mythic | 0.088% | 0.122% | 0.164% | 0.222% | 0.323% |
| Relic | 0.0116% | 0.0164% | 0.0224% | 0.0308% | 0.0454% |

Zone 1 Relic rate is **1 in 8,621 lumps**. At 12 lumps/minute that is roughly 12 hours of continuous Zone 1 digging — which is why the two Zone-1-exclusive Relics are permanent chase items and why they must never be removed from the pool.

### 4.5 Grade expected values (base units, Zone 1)

| Grade | EV | Median outcome | Prior (Z1) |
|---|---|---|---|
| Dud | 35.79 | Scrap (12.5) | 40% |
| Plain | 114.15 | Common (75) | 38% |
| Promising | 471.38 | Good (325) | 18% |
| Charged | 1,912.00 | Good (325) | 4% |

**Note the gap between mean and median on every grade.** A Plain lump has an EV of 114 but a median outcome of 75. Opening a Plain lump is +EV *only because of the tail*. Players will feel this as "I keep opening and getting Commons" and it is the single most important emotional texture in the game. Do not flatten it.

Zone 1 blended EV = 0.40(35.79) + 0.38(114.15) + 0.18(471.38) + 0.04(1,912) = **219.02 coins**.

| Zone | Blended EV (base) | × mult | **Blended EV (coins)** |
|---|---|---|---|
| 1 | 219.02 | 1.0 | **219** |
| 2 | 275.53 | 2.2 | **606** |
| 3 | 350.03 | 5.0 | **1,750** |
| 4 | 446.08 | 11.0 | **4,907** |
| 5 | 567.23 | 24.0 | **13,614** |

### 4.6 Master item table (60 items)

| Item | Tier | Zone | Value |
|---|---|---|---|
| Bent Nail | Scrap | 1 | 6 |
| Cracked Bottle | Scrap | 1 | 11 |
| Soggy Newspaper | Scrap | 1 | 15 |
| Chewed Wire | Scrap | 2 | 22 |
| Rusted Bolt | Scrap | 2 | 35 |
| Barnacle Clump | Scrap | 3 | 55 |
| Shredded Manifest | Scrap | 3 | 85 |
| Fused Slag | Scrap | 4 | 180 |
| Tin Lunchbox | Common | 1 | 38 |
| Novelty Keychain | Common | 1 | 62 |
| Cracked Wristwatch | Common | 1 | 95 |
| Brass Doorknob | Common | 2 | 110 |
| Ceramic Figurine | Common | 2 | 190 |
| Diver's Boot | Common | 3 | 260 |
| Ship's Cutlery Set | Common | 3 | 420 |
| Deposit Slip Book | Common | 4 | 700 |
| Security Baton | Common | 4 | 1,100 |
| Scorched Alloy Plate | Common | 5 | 1,900 |
| Silver Locket | Good | 1 | 180 |
| Pocket Camera | Good | 1 | 310 |
| Sealed Coin Roll | Good | 1 | 480 |
| Copper Ingot | Good | 2 | 620 |
| Antique Compass | Good | 2 | 900 |
| Brass Sextant | Good | 3 | 1,400 |
| Captain's Log | Good | 3 | 2,200 |
| Bearer Bond Sheaf | Good | 4 | 3,600 |
| Vault Key Blank | Good | 4 | 5,400 |
| Iridium Shard | Good | 5 | 9,800 |
| Signed Baseball | Rare | 1 | 700 |
| Pre-War Radio | Rare | 1 | 1,450 |
| Gold Signet Ring | Rare | 2 | 2,000 |
| Nautical Chronometer | Rare | 2 | 3,800 |
| Ship's Bell (Intact) | Rare | 3 | 5,200 |
| Pearl Strand | Rare | 3 | 8,600 |
| Safe Deposit Box | Rare | 4 | 12,000 |
| Unmarked Gold Bar | Rare | 4 | 19,000 |
| Meteorite Core | Rare | 5 | 28,000 |
| Fallen Star Fragment | Rare | 5 | 42,000 |
| Prototype Arcade Board | Epic | 1 | 4,200 |
| Sealed Wax Cylinder | Epic | 1 | 8,300 |
| Master Diver's Helm | Epic | 2 | 14,000 |
| Buried Coin Hoard | Epic | 3 | 32,000 |
| Admiral's Sabre | Epic | 3 | 45,000 |
| Vault Manifest | Epic | 4 | 78,000 |
| Blackplate Cipher | Epic | 4 | 99,000 |
| Crater Glass Prism | Epic | 5 | 210,000 |
| The Landfill Crown | Mythic | 1 | 26,000 |
| Unopened Time Capsule | Mythic | 1 | 55,000 |
| Sunken Reliquary | Mythic | 2 | 88,000 |
| Kraken's Tooth | Mythic | 3 | 210,000 |
| Ghost Ship Wheel | Mythic | 3 | 300,000 |
| The Founder's Ledger | Mythic | 4 | 480,000 |
| Vault Zero Keycard | Mythic | 4 | 660,000 |
| Impact Diamond | Mythic | 5 | 1,400,000 |
| The First Lump | Relic | 1 | 320,000 |
| Leviathan's Eye | Relic | 3 | 1,600,000 |
| The Drowned Crown | Relic | 3 | 1,950,000 |
| Vault Zero Itself | Relic | 4 | 4,400,000 |
| The Wandering Star | Relic | 5 | 8,000,000 |
| Nothing At All | Relic | 5 | 9,600,000 |

**"Nothing At All"** is an empty box. It is the rarest and most valuable item in the game. It exists because the joke will be posted, and because a player who opens a lump and sees literally nothing, then sees the value, produces the single best clip the game can generate.

### 4.7 The hint system

Every lump generates **three independent hints**, each rendered as one of three levels:

- **Weight:** Light / Solid / Heavy
- **Temperature:** Cold / Warm / Hot
- **Sheen:** Dull / Faint / Shimmering

Each hint is drawn independently from a distribution determined by the lump's Grade:

| Grade | P(Low) | P(Mid) | P(High) |
|---|---|---|---|
| Dud | 0.70 | 0.25 | 0.05 |
| Plain | 0.35 | 0.45 | 0.20 |
| Promising | 0.12 | 0.38 | 0.50 |
| Charged | 0.04 | 0.21 | 0.75 |

The **hint score** S = sum of the three hints (Low = 0, Mid = 1, High = 2), so S ranges 0–6. The player never sees S as a number; they see three words and learn to read them.

A perfect-hints Dud (`HEAVY · HOT · SHIMMERING` on a Dud) occurs at 0.05³ = **0.0125%**, about 1 in 8,000 lumps. An all-low Charged occurs at 0.04³ = **0.0064%**. Both are designed-in heartbreak/miracle events and require no special code.

### 4.8 Worked example: the full roll, Zone 1

Player has Luck L = 0.15 (Reinforced Shovel). Zone 1 grade mix: Dud 40 / Plain 38 / Promising 18 / Charged 4.

1. **Roll u** = `math.random()` → suppose `u = 0.6100`
2. **Apply luck:** `u' = u ^ (1 / (1 + L))` = `0.61 ^ (1/1.15)` = `0.61 ^ 0.8696` = **0.6516**
   *(Luck raises u toward 1, biasing toward better grades. L = 0 leaves u unchanged.)*
3. **Grade by cumulative:** Dud [0, 0.40), Plain [0.40, 0.78), Promising [0.78, 0.96), Charged [0.96, 1.0). `u' = 0.6516` → **Plain**.
   *(Without luck, u = 0.61 would also be Plain; with L = 0.15 the Promising band widens from 18% to ~19.8% of raw rolls.)*
4. **Generate hints** from the Plain row: three draws at (0.35, 0.45, 0.20). Suppose → Mid, High, Mid. Displayed: `SOLID · HOT · FAINT`. S = 1 + 2 + 1 = **4**.
5. **Player sees** blind offer 140, open cost 45, and decides.
6. **If OPEN:** roll `math.random(1, 10000)` against the Plain rarity table. Cumulative: Scrap [1, 4500], Common [4501, 8500], Good [8501, 9800], Rare [9801, 9980], Epic [9981, 9999], Mythic [10000, 10000]. Suppose roll = 9,213 → **Good**.
7. **Pick item** uniformly from Zone 1 Good items: Silver Locket (180), Pocket Camera (310), Sealed Coin Roll (480). Suppose → **Sealed Coin Roll, 480 coins**.
8. **Net:** 480 − 45 = **435 coins**, versus the 140 they'd have taken blind. Catalogue slot fills if new.

**Luck applies only at step 2.** It never touches the rarity roll. This is deliberate: it keeps luck a single scalar, keeps the rarity tables fixed and auditable, and means a Lucky Charm cannot produce an outcome that a free player couldn't also get.

---

## 5. Currency and economy

### 5.1 Currencies

| Currency | Earned from | Spent on | Purchasable with Robux? |
|---|---|---|---|
| **Coins** | selling items, blind sales, daily lump, catalogue milestones | open costs, shovels, zones, shelf slots | Yes |
| **Scrap** | auto-converted from Scrap-tier items (1 Scrap per Scrap item) | transmutation machine (post-launch), shelf cosmetics | No |
| **Relic Shards** | 1 per Mythic pull, 10 per Relic pull | permanent +0.02 Luck each, capped at +0.40 | **No — never** |

Relic Shards being unpurchasable is a design requirement and a policy safeguard. It means the top of the luck curve is earned only by playing, which keeps the game defensible if Roblox scrutinises unboxing-adjacent mechanics.

### 5.2 Every coin source

| Source | Amount |
|---|---|
| Selling a revealed item | item's full value |
| Blind sale | see §5.3 |
| Daily Golden Lump | ~5,300 at Zone 1, scales with zone multiplier |
| Catalogue milestone (10 / 25 / 40 / 60 entries) | 5,000 / 50,000 / 500,000 / 5,000,000 |
| Best Find leaderboard (weekly top 3) | 250,000 / 100,000 / 50,000 |
| Bin sale (another player buys your blind lump) | you already received the blind price; no extra |
| Dev product coin packs | see §10 |

### 5.3 Blind-sell price — the formula

The blind offer is **not** computed from the exact hint score. It is computed from a **coarser bucket**, so the player always holds finer information than the price does. This is where skill lives.

```lua
BUCKET = { [0]="LOW", [1]="LOW", [2]="MID", [3]="MID", [4]="MID", [5]="HIGH", [6]="HIGH" }

blindPrice(zone, hintScore) =
    round( BLIND_RATIO * BucketEV[zone][ BUCKET[hintScore] ] )
```

`BucketEV` is a precomputed 5×3 lookup table — fifteen numbers, generated offline from the grade priors and hint distributions. It is not computed at runtime.

**BLIND_RATIO = 0.70** (tunable, §13).

| Zone | LOW offer (S 0–1) | MID offer (S 2–4) | HIGH offer (S 5–6) |
|---|---|---|---|
| 1 | 40 | 140 | 525 |
| 2 | 125 | 435 | 1,630 |
| 3 | 400 | 1,390 | 5,200 |
| 4 | 1,050 | 3,660 | 13,700 |
| 5 | 1,720 | 6,500 | 18,100 |

Because the MID bucket spans S=2 (EV 109) through S=4 (EV 355) at the same 140-coin offer, a player who learns to distinguish "two highs" from "one high" inside that bucket gains a real, permanent edge. That is the entire skill ceiling of the game, and it costs nothing to implement.

### 5.4 Open cost — the formula

```lua
openCost(zone) = round( OPEN_COST_RATIO * BlendedEV[zone] )
```

**OPEN_COST_RATIO = 0.205** (tunable, §13).

| Zone | Blended EV | Open cost |
|---|---|---|
| 1 | 219 | 45 |
| 2 | 606 | 125 |
| 3 | 1,750 | 360 |
| 4 | 4,907 | 1,000 |
| 5 | 13,614 | 2,800 |

Open cost is deliberately **not** a flat fraction of the zone value multiplier. It tracks blended EV, which rises faster than value alone because deeper zones also roll better grades. Scaling it by value multiplier only would drag the decision threshold down every zone until endgame players never sold blind. This one detail is what keeps the core mechanic alive at Zone 5.

The first **3 lumps** of any new profile have `openCost = 0`. This is the tutorial.

### 5.5 Every coin sink

| Sink | Scale |
|---|---|
| Open costs | 45 → 2,800 per lump; the primary sink, ~20% of gross income |
| Shovel tiers | 8,000 → 14,000,000 |
| Zone unlocks | 25,000 → 5,000,000 |
| Shelf slots | 1,000 × 1.7ⁿ, from 1,700 up to ~201,600 for the 10th |
| Bin purchases | 2× the seller's blind price |

### 5.6 Coins per minute — the curve

Assumes optimal play (blind on offers that beat net-open EV) and the shovel a player would realistically own at that point.

| Stage | Zone | Shovel | Cycle | Lumps/min | Coins/lump | **Coins/min** |
|---|---|---|---|---|---|---|
| New player | 1 | Rusty | 5.00s | 12.0 | 200 | **2,400** |
| Early | 1 | Steel | 4.25s | 14.1 | 200 | **2,824** |
| Early-mid | 2 | Steel | 4.63s | 13.0 | 546 | **7,082** |
| Mid | 3 | Reinforced | 4.40s | 13.6 | 1,575 | **21,483** |
| Late-mid | 4 | Powered | 4.16s | 14.4 | 4,416 | **63,679** |
| Endgame | 5 | Powered | 4.40s | 13.6 | 12,051 | **164,371** |
| Max | 5 | Excavator | 4.00s (×2 lumps) | 30.0 | 12,051 | **361,530** |

**Curve check.** Step-over-step growth: ×1.18, ×2.51, ×3.03, ×2.96, ×2.58, ×2.20. No spike, no flatline. The largest single jump is 3.03× at the Zone 3 transition, which is intentional — Zone 3 is where a player who was going to quit either commits or leaves, and it should feel like a breakthrough.

### 5.7 Time-to-milestone (cross-check against §3 and §7)

| Milestone | Cost | Rate at that point | Time for step | **Cumulative** |
|---|---|---|---|---|
| Steel Shovel | 8,000 | 2,400/min | 3.3 min | **3 min** |
| Zone 2 | 25,000 | 2,824/min | 8.9 min | **12 min** |
| Reinforced Shovel | 100,000 | 7,082/min | 14.1 min | **26 min** |
| Zone 3 | 150,000 | 7,988/min | 18.8 min | **45 min** |
| Zone 4 | 900,000 | 21,483/min | 41.9 min | **87 min** |
| Powered Shovel | 1,200,000 | 56,392/min | 21.3 min | **108 min** |
| Zone 5 | 5,000,000 | 63,679/min | 78.5 min | **187 min** |
| Excavator | 14,000,000 | 164,371/min | 85.2 min | **272 min** |

**~4.5 hours to full progression.** No step exceeds 90 minutes, and the two longest (Zone 5, Excavator) sit after the player is committed. There is no wall.

---

## 6. The core decision mechanic

This is the differentiator. It gets the most detail.

### 6.1 The rational rule

Opening beats selling blind when:

```
EV(lump | hints) − openCost  >  blindPrice
```

Since `blindPrice = BLIND_RATIO × BucketEV`, and BucketEV is a coarser estimate than the player's actual hint information, the true rule is:

```
open  ⟺  EV(hintScore) − openCost  >  BLIND_RATIO × BucketEV(bucket)
```

The player is comparing their **private, finer** estimate against the game's **public, coarser** offer. That asymmetry is the whole design.

### 6.2 The decision table — Zone 1

Open cost 45. Posteriors computed from the grade priors (40/38/18/4) and the hint distributions in §4.7.

| S | P(this S) | P(Dud) | P(Plain) | P(Prom) | P(Chg) | EV | Open net | Blind offer | **Correct** | Margin |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 15.38% | 89.20% | 10.59% | 0.20% | 0.00% | 44.99 | −0.01 | 40 | **BLIND** | +40.0 |
| 1 | 21.28% | 69.07% | 29.53% | 1.39% | 0.02% | 65.34 | 20.34 | 40 | **BLIND** | +19.7 |
| 2 | 20.42% | 40.10% | 53.24% | 6.49% | 0.17% | 109.02 | 64.02 | 140 | **BLIND** | +76.0 |
| 3 | 17.01% | 16.02% | 62.59% | 20.29% | 1.11% | 193.98 | 148.98 | 140 | **OPEN** | +9.0 |
| 4 | 12.98% | 4.51% | 47.85% | 42.51% | 5.14% | 354.81 | 309.81 | 140 | **OPEN** | +169.8 |
| 5 | 8.67% | 0.87% | 23.66% | 59.14% | 16.34% | 618.52 | 573.52 | 525 | **OPEN** | +48.5 |
| 6 | 4.25% | 0.12% | 7.16% | 52.99% | 39.74% | 1,017.82 | 972.82 | 525 | **OPEN** | +447.8 |

Probabilities sum to 100.00%.

**Optimal split at Zone 1: 57.09% blind / 42.91% open.**

Three properties worth naming:

1. **S = 3 is the knife edge.** Opening beats blind by 9 coins out of ~190. A player who mistakes S=2 for S=3 loses almost nothing; a player who *learns* the difference gains a steady edge. This is the skill boundary and it is exactly where you want it — at the most common decision point (S=3 is 17% of all lumps).
2. **S = 0 is nearly free money either way.** Open net is −0.01, blind is 40. The floor is merciful, which stops new players from going broke in their first session.
3. **S = 5 is the trap.** Blind offers 525 on a lump worth 618 — the offer *looks* generous because it's the HIGH bucket, and it's the second-thinnest margin in the table. Players will sell these blind and regret it, and those regrets are clips.

### 6.3 The decision table — Zone 5

Open cost 2,800. Grade priors 8/36/38/18.

| S | P(this S) | EV | Open net | Blind offer | **Correct** |
|---|---|---|---|---|---|
| 0 | 4.35% | 1,695 | −1,105 | 1,720 | **BLIND** |
| 1 | 9.54% | 2,803 | 3 | 1,720 | **BLIND** |
| 2 | 14.90% | 4,606 | 1,806 | 6,500 | **BLIND** |
| 3 | 18.76% | 7,961 | 5,161 | 6,500 | **BLIND** |
| 4 | 20.65% | 13,835 | 11,035 | 6,500 | **OPEN** |
| 5 | 19.17% | 21,942 | 19,142 | 18,100 | **OPEN** |
| 6 | 12.63% | 31,899 | 29,099 | 18,100 | **OPEN** |

**Optimal split at Zone 5: 47.54% blind / 52.46% open.**

The split drifts from 57/43 to 48/52 across the game, which is the correct direction — deeper zones make opening more often right, so progression *feels* like earned confidence rather than a re-tuned treadmill. Both endpoints sit inside the 45–57% band.

### 6.4 Why real players won't play optimally (and why that's fine)

The modelled split is 57/43 at Zone 1. Observed behaviour will run 5–10 points more toward opening, because curiosity beats expected value in every unboxing game ever measured. Expected live split: **~47–50% blind / 50–53% open** — landing on the 45/55 target without any additional tuning.

**Do not tune against the model. Tune against the log.**

### 6.5 Drift detection and the adjustment process

Every decision writes one row:

```lua
{ userId, zone, hintScore, choice = "BLIND"|"OPEN", timestamp }
```

Fire-and-forget to an OrderedDataStore keyed by week, or to an external endpoint if you have one. Aggregate weekly.

**The check:** `blindRate = blindCount / totalDecisions`, computed per zone.

| Observed blind rate | Diagnosis | Action |
|---|---|---|
| 60%+ | Blind too generous; nobody's opening; game is a slot machine with no gamble | `BLIND_RATIO -= 0.05` |
| 45–58% | Healthy | none |
| 30–44% | Blind too stingy; opening is automatic; no decision | `BLIND_RATIO += 0.05` |
| under 30% | Decision has collapsed | `BLIND_RATIO += 0.10`, re-check in 3 days |

**Sensitivity of BLIND_RATIO at Zone 1:**

| BLIND_RATIO | Threshold EV | Blind on | % blind |
|---|---|---|---|
| 0.50 | 90 | S ≤ 1 | 36.7% |
| 0.60 | 113 | S ≤ 2 | 57.1% |
| **0.70** | **150** | **S ≤ 2** | **57.1%** |
| 0.75 | 180 | S ≤ 2 | 57.1% |
| 0.80 | 225 | S ≤ 3 | 74.1% |

**Be aware of this:** with only 7 hint scores, the split moves in *steps*, not smoothly. BLIND_RATIO 0.60 through 0.75 all produce the same optimal split. That's good for stability and bad for fine-tuning. So:

- **BLIND_RATIO is the coarse lever** — moves the split in jumps of ~17 points.
- **OPEN_COST_RATIO is the fine lever** — shifts the threshold continuously against the EV ladder, so a change of 0.01 nudges behaviour without jumping a bucket.

Both are single numbers in one config module. Changing either is a one-line edit and a publish — doable from a phone, which was the requirement.

### 6.6 The invariant that must never break

**No purchase may change the sign of the decision.** If a gamepass makes opening correct where it previously wasn't, the hook is dead and the game becomes a pay-to-win unboxer. §10 checks every product against this.

---

## 7. Progression and upgrades

### 7.1 Shovels

Cost curve: `cost(n) = 8000 × SHOVEL_COST_MULT^(n-1)` where **SHOVEL_COST_MULT = 12**.

| Tier | Cost | Dig time × | Luck | Special |
|---|---|---|---|---|
| Rusty | 0 | 1.00 | +0.00 | starting item |
| Steel | 8,000 | 0.75 | +0.00 | required for Zone 3 |
| Reinforced | 100,000 | 0.60 | +0.15 | required for Zone 4 |
| Powered | 1,200,000 | 0.48 | +0.30 | required for Zone 5 |
| Excavator | 14,000,000 | 0.40 | +0.30 | digs **2 lumps per action** |

The Excavator doubles throughput rather than adding luck, because a fourth luck increment would push free-player Luck past the Lucky Charm gamepass and make the pass worthless.

### 7.2 Luck sources and the cap

| Source | Luck | Max |
|---|---|---|
| Reinforced Shovel | +0.15 | one-time |
| Powered / Excavator | +0.30 | replaces the above |
| Lucky Charm (gamepass) | +0.10 | one-time |
| Relic Shards | +0.02 each | +0.40 (20 shards) |
| Catalogue milestones (10/25/40/60) | +0.03 each | +0.12 |
| **Theoretical maximum** | | **+0.92** |

**LUCK_CAP = 1.00**, hard-clamped in code. At L = 1.00 the Zone 1 Charged rate rises from 4.0% to 8.0% — meaningful, not distribution-breaking. A maxed player is roughly 2× as likely to hit a Charged lump as a new one, which is the right ratio: visible, worth chasing, not a different game.

### 7.3 Shelf slots

`slotCost(n) = 1000 × 1.7^n`, **SHELF_COST_MULT = 1.7**.

| Slot | Cost |
|---|---|
| 1–12 | free (base) |
| 13 | 1,700 |
| 14 | 2,890 |
| 15 | 4,913 |
| 18 | 24,138 |
| 22 | 201,599 |

### 7.4 Curve cross-check

Every upgrade priced against the coins/min available when a player would realistically buy it (§5.7): the longest gap is 85 minutes (Excavator), the shortest is 3 minutes (Steel). Ratio of upgrade cost to current income rate stays between 3.3 and 85 minutes across the whole game, with a median of ~21 minutes — roughly one meaningful purchase per session. That is the target.

---

## 8. Collection, shelf, and the blind-sale bin

### 8.1 Catalogue data shape

```lua
catalogue = {
    ["silver_locket"]   = { found = true,  count = 14, bestValue = 180,   firstFound = 1735689600 },
    ["antique_compass"] = { found = true,  count = 3,  bestValue = 900,   firstFound = 1735776000 },
    ["landfill_crown"]  = { found = false },
}
```

Only `found = true` entries store the full record; unfound items are either absent or a single-field stub. The UI derives silhouettes by iterating the master ItemTable and checking membership — the *display* of unfound items is a client concern, the *record* is server-only.

**Milestone bonuses** fire at 10 / 25 / 40 / 60 unique entries: coins per §5.2 plus +0.03 Luck each.

### 8.2 The shelf

- Each player owns a numbered plot in a shared warehouse. Plots are assigned on join from a pool of 24 per server.
- Base 12 display slots, expandable by coins (§7.3) and by gamepass (+10).
- Placing an item on the shelf **removes it from sellable inventory**. Displaying costs you the coins. This is what makes a full shelf a status signal rather than a free flex.
- Any player can walk into the warehouse and read any plot. Hovering an item shows: name, rarity, value, and the owner's name.
- Shelf contents persist across sessions and across prestige (post-launch).

```lua
shelf = {
    [1] = "unopened_time_capsule",
    [2] = "pearl_strand",
    [3] = nil,
}
```

### 8.3 The blind-sale bin

**This is the highest-value-per-line-of-code feature in the game. Do not cut it.**

Mechanically:

1. Player sells a lump blind. They receive `blindPrice` immediately. **The lump is not destroyed.**
2. The lump is pushed to a server-scoped bin — a plain Lua table on the server, never persisted, cleared on server shutdown.
3. The bin holds the **12 most recent** blind-sold lumps, FIFO. Older entries drop silently.
4. Any *other* player in that server can buy a bin lump for `2 × blindPrice`.
5. The buyer sees, before purchasing: the three hints, the zone it came from, the price, and the seller's display name. They see **nothing** the seller didn't see.
6. On purchase, the buyer opens it immediately — no second open fee. The roll happens at purchase time using the lump's stored Grade and its origin zone's tables.
7. The result is announced in the server chat regardless of rarity: `Fallen bought SnowyKid_88's lump for 280 and pulled… GOOD — Sealed Coin Roll (480).`
8. The seller receives nothing extra. Their payout was final at step 1.

**Why it balances.** The buyer pays 2× blind = 1.4× EV, which is a losing bet in raw expectation (they pay 1.4 EV for 1.0 EV). It is a bad financial decision and a great emotional one, and players will make it constantly. It's a net coin *sink*, which the economy needs, and it costs the seller nothing, so nobody feels robbed.

**Why the seller must watch.** The purchase announcement names the seller. That's the whole clip.

```lua
bin = {
    { lumpId = "a3f9", grade = "Promising", zone = 1, hints = {2,1,2},
      hintScore = 5, price = 1050, sellerName = "SnowyKid_88", sellerId = 12345 },
}
```

**Exploit guard:** a player cannot buy their own lump (`sellerId ~= buyerId`), and bin entries expire after 180 seconds so a player can't hold a good-hint lump hostage for a friend.

---

## 9. Social and retention systems

### 9.1 Announcements

| Rarity | Scope | Effect |
|---|---|---|
| Epic | server chat | text line, soft chime |
| Mythic | server chat | text line, gold screen border 2s, distinct sound |
| Relic | **all servers** via MessagingService | full-screen flash, unique sound, permanent entry in a Hall of Finds |

Format:

```
[!] {displayName} pulled a {RARITY} — {itemName} ({value} coins) in {zoneName}!
```

Relic format:

```
[!!!] {displayName} FOUND A RELIC — {itemName} ({value} coins). Server {n}.
```

**Threshold rationale:** Epic fires roughly once every 140 lumps per player. In a 12-player server at 12 lumps/min that's an announcement every ~6 seconds, which is far too many. **So the Epic threshold is rate-limited: maximum one announcement per player per 60 seconds, and maximum 6 per server per minute.** Mythic and Relic bypass the limit. Without this, the feature becomes wallpaper within one session.

### 9.2 Daily Golden Lump

- One per 20 hours (not a calendar day — a 20-hour timer never punishes a shift worker for logging in an hour later).
- Rolls **Charged** grade, then **rerolls until the tier is Rare or better**.
- Conditional EV at Zone 1: 72.7% Rare / 22.7% Epic / 3.94% Mythic / 0.61% Relic → **~5,333 coins**, scaling by zone multiplier.
- **Relic chance per claim: 1 in 164.** That number is the reason to log in.
- Hints always display all-High, so the player knows it's special and gets the "open it" ritual.
- VIP gamepass grants a second daily lump.

Explicitly **not** a login streak. Streaks are homework and they punish irregular schedules.

### 9.3 Best Find leaderboard

- Tracks the single highest-value item any player has revealed in the current week.
- OrderedDataStore, key `bestfind_{isoWeek}`.
- Resets Monday 00:00 UTC.
- Top 3 receive 250,000 / 100,000 / 50,000 coins and a shelf plaque that persists.
- It is a **luck** ladder, not a skill ladder, which is the point: every player believes they can win it, so every player checks it.

### 9.4 Retention hooks: MVP vs post-launch

| Hook | MVP | Post-launch |
|---|---|---|
| Catalogue silhouettes | ✅ | |
| Rare announcements | ✅ | |
| Daily Golden Lump | ✅ | |
| Best Find board | ✅ | |
| Blind-sale bin | ✅ | |
| Shared shelf warehouse | ✅ | |
| Catalogue milestones | ✅ | |
| Hall of Finds (Relic history) | | ✅ |
| Meteor Lump event | | ✅ |
| Burial / appreciation | | ✅ |
| Prestige | | ✅ |
| Seasonal item pools | | ✅ |

---

## 10. Monetization

Every product is checked against the §6.6 invariant: **it must not flip the sign of the sell-or-open decision.**

### 10.1 Gamepasses

| Product | Price | Effect | Why they buy | Decision-safe? |
|---|---|---|---|---|
| **Scanner** | 99 R$ | Adds a **4th hint** (independent draw from the same grade). Hint score becomes 0–8; the bucket table extends to LOW 0–2, MID 3–5, HIGH 6–8. | Reduces uncertainty without removing it. The single most desirable item in the game. | ✅ Sharpens the estimate on both sides equally. A Scanner player still sells blind ~50% of the time — they just sell blind on the *right* lumps. |
| **Big Shelf** | 149 R$ | +10 display slots (12 → 22) | Display is status; the shelf fills fast | ✅ Cosmetic. Zero gameplay effect. |
| **Lucky Charm** | 249 R$ | +0.10 Luck, permanent | Everyone wants luck | ✅ Shifts the grade prior, which shifts blind offers and open EV **proportionally**. Split is unchanged. |
| **Auto-Dig** | 149 R$ | Dig repeats without holding | Mobile QoL; the hold is the tedious part | ✅ Automates the dig, never the decision. The decision prompt still requires a tap. |
| **2× Coins** | 299 R$ | Doubles all coin gains **and doubles open cost** | Faster progression | ✅ **Only because open cost is doubled too.** See warning below. |
| **VIP** | 399 R$ | Chat tag, +1 daily Golden Lump, private shelf plot, exclusive shovel skin | Identity and a second lottery ticket | ✅ Social and cosmetic. |

> **⚠️ The 2× Coins trap.** If 2× Coins doubles income but leaves open cost alone, the break-even drops from `cost/0.30` to `cost/0.60` — opening becomes correct roughly twice as often, and a paying player is playing a materially different, easier game. This is a real balance leak and it is easy to ship by accident. **Open cost must scale with the player's active coin multiplier.** Implement as `effectiveOpenCost = openCost * player.coinMultiplier`. One line, and it preserves the entire design.

### 10.2 Developer products

| Product | Price | Grants |
|---|---|---|
| Coin Pouch | 49 R$ | 5,000 coins |
| Coin Sack | 199 R$ | 40,000 coins |
| Coin Crate | 699 R$ | 350,000 coins |
| Coin Vault | 1,999 R$ | 3,000,000 coins |
| Golden Lump ×3 | 99 R$ | 3 immediate Golden Lumps |
| Zone Skip | 249 R$ | Waives the **coin cost** of the next zone — **not** the catalogue requirement |

Coin packs are priced against §5.7: the 199 R$ Sack is roughly 14 minutes of Zone 2 income, the 699 R$ Crate roughly 16 minutes of Zone 3. Deliberately modest — coins are the least interesting thing to sell, because coins only buy fees and cosmetics, never rarity.

**Zone Skip preserving the catalogue gate** is the guard that stops a spending player from rocketing to Zone 5 in ten minutes and churning.

### 10.3 What is explicitly not sold

- Relic Shards, or anything that raises Luck past the earned cap.
- Robux-priced random outcomes of any kind. Every gamble in this game is paid for in coins earned by playing.
- Anything that reveals a lump's contents before the decision.
- Trading, or any mechanic that gives a purchased item real-money resale value.

The third bullet is the hook. The fourth is the policy shield.

---

## 11. Data and save schema

ProfileStore template. Every field has a default; nothing is nil-checked at read time.

```lua
local ProfileTemplate = {
    -- Currency
    coins            = 0,          -- number, integer
    scrap            = 0,          -- number, integer
    relicShards      = 0,          -- number, integer

    -- Progression
    currentZone      = 1,          -- number, 1..5
    zonesUnlocked    = { [1] = true },        -- map<number, boolean>
    shovelTier       = 1,          -- number, 1..5 (1 = Rusty)
    shelfSlots       = 12,         -- number, purchased total
    luckBonus        = 0.0,        -- number, cached sum of all Luck sources, clamped to LUCK_CAP

    -- Collection
    catalogue        = {},         -- map<itemId, { found:boolean, count:number,
                                   --               bestValue:number, firstFound:number }>
    catalogueCount   = 0,          -- number, cached count of found == true
    milestonesPaid   = {},         -- map<number, boolean>  keys: 10, 25, 40, 60

    -- Shelf
    shelf            = {},         -- array<itemId|nil>, length == shelfSlots

    -- Inventory (unsold revealed items awaiting keep/sell)
    inventory        = {},         -- array<{ itemId:string, value:number, rolledAt:number }>

    -- Monetization state
    passes = {
        scanner      = false,
        bigShelf     = false,
        luckyCharm   = false,
        autoDig      = false,
        doubleCoins  = false,
        vip          = false,
    },
    coinMultiplier   = 1,          -- number, 1 or 2; drives effectiveOpenCost

    -- Retention
    lastGoldenLump   = 0,          -- number, os.time()
    goldenLumpsOwed  = 0,          -- number, from dev product purchases
    bestFindValue    = 0,          -- number, all-time
    bestFindItem     = "",         -- string, itemId
    weeklyBestValue  = 0,          -- number, resets weekly
    weeklyBestWeek   = 0,          -- number, ISO week index

    -- Tutorial / session
    freeOpensLeft    = 3,          -- number, counts down from 3 on first session
    totalLumpsDug    = 0,          -- number, lifetime
    decisionsBlind   = 0,          -- number, lifetime, for tuning telemetry
    decisionsOpen    = 0,          -- number, lifetime, for tuning telemetry

    -- Meta
    createdAt        = 0,          -- number, os.time()
    dataVersion      = 1,          -- number, for future migrations
}
```

`dataVersion` exists from day one. Adding it later means writing a migration for every existing profile; adding it now costs one line.

**The bin is not in this schema.** It is server-scoped, in-memory, and intentionally lost on shutdown.

---

## 12. Technical architecture

### 12.1 Folder structure

```
ServerScriptService/
  Main.server.lua              -- requires and initialises every service in order
  Services/
    PlayerDataService.lua      -- ProfileStore wrapper; load, release, autosave
    DigService.lua             -- validates dig requests, applies cooldown, calls LumpService
    LumpService.lua            -- rolls Grade, generates hints, holds active lumps per player
    RevealService.lua          -- rolls tier, picks item, writes catalogue, fires announcements
    EconomyService.lua         -- THE ONLY place coins/scrap/shards change
    ShelfService.lua           -- place, remove, replicate shelf state
    BinService.lua             -- server-scoped bin, purchase handling, expiry
    UpgradeService.lua         -- shovel and zone purchases, luck recalculation
    CatalogueService.lua       -- milestone detection and payout
    AnnounceService.lua        -- rate limiting, chat, MessagingService for Relics
    LeaderboardService.lua     -- OrderedDataStore, weekly reset
    DailyService.lua           -- Golden Lump timer and roll
    TelemetryService.lua       -- decision logging for §6.5

ReplicatedStorage/
  Remotes/                     -- see 12.2
  Modules/
    Config.lua                 -- every tunable constant (§13). No logic.
    ItemTable.lua              -- the 60 items
    GradeTable.lua             -- grade → rarity weights
    HintTable.lua              -- grade → hint distributions
    ZoneTable.lua              -- zone definitions, grade mixes, multipliers
    BucketEV.lua               -- precomputed 5×3 blind-offer lookup
    Formatters.lua             -- shared number/name formatting (client + server)

StarterPlayerScripts/
  UIController.client.lua      -- all screen state; listens to remotes
  DigController.client.lua     -- input handling, fires RequestDig
  ShelfController.client.lua   -- warehouse hover and inspect
```

### 12.2 RemoteEvents

Client → server. Every one is rate-limited and validated.

| Remote | Client sends | Server validates | Server returns |
|---|---|---|---|
| `RequestDig` | nothing | player has no active lump; ≥ digTime since last dig; player is inside their unlocked zone's region | `LumpSpawned(hints, blindOffer, openCost, lumpId)` |
| `RequestOpen` | `lumpId` | lumpId matches the player's active lump; player has ≥ effectiveOpenCost coins (or freeOpensLeft > 0) | `RevealResult(itemId, tier, value, isNew)` |
| `RequestSellBlind` | `lumpId` | lumpId matches the player's active lump | `BlindSold(amount)`, plus `BinUpdated` broadcast |
| `RequestSellItem` | `inventoryIndex` | index exists in the player's inventory | `CoinsChanged(newBalance)` |
| `RequestKeepItem` | `inventoryIndex, shelfSlot` | index exists; slot is within shelfSlots; slot is empty | `ShelfUpdated(shelf)` |
| `RequestBuyBin` | `lumpId` | lump is in the bin; `sellerId ~= buyerId`; not expired; player has ≥ 2× price | `RevealResult(...)`, plus chat announcement |
| `RequestBuyUpgrade` | `upgradeType, tier` | tier is exactly current + 1; player has the coins; prerequisites met (catalogue count, prior shovel) | `UpgradePurchased(type, tier)` |
| `RequestClaimDaily` | nothing | `os.time() - lastGoldenLump >= 72000` **or** `goldenLumpsOwed > 0` | `RevealResult(...)` |
| `RequestPlaceShelf` | `inventoryIndex, slot` | as `RequestKeepItem` | `ShelfUpdated(shelf)` |

Server → client (no request): `LumpSpawned`, `RevealResult`, `CoinsChanged`, `CatalogueUpdated`, `ShelfUpdated`, `BinUpdated`, `Announce`, `UpgradePurchased`, `LeaderboardUpdated`.

### 12.3 Calculations that must never happen on the client

Non-negotiable. Every one of these on the client is an exploit.

- **The Grade roll.** If the client rolls, every lump is Charged.
- **The tier roll and item pick.**
- **The luck value.** Client may *display* it; it must be recomputed server-side on every roll from the profile.
- **The blind offer.** Computed server-side from the BucketEV lookup and sent down. Never derived client-side.
- **The open cost deduction**, including the coinMultiplier scaling.
- **Any write to `coins`, `scrap`, `relicShards`, `catalogue`, or `shelf`.**
- **Bin contents before purchase.** The client receives hints and price only — never the stored Grade, and never a resolved item.
- **Cooldown enforcement.** Client-side debounce is UX; server-side timestamp check is security. Do both.

### 12.4 The one pattern to internalise

```
client fires remote
    → server validates (does this player own this? can they afford it? has enough time passed?)
    → server mutates the profile
    → server fires result back
    → client animates
```

Always that order. The client asks; it never tells. If you only take one thing from this section, take that.

---

## 13. Tuning constants — `ReplicatedStorage/Modules/Config.lua`

Every number here can be changed without touching gameplay code. Nothing in this module contains logic.

```lua
return {
    -- CORE DECISION (the two levers from §6.5)
    BLIND_RATIO          = 0.70,   -- coarse lever; moves split in ~17pt steps
    OPEN_COST_RATIO      = 0.205,  -- fine lever; continuous

    -- LUCK
    LUCK_CAP             = 1.00,
    LUCK_REINFORCED      = 0.15,
    LUCK_POWERED         = 0.30,
    LUCK_CHARM_PASS      = 0.10,
    LUCK_PER_SHARD       = 0.02,
    LUCK_SHARD_CAP       = 0.40,
    LUCK_PER_MILESTONE   = 0.03,

    -- COST CURVES
    SHOVEL_BASE_COST     = 8000,
    SHOVEL_COST_MULT     = 12,
    SHELF_BASE_COST      = 1000,
    SHELF_COST_MULT      = 1.7,

    -- PACING
    DECISION_TIME_BUDGET = 2.0,    -- assumed non-dig seconds per cycle; all §5.6 math depends on this
    FREE_OPENS           = 3,
    GOLDEN_LUMP_COOLDOWN = 72000,  -- 20 hours in seconds

    -- BIN
    BIN_SIZE             = 12,
    BIN_PRICE_MULT       = 2.0,
    BIN_EXPIRY_SECONDS   = 180,

    -- ANNOUNCEMENTS
    ANNOUNCE_MIN_TIER    = "Epic",
    ANNOUNCE_PER_PLAYER_COOLDOWN = 60,
    ANNOUNCE_PER_SERVER_PER_MIN  = 6,

    -- REWARDS
    MILESTONE_THRESHOLDS = {10, 25, 40, 60},
    MILESTONE_COINS      = {5000, 50000, 500000, 5000000},
    LEADERBOARD_PRIZES   = {250000, 100000, 50000},
    SHARDS_PER_MYTHIC    = 1,
    SHARDS_PER_RELIC     = 10,

    -- SECURITY
    DIG_COOLDOWN_GRACE   = 0.15,   -- seconds of leniency on server-side dig timing
    MAX_REMOTE_PER_SEC   = 8,
}
```

Grade mixes, rarity weights, hint distributions, zone definitions, and the BucketEV lookup live in their own data modules (§12.1) rather than here, because they are tables rather than scalars — but they are equally hot-editable and contain no logic either.

---

## 14. Build roadmap — 7 weeks

Each item is a buildable unit with a done condition.

### Week 1 — The interaction
- [ ] Baseplate, one trash mound, one dig spot part with a ProximityPrompt (3.0s hold)
- [ ] `Config.lua` with every constant from §13, even the ones nothing reads yet
- [ ] `PlayerDataService` with ProfileStore, loading the §11 template
- [ ] `EconomyService` with `AddCoins` / `RemoveCoins` — the only functions that touch currency
- [ ] Coins on the leaderstats
- [ ] `RequestDig` remote: server validates cooldown, spawns a grey Part welded to the player's hand
- [ ] A SELL button that grants 40 coins and deletes the lump

**Done when:** you can dig, sell, and see the number go up. If this is not satisfying with a grey brick and no UI, stop and fix it before week 2.

### Week 2 — The roll and the decision
- [ ] `ItemTable.lua` — all 60 items from §4.6
- [ ] `GradeTable.lua` — the four rarity tables from §4.2
- [ ] `HintTable.lua` — the grade → hint distributions from §4.7
- [ ] `ZoneTable.lua` — Zone 1 only for now
- [ ] `LumpService`: roll Grade with the `u^(1/(1+L))` luck function, generate 3 hints, store the active lump server-side
- [ ] `BucketEV.lua` — Zone 1 row (40 / 140 / 525)
- [ ] Two-button prompt showing hints, blind offer, and open cost
- [ ] `RequestOpen` and `RequestSellBlind` remotes with full server validation
- [ ] `RevealService`: roll tier from the Grade table, pick an item, return it
- [ ] `freeOpensLeft` countdown from 3

**Done when:** you can dig, read hints, choose, and see a real item with a real value.

### Week 3 — Persistence and catalogue
- [ ] Catalogue writes on first find (§8.1 shape)
- [ ] Catalogue UI: 60 slots, silhouettes for unfound, full detail on found
- [ ] Inventory + keep/sell prompt after every reveal
- [ ] Autosave on a 60s loop plus on `PlayerRemoving`
- [ ] `dataVersion` field wired and checked on load
- [ ] **Test data loss deliberately:** force-close Studio mid-session, rejoin, confirm nothing is lost

**Done when:** you can log out and come back to your exact state. Do not proceed until this is bulletproof — data loss on launch day kills a game permanently.

### Week 4 — Progression
- [ ] `UpgradeService`: Steel and Reinforced shovels, with prerequisite checks
- [ ] Dig time multiplier applied server-side
- [ ] Luck recalculation on every upgrade, clamped to `LUCK_CAP`
- [ ] Zone 2 (The Quarry): second dig region, unlock gate on coins + catalogue count
- [ ] `ZoneTable` and `BucketEV` extended to Zone 2
- [ ] Zone teleport / region gating

**Done when:** buying the Steel Shovel visibly changes how the game plays.

### Week 5 — Social
- [ ] `AnnounceService`: Epic+ chat messages with the §9.1 rate limiting
- [ ] `BinService`: 12-slot server bin, `RequestBuyBin`, expiry, self-purchase guard
- [ ] Bin UI showing hints, price, and seller name
- [ ] Purchase announcement naming both parties
- [ ] Shared shelf warehouse: 24 plots, plot assignment on join
- [ ] `ShelfService` place/remove, replicated to all clients in the server

**Done when:** two players in one server can see each other's finds and buy each other's blind lumps.

### Week 6 — Retention and content
- [ ] Zones 3, 4, 5 with their tables, gates, and BucketEV rows
- [ ] Powered Shovel and Excavator (including the 2-lump dig)
- [ ] `DailyService`: Golden Lump, 20-hour timer, Charged-with-Rare-floor roll
- [ ] Catalogue milestones at 10/25/40/60 with coin and luck payouts
- [ ] `LeaderboardService`: weekly Best Find on OrderedDataStore, Monday UTC reset
- [ ] Relic Shards awarded on Mythic and Relic pulls
- [ ] `TelemetryService`: log every decision per §6.5

### Week 7 — Monetization, hardening, ship
- [ ] All six gamepasses, including **`effectiveOpenCost = openCost * coinMultiplier`**
- [ ] All six dev products, with Zone Skip preserving the catalogue gate
- [ ] Scanner's 4th hint and the extended 0–8 bucket table
- [ ] Rate limiting on every remote (`MAX_REMOTE_PER_SEC`)
- [ ] MessagingService for cross-server Relic announcements
- [ ] Reveal sound design — this carries more emotional weight than any visual in the budget
- [ ] Icon and thumbnail: **show the two buttons, not the lump.** The decision is the differentiator; the lump looks like every other unboxing game on the platform
- [ ] Publish

---

## 15. Post-launch roadmap

Ordered by value-per-effort. "Effort" is relative to the full 7-week MVP.

| # | System | What it adds | Effort |
|---|---|---|---|
| 1 | **Hall of Finds** | Permanent cross-server record of every Relic ever pulled, with names and dates. Turns a one-time event into permanent status. | 5% |
| 2 | **Meteor Lump event** | A guaranteed-Charged lump spawns somewhere in the map every 20 minutes; first player to reach it takes it. Shared objective, zero content authoring. | 8% |
| 3 | **Transmutation machine** | Feed 10 duplicate items in, get 1 random item of one tier higher. Turns dead inventory into a second gambling loop and gives Scrap a purpose. | 12% |
| 4 | **Authentication / fakes** | 15% of Rare+ items are forgeries worth 10% of face value. Players buy an authentication kit or gamble. Adds a second decision layer on top of the first. | 15% |
| 5 | **Burial & appreciation** | Bury an item; it gains 2% value per hour up to +100%, capped at 48 hours. A reason to return tomorrow that isn't a login streak. | 10% |
| 6 | **Prestige (Reset the Dump)** | Wipe coins, zones, and shovels for permanent +Luck and a shelf badge. Catalogue and shelf persist — that's what makes it feel like advancement. | 15% |
| 7 | **Seasonal pools** | 6 rotating items per season, removed permanently at season end. Scarcity without power creep. | 8% per season |
| 8 | **Weight limits (Overpack)** | Carry multiple unopened lumps; exceed capacity and drop a random one. Adds spatial tension to a game that has none. | 20% |
| 9 | **Shared mall shelves** | Rent a shelf in a public mall; passive income scales with other players' foot traffic past your plot. The strongest social loop available, but it needs a real population first. | 30% |
| 10 | **Auction house** | Players auction *unopened* lumps to each other. Highest economic ceiling, highest exploit risk. Needs rate limits, escrow, and dupe hardening. | 50% |

**Do not build #10 until the game has been live and stable for six months.** One duplication exploit in an auction system destroys an economy permanently and irreversibly, and no amount of design quality survives it.

---

## Cross-check summary

- §5 income (2,400 → 361,530 coins/min) supports §7 upgrade costs (8,000 → 14,000,000) at 3–85 minutes per purchase, median 21.
- §7 shovel prerequisites gate §3 zone unlocks; both are affordable at the income rate available when reached.
- §4 blended EVs feed §5.4 open costs feed §6 decision tables; the resulting split (57% → 48% blind) sits inside the 45–57% target across all five zones.
- §10 products are each verified against the §6.6 invariant; the one that failed (2× Coins) has an explicit fix.
- §11 schema contains a field for every system in §4–§10; nothing is stored that no service reads.

---

*No design guarantees traffic. What this spec buys is an internally consistent economy that won't need rebuilding after launch, and a core mechanic whose only real failure mode is controlled by two numbers in one file.*
