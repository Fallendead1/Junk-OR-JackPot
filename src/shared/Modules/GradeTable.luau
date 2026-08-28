-- Grade -> rarity tier weights, out of 10,000. Source: GDD §4.2.
--
-- This is one of the files CLAUDE.md marks as yours to own, not Claude's — it's
-- the core rarity balance. It's filled in here with the GDD's exact numbers so
-- Phase 0's exit criteria (each grade's weights sum to 10000) actually pass,
-- but any future rebalancing of these weights is your call, not something to
-- change without being asked directly.
return {
	Dud = { Scrap = 7500, Common = 2300, Good = 180, Rare = 18, Epic = 2, Mythic = 0, Relic = 0 },
	Plain = { Scrap = 4500, Common = 4000, Good = 1300, Rare = 180, Epic = 19, Mythic = 1, Relic = 0 },
	Promising = { Scrap = 1500, Common = 4200, Good = 3200, Rare = 900, Epic = 180, Mythic = 18, Relic = 2 },
	Charged = { Scrap = 0, Common = 2500, Good = 4200, Rare = 2400, Epic = 750, Mythic = 130, Relic = 20 },
}
