local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)

-- GDD §12.2: "Every [remote] is rate-limited and validated." One shared
-- sliding-window limiter every remote handler calls first, so a player
-- spamming any single remote past Config.MAX_REMOTE_PER_SEC gets silently
-- ignored before the handler's own validation even runs.
local RateLimiter = {}

-- [player] = { [remoteName] = { timestamp, timestamp, ... } }
local timestampsByPlayer = {}

-- Call as the very first line of every remote handler:
--   if not RateLimiter.Allow(player, "RequestDig") then return end
function RateLimiter.Allow(player, remoteName)
	local playerTimestamps = timestampsByPlayer[player]
	if not playerTimestamps then
		playerTimestamps = {}
		timestampsByPlayer[player] = playerTimestamps
	end

	local remoteTimestamps = playerTimestamps[remoteName]
	if not remoteTimestamps then
		remoteTimestamps = {}
		playerTimestamps[remoteName] = remoteTimestamps
	end

	local now = os.clock()
	local i = 1
	while i <= #remoteTimestamps do
		if now - remoteTimestamps[i] > Config.MAX_REMOTE_WINDOW_SECONDS then
			table.remove(remoteTimestamps, i)
		else
			i += 1
		end
	end

	if #remoteTimestamps >= Config.MAX_REMOTE_PER_SEC then
		return false
	end

	table.insert(remoteTimestamps, now)
	return true
end

function RateLimiter.Init()
	Players.PlayerRemoving:Connect(function(player)
		timestampsByPlayer[player] = nil
	end)
end

return RateLimiter
