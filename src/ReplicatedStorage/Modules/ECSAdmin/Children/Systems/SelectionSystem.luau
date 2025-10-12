--!strict
local EntityAdmin =  require(script:FindFirstAncestor("EntityAdmin"))
local SelectionSystem = EntityAdmin.BaseSystem:extend(script)

-- Each INPUT, is a component that says "Am I consumed", "Did FINISH" ect
local UserInputService = game:GetService('UserInputService')



function SelectionSystem.Init(self)
	self.ReadQuery = EntityAdmin.Query.OfComponentArray({"Selector"})
	self.WriteComponentMask = EntityAdmin.GetComponentMask("Selector")
	
	
	
	self.StartMouseButtonPressed = nil
	
	UserInputService.InputBegan:Connect(function(InputObject, GameProcessed)
		if GameProcessed then return end
		if InputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		
		self.StartMouseButtonPressed = true
	end)
	
	UserInputService.InputEnded:Connect(function(InputObject, GameProcessed)
		if GameProcessed then return end
		if InputObject.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		self.StartMouseButtonPressed = nil
	end)
	
	self.LastSelectedBlock = nil
	
	return self
end

local RenderSystem = require(game.ReplicatedStorage.EntityAdmin3.InternalSystems.RenderSystem)

function SelectionSystem:Update(DT)			
	local RawMouse = game.Players.LocalPlayer:GetMouse()
	
	for _, Entity in self:GetMatched() do
		local Selector = Entity:GetComponent("Selector")
		local SelectorPositionAttachment = Entity:GetComponent("Renderable").Asset.Handle
		
	--	local Network = Entity:GetComponent("Network")
	--	if Network.Owner ~= game.Players.LocalPlayer then continue end
		
		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}
		Params.FilterType = Enum.RaycastFilterType.Exclude
		
		local Result = workspace:Raycast(RawMouse.UnitRay.Origin, RawMouse.UnitRay.Direction * 500, Params)
		
		local ViewingEntity = if Result then RenderSystem.GetEntityFromPart(self.World, Result.Instance) else nil
		Selector.Viewing = ViewingEntity
		
		if self.StartMouseButtonPressed == nil and self.LastSelectedBlock and ViewingEntity ~= self.LastSelectedBlock then
			self.World:PushEvent("Deselected", {
				Selector = Entity,
				DeselectedEntity = self.LastSelectedBlock
			})
			
			Selector.SelectedEntities[1] = nil
			self.LastSelectedBlock = nil
		end
		
		if self.StartMouseButtonPressed == nil then return end
		if Selector.SelectedEntities[1] then return end -- do not change if we have a currently selected block
		if (Result.Instance.Position - SelectorPositionAttachment.Position).Magnitude > Selector.MaxSelectionDistance then return end
		
		if ViewingEntity ~= Selector.LastSelectedBlock then
			if Selector.LastSelectedBlock then
				self.World:PushEvent("Deselected", {
					Selector = Entity,
					DeselectedEntity = self.LastSelectedBlock
				})
			end

			Selector.SelectedEntities[1] = ViewingEntity
			self.LastSelectedBlock = ViewingEntity

			self.World:PushEvent("Selected", {
				Selector = Entity,
				SelectedEntity = self.LastSelectedBlock
			})
		end
	
			
	end
end

return SelectionSystem

-- if player stops viewing the block we also clear the selection