local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Modules.Config)

local EconomyService = require(ServerScriptService.Services.EconomyService)

local CatalogueService = {}

-- GDD §5.2. Config.MILESTONE_THRESHOLDS/MILESTONE_COINS are parallel arrays
-- (10 -> 5000, 25 -> 50000, 40 -> 500000, 60 -> 5000000). Pays each threshold
-- at most once per profile, tracked in profile.Data.milestonesPaid. Luck is
-- not touched here -- the caller (RevealService.ProcessReveal) recalculates
-- it once after all of a reveal's side effects are applied.
function CatalogueService.CheckMilestones(player, profile)
	for i, threshold in ipairs(Config.MILESTONE_THRESHOLDS) do
		if profile.Data.catalogueCount >= threshold and not profile.Data.milestonesPaid[threshold] then
			profile.Data.milestonesPaid[threshold] = true
			EconomyService.AddCoins(player, Config.MILESTONE_COINS[i], "Catalogue milestone: " .. threshold .. " entries")
		end
	end
end

function CatalogueService.Init() end

return CatalogueService
