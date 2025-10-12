--~strict

local EntityAdmin = require(script:FindFirstAncestor("EntityAdmin"))
local FlagSystem = EntityAdmin.BaseSystem:extend(script) 
local Cleaner = require(game.ReplicatedStorage.Utility.Cleaner)
local DestructionQue = require(game.ReplicatedStorage.Utility.DestructionQue)


export type FlagHolder = {
	Hitbox: BasePart
}

export type Flag = {
	State: {
		Type: "InHolder",
		Holder: EntityAdmin.Entity,	
	} | {
		Type: "PlayerCarrying",
		Rig: EntityAdmin.Entity,
	} | {
		Type: "Despawning",
		DespawnTimer: number,
	},
	
	GrabHitbox: BasePart,
	FlagAttachment: Attachment
}


local function AreInSameTeams(Entity1, Entity2)
	local Team1 = Entity1:GetComponent("TeamInfo")
	local Team2 = Entity2:GetComponent("TeamInfo")
	
	if Team1 == nil or Team2 == nil then return false end
	
	return Team1.Team == Team2.Team 
end

local function GetAvaliableHolder(FlagEntity: EntityAdmin.Entity)
	local World = FlagEntity.World
	local FlagComponent = FlagEntity:GetComponent("Flag")
	
	local FlagHolderUnavaliableMap = {}
	local AvaliableHolder;
	
	for EntityID, Component: Flag in World.ComponentDatabase.Flag do
		if Component.State.Type == "InHolder" then 
			FlagHolderUnavaliableMap[Component.State.Holder] = true	
		end
	end
	
	for EntityID, Component: FlagHolder in World.ComponentDatabase.FlagHolder do
		local HolderEntity = World.AllEntities[EntityID]
		
		if FlagHolderUnavaliableMap[EntityID] then continue end
		if not AreInSameTeams(FlagEntity, HolderEntity) then continue end

		AvaliableHolder = HolderEntity
		break
	end
	
	return AvaliableHolder
end

local function GetPlayerCarryFlag(Player, World)
	for Entity, Component in World:GetAllComponentsOfType("FlagComponent") do

		if Component.FlagState.State == nil then continue end
		if Component.FlagState.State ~= "OnPlayerBack" then continue end
		if Component.FlagState.Player ~= Player then continue end

		return Entity
	end
end

local function GetFlagOfHolder(Holder, World)
	for Entity, Component in World:GetAllComponentsOfType("FlagComponent") do
	
	
		if Component.FlagState.State == nil then continue end
		if Component.FlagState.State ~= "InHolder" then continue end
		if Component.FlagState.Holder ~= Holder then continue end
		
		
		return Entity
	end
end

local function GetPlayerFromHitPart(World: EntityAdmin.World, Hit)
	local Humanoid: Humanoid = Hit.Parent:FindFirstChild("Humanoid")
	if Humanoid == nil then return end
	if Humanoid.Health <= 0 then return end
	local Player = game.Players:GetPlayerFromCharacter(Humanoid.Parent)
	
	if Player then
		local ID =next(World.ComponentDatabase.PlayerConnection)
		return World.AllEntities[ID]
	else
		return nil
	end
	
	--return Player
end

local function IsPlayerEligibleToCarryFlag(Player, Flag, World)
	local FlagComponent = World:GetComponent(Flag, "FlagComponent")
	local FlagTeam = World:GetComponent(Flag, "TeamComponent")
	
	if Player.Team == FlagTeam.Team then return false end
	if GetPlayerCarryFlag(Player, World) then return false end
	return true
end



function FlagSystem.Init(self) 
	self.ReadQuery = EntityAdmin.Query.OfComponentArray({"Flag"}, {"FlagHolder"})
	self.WriteComponentMask = EntityAdmin.GetComponentMask("Flag", "FlagHolder")
	self.RunMode = "Server"
	
	self.UnassignedFlags = {}
	self.UnassignedHolders = {}
	self.EntityCleaners = {}
	self.OriginalFlagParents = {}
	
	self.FlagHolderTouchedQue = {}
	self.TouchedEventQue = {}
	
	self.DestructionQue = DestructionQue.new()
end



local function SetupRigidConstraint(FlagEntity, Holder)
	
	local FlagMesh = FlagEntity:GetComponent("Renderable").Asset
	local FlagAttachment = FlagEntity:GetComponent("Flag").FlagAttachment
	local RigidConstraint = FlagMesh:FindFirstChild('BaseWeld')

	if RigidConstraint == nil then
		RigidConstraint = Instance.new('RigidConstraint')
		RigidConstraint.Name = "BaseWeld"
		RigidConstraint.Parent = FlagMesh	
	end

	RigidConstraint.Attachment0 = Holder:GetComponent("FlagHolder").FlagAttachment
	RigidConstraint.Attachment1 = FlagAttachment

	return RigidConstraint
	
end

local FlagFsmTransitonTable = {
	InHolder = {
		PlayerRequestPickup = function(Flag, Rig)
			local FlagComponent = Flag:GetComponent("Flag")
			
			FlagComponent.State = {
				Type = "PlayerCarrying",
				Rig = Rig
			}
		end,
	},
	
	Despawning = {
		TimerExpired = function(Flag)
			local FlagComponent = Flag:GetComponent("Flag")
			
			FlagComponent.State = {
				Type = "InHolder",
				Holder = GetAvaliableHolder(Flag)
			}
		end,
		PlayerRequestPickup = function(Flag, Rig)
			local FlagComponent = Flag:GetComponent("Flag")
			FlagComponent.State = {
				Type = "PlayerCarrying",
				Rig = Rig
			}
		end,
	},
	
	PlayerCarrying = { 
		Dropped = function(Flag)
			local FlagComponent = Flag:GetComponent("Flag")
			FlagComponent.State = {
				Type = "Despawning",
				DespawnTimer = 20
			}
		end,
		EnemyPlayerTouchedTheirTeamBase = function(Flag)	
			local FlagComponent = Flag:GetComponent("Flag")
			FlagComponent.State.Rig:GetComponent("BodyGearLayout").BodyBackAttachment = nil
			
			Flag.World:PushEvent("FlagCaptured", {
				Capturer = FlagComponent.State.Rig,
				CapturerTeam = FlagComponent.State.Rig:GetComponent("TeamInfo").Team,
				Flag = Flag,
			})
			
			FlagComponent.State = {
				Type = "InHolder",
				Holder = GetAvaliableHolder(Flag)
			}
		end,
	
		SameTeamPlayerTouchedTeamBase = function(Flag, HolderTouched) -- players is the same team as the flag and touches their shared team based
			local FlagComponent = Flag:GetComponent("Flag")
			FlagComponent.State = {
				Type = "InHolder",
				--Holder = if IsHolderAvaliable(HolderTouched) then HolderTouched else GetAvaliableHolder(Flag),
				Holder = GetAvaliableHolder(Flag)
			}
		end,
	}
}

local function PutFlagOnPlayerBack(Flag)
	local FlagComponent = Flag:GetComponent("Flag")
	--	local CarryingHumanoid = FlagComponent.State.Rig:GetComponent("Renderable").Asset
	
	
	local CarryingHumanoid = FlagComponent.State.Rig
	CarryingHumanoid:GetComponent("BodyGearLayout").BodyBackAttachment = Flag
	
	if true then return end
	
	local RigidConstraint =  CarryingHumanoid:FindFirstChild("BackWeld")
	
	if RigidConstraint == nil then
		RigidConstraint = Instance.new('RigidConstraint')
		RigidConstraint.Attachment0 = FlagComponent.FlagAttachment
		RigidConstraint.Attachment1 =	CarryingHumanoid:FindFirstChild("BodyBackAttachment", true)
		RigidConstraint.Name = "BackWeld"
		RigidConstraint.Parent = CarryingHumanoid
	end
	
	return RigidConstraint
end

local function GetConnectedJoint(partA, partB)
	if partA:IsA("Model") then partA = partA.PrimaryPart end
	if partB:IsA("Model") then partB = partB.PrimaryPart end
	
	for _, joint in partA:GetJoints() do
		if joint.Part0 == partB or joint.Part1 == partB then
			return joint
		end
	end
	return nil
end

-- FLAG Systrm can be converted into a two pass system but 1 pass is easier

function FlagSystem:Update(DT)
	--ProcessUnIntializedFlags(World)
	
	for ID, Entity in self:GetNewMatched() do
		local FlagComponent: Flag = Entity:GetComponent("Flag")
		local FlagHolderComponent: FlagHolder = Entity:GetComponent("FlagHolder")
		
		if FlagComponent then
			FlagComponent.GrabHitbox.Touched:Connect(function(Hit)
				local Player = GetPlayerFromHitPart(self.World, Hit)
				if Player == nil then return end
				
				self.TouchedEventQue[Entity] = {Player = Player}
			end)
		end
		
		if FlagHolderComponent then
			
			FlagHolderComponent.Hitbox.Touched:Connect(function(Hit)
				local Player = GetPlayerFromHitPart(self.World, Hit)
				if Player == nil then return end
				
				self.FlagHolderTouchedQue[Player] = {Entity = Entity}
			end)
		end
	end
	
	for ID, Entity in self:GetMatched() do
		local FlagComponent: Flag = Entity:GetComponent("Flag")
		local FlagHolderComponent: FlagHolder = Entity:GetComponent("FlagHolder")
		
		if FlagComponent then	
			------- PRE State transofmrations --- effects we want to do so we can determine transitions based on our current state
			if FlagComponent.State.Type == "Despawning" then -- if the flag is gonna go 0 this frame, we want it to despawn so handle it before state transitions rathern then post transitions
				FlagComponent.State.DespawnTimer -= DT
			end
			--------------------------------------------
			
			if FlagComponent.State.Type == "InHolder" then
				local PlayerRequestPickup = self.TouchedEventQue[Entity]
				
				if PlayerRequestPickup and not AreInSameTeams(PlayerRequestPickup.Player, FlagComponent.State.Holder) then
					FlagFsmTransitonTable.InHolder.PlayerRequestPickup(Entity, PlayerRequestPickup.Player)
				end
			end
			
			
			if FlagComponent.State.Type == "Despawning" then
				local TimerExpired = FlagComponent.State.DespawnTimer <= 0
				local PlayerRequestPickup = self.TouchedEventQue[Entity]
				
				if TimerExpired then
					FlagFsmTransitonTable.Despawning.TimerExpired(Entity)
				elseif PlayerRequestPickup then
					FlagFsmTransitonTable.Despawning.PlayerRequestPickup(Entity, PlayerRequestPickup.Player)
				end
			end
			
			if FlagComponent.State.Type == "PlayerCarrying" then
				local Player = FlagComponent.State.Rig
				local Rig: Instance = Player:GetComponent("Renderable").Asset
				
				local PlayerTouchedTheirBase = self.FlagHolderTouchedQue[Player] and AreInSameTeams(Player, self.FlagHolderTouchedQue[Player].Entity)
				
				local EnemyPlayerTouchedTheirTeamBase = PlayerTouchedTheirBase and not AreInSameTeams(Player, Entity)
				local SameTeamPlayerTouchedTeamBase = PlayerTouchedTheirBase and AreInSameTeams(Player, Entity) 
				
				local PlayerDead = Rig:FindFirstChild("Humanoid") == nil or Rig.Humanoid.Health <= 0 
				local PlayerLeft = Rig:IsDescendantOf(workspace) == false
				
				if PlayerDead or PlayerLeft then
					FlagFsmTransitonTable.PlayerCarrying.Dropped(Entity)
				elseif EnemyPlayerTouchedTheirTeamBase then
					FlagFsmTransitonTable.PlayerCarrying.EnemyPlayerTouchedTheirTeamBase(Entity)
				elseif SameTeamPlayerTouchedTeamBase then
					FlagFsmTransitonTable.PlayerCarrying.SameTeamPlayerTouchedTeamBase(Entity, self.FlagHolderTouchedQue[Player].Entity)
				end
			end
			
			
			---- POST State TRANSITIONS ---
			if FlagComponent.State.Type == "InHolder" then
				local Constraint = SetupRigidConstraint(Entity, FlagComponent.State.Holder)
				self.DestructionQue:MarkNoDestroyThisFrame(Constraint)
			end
			
			if FlagComponent.State.Type == "PlayerCarrying" then
				local Player = FlagComponent.State.Rig
				local Rig = Player:GetComponent("Renderable").Asset
				
				local Constraint = PutFlagOnPlayerBack(Entity) -- whatever the connected weld is, mark it for destruction if next frame this state isn't true. 
			--	self.DestructionQue:MarkNoDestroyThisFrame(Constraint)
			end
			
			if FlagComponent.State.Type == "Despawning" then -- depsawnining has no post conditions only the previous pre condition
				
			end
			-------------------------
		end
		
	
		if FlagHolderComponent then

		end
		
	end
	
	self.DestructionQue:ClearThoseNotMarked()
	
	table.clear(self.TouchedEventQue)
	table.clear(self.FlagHolderTouchedQue)
end


return FlagSystem