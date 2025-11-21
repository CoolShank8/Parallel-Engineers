local GameMode = {}
local PlotSystem = require(game.ReplicatedStorage.GameSystems.PlotSystem)
local EntityAdmin = require(game.ReplicatedStorage.Packages.EntityAdmin)


function GameMode:Start()
	for i ,Player in game.Players:GetPlayers() do
		Player.Character.HumanoidRootPart.CFrame = workspace.Spawns:GetChildren()[i].CFrame * CFrame.new(0, 10, 0)
	end

end

return GameMode