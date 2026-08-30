local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore)

-- Phase 2 requires autosaving every 60s; ProfileStore defaults to 300s.
ProfileStore.SetConstant("AUTO_SAVE_PERIOD", 60)

-- Exact shape from GDD §11. Every field has a default; nothing is nil-checked
-- at read time — Profile:Reconcile() below fills in any field a service adds
-- to this template later without needing a migration for existing profiles.
local ProfileTemplate = {
	-- Currency
	coins = 0,
	scrap = 0,
	relicShards = 0,

	-- Progression
	currentZone = 1,
	zonesUnlocked = { [1] = true },
	shovelTier = 1, -- old hold-E dig system; retired once dig-minigame-spec.md's build order reaches it
	shelfSlots = Config.SHELF_BASE_SLOTS,
	luckBonus = 0.0,

	-- Dig minigame equipment (dig-minigame-spec.md §5.3)
	equippedDetectorTier = 0,
	equippedShovelTier = 1,
	ownedDetectors = { [0] = true },
	ownedShovels = { [1] = true },
	walkSpeedBonus = 0,

	-- Collection
	catalogue = {},
	catalogueCount = 0,
	milestonesPaid = {},

	-- Shelf
	shelf = {},

	-- Inventory (unsold revealed items awaiting keep/sell)
	inventory = {},

	-- Monetization state
	passes = {
		scanner = false,
		bigShelf = false,
		luckyCharm = false,
		autoDig = false,
		doubleCoins = false,
		vip = false,
	},
	coinMultiplier = 1,

	-- Retention
	lastGoldenLump = 0,
	goldenLumpsOwed = 0,
	-- Not in the GDD §11 schema (which only lists goldenLumpsOwed), but GDD
	-- §10.2's Zone Skip needs an equivalent consumable counter -- added
	-- following that exact same pattern.
	zoneSkipsOwed = 0,
	bestFindValue = 0,
	bestFindItem = "",
	weeklyBestValue = 0,
	weeklyBestWeek = 0,

	-- Tutorial / session
	freeOpensLeft = 3,
	totalLumpsDug = 0,
	decisionsBlind = 0,
	decisionsOpen = 0,

	-- Meta
	createdAt = 0,
	dataVersion = 1,
}

local playerStore = ProfileStore.New("PlayerData", ProfileTemplate)

local PlayerDataService = {}

-- Fires (player) once a profile has finished loading and is safe to read/write
-- via GetProfile(player). Other services use this instead of duplicating
-- join/load logic. (Fires just the player, not the profile itself — the
-- Profile object has internal cyclic references that BindableEvent:Fire()
-- can't marshal.)
PlayerDataService.ProfileLoaded = Instance.new("BindableEvent")

local profiles = {}

local function onPlayerAdded(player)
	local profile = playerStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Only happens if the server is shutting down while the load was in flight.
		player:Kick("Your data could not be loaded. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		-- Player left while their profile was still loading.
		profile:EndSession()
		return
	end

	if profile.Data.createdAt == 0 then
		profile.Data.createdAt = os.time()
	end

	profiles[player] = profile
	print("[PlayerDataService] Loaded profile for " .. player.Name)
	PlayerDataService.ProfileLoaded:Fire(player)
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if profile == nil then
		return
	end

	profile:EndSession()
	print("[PlayerDataService] Released profile for " .. player.Name)
end

-- Other services will call this once they exist (Phase 3+). Returns nil if
-- the profile hasn't loaded yet or the player has left.
function PlayerDataService.GetProfile(player)
	return profiles[player]
end

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerDataService
