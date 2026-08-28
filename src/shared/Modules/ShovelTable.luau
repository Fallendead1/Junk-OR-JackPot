-- Shovel tiers. Source: GDD §7.1. Index = shovelTier (also referenced by
-- ZoneTable's requirement.shovelTier gates). Tiers 4-5 (Powered, Excavator)
-- are added in Phase 11.
return {
	[1] = { name = "Rusty", cost = 0, digTimeMultiplier = 1.00, luckBonus = 0.00 },
	[2] = { name = "Steel", cost = 8000, digTimeMultiplier = 0.75, luckBonus = 0.00 },
	[3] = { name = "Reinforced", cost = 100000, digTimeMultiplier = 0.60, luckBonus = 0.15 },
}
