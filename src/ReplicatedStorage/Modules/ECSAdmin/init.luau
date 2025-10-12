--!strict

local EntityAdmin: EntityAdmin = {}:: EntityAdmin

export type EntityID = string
export type Bitfield = number

local Signal = require(script.Children.InternalClasses.Signal)


export type GEntity<Object> = {
	Destroy: (GEntity<Object>) -> (),

	Sync: (GEntity<Object>, WhichStreamers: {}?, PropertySyncDictionary:{any}?) ->(), -- force sync the current full state for clients useful if u've only been streaming critical data clients and now client access full file and wants to view all data
	
	Path: Object,
	MarkChange: (GEntity<Object>, ChangeBitmask: number|{string}, Operation: ("Insertion"|"Deletion")? ) -> (),
	UpdateIdentity: (GEntity<Object>, TransformationDescriptor: {}) -> (), -- updates the identity properties
	AddChild: (GEntity<Object>, IndexName: string) -> (),
	
	
	SetComponent: (
		((GEntity<Object>, Component: "Network", NetworkComponent: Network) -> ())&
		((GEntity<Object>, Component: "Physics", PhyscisComponent: Physics) -> ())&
		((GEntity<Object>, Component: "Selector",SelectorComponent: Selector) -> ())&
		((GEntity<Object>, Component: "Health",  HealthComponent: Health) -> ())&
		((GEntity<Object>, Component: "Transform",  TransformComponent: Transform) -> ())&
		((GEntity<Object>, Component: "Inventory",  InventoryComponent: Inventory) -> ())&
		((GEntity<Object>, Component: "UIDesign",  UIDesignComponent: UIDesign) -> ())
	),


	GetComponent: (
		((GEntity<Object>, Component: "Network") -> (Network))&
		((GEntity<Object>, Component: "Physics") -> (Physics))&
		((GEntity<Object>, Component: "Selector") -> (Selector))&
		((GEntity<Object>, Component: "Health") -> (Health))&
		((GEntity<Object>, Component: "Transform") -> (Transform))&
		((GEntity<Object>, Component: "Inventory") -> (Inventory))&
		((GEntity<Object>, Component: "UIDesign") -> (UIDesign))
	), 

	--GetComponent: MakeGetComponent<ComponentMapper>,

	World: World,
	ID: EntityID,
	Identity: {},

}

export type Entity = {
	Destroy: (Entity) -> (),
	Path: {},

	Sync: (Entity, WhichStreamers: {}?, PropertySyncDictionary:{any}?) ->(), -- force sync the current full state for clients useful if u've only been streaming critical data clients and now client access full file and wants to view all data
	
	MarkChange: (Entity, ChangeBitmask: number|{string}, Operation: ("Insertion"|"Deletion")? ) -> (),
	UpdateIdentity: (Entity, TransformationDescriptor: {}) -> (), -- updates the identity properties
	AddChild: (Entity, IndexName: string) -> (),

	SetComponent: (
		((Entity, Component: "Network", NetworkComponent: Network) -> ())&
		((Entity, Component: "Physics", PhyscisComponent: Physics) -> ())&
		((Entity, Component: "Selector",SelectorComponent: Selector) -> ())&
		((Entity, Component: "Health",  HealthComponent: Health) -> ())&
		((Entity, Component: "Transform",  TransformComponent: boolean) -> ())&
		((Entity, Component: "Inventory",  InventoryComponent: Inventory) -> ())&
		((Entity, Component: "UIDesign",  UIDesignComponent: UIDesign) -> ())
	),


	GetComponent: (
		((Entity, Component: "Network") -> (Network))&
		((Entity, Component: "Physics") -> (Physics))&
		((Entity, Component: "Selector") -> (Selector))&
		((Entity, Component: "Health") -> (Health))&
		((Entity, Component: "Transform") -> (Transform))&
		((Entity, Component: "Inventory") -> (Inventory))&
		((Entity, Component: "UIDesign") -> (UIDesign))
	), 

	--GetComponent: MakeGetComponent<ComponentMapper>,
	MutateComponent: (Entity, ComponentType) -> (ComponentRef),

	World: World,
	ID: EntityID,
	Identity: {},

}


local ComponentNames = {"GoalAnimator", "Clock", "UIDesign", "WeldConstraint", "Network","Physics","Selector","Health","Transform","Inventory","Attachments", "TeamInfo", "Storage", "RespawnLoadout", "Renderable", "LootDropper", "StorageItem", "Handle", "RigGear", "BodyGearLayout", "LayoutOrder", "LayoutConstraint", "HandGrabbers", "PlayerConnection", "FlagHolder", "Flag"}

export type ComponentMapper = {
	Network: {Network},
	Physics: {Physics},
	Selector: {Selector},
	Health: {Health},
	Transform: {Transform},
	Inventory: {Inventory},
	UIDesign: {UIDesign}
}


export type UIDesign = {
	Design: GuiBase,
	Visible: boolean
}


export type Selector = {
	Viewing: Entity?,
	MaxSelectable: number,
	SelectedEntities: {Entity}
}

export type Network = {
	Authority: "Server"| Player,
	Owner: Player?,
	StreamTo: Bitfield, -- bit 32 bitfield
	CreationBeingClientPredicted: boolean,
}

export type Physics = {
	Velocity: Vector3,
	Acceleration: Vector3
}

export type Health = {
	Current: number,
	Max: number,
	HealRate: number
}

export type Transform = {
	CFrame: CFrame,
	Position: Vector3,
	Size: Vector3
}

export type Storage = {
	All: {
		[Entity]: {
			StackCount: number?,
		}
	}
}

export type WearingItems = {
	[Entity]: {
		AttachmentName: string,
		SlotHolder: Entity? -- is the attachment part of this entity, or nested entity (like our tool belt entity)
	}
}

export type SlotAttachments = {
	[string]: CFrame -- Attachment name to relative cframe of the entity 
}

export type Grabbing = {
	Type: "TurnGrabbed",
	ArmType: "Left"|"Right",
	Grabbed: Entity,
	GrabbedAttachment: Attachment?, -- should we grab a specfic part of the object?
	Degrees: number
}|{
	Type: "PickupGrabbed",
	ArmType: "Left"|"Right",
	Grabbed: Entity,
	GrabbedAttachment: Attachment?, -- should we grab a specfic part of the object?
	PlaceAttachment: Attachment?, -- Which attachment to place in our parent entity if placing behavior we want
	PlaceEntity: Entity? -- if attachment not in our entity, then choose a custom entity (tool belt)
}


export type Que<T> = {
	filter: (Que<T>, (T) -> (boolean)) -> (Que<T>)	
}

local SystemFolder = game.ReplicatedStorage.EntityAdmin3.Systems

export type World = {
	CreateEntity: (World, Class: EntityClass?, ...any) -> (Entity),
	CreateEntityOfClass: <T> (World, Class: EntityClass?, ... any) -> (T),
	CreateEntityOfClassWithID: <T> (World, Class: EntityClass?, ... any) -> (T),
	
	CreateEntityWithID: (World, EntityID, Class: EntityClass?, ...any) -> (Entity),
	GetEntity: (World, EntityID) -> (Entity?),
	
	AddSystem:( 
		((World, Type: typeof(SystemFolder.RenderSystem)) -> System)&
		((World, Type: typeof(SystemFolder.AttachmentSystem)) ->  System)&
		((World, Type: typeof(SystemFolder.ConstraintSystem)) -> System)
	),
	
	CreateEntityTuple: (...Entity) ->(),
	
	ChangeDetector: ChangeDetector,
	ComponentDatabase: ComponentMapper,
	EventDatabase: {[string]: {}},
	AllEntities: {[EntityID]: Entity},
	
	PushEvent: (World, EventName: string, Record: {}) -> (),
}

export type Env = {
	IsAuthority: (self: Env) -> (boolean),
	IsOwner: (self: Env) -> (boolean)
}

export type ComponentRef = {
	Set: (ComponentRef, Field: string|{string}) -> (),
	InsertIntoTable: (ComponentRef, string|{string}) -> (),
}


export type ChangeDetector = {
	ComponentCreated: (ComponentType) -> ({On: Signal.Signal<EntityID>, GetQue: () -> (
		Que<{
			EntityID: EntityID,
			Count: number,
		}>
		
		)}),

	ComponentRemoved: (ComponentType) -> ({On: Signal.Signal<EntityID>, GetQue: () -> (
		Que<{
			EntityID: EntityID,
			Count: number,
		}>

		)}),

	ComponentChanged: (ComponentType) -> ({On: Signal.Signal<EntityID>, GetQue: () -> ( 
		Que<{
			EntityID: EntityID,
		}>

		)}),
	
	
	
	Changed: () -> (),
	IdentityChanged: () -> (),
	ChildAdded: () -> (),
	ChildRemoved: () -> (),
	Destroyed: () -> (),
}



export type System = {
	World: World,
	
	ReadQuery: {},
	WriteComponentMask: Bitfield,
	RunMode: "Client"|"Server"|"Shared",
	[any]: any,
	
	Predict: (System, Entity) -> (),
	Step: (System) -> (),
	
	GetMatched: (System) -> ({[EntityID]: Entity}),
	GetNewMatched: (System) -> ({[EntityID]: Entity}),
	GetRemovedMatched: (System) -> ({[EntityID]: Entity}),
}

export type SystemClass = {
	Commands: {[string]: (...any) -> (Command)},
	
	Update: (System, DT: number) -> (),
	Init: (System) -> (),
}

-- traderejected (COMMAND)
export type CommandAccepter = {
	ExecuteValidator: (Issuer: Player) -> (boolean),
	UndoValidator: (Issuer: Player) -> (boolean)
}

export type Command2 = {
	ID: string,
	Functor: () ->(),
	Args: {any},
	
	
	World: World,	
} | 
{
	Executed: false,
	
	PredictExecute: () -> (),
	Execute: () -> (),
	
}|{
	Undone: false,
	Undo: () -> (),
	PredictUndo: () -> (),
}|{
	Replicated: true,

	ServerAccepted: Signal.Signal<{}>,
	ServerRejected: Signal.Signal<{}>,
	
	ServerAcceptedUndo: Signal.Signal<{}>,
	ServerRejectedUndo: Signal.Signal<{}>
} 
	
export type Command = {
	ID: string,
	Functor: () ->(),
	Args: {any},


	World: World,
	PredictExecute: (self: Command) -> (),
	Execute: (self: Command) -> (),
}



export type EntityClass = {
	Module: ModuleScript,
	OnDestroy: (Entity) -> (),
	Commands: {[string]: (...any) -> ()},
	
	OnInit: (Entity, Env, ...any) -> (), 	-- Setup components, non-authority-specific state. thing everyone has
	OnOwnerInit: (Entity) -> (),
	OnAuthorityInit: (Entity: Entity) -> (Entity), -- Called only on authority, Client if client object or server if server object. If predicted object created on client, this is called on server when object is confirmed on server.
	OnPredictedInit: (Entity) -> (), -- Called when a predicted client creates entity
	OnPredictionConfirmed: (Entity) -> (), -- called on the client that predicted the creation of this entity
	OnPredictionRejected: (Entity) -> (), -- called on the client that predicted the creation of this entity

	OnStreamToObserved: (Entity) -> (),
	
	[string]: any
}


export type BaseEntity = {
	extend: (BaseEntity, ClassModuleScript: ModuleScript) -> EntityClass,

	createEntity: () -> (),
	createEntityOfClass: () -> (),
}

export type BaseSystem = {
	extend: (BaseSystem, SystemModuleScript: ModuleScript, Info: {}?) -> SystemClass,

	createSystem: () -> (),
}

export type BaseComponentRef = {
	extend: (BaseComponentRef, ComponentRefModuleScript: ModuleScript, ComponentDef: any) -> {Path: any, new: any},
	GetExistingType: (TypeName: string, IsOptional: boolean?) -> any,
	DefineLiteralType: (...string) -> any,
	DefineUnionType: (...{}) -> any
--	DefineUnionType: ()
}

export type BaseCommand = {
	extend: (BaseCommand, CommandModuleScript: ModuleScript) -> BaseCommand,
	commandify: ((any) -> (any)) -> (Command),
}


export type Serializer = {
	SerializeWorld: (World) -> (),
	SerializeEntity: (GEntity<any>|BaseEntity) -> (),
	SerializeSystem: (System) -> (),
	
	LoadWorld: (World, WorldID: string) -> (World),
	LoadEntity: (GEntity<any>|BaseEntity, WorldID: string, EntityID: string) -> (Entity),
	LoadSystem: (System, WorldID: string) -> (System),
}

export type Query = {
	OfComponentArray: (...{string}) -> ()
}

export type EntityAdmin = {
	CreateWorld: (ID: string) -> (World),
	GetWorld: (ID:string) -> (World),
	
	BaseEntity: BaseEntity,
	BaseSystem: BaseSystem,
	BaseComponentRef: BaseComponentRef,
	BaseCommand: BaseCommand,
	
	Serializer: Serializer,
	Query: Query,
	
	GetComponentMask: (...string) -> (Bitfield),
}

local EntityAdmin = {
	BaseEntity = require(script.Children.BaseEntity),
	BaseComponentRef = require(script.Children.BaseComponentRef),
	BaseSystem = require(script.Children.BaseSystem),
	BaseCommand = require(script.Children.BaseCommand),
	Serializer = require(script.Children.Serializer),
	Query = require(script.Children.Query),
}

local AllWorlds = {}

local ComponentNameToIndex = {}; for i,v in ComponentNames do ComponentNameToIndex[v] = i end


function EntityAdmin.GetComponentMask(...: string)
	local Mask = 0
	
	for _, ComponentName in {...} do
		Mask += 2^ (ComponentNameToIndex[ComponentName] - 1)
	end
	
	return Mask
end

function EntityAdmin.CreateWorld(ID: string): World
	local WorldClass = require(script.Children.World) -- make lua type checker stop bothering about Cyclic dependencies
	AllWorlds[ID] = WorldClass.new(ID)
	return AllWorlds[ID]
end

function EntityAdmin.GetWorld(ID: string)
	return AllWorlds[ID]
end


return EntityAdmin:: EntityAdmin