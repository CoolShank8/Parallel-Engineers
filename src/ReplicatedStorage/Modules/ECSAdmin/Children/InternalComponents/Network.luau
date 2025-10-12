--!strict

local ComponentBase = require(script:FindFirstAncestor("EntityAdmin").Children.BaseComponentRef)
local NetworkComponent = ComponentBase:extend("Network")



local Path = {
	Authority = "Server",
	Owner = game.Players.LocalPlayer,
	StreamTo = 0,
	CreationBeingClientPredicted = true,
}

export type Path = typeof(Path)


function NetworkComponent.new(Authority)
	return {
		Authority = Authority,
		Owner = game.Players.LocalPlayer,
		StreamTo = {"Server"},
		CreationBeingClientPredicted = true
	}
end



return NetworkComponent