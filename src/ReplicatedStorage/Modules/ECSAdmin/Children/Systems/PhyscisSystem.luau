local EntityAdmin =  require(script:FindFirstAncestor("EntityAdmin"))
local PhysicsSystem = EntityAdmin.BaseSystem:extend(script)

function PhysicsSystem.Init(self)
	self.ReadQuery = EntityAdmin.Query.OfComponentArray({"Transform", "Renderable"})
	self.WriteComponentMask = EntityAdmin.GetComponentMask("Transform")
end

function PhysicsSystem:Update(DT)


	for EntityID, Entity in self:GetMatched() do
		local Transform = Entity:GetComponent("Transform")
		local Renderable = Entity:GetComponent("Renderable")
		
		Transform.CFrame = Renderable.Asset:GetPivot()
	end

end
return PhysicsSystem