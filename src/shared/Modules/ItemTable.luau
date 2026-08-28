-- All 60 items. Source: GDD §4.6.
--
-- This is one of the files CLAUDE.md marks as yours to own, not Claude's. It's
-- filled in here with the GDD's exact names/tiers/zones/values so Phase 0's
-- exit criteria (exactly 60 entries) actually pass, but it's still your file —
-- flavor text, icons, or a rebalance later is your call.
return {
	-- Scrap
	bent_nail = { name = "Bent Nail", tier = "Scrap", zone = 1, value = 6 },
	cracked_bottle = { name = "Cracked Bottle", tier = "Scrap", zone = 1, value = 11 },
	soggy_newspaper = { name = "Soggy Newspaper", tier = "Scrap", zone = 1, value = 15 },
	chewed_wire = { name = "Chewed Wire", tier = "Scrap", zone = 2, value = 22 },
	rusted_bolt = { name = "Rusted Bolt", tier = "Scrap", zone = 2, value = 35 },
	barnacle_clump = { name = "Barnacle Clump", tier = "Scrap", zone = 3, value = 55 },
	shredded_manifest = { name = "Shredded Manifest", tier = "Scrap", zone = 3, value = 85 },
	fused_slag = { name = "Fused Slag", tier = "Scrap", zone = 4, value = 180 },

	-- Common
	tin_lunchbox = { name = "Tin Lunchbox", tier = "Common", zone = 1, value = 38 },
	novelty_keychain = { name = "Novelty Keychain", tier = "Common", zone = 1, value = 62 },
	cracked_wristwatch = { name = "Cracked Wristwatch", tier = "Common", zone = 1, value = 95 },
	brass_doorknob = { name = "Brass Doorknob", tier = "Common", zone = 2, value = 110 },
	ceramic_figurine = { name = "Ceramic Figurine", tier = "Common", zone = 2, value = 190 },
	divers_boot = { name = "Diver's Boot", tier = "Common", zone = 3, value = 260 },
	ships_cutlery_set = { name = "Ship's Cutlery Set", tier = "Common", zone = 3, value = 420 },
	deposit_slip_book = { name = "Deposit Slip Book", tier = "Common", zone = 4, value = 700 },
	security_baton = { name = "Security Baton", tier = "Common", zone = 4, value = 1100 },
	scorched_alloy_plate = { name = "Scorched Alloy Plate", tier = "Common", zone = 5, value = 1900 },

	-- Good
	silver_locket = { name = "Silver Locket", tier = "Good", zone = 1, value = 180 },
	pocket_camera = { name = "Pocket Camera", tier = "Good", zone = 1, value = 310 },
	sealed_coin_roll = { name = "Sealed Coin Roll", tier = "Good", zone = 1, value = 480 },
	copper_ingot = { name = "Copper Ingot", tier = "Good", zone = 2, value = 620 },
	antique_compass = { name = "Antique Compass", tier = "Good", zone = 2, value = 900 },
	brass_sextant = { name = "Brass Sextant", tier = "Good", zone = 3, value = 1400 },
	captains_log = { name = "Captain's Log", tier = "Good", zone = 3, value = 2200 },
	bearer_bond_sheaf = { name = "Bearer Bond Sheaf", tier = "Good", zone = 4, value = 3600 },
	vault_key_blank = { name = "Vault Key Blank", tier = "Good", zone = 4, value = 5400 },
	iridium_shard = { name = "Iridium Shard", tier = "Good", zone = 5, value = 9800 },

	-- Rare
	signed_baseball = { name = "Signed Baseball", tier = "Rare", zone = 1, value = 700 },
	pre_war_radio = { name = "Pre-War Radio", tier = "Rare", zone = 1, value = 1450 },
	gold_signet_ring = { name = "Gold Signet Ring", tier = "Rare", zone = 2, value = 2000 },
	nautical_chronometer = { name = "Nautical Chronometer", tier = "Rare", zone = 2, value = 3800 },
	ships_bell_intact = { name = "Ship's Bell (Intact)", tier = "Rare", zone = 3, value = 5200 },
	pearl_strand = { name = "Pearl Strand", tier = "Rare", zone = 3, value = 8600 },
	safe_deposit_box = { name = "Safe Deposit Box", tier = "Rare", zone = 4, value = 12000 },
	unmarked_gold_bar = { name = "Unmarked Gold Bar", tier = "Rare", zone = 4, value = 19000 },
	meteorite_core = { name = "Meteorite Core", tier = "Rare", zone = 5, value = 28000 },
	fallen_star_fragment = { name = "Fallen Star Fragment", tier = "Rare", zone = 5, value = 42000 },

	-- Epic
	prototype_arcade_board = { name = "Prototype Arcade Board", tier = "Epic", zone = 1, value = 4200 },
	sealed_wax_cylinder = { name = "Sealed Wax Cylinder", tier = "Epic", zone = 1, value = 8300 },
	master_divers_helm = { name = "Master Diver's Helm", tier = "Epic", zone = 2, value = 14000 },
	buried_coin_hoard = { name = "Buried Coin Hoard", tier = "Epic", zone = 3, value = 32000 },
	admirals_sabre = { name = "Admiral's Sabre", tier = "Epic", zone = 3, value = 45000 },
	vault_manifest = { name = "Vault Manifest", tier = "Epic", zone = 4, value = 78000 },
	blackplate_cipher = { name = "Blackplate Cipher", tier = "Epic", zone = 4, value = 99000 },
	crater_glass_prism = { name = "Crater Glass Prism", tier = "Epic", zone = 5, value = 210000 },

	-- Mythic
	landfill_crown = { name = "The Landfill Crown", tier = "Mythic", zone = 1, value = 26000 },
	unopened_time_capsule = { name = "Unopened Time Capsule", tier = "Mythic", zone = 1, value = 55000 },
	sunken_reliquary = { name = "Sunken Reliquary", tier = "Mythic", zone = 2, value = 88000 },
	krakens_tooth = { name = "Kraken's Tooth", tier = "Mythic", zone = 3, value = 210000 },
	ghost_ship_wheel = { name = "Ghost Ship Wheel", tier = "Mythic", zone = 3, value = 300000 },
	founders_ledger = { name = "The Founder's Ledger", tier = "Mythic", zone = 4, value = 480000 },
	vault_zero_keycard = { name = "Vault Zero Keycard", tier = "Mythic", zone = 4, value = 660000 },
	impact_diamond = { name = "Impact Diamond", tier = "Mythic", zone = 5, value = 1400000 },

	-- Relic
	the_first_lump = { name = "The First Lump", tier = "Relic", zone = 1, value = 320000 },
	leviathans_eye = { name = "Leviathan's Eye", tier = "Relic", zone = 3, value = 1600000 },
	the_drowned_crown = { name = "The Drowned Crown", tier = "Relic", zone = 3, value = 1950000 },
	vault_zero_itself = { name = "Vault Zero Itself", tier = "Relic", zone = 4, value = 4400000 },
	the_wandering_star = { name = "The Wandering Star", tier = "Relic", zone = 5, value = 8000000 },
	nothing_at_all = { name = "Nothing At All", tier = "Relic", zone = 5, value = 9600000 },
}
