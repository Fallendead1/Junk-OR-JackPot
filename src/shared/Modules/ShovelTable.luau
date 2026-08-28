-- Shovel tiers. Source: GDD §7.1. Index = shovelTier (also referenced by
-- ZoneTable's requirement.shovelTier gates).
-- Powered/Excavator both grant +0.30 Luck, not a stacked 4th increment --
-- luck is read from whichever tier the player currently owns (never summed
-- across tiers), so this "replaces the above" behavior falls out for free.
return {
	[1] = { name = "Rusty", cost = 0, digTimeMultiplier = 1.00, luckBonus = 0.00, lumpsPerDig = 1 },
	[2] = { name = "Steel", cost = 8000, digTimeMultiplier = 0.75, luckBonus = 0.00, lumpsPerDig = 1 },
	[3] = { name = "Reinforced", cost = 100000, digTimeMultiplier = 0.60, luckBonus = 0.15, lumpsPerDig = 1 },
	[4] = { name = "Powered", cost = 1200000, digTimeMultiplier = 0.48, luckBonus = 0.30, lumpsPerDig = 1 },
	[5] = { name = "Excavator", cost = 14000000, digTimeMultiplier = 0.40, luckBonus = 0.30, lumpsPerDig = 2 },
}
