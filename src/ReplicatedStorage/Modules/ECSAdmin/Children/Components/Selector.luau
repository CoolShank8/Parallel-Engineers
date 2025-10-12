local EntityAdmin = require(script:FindFirstAncestor("EntityAdmin"))
local Selector = EntityAdmin.BaseComponentRef:extend(script)

function Selector.new(Authority)
	return {
		Authority = Authority,
		Owner = game.Players.LocalPlayer,
		StreamTo = {"Server"},
		CreationBeingClientPredicted = true
	}
end

function Selector:AddStreamer(PLayer)
	self:InsertIntoTablePath("StreamTo", PLayer)
end

return {}