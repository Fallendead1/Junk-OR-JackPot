local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardService = {}

local SECONDS_PER_WEEK = 7 * 24 * 3600
-- Jan 5 1970 00:00 UTC was a Monday (Jan 1 1970 was a Thursday, +4 days).
-- Using this as a fixed reference point turns "resets Monday 00:00 UTC" into
-- a plain integer division -- no calendar/timezone math needed, and os.time()
-- on Roblox is already UTC.
local REFERENCE_MONDAY = 4 * 24 * 3600

function LeaderboardService.GetWeekKey()
	return math.floor((os.time() - REFERENCE_MONDAY) / SECONDS_PER_WEEK)
end

local function getStoresForWeek(weekKey)
	local ordered = DataStoreService:GetOrderedDataStore("BestFindRank_" .. weekKey)
	local details = DataStoreService:GetDataStore("BestFindDetails_" .. weekKey)
	return ordered, details
end

-- Called after every reveal (normal open or bin purchase). Updates the
-- player's own all-time and weekly-best fields, and -- only when this beats
-- their own weekly best -- pushes to the shared weekly leaderboard.
function LeaderboardService.RecordFind(player, profile, itemName, value)
	if value > profile.Data.bestFindValue then
		profile.Data.bestFindValue = value
		profile.Data.bestFindItem = itemName
	end

	local currentWeek = LeaderboardService.GetWeekKey()
	if profile.Data.weeklyBestWeek ~= currentWeek then
		profile.Data.weeklyBestValue = 0
		profile.Data.weeklyBestWeek = currentWeek
	end

	if value <= profile.Data.weeklyBestValue then
		return
	end

	profile.Data.weeklyBestValue = value

	local ordered, details = getStoresForWeek(currentWeek)
	local userIdKey = tostring(player.UserId)
	task.spawn(function()
		pcall(function()
			ordered:SetAsync(userIdKey, value)
			details:SetAsync(userIdKey, { itemName = itemName, value = value, displayName = player.DisplayName })
		end)
	end)
end

-- Returns up to `limit` entries for the CURRENT week, highest value first:
-- { { userId, value, itemName, displayName }, ... }. Can yield (real
-- DataStore calls) -- fine to call from a RemoteEvent handler.
function LeaderboardService.GetTopFinds(limit)
	local currentWeek = LeaderboardService.GetWeekKey()
	local ordered, details = getStoresForWeek(currentWeek)

	local results = {}
	pcall(function()
		local pages = ordered:GetSortedAsync(false, limit)
		local page = pages:GetCurrentPage()
		for _, entry in ipairs(page) do
			local detail = details:GetAsync(entry.key)
			table.insert(results, {
				userId = entry.key,
				value = entry.value,
				itemName = detail and detail.itemName,
				displayName = detail and detail.displayName,
			})
		end
	end)

	return results
end

local function onRequestLeaderboard(player)
	local topFinds = LeaderboardService.GetTopFinds(3)
	ReplicatedStorage.Remotes.LeaderboardResult:FireClient(player, topFinds)
end

function LeaderboardService.Init()
	ReplicatedStorage.Remotes.RequestLeaderboard.OnServerEvent:Connect(onRequestLeaderboard)
end

return LeaderboardService
