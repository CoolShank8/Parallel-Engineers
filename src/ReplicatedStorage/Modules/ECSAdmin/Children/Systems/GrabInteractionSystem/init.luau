--!strict

local EntityAdmin = require(script:FindFirstAncestor("EntityAdmin"))
local GrabInteractionSystem = EntityAdmin.BaseSystem:extend(script)
local HandGrabbersUtil = require(script:FindFirstAncestor("EntityAdmin").Children.Components.HandGrabbers)


export type HandFSMTest = {
	HeldItem: EntityAdmin.Entity,
	IKControl: IKControl,
	WeldConstraint: WeldConstraint,
	ArmAttachment: Attachment,
	
	State: {
		Name: "MovingToAttachment",
		Attachment: Attachment,
		ReachedGoal: boolean
	} | {
		Name: "Idle"
	} | {
		Name: "AnimatingToMiddle"
	}
	
	-- all four  states should be cancellable 
}

export type Goal = {
	Type:  "GrabItem",
	Hand: "LeftHand"|"RightHand"|"Both",
	Item: EntityAdmin.Entity,
	DoSwap: boolean
}
| {
	Type: "PlaceItem",
	Hand: "LeftHand"|"RightHand"|"Both",
	Attachment: Attachment
}

export type HandGrabbersTEST = {	
	["RightHand"|"LeftHand"]: HandFSMTest,
	LeftHand: HandFSMTest,
	RightHand: HandFSMTest,

	-- GrabItem
	-- PlaceItem
	
	-- [GRAB Item] Left hand holds Sword. We want to hold a Gun instead in our left hand. We can either:
	-- A) Return sword to a toolbelt slot. And then pick up a gun.
	-- B) Move our hand to the gun location, place the sword at that location, and move our hand back to the idle position. 
	-- C) Drop sword on the ground and pick up a gun 
	
	-- [PLACE Item] Right hand wants to place an item.
	-- A) If the location is empty, we can place the item
	-- B) If the location already holds the item, we can Place our item at that location. And move that item to a new location
	
	Goal: Goal
}

local function WeldHoldItem(CharacterRig, HandType: "Left"|"Right", ItemToGrab)
	local HandMesh = CharacterRig:FindFirstChild(HandType .. "Hand", true)
	local GrabItemHandleAttachment: Attachment = ItemToGrab:GetComponent("Handle")[HandType .. "GripAttachment"] or error('Correct grip not found')
	local HandAttachment: Attachment = CharacterRig:FindFirstChild(HandType .. "GripAttachment", true)
	
	local ItemToGrabMesh = ItemToGrab:GetComponent("Renderable").MeshRig

	local MainPart;

	if ItemToGrabMesh:IsA("Tool") then
		MainPart = ItemToGrabMesh.Handle
		MainPart.Anchored = false
	elseif ItemToGrabMesh:IsA("Model") then
		MainPart = ItemToGrabMesh.PrimaryPart
		MainPart.Anchored = false
	else
		MainPart = ItemToGrabMesh
	end
	
	for i,v: Instance in MainPart:GetJoints() do
		if v:IsA("WeldConstraint") then
			if v.Part0:IsDescendantOf(ItemToGrabMesh) and v.Part1:IsDescendantOf(ItemToGrabMesh) then
				continue
			end
		end
		
		if v:IsA("RigidConstraint") then
			if v.Attachment0:IsDescendantOf(ItemToGrabMesh) and v.Attachment1:IsDescendantOf(ItemToGrabMesh) then
				continue
			end
		end
		
		v:Destroy()
	end

	local RigidConstraint = Instance.new('RigidConstraint')
	RigidConstraint.Attachment0 = HandAttachment
	RigidConstraint.Attachment1 = GrabItemHandleAttachment
	RigidConstraint.Parent = ItemToGrabMesh
	
	return RigidConstraint
end

local function WeldPlaceItem(Attachment, ItemToGrab, HandName)
	local ItemToGrabMesh = ItemToGrab:GetComponent("Renderable").MeshRig
	local GrabItemHandleAttachment: Attachment = ItemToGrab:GetComponent("Handle")[HandName .. "GripAttachment"] or error('Correct grip not found')

	local MainPart;

	if ItemToGrabMesh:IsA("Tool") then
		MainPart = ItemToGrabMesh.Handle
		MainPart.Anchored = false
	elseif ItemToGrabMesh:IsA("Model") then
		MainPart = ItemToGrabMesh.PrimaryPart
		MainPart.Anchored = false
	else
		MainPart = ItemToGrabMesh
	end
	
	for i,v: Instance in MainPart:GetJoints() do
		if v:IsA("WeldConstraint") then
			if v.Part0:IsDescendantOf(ItemToGrabMesh) and v.Part1:IsDescendantOf(ItemToGrabMesh) then
				continue
			end
		end

		if v:IsA("RigidConstraint") then
			if v.Attachment0:IsDescendantOf(ItemToGrabMesh) and v.Attachment1:IsDescendantOf(ItemToGrabMesh) then
				continue
			end
		end

		v:Destroy()
	end

	local RigidConstraint = Instance.new('RigidConstraint')
	RigidConstraint.Attachment0 = Attachment
	RigidConstraint.Attachment1 = GrabItemHandleAttachment
	RigidConstraint.Parent = ItemToGrabMesh

	return RigidConstraint
end



local function Make_IK_Constraint(RigEntity, HandType) : IKControl
	local RigMesh = RigEntity:GetComponent("Renderable").MeshRig
	local HandObject = RigMesh:FindFirstChild(HandType .. "Hand", true)
	
	
		local IkConstraint = Instance.new('IKControl')
		IkConstraint.Type = Enum.IKControlType.Position
		IkConstraint.ChainRoot = RigMesh:FindFirstChild(HandType .. "UpperArm", true)
		IkConstraint.EndEffector =  HandObject
		IkConstraint.SmoothTime = 0.08
		IkConstraint.Weight = 1
		IkConstraint.Parent = RigMesh 
	
		return IkConstraint
end

local function CFrameCloseEnough(cf1: CFrame, cf2: CFrame, posTol: number, angTol: number): boolean
	local posDist = (cf1.Position - cf2.Position).Magnitude

	local rel = cf1:ToObjectSpace(cf2)
	local _, ang = rel:ToAxisAngle()

	return posDist <= posTol and ang <= angTol
end


local function CreateGhostAttachmentForRigPart(Rig: Model, RigPart: BasePart): Attachment
	-- We’ll create an Attachment that “remembers” the default CFrame of this rig part
	-- relative to the rig’s root.

	-- Find HumanoidRootPart (or PrimaryPart fallback)
	local rootPart = Rig:FindFirstChild("HumanoidRootPart") or Rig.PrimaryPart
	if not rootPart then
		error("Rig has no HumanoidRootPart or PrimaryPart")
	end

	-- Compute where this part sits in the *rest pose* relative to root
	-- (Assumes rig is imported in correct rest pose)
	local relative = rootPart.CFrame:ToObjectSpace(RigPart.CFrame)

	-- Spawn ghost attachment in workspace (or you can parent under Rig if you prefer)
	local ghost = Instance.new("Attachment")
	ghost.Name = RigPart.Name .. "_Ghost"
	ghost.Parent = Rig.PrimaryPart -- free-floating, won’t affect physics
	ghost.WorldCFrame = rootPart.CFrame:ToWorldSpace(relative)
	return ghost
end


local function FindSwapAttachment(ItemWeAreGrabbing, HandName)
	local GrabItemHandleAttachment: Attachment = ItemWeAreGrabbing:GetComponent("Handle")[HandName .. "GripAttachment"] or error('Correct grip not found')
	local ItemWeAreGrabbingMesh = ItemWeAreGrabbing:GetComponent("Renderable").MeshRig
	
	local MainPart;

	if ItemWeAreGrabbingMesh:IsA("Tool") then
		MainPart = ItemWeAreGrabbingMesh.Handle
	elseif ItemWeAreGrabbingMesh:IsA("Model") then
		MainPart = ItemWeAreGrabbingMesh.PrimaryPart
	else
		MainPart = ItemWeAreGrabbingMesh
	end

	for i,v: RigidConstraint in MainPart:GetJoints() do
		if v:IsA("RigidConstraint") == false then continue end
		
		if v.Attachment0 == GrabItemHandleAttachment  then
			return v.Attachment1
		end
		
		if v.Attachment1 == GrabItemHandleAttachment then
			return v.Attachment0
		end
	end
end

local TransitionTable = {
	Enter = function(HandFSM: HandFSMTest)
		if HandFSM.State.Name == "MovingToAttachment" then
			HandFSM.IKControl.Type = Enum.IKControlType.Transform
			HandFSM.IKControl.Target = HandFSM.State.Attachment
		elseif HandFSM.State.Name == "Idle" then
			
		
		end
		
	end,
	
	
}

local function RunSingleHandFSM(HandFSM: HandFSMTest)	
	if HandFSM.State == nil then
		HandFSM.State = {
			Name = "Idle"
		}
	end
	
	if HandFSM.State.Name == "MovingToAttachment" then
		local PreviousTarget =  HandFSM.IKControl.Target
		HandFSM.IKControl.Target =  HandFSM.State.Attachment
		
		local DidReachGoal = CFrameCloseEnough(HandFSM.IKControl:GetRawFinalTarget(), HandFSM.IKControl:GetSmoothedFinalTarget(), 0.1, math.rad(10))
		
		if DidReachGoal == true then
			HandFSM.State.ReachedGoal = true
		end
		
	elseif HandFSM.State.Name == "Idle" then
		
	
	end
end


local function PlaceItemGoal(Goal: Goal, HandFSM)  : boolean
	if Goal and Goal.Type == "PlaceItem" then
		local HandType = Goal.Hand
		local HandName: "Left"|"Right" = if HandType == "LeftHand" then "Left" else "Right"
		local PlacementAttachment = Goal.Attachment

		local HeldItem = HandFSM.HeldItem 

		if HeldItem then	
			if HandFSM.State.Name == "Idle" then
				HandFSM.State = {Name = "MovingToAttachment", Attachment = PlacementAttachment}
				TransitionTable.Enter(HandFSM)
			end

			if HandFSM.State.Name == "MovingToAttachment" then

				-- If im holding the item, then i shouldn't be moving it to itemgripattachment, instead armattachment

				if HandFSM.State.Attachment == PlacementAttachment and HandFSM.State.ReachedGoal then --T We placed item, now it's time to retrieve our arm back
					HandFSM.State = {Name = "MovingToAttachment", Attachment = HandFSM.ArmAttachment}
					WeldPlaceItem(PlacementAttachment, HeldItem, HandName)
					HandFSM.HeldItem = nil
					TransitionTable.Enter(HandFSM)
				elseif HandFSM.State.Attachment ~= PlacementAttachment then -- if the attachment isn't our grip, and not the idle one then we need to change item
					HandFSM.State = {Name = "MovingToAttachment", Attachment = PlacementAttachment}
					TransitionTable.Enter(HandFSM)
				end

			end

		end

		if not HeldItem then

			if HandFSM.State.Name == "MovingToAttachment" then
				
				if HandFSM.State.Attachment == HandFSM.ArmAttachment and HandFSM.State.ReachedGoal then
					HandFSM.State = {Name = "Idle"}	
				elseif HandFSM.State.Attachment ~= HandFSM.ArmAttachment  then
					HandFSM.State = {Name = "MovingToAttachment", Attachment = HandFSM.ArmAttachment}
					TransitionTable.Enter(HandFSM)
				end
			end

			if HandFSM.State.Name == "Idle" then
				return true
			end
		end
	end
	
	
	return false
end


local function RunHandGoals(RigEntity, DT)
	local MeshRig = RigEntity:GetComponent("Renderable").MeshRig
	local HandGrabbers: HandGrabbersTEST = RigEntity:GetComponent("HandGrabbers")
	local Goal = HandGrabbers.Goal
	
	RigEntity:MarkComponentChange("HandGrabbers", {__Mask = 0})
	
	if HandGrabbers.LeftHand.IKControl == nil then
		HandGrabbers.LeftHand.IKControl = Make_IK_Constraint(RigEntity, "Left")
		HandGrabbers.LeftHand.IKControl.SmoothTime = .1
		HandGrabbers.LeftHand.IKControl.Weight = 1

		HandGrabbers.LeftHand.ArmAttachment = CreateGhostAttachmentForRigPart(MeshRig, MeshRig:FindFirstChild("LeftHand", true))
	end

	if HandGrabbers.RightHand.IKControl == nil then
		HandGrabbers.RightHand.IKControl = Make_IK_Constraint(RigEntity, "Right")
		HandGrabbers.RightHand.IKControl.SmoothTime = .12
		HandGrabbers.RightHand.IKControl.Weight = 1

		HandGrabbers.RightHand.ArmAttachment = CreateGhostAttachmentForRigPart(MeshRig, MeshRig:FindFirstChild("RightHand", true))
	end
	
	RunSingleHandFSM(HandGrabbers.LeftHand)
	RunSingleHandFSM(HandGrabbers.RightHand)
	
	
	if Goal and Goal.Type == "PlaceItem" then			
		local HandType = Goal.Hand
		local HandFSM = HandGrabbers[HandType]
		
		local IsDone = PlaceItemGoal(Goal, HandFSM)
		
		if IsDone then
			HandGrabbers.Goal = nil
		end
	end
	
	if Goal and Goal.Type == "GrabItem" then
		local HandType = Goal.Hand
		local HandName: "Left"|"Right" = if HandType == "LeftHand" then "Left" else "Right"
		local HandFSM = HandGrabbers[HandType]
		local ItemToGrab = Goal.Item
		local ItemGripAttachment = ItemToGrab:GetComponent("Handle")[HandName .. "GripAttachment"]
		
		if Goal.ReturnCurrentHeldItem and HandFSM.HeldItem and HandFSM.HeldItem ~= ItemToGrab then -- if we are holding an item that is not our grabbed item we need to return it
			local IsDone = PlaceItemGoal({ -- Runs Item goal only until we are no longer holding the item, (So won't be running the idle state). IsDone shouldn't really ever fire
				Type = "PlaceItem",
				Hand = HandType,
				Attachment = Goal.ReturnCurrentHeldItem
			}, HandFSM)
			
			
		else -- we should be good to proceed with GrabbingItemGoal
			
			local HasItem = HandFSM.HeldItem and HandFSM.HeldItem == ItemToGrab

			if HasItem then		
				if HandFSM.State.Name == "MovingToAttachment" then

					-- If im holding the item, then i shouldn't be moving it to itemgripattachment, instead armattachment

					if HandFSM.State.Attachment == HandFSM.ArmAttachment and HandFSM.State.ReachedGoal then -- IF we have reached the Armattachment, (meaning we have grabbed item equipped in default pose we are done!)
						HandFSM.State = {Name = "Idle"}	
					elseif HandFSM.State.Attachment ~= ItemGripAttachment and HandFSM.State.Attachment ~= HandFSM.ArmAttachment then -- if the attachment isn't our grip, and not the idle one then we need to change item
						HandFSM.State = {Name = "MovingToAttachment", Attachment = HandFSM.ArmAttachment}
						TransitionTable.Enter(HandFSM)
					elseif HandFSM.State.Attachment == ItemGripAttachment and HandFSM.State.ReachedGoal then
						HandFSM.State = {Name = "MovingToAttachment", Attachment = HandFSM.ArmAttachment}
						TransitionTable.Enter(HandFSM)
					end

				end

				if HandFSM.State.Name == "Idle" then
					HandGrabbers.Goal = nil -- goal has been achieved
				end
			end

			if not HasItem then
		

				if HandFSM.State.Name == "Idle" then
					HandFSM.State = {Name = "MovingToAttachment", Attachment = ItemGripAttachment}
					TransitionTable.Enter(HandFSM)
				end

				if HandFSM.State.Name == "MovingToAttachment" then
					if HandFSM.State.Attachment == HandFSM.ArmAttachment  then
						HandFSM.State = {Name = "MovingToAttachment", Attachment = ItemGripAttachment}
						TransitionTable.Enter(HandFSM)
					elseif HandFSM.State.Attachment ~= ItemGripAttachment  then
						HandFSM.State = {Name = "MovingToAttachment", Attachment = ItemGripAttachment}
						TransitionTable.Enter(HandFSM)
					elseif HandFSM.State.Attachment == ItemGripAttachment and HandFSM.State.ReachedGoal then
						HandFSM.State = {Name = "MovingToAttachment", Attachment = HandFSM.ArmAttachment}

						if Goal.DoSwap and HandFSM.HeldItem then
							local SWAP_Attachment = FindSwapAttachment(ItemToGrab, HandName)

							if SWAP_Attachment == nil then
								error('System could not find a valid swap attachment to swap with')
							end

							WeldPlaceItem(SWAP_Attachment, HandFSM.HeldItem, HandName)
						end

						warn('THIS PART RAN')

						HandFSM.HeldItem = ItemToGrab -- This state means we've reached the item so we can grab it essentially
						TransitionTable.Enter(HandFSM)
					end
				end
			end
			
			
		end
		
		
		
		
		if HandGrabbers.RightHand.HeldItem then
			if HandGrabbers.RightHand.WeldConstraint == nil then
				HandGrabbers.RightHand.WeldConstraint = WeldHoldItem(MeshRig, "Right", HandGrabbers.RightHand.HeldItem)
			else
				if HandGrabbers.RightHand.WeldConstraint.Parent ~= HandGrabbers.RightHand.HeldItem then
					HandGrabbers.RightHand.WeldConstraint:Destroy()
					HandGrabbers.RightHand.WeldConstraint = WeldHoldItem(MeshRig, "Right", HandGrabbers.RightHand.HeldItem)
				end
			end
		end
		
	end
end


function GrabInteractionSystem.Init(self)
	self.ReadQuery = EntityAdmin.Query.OfComponentArray({"HandGrabbers", "Renderable"}) 
	self.RunMode = "Server"
	self.WriteComponentMask = EntityAdmin.GetComponentMask("WeldConstraint")
	
	self.RigIKConstraints = {}
	self.RigHoldingItemsWelds = {}
end

function GrabInteractionSystem:Update(DT)
	for EntityID, Entity in self:GetMatched() do
		self.RigHoldingItemsWelds[Entity] = self.RigHoldingItemsWelds[Entity] or {}
		
		local HandGrabbers = Entity:GetComponent("HandGrabbers") :: HandGrabbers
		local RigMesh = Entity:GetComponent("Renderable").MeshRig
		
		RunHandGoals(Entity, DT)
		
		if HandGrabbers.LeftHand then
		--	Run_Individual_Hand(self, Entity, HandGrabbers, "LeftHand", DT)
		end
		
		if HandGrabbers.RightHand then
		--	Run_Individual_Hand(self, Entity, HandGrabbers, "RightHand", DT)
		end
	end

end
return GrabInteractionSystem