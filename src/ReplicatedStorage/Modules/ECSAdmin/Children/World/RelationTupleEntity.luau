local RelationTupleEntity = {}
RelationTupleEntity.EntityToRelation = {}
RelationTupleEntity.AllRelations = {}

RelationTupleEntity.__index = RelationTupleEntity

function RelationTupleEntity.new(World, Entity1, Entity2)
	assert(Entity1, "Must supply entity1 when defining a tuple entity")
	
	if Entity2 == nil then
		return Entity1
	end
	
	local self = {}
	self.World = World
	self.Entity1 = Entity1 
	self.Entity2 = Entity2	
	self.ComponentMask = 0
	
	RelationTupleEntity.EntityToRelation[Entity1] = RelationTupleEntity.EntityToRelation[Entity1] or {}
	RelationTupleEntity.EntityToRelation[Entity1][Entity2] = self
	RelationTupleEntity.AllRelations[self] = self
	
	setmetatable(self, RelationTupleEntity)
	return self
end

function RelationTupleEntity:SetComponent(ComponentName, Component)
	self.World.ComponentDatabase[ComponentName] = self.World.ComponentDatabase[ComponentName] or {}
	self.World.ComponentDatabase[ComponentName][self] = Component
	
	local EntityAdmin = require(game.ReplicatedStorage.EntityAdmin3)
	self.ComponentMask = bit32.bor(self.ComponentMask, EntityAdmin.GetComponentMask(ComponentName))
end

function RelationTupleEntity:GetComponent(ComponentName)
	if self.World.ComponentDatabase[ComponentName] == nil then return end
	return self.World.ComponentDatabase[ComponentName][self]
end

function RelationTupleEntity:Destroy()
	if RelationTupleEntity[self.Entity1] == nil or RelationTupleEntity[self.Entity2] == nil then return end
	
	self.Entity1:Destroy()
	self.Entity2:Destroy()
	
	RelationTupleEntity[self.Entity1][self.Entity2] = nil
	RelationTupleEntity.AllRelations[self] = nil
	
	if next(RelationTupleEntity[self.Entity1]) == nil then
		RelationTupleEntity[self.Entity1] = nil
	end
end

return RelationTupleEntity