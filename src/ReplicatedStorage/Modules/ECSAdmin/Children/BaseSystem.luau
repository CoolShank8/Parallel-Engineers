local BaseSystem = {}
BaseSystem.AllSystemClasses = {}

local SystemMethods = {}
local BaseCommand = require(script:FindFirstAncestor("EntityAdmin").Children.BaseCommand)

SystemMethods.__index = SystemMethods

function BaseSystem:extend(Module)
	local NewSystemClass = {}
	NewSystemClass.__index = NewSystemClass
	NewSystemClass.Commmands = setmetatable({}, {
		__newindex = function(CommandTable, CommandName, CommandFunctor)
			BaseCommand.Define(script, "AllSystemClasses", "Commands", CommandName)
		end,
	})
	
	BaseSystem.AllSystemClasses[NewSystemClass] = Module
	
	setmetatable(NewSystemClass, SystemMethods)
	return NewSystemClass
end

function BaseSystem.createSystem(World, ClassType, ID, ...)
	local SystemClass =  ClassType

	local System = {}
	System.ID = ID
	System.World = World	
	System.ReadQuery = nil
	System.WriteComponentMask = 0
	System.AllMatched = {}
	System.NewlyMatched = {}
	System.RemovingMatched = {}
	System.NetworkChannels = {}
	
	
	setmetatable(System, SystemClass)
	SystemClass.Init(System, ...)
	
	return System
end


function SystemMethods:GetNetworkChannel(ChannelName)
	if game:GetService('RunService'):IsServer() then
		local Channel = self.NetworkChannels[ChannelName]
		
		if Channel == nil then
			Channel = Instance.new('RemoteEvent')
			Channel.Name = self.ID .. "/" .. ChannelName
			Channel.Parent = script
		end
		
		return Channel
	else
		self.NetworkChannels[ChannelName] = self.NetworkChannels[ChannelName] or script:FindFirstChild(self.ID .. "/" .. ChannelName)
		return self.NetworkChannels[ChannelName]
	end
end

function SystemMethods:GetRemovedMatched()
	return self.RemovingMatched
end

function SystemMethods:GetNewMatched()
	return self.NewlyMatched
end

function SystemMethods:GetMatched()
	return self.AllMatched
end

return BaseSystem