local Tool = script:FindFirstAncestorWhichIsA('Tool')
local GridTexture = Tool:WaitForChild('GridTexture')
GridTexture.Parent = nil

local function VisualizePlot()
	GridTexture.Parent = workspace.Map.Plot1
end

local function CleanupVisualization()
	GridTexture.Parent = nil
end

Tool.Equipped:Connect(VisualizePlot)
Tool.Unequipped:Connect(CleanupVisualization)