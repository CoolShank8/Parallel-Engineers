local GameMode = {}
local PlotService = require(game.ServerScriptService.Services.PlotService)
local EntityAdmin = require(game.ReplicatedStorage.Modules.EntityAdmin)


function GameMode:Start()
	for i ,Player in game.Players:GetPlayers() do
		Player.Character.HumanoidRootPart.CFrame = workspace.Spawns:GetChildren()[i].CFrame * CFrame.new(0, 10, 0)
	end

end

return GameMode