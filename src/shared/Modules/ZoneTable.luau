-- The 5 zones. Indexed by zone number. Source: GDD §3.
-- requirement is nil for Zone 1 (free). Otherwise it's a table of gates that
-- must ALL be met: shovelTier (see UpgradeService's tier numbering, GDD §7.1 —
-- 1 Rusty, 2 Steel, 3 Reinforced, 4 Powered, 5 Excavator) and/or catalogueEntries.
return {
	[1] = {
		name = "The Dump",
		unlockCost = 0,
		requirement = nil,
		digTime = 3.0,
		valueMultiplier = 1.0,
		openCost = 45,
		gradeMix = { Dud = 40, Plain = 38, Promising = 18, Charged = 4 },
	},
	[2] = {
		name = "The Quarry",
		unlockCost = 25000,
		requirement = { catalogueEntries = 5 },
		digTime = 3.5,
		valueMultiplier = 2.2,
		openCost = 125,
		gradeMix = { Dud = 32, Plain = 40, Promising = 22, Charged = 6 },
	},
	[3] = {
		name = "The Wreck",
		unlockCost = 150000,
		requirement = { shovelTier = 2, catalogueEntries = 15 },
		digTime = 4.0,
		valueMultiplier = 5.0,
		openCost = 360,
		gradeMix = { Dud = 24, Plain = 41, Promising = 26, Charged = 9 },
	},
	[4] = {
		name = "The Vault",
		unlockCost = 900000,
		requirement = { shovelTier = 3, catalogueEntries = 30 },
		digTime = 4.5,
		valueMultiplier = 11.0,
		openCost = 1000,
		gradeMix = { Dud = 16, Plain = 40, Promising = 31, Charged = 13 },
	},
	[5] = {
		name = "The Crater",
		unlockCost = 5000000,
		requirement = { shovelTier = 4, catalogueEntries = 50 },
		digTime = 5.0,
		valueMultiplier = 24.0,
		openCost = 2800,
		gradeMix = { Dud = 8, Plain = 36, Promising = 38, Charged = 18 },
	},
}
