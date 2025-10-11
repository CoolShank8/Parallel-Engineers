local GameMode = {}
local PlotService = require(game.ServerScriptService.Services.PlotService)

function GameMode:Start()
	for i ,Player in game.Players:GetPlayers() do
		PlotService.Give(Player,)
		
		Player.Character.HumanoidRootPart.CFrame = workspace.Map.Plot1.CFrame * CFrame.new(0, 5, 0)
	end
end

return GameMode