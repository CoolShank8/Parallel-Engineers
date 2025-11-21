local PlotBuild = workspace.PlotBuild
local PlotSystem = {}

function PlotSystem.Assign(Player, Plot)
	Plot.Sign:Destroy()
end

for i,v in PlotBuild.Expansions:GetChildren() do
	local SignPart = v.Sign.Sign
	
	local ProximityPrompt = Instance.new('ProximityPrompt')
	ProximityPrompt.Enabled = true
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.HoldDuration = .2
	ProximityPrompt.Parent = SignPart
	
	ProximityPrompt.Triggered:Connect(function(Player)
		print("Player wants to buy the plot") 
		PlotSystem.Assign(Player, v)
	end)
end

print('Wow')

return PlotSystem