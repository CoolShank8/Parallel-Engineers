local BaseComponentRef = {}

function BaseComponentRef.GetExistingType(TypeName, IsOptional)
	return setmetatable({
		Operand = "ExistingType",
		TypeName = TypeName,
		IsOptional = IsOptional or false
	}, BaseComponentRef)
end

function BaseComponentRef.DefineLiteralType(...: string)
	return setmetatable({
		Operand = "Literal",
		LiteralPossibilties = {...}
	}, BaseComponentRef)
end

function BaseComponentRef.DefineUnionType(...)
	return setmetatable({
		Operand = "Union",
		UnionItems = {...}
	}, BaseComponentRef)
end


-- CHANGE types, PropertyChanged, In

local function Recursive_Explore(ComponentDescription, AllCompressedFields, COUNT_TABLE)
	AllCompressedFields = AllCompressedFields or {}
	COUNT_TABLE = COUNT_TABLE or {Count = -1}
	
	for FieldName , Child in ComponentDescription do
		if AllCompressedFields[FieldName] == nil then
			COUNT_TABLE.Count += 1
		else
			--warn(FieldName .. ' duplicate iteration') -- TODO fix this duplicate iteration
		end
		
		AllCompressedFields[FieldName] = AllCompressedFields[FieldName] or {__Mask = 2^COUNT_TABLE.Count}
		
		
		
		if type(Child) == 'string' or type(Child) == 'number' or type(Child) == 'boolean' then
			continue
		end
		
		if getmetatable(Child) == BaseComponentRef then
			local Operand = Child.Operand
			
			if Operand == "ExistingType" then
				continue
			elseif Operand == "Literal" then
				continue
			elseif Operand == "Union" then
				
				for FieldChild, Item in Child.UnionItems do
					
					if getmetatable(Item) == BaseComponentRef then
						if Item.Operand ~= "Union" then continue end
					end
					
					Recursive_Explore(Item, AllCompressedFields[FieldName], COUNT_TABLE)
				end
			
			end
			
		else
			Recursive_Explore(Child, AllCompressedFields[FieldName], COUNT_TABLE)
		end
	end
	
	
	return AllCompressedFields
end

local function GetCompressedPathArray(CompressedPathData, Array, PreviousIndex)
	Array = Array or {}
	
	for i,v in CompressedPathData do
		if PreviousIndex then
			i =  PreviousIndex .. "." .. i
		end
		
		if type(v) == 'table' then
			GetCompressedPathArray(v, Array, i)
		end
		
		table.insert(Array, i)
	end
	
	return Array
end

function BaseComponentRef:extend(ModuleScript, ComponentDescription)
	local NewComponentUtility = {}
	
	local PathStructure = Recursive_Explore(ComponentDescription)
	local CompressedPathsArray = GetCompressedPathArray(PathStructure)
	local CompressedPathsToBitmask = {}
	
	for i,v in CompressedPathsArray do
		CompressedPathsToBitmask[v] = 2^(i - 1)
	end
	
	NewComponentUtility.Path = PathStructure
			
		
	--local Module = require(ModuleScript)
	
	--Module.CompressedFieldsArray = {}
	--Module.CompressedFieldToBitMask = {}
	
	
	return NewComponentUtility
end

function BaseComponentRef:SetPath(Path: {string}, Value)
	local ChangeDetector = self.World.ChangeDetector
	local Component = self.World.ComponentDatabase[self.ComponentName][self.EntityID]
	
	local LastIndex;
	
	for i, Field in Path do
		if i == #Path then
			LastIndex = Field
			Component[Field] = Value
			break
		end
	end

	if ChangeDetector.ComponentTrackTable[self.ComponentName] then
		ChangeDetector:RawNotifyComponentChanged(self.ComponentName, self.EntityID)
	end
end

return BaseComponentRef