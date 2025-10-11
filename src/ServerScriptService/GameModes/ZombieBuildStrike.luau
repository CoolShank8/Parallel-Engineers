local GameMode = {}

function GameMode:Start()
	for i ,Player in game.Players:GetPlayers() do
		Player.Character.HumanoidRootPart.CFrame = workspace.Plots:GetChildren()[i].CFrame * CFrame.new(0, 5, 0)
	end
end

return GameMode