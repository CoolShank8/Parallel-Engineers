local EntityAdmin =  require(script:FindFirstAncestor("EntityAdmin"))
local PlayerConnectionSystem = EntityAdmin.BaseSystem:extend(script)

function PlayerConnectionSystem.Init(self)
	self.ReadQuery = EntityAdmin.Query.OfComponentArray()
	self.WriteComponentMask = EntityAdmin.GetComponentMask()
	self.RunMode = "Server"
	
	self.Que = {}
	self.PlayerToId = {}
	self.IdToPlayer = {}
	
	game.Players.PlayerAdded:Connect(function(Player)	
		self.Que[Player] = "Join"
	end)
	
	game.Players.PlayerRemoving:Connect(function(Player)
		if self.Que[Player] == "Join" then
			self.Que[Player] = nil
		else
			self.Que[Player] = "Left"
		end
	end)
	
	self.World:GetSingletonComponent("NetworkConnections").PlayerInstanceToReplicationID = self.PlayerToId
end


function PlayerConnectionSystem:Update(DT)	
	local FreeIdsQue = {}
	local LeavingBitmask = 0
	local JoiningBitmask = 0
	
	for i = 1,60,1 do
		local P: Player? = self.IdToPlayer[i] 
		if P then continue end
		table.insert(FreeIdsQue, i) -- add to the free id pool to reuse
	end
	
	for Player, QueAction in self.Que do
		if QueAction ~= "Left" then continue end
		
		local ID_Used = self.PlayerToId[Player] -- do not add this removed id to the reusepool until next frame
		self.PlayerToId[Player] = nil
		self.IdToPlayer[ID_Used] = nil
		
		self.Que[Player] = nil
		LeavingBitmask += 2^(ID_Used - 1)
	end
	
	if #FreeIdsQue == 0 then return end	
	
	local Incrementer = 1 -- fill from lowest ID to top ID
	
	for Player, QueAction in self.Que do
		if QueAction ~= "Join" then continue end
		
		if Incrementer > #FreeIdsQue then  -- keep player in join que for next frame
			continue
		else
			self.Que[Player] = nil
		end
		
		local FreeID = FreeIdsQue[Incrementer]
		self.PlayerToId[Player] = FreeID
		self.IdToPlayer[FreeID] = Player
		
		Incrementer += 1
		JoiningBitmask += 2^(FreeID - 1)
	end
	
	self.World:GetSingletonComponent("NetworkConnections").PlayerJoinedBitmask = JoiningBitmask
	self.World:GetSingletonComponent("NetworkConnections").PlayerLeavingBitmask = LeavingBitmask
end

return PlayerConnectionSystem