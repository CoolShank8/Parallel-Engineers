local BaseSerializer = {}

local function DeepSerialize(Object, IsNotFirstTime)
	local EntityClass =  require(script:FindFirstAncestor("EntityAdmin").Children.BaseEntity)
	local WorldClass = require(script:FindFirstAncestor("EntityAdmin").Children.World)
	local SignalClass =  require(script:FindFirstAncestor("EntityAdmin").Children.InternalClasses.Signal)

	if getmetatable(Object) == SignalClass then
		warn('SIGNAL')
		return nil
	end
	
	if getmetatable(Object) == WorldClass then
		return {
			Type = "World",
			ID = Object.ID
		}
	end
	
	if EntityClass.GetEntityClassModule(Object) and IsNotFirstTime then
		return {
			Type = "Entity",
			Class = EntityClass.GetEntityClassModule(Object),
			WorldID = Object.World.ID,
			ID = Object.ID
		}
	end
	
	if IsNotFirstTime == nil then
		local Format = {}
		Format.Table = {}
		Format.Type = "Entity"
		Format.ID = Object.ID
		Format.Class = EntityClass.GetEntityClassModule(Object)

		for Key, Value in Object do
			Format.Table[Key] = DeepSerialize(Value, true)
		end

		return Format
	end
	
	if type(Object) == 'table' then 
		local Format = {}
		Format.Type = 'Table'
		Format.Table = {}
		Format.IsFrozen = table.isfrozen(Object)
		
		if getmetatable(Object) then
			local Metatable = getmetatable(Object)
			Format.Module = Metatable.__module	
		end	
		
		for Key, Value in Object do
			Format.Table[Key] = DeepSerialize(Value, true)
		end
		
		return Format
	end
	
	return {
		Type = "Value",
		Value = Object
	}
	
	-- value type, number, string, vector, ect
end

local function DeepDeserializeIntoTable(EntityObject, SerialPacket, AllEntityList, NotFirstTime)
	local EntityClass =  require(script:FindFirstAncestor("EntityAdmin").Children.BaseEntity)
	local WorldClass = require(script:FindFirstAncestor("EntityAdmin").Children.World)
	
	if NotFirstTime == nil then
		for Index, Value in SerialPacket.Table do
			EntityObject[Index] = DeepDeserializeIntoTable(EntityObject, Value, AllEntityList, true)
		end
		
		return
	end
	
	if SerialPacket.Type == 'Value' then -- If a table had a field value this would still work
		return SerialPacket.Value
	end
	
	if SerialPacket.Type == "World" then
		return WorldClass.AllWorlds[SerialPacket.ID]
	end
	
	if SerialPacket.Type == "Entity" then
		local World = WorldClass.AllWorlds[SerialPacket.WorldID]
		local Entity = World.AllEntities[SerialPacket.ID]
		
		if Entity == nil then
			warn("BROKEN")
		end
		
		return Entity
	end
	
	if SerialPacket.Type == 'Table' then
		local NewValue = {}

		for Index, Value in SerialPacket.Table do
			NewValue[Index] = DeepDeserializeIntoTable(EntityObject, Value, AllEntityList, true)
		end
		
		if SerialPacket.Module then
			setmetatable(NewValue, require(SerialPacket.Module))
		end
		
		if SerialPacket.IsFrozen then
			table.freeze(NewValue)
		end
		
		return NewValue 
	end
end

BaseSerializer.SerializePacket = DeepSerialize
BaseSerializer.DeserializePacket = DeepDeserializeIntoTable

function BaseSerializer.SerializeWorld(World)
	local EntityClass =  require(script:FindFirstAncestor("EntityAdmin").Children.BaseEntity)
	
	--local SerialWorld = DeepClone(World)
	--SerialWorld.PredictedCommandQue = nil
	
	local WorldSerial = {}
	WorldSerial.PredictedCommandQue = {}
	WorldSerial.ComponentDatabase = {}
	WorldSerial.AllEntities = {}
	WorldSerial.EventDatabase = {}
	WorldSerial.AllSystems = {}
	World.ObjectChangeBitmask = {}
	
	
	for EntityID, EntityObject in World.AllEntities do
		local SerialFormat = DeepSerialize(EntityObject)
		WorldSerial.AllEntities[EntityID] = SerialFormat
	end
	
	for ComponentName, ComponentArray in World.ComponentDatabase do
		WorldSerial.ComponentDatabase[ComponentName] = table.clone(ComponentArray)
	end
	
	return WorldSerial
end

function BaseSerializer.SerializeEntity(Entity)
	local SerialFormat = {
		Object = DeepSerialize(Entity),
		AllComponents = {}
	}
	
	SerialFormat.Object.ID = nil
	
	for ComponentName, ComponentArray in Entity.World.ComponentDatabase do
		if ComponentArray[Entity.ID] then
			SerialFormat.AllComponents[ComponentName] = DeepSerialize(ComponentArray[Entity.ID])
		end
	end
	
	
	return SerialFormat
end

function BaseSerializer.LoadEntity(SerialEntity, WorldID, EntityID)
	local EntityClassModuleScript = script:FindFirstAncestor("EntityAdmin").Children.BaseEntity
	local EntityClass = require(EntityClassModuleScript)
	local WorldClass = require(script:FindFirstAncestor("EntityAdmin").Children.World)
	
	local World = WorldClass.AllWorlds[WorldID]
	
	World.AllEntities[EntityID] = World.AllEntities[EntityID] or {}
	local Entity = World.AllEntities[EntityID]
	
	for ComponentName, Component in SerialEntity.AllComponents do
		World.ComponentDatabase[ComponentName] = World.ComponentDatabase[ComponentName] or {}
		World.ComponentDatabase[ComponentName][EntityID] = {}
		
		DeepDeserializeIntoTable(World.ComponentDatabase[ComponentName][EntityID], Component, World.AllEntities)
	end
	
	
	DeepDeserializeIntoTable(Entity, SerialEntity.Object, World.AllEntities)
	Entity.World = World
	
	if SerialEntity.Object.Class == nil then -- SERVER CLASS, SO DO NOT DO ANY INITILIZATION
		SerialEntity.Object.Class = EntityClassModuleScript
	end
	
	local ClassTable = require(SerialEntity.Object.Class)

	if SerialEntity.Object.Class == EntityClassModuleScript then
		setmetatable(Entity, ClassTable.EntityMethods)
	else
		local Context = {}
		
		local BaseEntityClass = require(EntityClassModuleScript)
		BaseEntityClass.__build(Entity)
		
		function Context:IsAuthority()
			return false
		end
		
		setmetatable(Entity, ClassTable)
		ClassTable.OnInit(Entity, Context)
	end
	
	
	return Entity
end

function BaseSerializer.LoadWorld(SerialWorld, WorldID)
	warn("SERIALWORLD: ", SerialWorld)
	
	local EntityClassModuleScript = script:FindFirstAncestor("EntityAdmin").Children.BaseEntity
	
	local EntityClass = require(EntityClassModuleScript)
	local WorldClass = require(script.Parent.World)
	
	
	WorldClass.AllWorlds[WorldID] = WorldClass.AllWorlds[WorldID] or {}
	local World = WorldClass.AllWorlds[WorldID]
	
	
	WorldClass._buildEmpty(World)
	
	
	for EntityID, SerialFormat in SerialWorld.AllEntities do -- load all entiites first so when we deserializing we wont have an entity ID to a null object
		World.AllEntities[EntityID] = World.AllEntities[EntityID] or {}
	end
	
	for ComponentName,v in SerialWorld.ComponentDatabase do
		World.ComponentDatabase[ComponentName] = SerialWorld.ComponentDatabase[ComponentName]
	end
	
	for EntityID, SerialFormat in SerialWorld.AllEntities do
		local Entity = World.AllEntities[EntityID]
		
		DeepDeserializeIntoTable(Entity, SerialFormat, World.AllEntities)
		Entity.World = World
		
		local ClassTable = require(SerialFormat.Class)
		
		if SerialFormat.Class == EntityClassModuleScript then
			setmetatable(Entity, ClassTable.EntityMethods)
		else
			setmetatable(Entity, ClassTable)
		end
	end
	
	for EntityID, SerialFormat in SerialWorld.AllEntities do
		local Entity = World.AllEntities[EntityID]
		local Metatable = getmetatable(Entity)
		
		if Metatable == EntityClass.EntityMethods then
			
		else
			local BaseEntityClass = require(EntityClassModuleScript)
			BaseEntityClass.__build(Entity)
			
			local Context = {}

			function Context:IsAuthority()
				return false
			end
			
			
			Metatable.OnInit(Entity, Context)
		end
	end
	
	setmetatable(World, WorldClass)
	
	warn(World)
	
	return World
end

return BaseSerializer