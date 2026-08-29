local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local LeaderboardService = require(ServerScriptService.Services.LeaderboardService)

-- GDD §6.5: one row per BLIND/OPEN decision, aggregated weekly to compute
-- blindRate per zone against the drift-detection table. Rows carry
-- structured fields rather than a single rankable number, so this uses a
-- plain DataStore instead of the OrderedDataStore LeaderboardService uses
-- (OrderedDataStore can only store a bare integer per key) -- namespaced by
-- week the same way, via LeaderboardService.GetWeekKey().
local TelemetryService = {}

local function getStoreForWeek(weekKey)
	return DataStoreService:GetDataStore("Telemetry_" .. weekKey)
end

-- Fire-and-forget, matching the GDD's own phrasing. Never blocks or fails
-- the caller -- a dropped telemetry row is not worth interrupting a player's
-- decision over.
function TelemetryService.LogDecision(player, zone, hintScore, choice)
	local row = {
		userId = player.UserId,
		zone = zone,
		hintScore = hintScore,
		choice = choice,
		timestamp = os.time(),
	}

	local store = getStoreForWeek(LeaderboardService.GetWeekKey())
	local rowKey = tostring(row.timestamp) .. "_" .. HttpService:GenerateGUID(false)

	task.spawn(function()
		pcall(function()
			store:SetAsync(rowKey, row)
		end)
	end)
end

-- Reads every row logged for a given week (defaults to the current week).
-- Can yield and can be slow for a busy week -- command-bar / analysis use
-- only, never called from a remote handler.
function TelemetryService.GetRowsForWeek(weekKey)
	weekKey = weekKey or LeaderboardService.GetWeekKey()
	local store = getStoreForWeek(weekKey)

	local rows = {}
	pcall(function()
		local pages = store:ListKeysAsync()
		while true do
			for _, key in ipairs(pages:GetCurrentPage()) do
				local row = store:GetAsync(key.KeyName)
				if row then
					table.insert(rows, row)
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)

	return rows
end

-- The GDD §6.5 check: blindRate = blindCount / totalDecisions, per zone.
function TelemetryService.GetBlindRateByZone(weekKey)
	local rows = TelemetryService.GetRowsForWeek(weekKey)

	local blindCountByZone = {}
	local totalByZone = {}
	for _, row in ipairs(rows) do
		totalByZone[row.zone] = (totalByZone[row.zone] or 0) + 1
		if row.choice == "BLIND" then
			blindCountByZone[row.zone] = (blindCountByZone[row.zone] or 0) + 1
		end
	end

	local blindRateByZone = {}
	for zone, total in pairs(totalByZone) do
		blindRateByZone[zone] = (blindCountByZone[zone] or 0) / total
	end
	return blindRateByZone
end

function TelemetryService.Init() end

return TelemetryService
