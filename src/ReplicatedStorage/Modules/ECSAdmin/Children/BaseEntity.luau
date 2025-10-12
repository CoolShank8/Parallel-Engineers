local BaseEntity = {}
local AllEntityClasses = {}

BaseEntity.EntityMethods ={}
local RunService = game:GetService('RunService')

local EntityMethods = BaseEntity.EntityMethods
EntityMethods.__index = EntityMethods

local EntityRequestRemote: RemoteFunction = script:FindFirstChild("EntityRequestRemote")

if RunService:IsServer() then
	EntityRequestRemote = Instance.new('RemoteFunction')
	EntityRequestRemote.Name = 'EntityRequestRemote'
	EntityRequestRemote.Parent = script
	
	EntityRequestRemote.OnServerInvoke = function(Player, WorldID, EntityID, RequestName, ...)
		local EntityAdmin = require(game.ReplicatedStorage.EntityAdmin3) :: any
		local World = EntityAdmin.GetWorld(WorldID)
		local Entity = World.AllEntities[EntityID]
		local EntityClass = getmetatable(Entity)
		
		local Request = EntityClass.ClientRequests[RequestName]
		
		local Env = {}
		function Env:IsClient() return false end
		function Env:IsAuthority() return true end
		
		return Request(Entity, Env, ...)
	end
end

local function makeChain(path)
	local t = path or {}
	return setmetatable(t, {
		__index = function(_, key)
			-- Copy path so we don’t mutate the original
			local newPath = table.clone(t)
			table.insert(newPath, key)
			return makeChain(newPath)
		end
	})
end

local RequestTableMetaTable =  {__index = function(RequestTable, RequestIndexName)
	local Entity = RequestTable.__entity
	local EntityClass = getmetatable(Entity)
	
	warn('RAN')
	
	local NewFunction = function(self, ...)
		
		local Entity = RequestTable.__entity
		
		local Env = {}
		function Env:IsClient() return true end
		function Env:IsAuthority() return false end

		local ClientReturnInfo = EntityClass.ClientRequests[RequestIndexName](Entity, Env, ...)

		if ClientReturnInfo == nil then -- nothing was returned so we should continue
			local ServerReturnInfo = EntityRequestRemote:InvokeServer(Entity.World.ID, Entity.ID, RequestIndexName, ...)
			
			return ServerReturnInfo
		else 
			return ClientReturnInfo -- EARLY EXIT client decided to cancel metohod
		end

	
	end
	
	return NewFunction
end}

local function MakeRequestTable(Entity)
	local RequestTable = {}
	RequestTable.__entity = Entity
	
	setmetatable(RequestTable, RequestTableMetaTable)
	return RequestTable
end

function BaseEntity:extend(Module)

	
	
	local NewEntityClass = {}
	NewEntityClass.__index = NewEntityClass
	NewEntityClass.Commmands = {}
	NewEntityClass.ClientRequests = {}
	
	AllEntityClasses[NewEntityClass] = Module
	
	setmetatable(NewEntityClass, EntityMethods)
	return NewEntityClass
end

function BaseEntity.__build(EntityTable)
	EntityTable.ClientRequests = MakeRequestTable(EntityTable)
	EntityTable.Path = makeChain({})
	
end

function BaseEntity.createEntity(World, ID, Parent)
	local Entity = {}
	Entity.ID = ID
	Entity.World = World
	Entity.ComponentMask = 0
	Entity.Parent = Parent
	Entity.ClientRequests = MakeRequestTable(Entity)
	Entity.Path = makeChain({})
	
	World.AllEntities[ID] = Entity
	setmetatable(Entity, EntityMethods)
	return Entity
end

function BaseEntity.createEntityOfClass(World, ID, ClassType: ModuleScript, ...)
	local EntityClass =  (ClassType)
	
	local Entity = BaseEntity.createEntity(World, ID)
	setmetatable(Entity, EntityClass)
	
	local Context = {}
	
	function Context:IsAuthority()
		return true
	end
	
	World.AllEntities[ID] = Entity
	EntityClass.OnInit(Entity, Context, ...)
	
	return Entity
end

function BaseEntity.GetEntityClassModule(Entity)
	local Metatable = getmetatable(Entity)
	
	if Metatable == EntityMethods then
		return script
	else
		return AllEntityClasses[getmetatable(Entity)]
	end
end

function EntityMethods:SendServerMessage()
	local NetworkComponent = self:GetComponentRef("NetworkComponent")
	if NetworkComponent.Authority == game.Players.LocalPlayer then error("Cannot send server message for local made entity") end
	
	
end

function EntityMethods:TellClientMessage()
	
end

function EntityMethods:SetParent(Parent)
	self.Parent = Parent
	self.World.ParentChangedEntitiesQue[self.ID] = true
end

function EntityMethods:MarkComponentChange(ComponentName, ChangeBitmask)
	self.World.ComponentDatabaseChangeBitmasks[ComponentName] = self.World.ComponentDatabaseChangeBitmasks[ComponentName]  or {}
	self.World.ComponentDatabaseChangeBitmasks[ComponentName][self.ID] = self.World.ComponentDatabaseChangeBitmasks[ComponentName][self.ID] or 0
	self.World.ComponentDatabaseChangeBitmasks[ComponentName][self.ID] = bit32.band(self.World.ComponentDatabaseChangeBitmasks[ComponentName][self.ID], ChangeBitmask.__Mask)
	
	self.World.EntityComponentChangedQue[self.ID] = true
end

function EntityMethods:MarkChange(ChangeBitmask: number|{string}, Operation: "Insertion"|"Deletion")
	self.World.ObjectChangeBitmask[self.ID] = self.World.ObjectChangeBitmask[self.ID] or {Bitmask = 0, OperationChangeMasks = {}}
	
	if type(ChangeBitmask) == 'number' then
		self.World.ObjectChangeBitmask[self.ID].Bitmask = bit32.band(ChangeBitmask, self.World.ObjectChangeBitmask[self.ID].Bitmask)
		
		if Operation then
			table.insert(self.World.ObjectChangeBitmask[self.ID].OperationChangeMasks, {Bitmask = ChangeBitmask, Type = Operation})
		end
	end
	
	if type(ChangeBitmask) == 'table' then
		table.insert(self.World.ObjectChangeBitmask[self.ID].OperationChangeMasks, {Path = ChangeBitmask, Type = Operation})
	end
	

end

function EntityMethods:GetFieldChanged(Field)
	
end

function EntityMethods:SetComponent(ComponentName, Component)
	local EntityAdmin = require(game.ReplicatedStorage.EntityAdmin3)
	
	self.World.ComponentDatabase[ComponentName] = self.World.ComponentDatabase[ComponentName] or {}
	self.World.ComponentDatabase[ComponentName][self.ID] = Component
	
	self.ComponentMask = bit32.bor(self.ComponentMask, EntityAdmin.GetComponentMask(ComponentName))
	self.World.ComponentBitmaskChangedQue[self.ID] = self
	
	if Component == nil then
		self.ComponentMask = bit32.bxor(self.ComponentMask, EntityAdmin.GetComponentMask(ComponentName))
	end
	
	self.World.ComponentDatabaseChangeBitmasks[ComponentName] = self.World.ComponentDatabaseChangeBitmasks[ComponentName]  or {}
	self.World.ComponentDatabaseChangeBitmasks[ComponentName][self.ID] = self.World.ComponentDatabaseChangeBitmasks[ComponentName][self.ID] or 0
	
end

function EntityMethods:GetComponent(ComponentName)
	if self.World.ComponentDatabase[ComponentName] == nil then return end
	return self.World.ComponentDatabase[ComponentName][self.ID]
end

function EntityMethods:SendStreamerMessage(Player: Player)
	
end

function EntityMethods:SendAllStreamersMessage()
	
end

function EntityMethods:SendOwnerMessage()
	
end

function EntityMethods:SendAllClientsMessage()
	
end


function EntityMethods:OnClientMessage()
	
end

function EntityMethods:Destroy()	
	self.World:DestroyEntity(self.ID)
	local Metatable = getmetatable(self)
	
	if Metatable.OnDestroy then
		Metatable.OnDestroy(self)
	end
end

function EntityMethods:GetComponentRef(ComponentType)
	local Ref = {}
	
	
	return Ref
end

function EntityMethods:SendAuthorityMessage()
	
end

return BaseEntity