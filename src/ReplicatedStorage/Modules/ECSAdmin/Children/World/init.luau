local WorldClass = {}
WorldClass.AllWorlds = {}
WorldClass.__index = WorldClass

local EntityAdmin = require(script.Parent) 
local RelationTupleEntity = require(script.RelationTupleEntity)
local Signal = require(game.ReplicatedStorage.Utility.Signal)

local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')

local AllWorlds = WorldClass.AllWorlds

local WorldManagerRemote: RemoteEvent = script:FindFirstChild("WorldManagerRemote")
local SystemClass = require(script.Parent.BaseSystem)

if RunService:IsServer() then
	WorldManagerRemote = Instance.new('RemoteEvent')
	WorldManagerRemote.Name = "WorldManagerRemote"
	WorldManagerRemote.Parent = script
	
	game.Players.PlayerAdded:Connect(function(Player)
		for ID, World in AllWorlds do
			--WorldManagerRemote:FireClient(Player, ID,  EntityAdmin.Serializer.SerializeWorld(World))
			
			local SerialWorld = {}
			SerialWorld.ID = ID
			SerialWorld.ComponentDatabase = {}
			SerialWorld.EventDatabase = {}
			SerialWorld.AllEntities = {}
			SerialWorld.PredictedCommandQue = {}
			SerialWorld.AllSystems = {}
			
			for _ ,System in World.AllSystems do
				if System.RunMode == "Shared" then
					SerialWorld.AllSystems[System.ID] = {
						SystemClassModule = SystemClass.AllSystemClasses[getmetatable(System)]
					}
				end
			end
			
			WorldManagerRemote:FireClient(Player, SerialWorld)
		end
	end)
else
	WorldManagerRemote.OnClientEvent:Connect(function(SerialWorld)
		local World = SerialWorld
		local CloneSystemInfo = table.clone(World.AllSystems)
		
		WorldClass._buildEmpty(World)
		
		World.AllSystems = {}
		World.SingletonComponents = {}
		
		World.EntityRemoved = Signal.new()
		World.EntityAdded = Signal.new()
		
		for ID ,SystemInfo in CloneSystemInfo do
			local System = EntityAdmin.BaseSystem.createSystem(World, require(SystemInfo.SystemClassModule), ID)
			table.insert(World.AllSystems, System)	
		end
		
		World.InternalSystems = {
			RenderSystem = EntityAdmin.BaseSystem.createSystem(World, require(game.ReplicatedStorage.EntityAdmin3.InternalSystems.RenderSystem), HttpService:GenerateGUID(false)),
			NetworkSystem = EntityAdmin.BaseSystem.createSystem(World, require(game.ReplicatedStorage.EntityAdmin3.InternalSystems.NetworkSystem), World.ID .. "/Networking"),
			UIRenderSystem = EntityAdmin.BaseSystem.createSystem(World, require(game.ReplicatedStorage.EntityAdmin3.InternalSystems.UIRenderSystem), HttpService:GenerateGUID(false))
		}
		
		setmetatable(World, WorldClass)
		AllWorlds[World.ID] = World
	end)
end

game:GetService('RunService').Heartbeat:Connect(function()
	
	for _ ,World in AllWorlds do
		for _, Command in World.PredictedCommandQue do
			Command:Execute()
		end
	end
	
	for ID, World in AllWorlds do
		World:Step(1/30)
	end
end)


function WorldClass._buildEmpty(World)
	World.ComponentDatabase = {}
	World.ComponentDatabaseChangeBitmasks = {}
	World.EventDatabase = {}
	World.ObjectChangeBitmask = {}
	World.EntityComponentChangedQue = {}
	World.ComponentBitmaskChangedQue = {}
	World.ParentChangedEntitiesQue = {}

	World.AllEntities = {}
	World.SingletonComponents = {}

	World.CurrentFrame = 0
	World.PredictedCommandQue = {}
	World.CreateEntityTuple = function(Entity1, Entity2) -- returns a relation type
		return RelationTupleEntity.new(World, Entity1, Entity2)
	end
	return World
end

function WorldClass:GetAllEvents(EventName)
	return self.EventDatabase[EventName] or {}
end

function WorldClass:PushEvent(EventName, Record: {})
	self.EventDatabase[EventName] = self.EventDatabase[EventName] or {}
	table.insert(self.EventDatabase[EventName], Record)
end

function WorldClass.new(ID)
	local World = WorldClass._buildEmpty({})
	
	World.ID = ID
	World.AllSystems = {}
	World.EntityAdded = Signal.new()
	World.EntityRemoved = Signal.new()
	
	if game:GetService('RunService'):IsServer() then
		WorldManagerRemote:FireAllClients(World.ID, World.CurrentFrame, EntityAdmin.Serializer.SerializeWorld(World))
	end
	
	World.InternalSystems = {
		RenderSystem = EntityAdmin.BaseSystem.createSystem(World, require(game.ReplicatedStorage.EntityAdmin3.InternalSystems.RenderSystem), HttpService:GenerateGUID(false)),
	}
	
	if RunService:IsServer() then
		World.InternalSystems.NetworkSystem = EntityAdmin.BaseSystem.createSystem(World, require(game.ReplicatedStorage.EntityAdmin3.InternalSystems.NetworkSystem), ID.. "/Networking")
	end
	
	if RunService:IsClient() then
		World.InternalSystems.UIRenderSystem = EntityAdmin.BaseSystem.createSystem(World, require(game.ReplicatedStorage.EntityAdmin3.InternalSystems.UIRenderSystem), HttpService:GenerateGUID(false))
	end
	
	AllWorlds[World.ID] = World
	
	setmetatable(World, WorldClass)	
	return World
end

function WorldClass:AddSingletonComponent(ComponentName, Component)
	self.SingletonComponents[ComponentName] = Component
end

function WorldClass:GetSingletonComponent(ComponentName, Component)
	return self.SingletonComponents[ComponentName]
end

function WorldClass:AddSystem(SystemType)
	local ID = HttpService:GenerateGUID(false)-- Made up of 32 bits for ID, 16 bits for world ID, 16 bits for version
	local System = EntityAdmin.BaseSystem.createSystem(self, SystemType, ID)
		
	table.insert(self.AllSystems, System)	
end

local function UPDATE_SYSTEM(System, ChangedEntities, World, DT)
	for EntityID, Entity in System.AllMatched do
		if World.AllEntities[EntityID] == nil then
			System.AllMatched[EntityID] = nil
			System.RemovingMatched[EntityID] = Entity
		end
	end

	for EntityID, Entity in ChangedEntities do
		local SystemReadQuery = System.ReadQuery
		local EntityMatched = if System.WriteComponentMask  ~= 0 then bit32.band(Entity.ComponentMask, System.WriteComponentMask) == System.WriteComponentMask else false
		local EntityMatched = false
		if EntityMatched == false then
			for _ , Bitmask in SystemReadQuery.ComponentBitmasks do
				EntityMatched = bit32.band(Entity.ComponentMask, Bitmask) == Bitmask
				if EntityMatched == true then break end
			end
		end


		local IsInSystem = System.AllMatched[EntityID]

		if EntityMatched then
			System.AllMatched[EntityID] = Entity

			if IsInSystem == nil then
				System.NewlyMatched[EntityID] = Entity
			end
		elseif IsInSystem then

			System.AllMatched[EntityID] = nil
			System.RemovingMatched[EntityID] = Entity
		end
	end


	System:Update(1/30)
	System.NewlyMatched ={}
	System.RemovingMatched = {}
end

local function EmptyQueInto(Que, NewTable)
	local EntitiesSystemModified = Que
	for i,v in EntitiesSystemModified do
		NewTable[i] = v
	end

	table.clear(Que)
end

function WorldClass:Step(DT)
	for EntityID, Entity in self.AllEntities do
		if Entity.PreUpdate then
			Entity:PreUpdate(DT)
		end
	end
	
	local ChangedEntities = table.clone(self.ComponentBitmaskChangedQue)
	table.clear(self.ComponentBitmaskChangedQue)
	
	for Entity in RelationTupleEntity.AllRelations do
		ChangedEntities[Entity] = Entity
	end
	
	for _ , System in self.AllSystems do
		UPDATE_SYSTEM(System, ChangedEntities, self, DT)
		
		EmptyQueInto(self.ComponentBitmaskChangedQue, ChangedEntities)
	end
	
	
	for EntityID, Entity in self.AllEntities do -- TODO, if components are modified in post update, notify downstream systems
		if Entity.PostUpdate then
			Entity:PostUpdate(DT)
		end
	end
	
	EmptyQueInto(self.ComponentBitmaskChangedQue, ChangedEntities)
	
	for SystemName, System in self.InternalSystems do
		UPDATE_SYSTEM(System, ChangedEntities, self, DT) -- these systems should not be adding/removing components, hence no need for cleanup of self.ComponentBitmaskChangedQue
	end
	
	if RunService:IsServer() then
		for i,v in self.AllEntities do
			if v:GetComponent("Clock") then
				if v:GetComponent("Clock").LifeTime == 0 then
					v:Destroy()
					continue
				end
				
				v:GetComponent("Clock").LifeTime -= 1
			end
		end
	end
	
	for ComponentName, ComponentArray in self.ComponentDatabaseChangeBitmasks do
		table.clear(ComponentArray)
	end
	
	table.clear(self.ParentChangedEntitiesQue)
	table.clear(self.ObjectChangeBitmask)
	table.clear(self.EntityComponentChangedQue)
	table.clear(self.EventDatabase)
end

function WorldClass:CreateEntity(ClassType, ...)
	local Entity;
	local ID = HttpService:GenerateGUID(false)-- Made up of 32 bits for ID, 16 bits for world ID, 16 bits for version
	
	if ClassType then
		Entity = EntityAdmin.BaseEntity.createEntityOfClass(self, ID, ClassType, ...)
	else
		Entity = EntityAdmin.BaseEntity.createEntity(self, ID)
	end
	
	self.EntityAdded:Fire(Entity)
	return Entity
end

function WorldClass:CreateEntityOfClass(ClassType, ...)
	local Entity;
	local ID = HttpService:GenerateGUID(false)-- Made up of 32 bits for ID, 16 bits for world ID, 16 bits for version

	if ClassType then
		Entity = EntityAdmin.BaseEntity.createEntityOfClass(self, ID, ClassType, ...)
	else
		Entity = EntityAdmin.BaseEntity.createEntity(self, ID)
	end

	self.EntityAdded:Fire(Entity)
	return Entity
end

function WorldClass:CreateEntityOfClassWithID(ClassType, ID, ...)
	local Entity;
	if ClassType then
		Entity = EntityAdmin.BaseEntity.createEntityOfClass(self, ID, ClassType, ...)
	else
		Entity = EntityAdmin.BaseEntity.createEntity(self, ID)
	end

	--	self.EntityAdded:Fire(Entity)
	return Entity
end

function WorldClass:CreateEntityWithID(ID, ClassType, ...)
	local Entity;
	if ClassType then
		Entity = EntityAdmin.BaseEntity.createEntityOfClass(self, ID, ClassType, ...)
	else
		Entity = EntityAdmin.BaseEntity.createEntity(self, ID)
	end

--	self.EntityAdded:Fire(Entity)
	return Entity
end

function WorldClass:GetEntity(ID)
	return self.AllEntities[ID]
end

function WorldClass:DestroyEntity(ID)
	self.EntityRemoved:Fire(self.AllEntities[ID])
	self.AllEntities[ID] = nil
	
	for ComponentName, ComponentArray in self.ComponentDatabase do
		if ComponentName == "UIDesign" then
			ComponentArray[ID].Design:Destroy()
		end
		
		if ComponentName == "Renderable"  then
			ComponentArray[ID].Asset:Destroy()
		end
		
		ComponentArray[ID] = nil
	end
	
	warn('Destroyed entity ' .. ID)
	
end

return WorldClass