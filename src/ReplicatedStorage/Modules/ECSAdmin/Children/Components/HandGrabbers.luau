--!strict

local EntityAdmin = require(script:FindFirstAncestor("EntityAdmin"))

local GetExistingType = EntityAdmin.BaseComponentRef.GetExistingType
local DefineLiteralType = EntityAdmin.BaseComponentRef.DefineLiteralType
local DefineUnionType = EntityAdmin.BaseComponentRef.DefineUnionType

local EntityType: EntityAdmin.Entity = GetExistingType("Entity")
local AttachmentType : Attachment = GetExistingType("Instance")
local IkControlType: IKControl = GetExistingType("Instance")
local WeldType: WeldConstraint = GetExistingType("Instance")
local EntityMaybeType: EntityAdmin.Entity = GetExistingType("Entity", true)

local SwapperHandType: "Both"|"Left"|"Hand" = DefineLiteralType("Both", "Left", "Hand")

local TypeSwapToolbeltItems: "SwapToolbeltItems" = DefineLiteralType("SwapToolbeltItems")
local SwapToolbeltItems = {
	Type = TypeSwapToolbeltItems,
	FirstItem = EntityType,
	SecondItem = EntityType,

	SwapperHand = SwapperHandType,
}

local TypePlacingHeldItemInToolbeltSlot: "PlacingHeldItemInToolbeltSlot" = DefineLiteralType("PlacingHeldItemInToolbeltSlot")
local PlacingHeldItemInToolbeltSlot = {
	Type = TypePlacingHeldItemInToolbeltSlot,
	Attachment = AttachmentType
}

local TypeSwapHeldItemWithToolbeltItem: "SwapHeldItemWithToolbeltItem" = DefineLiteralType("SwapHeldItemWithToolbeltItem")
local SwapHeldItemWithToolbeltItem = {
	Type = TypeSwapHeldItemWithToolbeltItem,
	HeldItem = EntityType,
	ItemToGrab = EntityType,

	SwapperHand = SwapperHandType
}

local TypeEmptyHandGrabbingItem: "EmptyHandGrabbingItem" = DefineLiteralType("SwapHeldItemWithToolbeltItem")
local EmptyHandGrabbingItem = {
	Type = TypeEmptyHandGrabbingItem,
	ItemToGrab = EntityType,

	Context = {
		IKControl = IkControlType,
		StartTime = 0
	}
}


local TypeGoingToHandIdle: "GoingToHandIdle" = DefineLiteralType("GoingToHandIdle")
local GoingToHandIdle = {
	Type = TypeGoingToHandIdle,
	HeldItem = EntityType,

	Context = {
		IKControl = IkControlType,
		WeldConstraint = WeldType,
		StartTime = 0
	}
}

local TypeHandIdle: "HandIdle" = DefineLiteralType("HandIdle")
local HandIdle = {
	Type = TypeHandIdle,
	HeldItem = EntityMaybeType,
}

export type HandFSM = typeof(PlacingHeldItemInToolbeltSlot)|typeof(EmptyHandGrabbingItem)|typeof(GoingToHandIdle)
type HandFSMUnion =  typeof(PlacingHeldItemInToolbeltSlot)&typeof(EmptyHandGrabbingItem)&typeof(GoingToHandIdle)

export type HandGrabbers = {
	LeftHand: HandFSM,
	RightHand: HandFSM,

	CurrentGoal: typeof(SwapToolbeltItems)|typeof(SwapToolbeltItems)
}


local ComponentDef = {
	LeftHand = DefineUnionType(PlacingHeldItemInToolbeltSlot, EmptyHandGrabbingItem, GoingToHandIdle),
	RightHand = DefineUnionType(PlacingHeldItemInToolbeltSlot, EmptyHandGrabbingItem, GoingToHandIdle)
}


-- Maximum compact layout needs: 165 bits (20 bytes -- about same as a cframe thats all!), order field is defined by the base class

type LeftHandOrRightHand = "LeftHand"|"RightHand"

export type Path = {
	LeftHand: HandFSMUnion,
	RightHand: HandFSMUnion,
	[LeftHandOrRightHand]: HandFSMUnion,

	CurrentGoal: typeof(SwapToolbeltItems)|typeof(SwapToolbeltItems)
}


export type HandGrabbersComponent = {
	Path: Path
}

local HandGrabbersComponent = EntityAdmin.BaseComponentRef:extend(script, ComponentDef)
 

function HandGrabbersComponent.new()
	local HandGrabbers = {}
	
	return HandGrabbers
end

return HandGrabbersComponent:: HandGrabbersComponent
