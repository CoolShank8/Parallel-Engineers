local ChangeDetector = {}
ChangeDetector.ComponentChanged = {}

--[[
| Path                     | Bitmask (binary) | Bits Set   |
| ------------------------ | ---------------- | ---------- |
| `Stats`                  | 0000 0001        | 0          |
| `Stats.Coins`            | 0000 0011        | 0, 1       |
| `Stats.Coins.Current`    | 0000 0111        | 0, 1, 2    |
| `Stats.Coins.Max`        | 0000 1011        | 0, 1, 3    |
| `Stats.Diamonds`         | 0001 0001        | 0, 4       |
| `Stats.Diamonds.Current` | 0011 0001        | 0, 4, 5    |
| `Stats.Diamonds.Max`     | 0101 0001        | 0, 4, 6    |
| `Stats.Diamonds.Max.Why` | 1101 0001        | 0, 4, 6, 7 |

]]

local ChangeDetector = {}

function ChangeDetector.new(World)
	local self = {}
	self.ComponentChanged = {}
	
	setmetatable(self, ChangeDetector)
	return self
end


function ChangeDetector:RawNotifyComponentChanged(ComponentName, EntitiyID)
	self.ComponentChanged[ComponentName][EntitiyID] = true
end

function ChangeDetector:GetComponentAddedQue(ComponentName)
	local Que = {}
	
	return Que
end

function ChangeDetector:GetComponentChangedQue(ComponentName)
	local Que = {}
	
	
	
	return Que
end

function ChangeDetector:OnComponentChanged(ComponentName, EntityID: string?) -- if entity ID only for that specfic entity

end

function ChangeDetector:GetComponentFieldChangedQue(Entity, ComponentName, FieldName)

end

function ChangeDetector:OnComponentFieldChange(Entity, ComponentName, FieldName)
	
end




return ChangeDetector