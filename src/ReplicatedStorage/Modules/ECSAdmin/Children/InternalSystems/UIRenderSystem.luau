local EntityAdmin = require(script:FindFirstAncestor("EntityAdmin"))
local UIRenderSystem = EntityAdmin.BaseSystem:extend(script)

local GUIContainer = Instance.new('ScreenGui', game.Players.LocalPlayer.PlayerGui)
GUIContainer.Enabled = true
GUIContainer.Name = "GuiContainer"

function UIRenderSystem.Init(self)
	self.ReadQuery = EntityAdmin.Query.OfComponentArray({"UIDesign"})
	self.WriteComponentMask = 0
	self.RunMode = "Client"
end

function UIRenderSystem:Update(DT)
	for EntityID, Entity in self:GetMatched() do
		
		
		local GUIDesign = Entity:GetComponent("UIDesign")
		local Design = GUIDesign.Design
		
		if Entity.Parent then
			local ParentDesignComponent = Entity.Parent:GetComponent("UIDesign")
			
			if ParentDesignComponent then
				if ParentDesignComponent.ParentInstancePortal then
					Design.Parent = ParentDesignComponent.ParentInstancePortal
				else
					Design.Parent = ParentDesignComponent.Design
				end
			end
		else
			if Design:IsA("ScreenGui")  then
				Design.Parent = game.Players.LocalPlayer.PlayerGui
			end

			if Design:IsA("GuiObject") then
				Design.Visible = GUIDesign.Visible or false
			end			
		end
		
		if Design:IsA("ScreenGui")  then
			Design.Enabled = GUIDesign.Visible or false 
		end

		if Design:IsA("GuiObject") then
			Design.Visible = GUIDesign.Visible or false
		end	
		
		if Design:IsA("ScreenGui") then continue end
		
		Design.Rotation = GUIDesign.Rotation or 0
	end

end
return UIRenderSystem