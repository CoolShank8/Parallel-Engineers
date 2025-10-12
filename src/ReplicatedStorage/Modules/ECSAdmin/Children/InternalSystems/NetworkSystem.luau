local EntityAdmin = require(script:FindFirstAncestor("EntityAdmin"))

local InternalNetworkingSystem = EntityAdmin.BaseSystem:extend(script, {
	ReadRequires = {"Network"}
})


function InternalNetworkingSystem.Init(self)
	
	
	self.ReadQuery = EntityAdmin.Query.OfComponentArray({"Network"})
	self.WriteComponentMask = EntityAdmin.GetComponentMask("Network")
	self.RunMode = "Shared"
	
	local World = self.World
	
	self.WorldAddRemote = self:GetNetworkChannel("WorldAddRemote")
	self.WorldRemoveRemote = self:GetNetworkChannel("WorldRemoveRemote")
	self.EntityAddRemote = self:GetNetworkChannel("EntityAddRemote")
	self.EntityParentChanged = self:GetNetworkChannel("EntityParentChanged")
	self.ComponentsChanged = self:GetNetworkChannel("ComponentsChanged")
	self.EntityObjectChanged = self:GetNetworkChannel("EntityObjectChanged")
	
	self.EntityInsertionQue = {}
	
	if game:GetService('RunService'):IsServer() then
		warn('server')
		
		for _, Player in game.Players:GetPlayers() do
			self.WorldAddRemote:FireClient(Player, World.ID, EntityAdmin.Serializer.SerializeWorld(World))
		end
		
		game.Players.PlayerAdded:Connect(function(Player)
			self.WorldAddRemote:FireClient(Player, World.ID,  EntityAdmin.Serializer.SerializeWorld(World))
		end)
		
		World.EntityAdded:Connect(function(Entity)
			table.insert(self.EntityInsertionQue, Entity)
		end)
	else
		self.WorldAddRemote.OnClientEvent:Connect(function(WorldID, WorldSerial)
			EntityAdmin.Serializer.LoadWorld(WorldSerial, WorldID)
		end)
		
		self.EntityAddRemote.OnClientEvent:Connect(function(WorldID, SerialEntityTable)
			
			for EntityID, SerialEntity in SerialEntityTable do -- allows us to have circular referneces between entities by preloading entities
				self.World.AllEntities[EntityID] = self.World.AllEntities[EntityID] or {}
			end
			
			for EntityID, SerialEntity in SerialEntityTable do 
				EntityAdmin.Serializer.LoadEntity(SerialEntity, WorldID, EntityID)
			end
		end)
		
		self.EntityParentChanged.OnClientEvent:Connect(function(WorldID, NewParentTable)
			for EntityID, ParentID in NewParentTable do
				warn('New parent changed')
				self.World.AllEntities[EntityID].Parent = self.World.AllEntities[ParentID]
			end
		end)
		
		self.ComponentsChanged.OnClientEvent:Connect(function(WorldID, ComponentChangeTable)
			for EntityID, ComponentMap in ComponentChangeTable do
				for ComponentName, ComponentSerial in ComponentMap do
					local Component = {}
					World.ComponentDatabase[ComponentName] = World.ComponentDatabase[ComponentName] or {}
					World.ComponentDatabase[ComponentName][EntityID] = Component
					
					EntityAdmin.Serializer.DeserializePacket(Component, ComponentSerial, self.World.AllEntities)
					

--					warn(`For Entity: {EntityID} component {ComponentName} was added or changed!`)
				end
			end
		end)
		
		self.EntityObjectChanged.OnClientEvent:Connect(function(WorldID, EntityToObjectChangeBitmask)
			for EntityID, NewPathInfo in EntityToObjectChangeBitmask do
				local Entity = self.World.AllEntities[EntityID]
				
				if Entity == nil then
					print('Entity is null', "  ", EntityID, World)
				end
				
				local IterTable = NewPathInfo
				local TargetTable = Entity
				
				for i,v in IterTable do
					TargetTable[i] = {}
					EntityAdmin.Serializer.DeserializePacket(TargetTable[i], v, self.World.AllEntities)
					TargetTable[i] = TargetTable[i].ActualValue
				end
			end
			
			
		--	warn(EntityToObjectChangeBitmask)
		end)
	end
	
	
	
end



function InternalNetworkingSystem:Update(DT)
	if game:GetService('RunService'):IsServer() == false then return end 
	
	local SerialEntityTable = {}
	local EntityToNewParent = {}
	local EntityComponentChangedPacket = {}
	local EntityToObjectChangedPacket = {}
	
	for _ ,Entity in self.EntityInsertionQue do
		local SerialEntity = EntityAdmin.Serializer.SerializeEntity(Entity)
		SerialEntityTable[Entity.ID] = SerialEntity
	end
	
	for ComponentName, ComponentArray in self.World.ComponentDatabaseChangeBitmasks do
		for EntityID, ComponentChangeBitmask in ComponentArray do
			if SerialEntityTable[EntityID] then continue end -- No need to duplicate creation of components
			local Component = self.World.ComponentDatabase[ComponentName][EntityID]

			EntityComponentChangedPacket[EntityID] = EntityComponentChangedPacket[EntityID] or {}
			EntityComponentChangedPacket[EntityID][ComponentName] = EntityAdmin.Serializer.SerializePacket(Component)
		end
	end
	
	for EntityID, _ in self.World.ParentChangedEntitiesQue  do
		EntityToNewParent[EntityID] = self.World.AllEntities[EntityID].Parent.ID
	end
	
	for EntityID, ChangeInfo in self.World.ObjectChangeBitmask do
		EntityToObjectChangedPacket[EntityID] = EntityToObjectChangedPacket[EntityID] or {}
		
		for _, OperationInfo in ChangeInfo.OperationChangeMasks do
			local Entity = self.World.AllEntities[EntityID]
			if Entity == nil then continue end -- entity got destroyed during iteration
			
			local ActualValue = Entity
			local PacketChange = EntityToObjectChangedPacket[EntityID]
			
			for PathIndex, PathName in OperationInfo.Path  do
				ActualValue = ActualValue[PathName]
				
				if PathIndex == #OperationInfo.Path then
					continue
				end
				
				PacketChange[PathName] = PacketChange[PathName] or {}
			end 
			
			PacketChange[OperationInfo.Path[#OperationInfo.Path]] = EntityAdmin.Serializer.SerializePacket({ActualValue = ActualValue})
		
		end
	end
	
	
	self.EntityAddRemote:FireAllClients(self.World.ID, SerialEntityTable)
	self.EntityParentChanged:FireAllClients(self.World.ID, EntityToNewParent)
	self.ComponentsChanged:FireAllClients(self.World.ID, EntityComponentChangedPacket)
	self.EntityObjectChanged:FireAllClients(self.World.ID, EntityToObjectChangedPacket)
	
	table.clear(self.EntityInsertionQue)
end

function InternalNetworkingSystem:ClientUpdate(DT)
	local LoadEntityQue = self.ClientRecievedMessageQue:filter({Message = "LoadEntity"})
	
	for _, Args in LoadEntityQue:PullOutAll() do
		local EntityID, EntitySerialized = unpack(Args)
	
		local Entity = EntityAdmin.Serializer.LoadEntity(EntitySerialized, self.World)
	end
end

function InternalNetworkingSystem:ServerUpdate(DT)
	
	-- NetworkAddedQue only contains those Currently with networcomponent and recently added (so it auto filters those removed before we could process)
	-- If NetworkComponenAddedQue to an entity then Just go through its streaming players and update clients, ignore other ques
	
	
	-- If NetworkStreamToPlayersChanged and not in NetworkComponentAddedQue then 
	-- remember that que is the end result of removal, additions of players 
	-- so safe to assume to take that action
	
	-- if something newly added CreatedCount > RemovedCount
	-- if something removed (And not just removed because we did create, remove, create, remove in 1 frame)
	
	-- Let socre be AddedCount - RemovedCount
	-- If Score > 0, then added, score < 0 then removed
	-- if score == 0, then no change
	
	-- ASSUMES ADD, REMOVE only trigger when an component is actually added and removed 
	
	local NetworkComponentCreatedList, NetworkComponentRemovedList = ArrayUtil.DiffList(
		self.NetworkComponentCreatedQue:PopAll(),
		self.NetworkComponentRemovedQue:PopAll()
	)
	
	local StreamingPlayerAddedList, StreamingPlayerRemovedList = ArrayUtil.DiffList(
		self.NetworkStreamingPlayerAddedQue:PopAll(),
		self.NetworkStreamingPlayerRemovedQue:PopAll()
	)
	
	StreamingPlayerAddedList:RemoveMatches(NetworkComponentCreatedList, "EntityID")
	
	for QuePacket in NetworkComponentCreatedList do
		local Entity = QuePacket.Entity
		local Network = Entity.Network
		
		for i,v in Network.StreamTo do
			self:SendClientMessage(v, "LoadEntity", Entity.ID, EntityAdmin.Serializer.SerializeEntity(QuePacket.Entity))
		end
	end
	
	for QuePacket in StreamingPlayerAddedList do		
		self:SendClientMessage(QuePacket.AddedElement, "LoadEntity", QuePacket.EntityID, EntityAdmin.Serializer.SerializeEntity(QuePacket.Entity))
	end
	
	for QuePacket in StreamingPlayerRemovedList do
		self:SendClientMessage(QuePacket.RemovedElement, "UnloadEntity", QuePacket.EntityID)
	end
	
	for NetworkEntity in self:GetEntities() do
		if NetworkComponentRemovedList:Find(NetworkEntity) then continue end
		local Network = NetworkEntity:GetComponentRef("Network") 
		
		Network.StreamTo = ArrayUtil.filter(Network.StreamTo, function(Player)
			if typeof(Player) == "Player" and Player:IsDescendantOf(game) == false then return true end
		end)
	end
end

return InternalNetworkingSystem