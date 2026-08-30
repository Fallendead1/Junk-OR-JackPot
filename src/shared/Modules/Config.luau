-- Every tunable number in the game. No logic lives here. Source: GDD §13.
return {
	-- CORE DECISION (the two levers from GDD §6.5)
	BLIND_RATIO = 0.70, -- coarse lever; moves the blind/open split in ~17pt steps
	OPEN_COST_RATIO = 0.205, -- fine lever; shifts the split continuously

	-- LUCK
	LUCK_CAP = 1.00,
	LUCK_CHARM_PASS = 0.10,
	LUCK_PER_SHARD = 0.02,
	LUCK_SHARD_CAP = 0.40,
	LUCK_PER_MILESTONE = 0.03,

	-- COST CURVES
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

	-- DIG MINIGAME (dig-minigame-spec.md, replaces the old hold-E dig system)
	COMMIT_TRIGGER_RANGE = 6, -- studs; §3.1/§7 state this explicitly but it was missing from the spec's own Config block
	SHOVEL_DECAY_BASE = 0.08, -- bar drain per second at Power 1 vs Scrap find
	CLICK_FILL_BASE = 0.12, -- bar fill per click at Power 1 vs Scrap find
	RARITY_DIFFICULTY = {
		Scrap = 0.6,
		Common = 0.8,
		Good = 1.0,
		Rare = 1.3,
		Epic = 1.7,
		Mythic = 2.2,
		Relic = 3.0,
	},
	POWER_FILL_SCALE = 0.025,
	POWER_DECAY_SCALE = 0.006,
	MAX_CLICK_RATE = 8,
	SUCCESS_THRESHOLD = 0.85,
	FAIL_THRESHOLD = 0.15,
	BAR_START_VALUE = 0.2, -- not in the spec's own text; starting at 1.0 (full) meant a single click could nearly already satisfy SUCCESS_THRESHOLD

	-- METAL DETECTOR
	SCAN_INTERVAL = 4.0,
	SCAN_BASE_CHANCE = 0.55,
	MAX_ACTIVE_FINDS = 3,
	FIND_DESPAWN_TIME = 30,

	-- BAR UI
	BAR_WIDTH_PX = 500,
	BAR_HEIGHT_PX = 40,
	SCREEN_SHAKE_MAGNITUDE = 0.08,
	SCREEN_SHAKE_DURATION = 0.15,
	SWING_DOWN_DURATION = 0.08,
	SWING_RETURN_DURATION = 0.12,

	-- SHOVEL TIERS (Power, WalkSpeedBonus, Cost) -- fully replaces the old ShovelTable.luau
	SHOVEL_TIERS = {
		[1] = { name = "Rusty Shovel", power = 1, speed = 0.00, cost = 0, robux = 0 },
		[2] = { name = "Stone Shovel", power = 3, speed = 0.05, cost = 1600, robux = 24 },
		[3] = { name = "Metal Shovel", power = 5, speed = 0.07, cost = 9000, robux = 64 },
		[4] = { name = "Gold Shovel", power = 7, speed = 0.09, cost = 45000, robux = 120 },
		[5] = { name = "Amethyst Shovel", power = 9, speed = 0.11, cost = 190000, robux = 200 },
	},

	-- DETECTOR TIERS (Luck multiplier, Range, Cost). Numbered 1-5 rather than
	-- the spec's own 0-4 -- ProfileStore's Reconcile silently drops a `[0]`
	-- key in a profile default table (likely an ipairs-based copy internally,
	-- since ipairs never visits index 0), confirmed live: ownedDetectors's
	-- default {[0]=true} never actually reached a real saved profile. Every
	-- other table in this game already starts at 1; this just brings
	-- detectors in line rather than fighting that quirk forever.
	DETECTOR_TIERS = {
		[1] = { name = "Starter Detector", luck = 1, range = 6.0, cost = 0, robux = 0 },
		[2] = { name = "Copper Detector", luck = 3, range = 7.5, cost = 400, robux = 9 },
		[3] = { name = "Silver Detector", luck = 5, range = 8.0, cost = 4000, robux = 24 },
		[4] = { name = "Gold Detector", luck = 8, range = 8.5, cost = 25000, robux = 64 },
		[5] = { name = "Platinum Detector", luck = 12, range = 9.0, cost = 150000, robux = 200 },
	},
}
