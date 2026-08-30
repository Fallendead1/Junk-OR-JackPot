local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Config)

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local DetectorService = require(ServerScriptService.Services.DetectorService)

-- dig-minigame-spec.md Step 5: the commit trigger. Clicking an owned,
-- still-active find spot within range starts the minigame -- fully
-- validated server-side (§3.1) regardless of what the client's ClickDetector
-- already filtered out.
local MinigameService = {}

-- [player] = { findSpotId, part, tier, zone, decayPerSecond, fillPerClick }
-- Grade is deliberately not duplicated in here -- it stays in DetectorService's
-- own table, read fresh by findSpotId whenever the eventual reveal needs it.
local activeMinigames = {}

function MinigameService.IsInMinigame(player)
	return activeMinigames[player] ~= nil
end

local function onFindSpotClicked(player, part)
	if MinigameService.IsInMinigame(player) then
		return -- one minigame at a time
	end

	if part:GetAttribute("OwnerId") ~= player.UserId then
		return -- not this player's find -- no stealing
	end

	if not part:GetAttribute("Active") then
		return -- already claimed or expired
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	-- ClickDetector's own MaxActivationDistance already gates this client-side,
	-- but §3.1 calls the range check out explicitly as a server validation.
	if (rootPart.Position - part.Position).Magnitude > Config.COMMIT_TRIGGER_RANGE then
		return
	end

	local findSpotId = tostring(part:GetAttribute("FindSpotId"))
	local findData = DetectorService.GetFindData(player, findSpotId)
	if not findData then
		return -- never trust a client-reachable Part's attributes alone
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	part:SetAttribute("Active", false) -- prevents double-triggering

	local shovelInfo = Config.SHOVEL_TIERS[profile.Data.equippedShovelTier]
	local decayPerSecond = Config.SHOVEL_DECAY_BASE * Config.RARITY_DIFFICULTY[findData.tier] * (1 - (shovelInfo.power * Config.POWER_DECAY_SCALE))
	local fillPerClick = Config.CLICK_FILL_BASE + (shovelInfo.power * Config.POWER_FILL_SCALE)

	activeMinigames[player] = {
		findSpotId = findSpotId,
		part = part,
		tier = findData.tier,
		zone = findData.zone,
		decayPerSecond = decayPerSecond,
		fillPerClick = fillPerClick,
	}

	-- Ownership of this find's lifecycle transfers to the minigame now -- the
	-- despawn sweep and MAX_ACTIVE_FINDS count shouldn't touch it anymore.
	DetectorService.ReleaseFind(player, findSpotId)

	-- §3.1/§7 payload, minus Grade -- GDD §12.3 says the Grade roll must
	-- never reach the client, and this is a plain RemoteEvent argument.
	ReplicatedStorage.Remotes.MinigameStart:FireClient(player, {
		rarity = findData.tier,
		zone = findData.zone,
		findSpotId = findSpotId,
		decayPerSecond = decayPerSecond,
		fillPerClick = fillPerClick,
	})
end

local function hookFindSpot(part)
	local clickDetector = part:WaitForChild("ClickDetector", 5)
	if not clickDetector then
		return
	end

	clickDetector.MouseClick:Connect(function(player)
		onFindSpotClicked(player, part)
	end)
end

function MinigameService.Init()
	local findsFolder = Workspace:WaitForChild("FindSpots")

	for _, part in ipairs(findsFolder:GetChildren()) do
		hookFindSpot(part)
	end
	findsFolder.ChildAdded:Connect(hookFindSpot)

	Players.PlayerRemoving:Connect(function(player)
		activeMinigames[player] = nil
	end)
end

return MinigameService
