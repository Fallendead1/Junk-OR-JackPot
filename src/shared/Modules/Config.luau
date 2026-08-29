-- Every tunable number in the game. No logic lives here. Source: GDD §13.
return {
	-- CORE DECISION (the two levers from GDD §6.5)
	BLIND_RATIO = 0.70, -- coarse lever; moves the blind/open split in ~17pt steps
	OPEN_COST_RATIO = 0.205, -- fine lever; shifts the split continuously

	-- LUCK
	LUCK_CAP = 1.00,
	LUCK_REINFORCED = 0.15,
	LUCK_POWERED = 0.30,
	LUCK_CHARM_PASS = 0.10,
	LUCK_PER_SHARD = 0.02,
	LUCK_SHARD_CAP = 0.40,
	LUCK_PER_MILESTONE = 0.03,

	-- COST CURVES
	SHOVEL_BASE_COST = 8000,
	SHOVEL_COST_MULT = 12,
	SHELF_BASE_COST = 1000,
	SHELF_COST_MULT = 1.7,

	-- PACING
	DECISION_TIME_BUDGET = 2.0, -- assumed non-dig seconds per cycle; the GDD's coins/min curve (§5.6) depends on this
	FREE_OPENS = 3,
	GOLDEN_LUMP_COOLDOWN = 72000, -- 20 hours in seconds, not a calendar day

	-- BIN
	BIN_SIZE = 12,
	BIN_PRICE_MULT = 2.0,
	BIN_EXPIRY_SECONDS = 180,

	-- ANNOUNCEMENTS
	ANNOUNCE_MIN_TIER = "Epic",
	ANNOUNCE_PER_PLAYER_COOLDOWN = 60,
	ANNOUNCE_PER_SERVER_PER_MIN = 6,
	ANNOUNCE_SERVER_WINDOW_SECONDS = 60, -- the "minute" in ANNOUNCE_PER_SERVER_PER_MIN

	-- REWARDS
	MILESTONE_THRESHOLDS = { 10, 25, 40, 60 },
	MILESTONE_COINS = { 5000, 50000, 500000, 5000000 },
	LEADERBOARD_PRIZES = { 250000, 100000, 50000 },
	SHARDS_PER_MYTHIC = 1,
	SHARDS_PER_RELIC = 10,

	-- MONETIZATION (GDD §10)
	DOUBLE_COINS_MULTIPLIER = 2,
	BIG_SHELF_BONUS_SLOTS = 10,
	GOLDEN_LUMP_X3_COUNT = 3,

	-- WORLD
	SHELF_BASE_SLOTS = 12, -- free display slots before any are bought (§7.3)
	WAREHOUSE_PLOT_COUNT = 24, -- shared warehouse plots (§8.2)
	ZONE_DIG_RADIUS = 15, -- studs from a zone's DigSpot the player must stand within

	-- SECURITY
	DIG_COOLDOWN_GRACE = 0.15, -- seconds of leniency on server-side dig timing
	MAX_REMOTE_PER_SEC = 8,
	MAX_REMOTE_WINDOW_SECONDS = 1, -- the "sec" in MAX_REMOTE_PER_SEC
}
