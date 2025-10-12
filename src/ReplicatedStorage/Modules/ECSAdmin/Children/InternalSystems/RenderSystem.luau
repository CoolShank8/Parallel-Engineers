local EntityAdmin = require(script:FindFirstAncestor("EntityAdmin"))
local AnalyticalSpring = require(game.ReplicatedStorage.Utility.AnalyticalSpring)
local RenderSystem = EntityAdmin.BaseSystem:extend(script)

export type Renderable = {
	Asset: Model|BasePart
}

function RenderSystem.GetEntityFromPart(World, Part: BasePart)
	
	local TouchedEntityID = Part:GetAttribute("ID")
	if TouchedEntityID == nil then return end
	local TouchedEntity = World.AllEntities[TouchedEntityID]
	if TouchedEntity == nil then return end
	return TouchedEntity
end

function RenderSystem.Init(self)
	self.ReadQuery = EntityAdmin.Query.OfComponentArray({"Transform", "Renderable"}, {"GoalAnimator"})
	self.WriteComponentMask = 0
end


function RenderSystem:Update(DT)
	
	
	for EntityID, Entity in self:GetMatched() do
		local Transform = Entity:GetComponent("Transform")
		local Renderable = Entity:GetComponent("Renderable")
		local GoalAnimator = Entity:GetComponent("GoalAnimator")
		
		Renderable.Asset:SetAttribute("ID", EntityID)
		
		if GoalAnimator and GoalAnimator.VisualSize and Renderable.Asset:FindFirstChild("ActualCollider") == nil then
			local ActualCollider = Instance.new('Part')
			ActualCollider.Name = "ActualCollider"
			ActualCollider.Anchored = true
			ActualCollider.Size = Transform.Size 
			ActualCollider.CFrame = Renderable.Asset.CFrame
			ActualCollider.Transparency = 1
			ActualCollider.CanCollide = false
			ActualCollider.Parent = Renderable.Asset
			
			ActualCollider:SetAttribute("ID", EntityID)
			
			Renderable.Asset.CanQuery = false
			Renderable.Asset.CanTouch = false
			Renderable.Asset.CanCollide = false
		end
		
		if GoalAnimator == nil and Renderable.Asset:FindFirstChild("ActualCollider") then
			Renderable.Asset:Destroy("ActualCollider")
			Renderable.Asset.CanQuery = true
			Renderable.Asset.CanTouch = true
			Renderable.Asset.CanCollide = true
		end
		
		if Renderable.Asset:IsA("BasePart") then
			if GoalAnimator and GoalAnimator.VisualSize then
				AnalyticalSpring.target(Renderable.Asset, GoalAnimator.VisualSize.GoalReacher.Dampening, GoalAnimator.VisualSize.GoalReacher.Frequency, {
					Size = GoalAnimator.VisualSize.Target * Transform.Size
				})
			else
				Renderable.Asset.Size = Transform.Size
			end
		end
		
		
		
		if not  (Renderable.Asset:IsA("Model") or Renderable.Asset:IsA("BasePart")) then continue end
	
		if Transform.Scale then
			Renderable.Asset:ScaleTo(Transform.Scale)
		end
	end
	
end
return RenderSystem