local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = ServerScriptService.Services

-- Every RemoteEvent in the game is created here, never by hand in the explorer.
local REMOTE_EVENT_NAMES = {
	"RequestDig",
	"LumpSpawned",
	"RequestSellBlind",
	"BlindSold",
	"CoinsChanged",
}

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

for _, remoteName in ipairs(REMOTE_EVENT_NAMES) do
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = remoteName
	remoteEvent.Parent = remotesFolder
end

-- Add service names here, in the exact order they must initialise.
local SERVICE_INIT_ORDER = {
	"PlayerDataService",
	"EconomyService",
	"DigService",
}

for _, serviceName in ipairs(SERVICE_INIT_ORDER) do
	local service = require(Services[serviceName])
	service.Init()
end
