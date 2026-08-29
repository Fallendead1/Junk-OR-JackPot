-- Real GamePass/DeveloperProduct ids from the Creator Dashboard for this
-- experience. Keys match profile.Data.passes' field names (GDD §11).
return {
	GamePasses = {
		scanner = 1962012857,
		bigShelf = 1962384871,
		luckyCharm = 1963824820,
		autoDig = 1966140567,
		doubleCoins = 1962054840,
		vip = 1962648891,
	},
	-- GDD §10.2. Coin grants are carried here (not as magic numbers in
	-- MonetizationService) so they stay auditable next to the id.
	DevProducts = {
		coinPouch = { id = 3710308147, coins = 5000 },
		coinSack = { id = 3710308455, coins = 40000 },
		coinCrate = { id = 3710308490, coins = 350000 },
		coinVault = { id = 3710308514, coins = 3000000 },
		goldenLumpX3 = { id = 3710308528 },
		zoneSkip = { id = 3710308537 },
	},
}
