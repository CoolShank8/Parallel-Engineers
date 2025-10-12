local EntityAdmin = require(game.ReplicatedStorage.EntityAdmin3)
local AttachmentSystem = EntityAdmin.BaseSystem:extend(script)

function AttachmentSystem.Init(self)
	self.ReadQuery = EntityAdmin.Query.OfComponentArray({"BodyGearLayout"})
	self.WriteComponentMask = EntityAdmin.GetComponentMask()
	self.RunMode = "Server"
	
	self.OldWelds = {}
end

local function WeldPlaceItem(Attachment, ItemToGrab, AttachmentOfMyItem)
	local ItemToGrabMesh = ItemToGrab:GetComponent("Renderable").Asset

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
	RigidConstraint.Attachment1 = AttachmentOfMyItem
	RigidConstraint.Parent = ItemToGrabMesh

	return RigidConstraint
end

function AttachmentSystem:Update(DT)
	
	
	for _, RigGearHolder in self:GetMatched() do
		local _ = self.World.CreateEntityTuple
		local RigGearLayout = RigGearHolder:GetComponent("BodyGearLayout")
		local SKIP_LIST = {}
		
		for AttachedWhere, Item in RigGearLayout do
			local Asset = RigGearHolder:GetComponent("Renderable").Asset
			
			local RigAttachment = Asset:FindFirstChild(AttachedWhere, true)
			local MyAttachment = Item:GetComponent("Handle")[AttachedWhere]
			local AttachmentGoal = RigAttachment.WorldCFrame
			
			local NewCFrame = AttachmentGoal:ToWorldSpace(MyAttachment.CFrame:Inverse())		
			
			if Item:GetComponent("Renderable") and Asset then
				local MyRig = Item:GetComponent("Renderable").Asset
				if self.OldWelds[RigGearHolder] == nil or self.OldWelds[RigGearHolder][Item] == nil then
					--MyRig:PivotTo(Transform.CFrame)
					warn('weld created')
					

					self.OldWelds[RigGearHolder] = self.OldWelds[RigGearHolder] or {}
					self.OldWelds[RigGearHolder][Item] = WeldPlaceItem(RigAttachment, Item, MyAttachment)
				end
				
				SKIP_LIST[Item] = true
			end
			
			
			--Asset.Name = "Hello"
		end
		
		if self.OldWelds[RigGearHolder] then
			for Part, Weld in self.OldWelds[RigGearHolder]  do
				if SKIP_LIST[Part] then continue end
				Weld:Destroy()
				self.OldWelds[RigGearHolder][Part] = nil
			end

		end
		
		--_(AttachedTo, Attached):SetComponent("WeldConstraint")
	end
end

return AttachmentSystem