local ServerScriptService = game:GetService("ServerScriptService")
local Services = ServerScriptService.Services

-- Add service names here, in the exact order they must initialise.
-- Empty until Phase 1 — Phase 0 builds no services.
local SERVICE_INIT_ORDER = {}

for _, serviceName in ipairs(SERVICE_INIT_ORDER) do
	local service = require(Services[serviceName])
	service.Init()
end
