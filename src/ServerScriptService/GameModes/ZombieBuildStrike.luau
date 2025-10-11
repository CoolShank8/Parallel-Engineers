local GameMode = {}

function GameMode:Start()
	for i ,Player in game.Players:GetPlayers() do
		Player.Character.HumanoidRootPart.CFrame = workspace.Plots:GetChildren()[i]
	end
end

return GameMode