local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)

local AnnounceService = {}

local TIER_RANK = { Scrap = 1, Common = 2, Good = 3, Rare = 4, Epic = 5, Mythic = 6, Relic = 7 }
local MIN_RANK = TIER_RANK[Config.ANNOUNCE_MIN_TIER]

-- GDD §9.1: Relic announces on every server, via MessagingService. Every
-- server's AnnounceService.Init() subscribes to this topic, so publishing
-- here is the only way a Relic reaches this server's own players too.
local RELIC_TOPIC = "RelicAnnouncement"

-- Roblox doesn't expose a real sequential server number -- game.JobId is a
-- GUID, unique per running server but not human-friendly. Hashed down to a
-- short number purely so the GDD's "Server {n}" template has something
-- glanceable to show; it has no gameplay meaning.
local function getServerLabel()
	local jobId = game.JobId
	if jobId == "" then
		return "Studio" -- JobId is blank outside a real published server
	end

	local hash = 0
	for i = 1, #jobId do
		hash = (hash * 31 + string.byte(jobId, i)) % 10000
	end
	return tostring(hash)
end

-- Session-only rate-limit state.
local lastAnnounceTimeByPlayer = {}
local serverAnnounceTimestamps = {} -- rolling window of the last minute's announce times

local function isWithinServerLimit()
	local now = os.clock()

	local i = 1
	while i <= #serverAnnounceTimestamps do
		if now - serverAnnounceTimestamps[i] > Config.ANNOUNCE_SERVER_WINDOW_SECONDS then
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
		return "[!!!] " .. player.DisplayName .. " FOUND A RELIC — " .. itemName .. " (" .. value .. " coins). Server " .. getServerLabel() .. "."
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

	if tier == "Relic" then
		-- Publishing (not FireAllClients) is what reaches every server,
		-- including this one -- the Init() subscription below is what actually
		-- fires the clients once the message comes back through the topic.
		local published = pcall(function()
			MessagingService:PublishAsync(RELIC_TOPIC, message)
		end)
		if not published then
			-- MessagingService can be temporarily rate-limited/unavailable;
			-- still announce locally so the moment isn't lost entirely.
			ReplicatedStorage.Remotes.Announce:FireAllClients(message, tier)
		end
	else
		ReplicatedStorage.Remotes.Announce:FireAllClients(message, tier)
	end
end

function AnnounceService.Init()
	Players.PlayerRemoving:Connect(function(player)
		lastAnnounceTimeByPlayer[player] = nil
	end)

	local subscribed, err = pcall(function()
		MessagingService:SubscribeAsync(RELIC_TOPIC, function(message)
			ReplicatedStorage.Remotes.Announce:FireAllClients(message.Data, "Relic")
		end)
	end)
	if not subscribed then
		warn("[AnnounceService] MessagingService subscription failed: " .. tostring(err))
	end
end

return AnnounceService
