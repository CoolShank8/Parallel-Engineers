local DropDown = {}
DropDown.__index = DropDown

function DropDown.new(config)
    local self = setmetatable(config, DropDown)

    self.Name = config.Name
    self._Instance = script.Dropdown
    self._ID = config.GUID
    self
end

function DropDown:mounth(parent)
    local newUI = self._Instance:Clone()
    newUI.Name = self.Name
end
