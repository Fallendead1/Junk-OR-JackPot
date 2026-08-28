local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)

local AnnounceService = {}

local TIER_RANK = { Scrap = 1, Common = 2, Good = 3, Rare = 4, Epic = 5, Mythic = 6, Relic = 7 }
local MIN_RANK = TIER_RANK[Config.ANNOUNCE_MIN_TIER]

-- Session-only rate-limit state.
local lastAnnounceTimeByPlayer = {}
local serverAnnounceTimestamps = {} -- rolling window of the last minute's announce times

local function isWithinServerLimit()
	local now = os.clock()

	local i = 1
	while i <= #serverAnnounceTimestamps do
		if now - serverAnnounceTimestamps[i] > 60 then
			table.remove(serverAnnounceTimestamps, i)
		else
			i += 1
		end
	end

	return #serverAnnounceTimestamps < Config.ANNOUNCE_PER_SERVER_PER_MIN
end

-- GDD §9.1. Note "pulled a {RARITY}" is the literal spec template (not
-- grammar-adjusted for vowels like the GDD's own flavor-text example).
local function formatMessage(player, tier, itemName, value, zoneName)
	if tier == "Relic" then
		return "[!!!] " .. player.DisplayName .. " FOUND A RELIC — " .. itemName .. " (" .. value .. " coins). Server 1."
	end
	return "[!] " .. player.DisplayName .. " pulled a " .. string.upper(tier) .. " — " .. itemName .. " (" .. value .. " coins) in " .. zoneName .. "!"
end

-- Called after every reveal. Silently does nothing below the Epic threshold.
function AnnounceService.Announce(player, tier, itemName, value, zoneName)
	local rank = TIER_RANK[tier]
	if not rank or rank < MIN_RANK then
		return
	end

	local bypassesLimit = tier == "Mythic" or tier == "Relic"

	if not bypassesLimit then
		local lastTime = lastAnnounceTimeByPlayer[player] or 0
		if os.clock() - lastTime < Config.ANNOUNCE_PER_PLAYER_COOLDOWN then
			return
		end
		if not isWithinServerLimit() then
			return
		end

		lastAnnounceTimeByPlayer[player] = os.clock()
		table.insert(serverAnnounceTimestamps, os.clock())
	end

	local message = formatMessage(player, tier, itemName, value, zoneName)
	ReplicatedStorage.Remotes.Announce:FireAllClients(message, tier)
end

function AnnounceService.Init()
	Players.PlayerRemoving:Connect(function(player)
		lastAnnounceTimeByPlayer[player] = nil
	end)
end

return AnnounceService
