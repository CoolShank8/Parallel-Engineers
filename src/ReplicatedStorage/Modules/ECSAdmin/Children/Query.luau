local QueryManager = {}
local Signal = require(script:FindFirstAncestor("EntityAdmin").Children.InternalClasses.Signal)

local QueryMethods = {}
QueryMethods.__index = QueryManager

--[[
	Query example
	
	Give me All Current Entities with HandComponent.Type == "GrabbingItem"
	
	Only query this this specfic entity when HandComponent.Type == "GrabbingItem"

]]

function QueryManager.OfTheseEntities(EntityTable, ComponentName: string, ComponentPath: string, Value: string) -- auto destroyed when {entities} are destroyed
	local Query = {}
	Query.EntityTable = EntityTable
	Query.Matched = Signal.new()
	Query.Unmatched = Signal.new()
	
	setmetatable(Query, QueryMethods)
	return Query
end

function QueryManager.OfComponentArray(...: {string}) -- auto destroyed when world is destroyed
	local EnityAdmin = require(game.ReplicatedStorage.EntityAdmin3)
	
	local Query = {}
	Query.Matched = Signal.new()
	Query.Unmatched = Signal.new()
	Query.ComponentBitmasks = {}
	
	for _, MaskOfBorTable in {...} do
		table.insert(Query.ComponentBitmasks, EnityAdmin.GetComponentMask(unpack(MaskOfBorTable)))
	end
	
	-- QUery({"Position", "Velocity"}, "Weld") means Query those that have both position and velocity or those that have weld
	
	setmetatable(Query, QueryManager)
	return Query
end

function QueryMethods:SetAutoUpdater(Type: "PreFrame"|"PostFrame"|"PreRender")
	
end

function QueryMethods:GetMatched(World)
	
end

function QueryMethods:Destroy()
	
end

return QueryManager