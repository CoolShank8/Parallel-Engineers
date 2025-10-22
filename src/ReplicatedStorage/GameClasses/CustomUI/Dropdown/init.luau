local RequestRemote = game.ReplicatedStorage.Remotes.RequestRemote

local TM = require(game.ReplicatedStorage.Packages.FirstParty.tweenModule)

type option = {
    Defould:boolean,
    Text:string,
    Index:number,
    Name:string,
    DisplayText:string,
    SelectedOptionText:string
}

export type options = {
    [number]:option
}

local dropdownTag = "Dropdown_Unv"

local DropDown = {}
DropDown.__index = DropDown

DropDown._OpenDropdowns = {}
DropDown._Info = {}::{
    [number]:{
        Object:any,
        IsOpen:boolean
    }    
}

function DropDown.new(config)
    local self = setmetatable(config, DropDown)

    self.Name = config.Name or "newDropdown"
    self._Instance = script.DropDownTemp
    self._ID = RequestRemote:InvokeServer("GetGuid", false)
    self.Title = config.Title or "Title not set"
    self.DropIcon = config.DropIcon or "rbxassetid://16167593004"
    self.DropIconRO = config.DropIconRO or Vector2.new(688, 0)
    self.DropIconRS = config.DropIconRS or Vector2.new(108,108)
    self.LayoutOrder = config.LayoutOrder or 1

    local function buildOptions(options:options):options
        local isDefouldSet = false
        local buildedOptions = {}
        for _, option in pairs(options) do
            local newOption = {}

            newOption.Defould = option.Defould
            if option.Defould then
                if isDefouldSet then
                    warn("Duplicated defould option spotted this might give unwanted behavior")
                    newOption.Defould = false
                else
                    isDefouldSet = true
                end
            end
            
            newOption.Text = option.Text or "option"
            newOption.Index = option.Index or 0
            newOption.Name = option.Name or "new-option"
            newOption.DisplayText = option.DisplayText or "option"
            newOption.SelectedOptionText = option.SelectedOptionText or "new-option"

            table.insert(buildedOptions, newOption)
        end

        return buildedOptions
    end

    self.Options = buildOptions(config.Options)

    self.TweeningEnabled = if self.TweeningEnabled ~= nil then self.TweeningEnabled else false

    --warn(self)

    if self.TweenInfo == nil then
         self.TweenInfo = {}
    end

    if self.TweenInfo.In == nil then
         self.TweenInfo.In = {}
    end

    self.TweenInfo.In.EasingStyle = config.TweenInfo.In.EasingStyle or Enum.EasingStyle.Linear
    self.TweenInfo.In.EasingDirection = config.TweenInfo.In.EasingDirection or Enum.EasingDirection.Out
    self.TweenInfo.In.Duration = config.TweenInfo.In.Duration or 1
    self.TweenInfo.In.TargetSize = UDim2.new(0,0,0,0) -- should be changed uppon mounting to actual size

    if self.TweenInfo.Out == nil then
         self.TweenInfo.Out = {}
    end

    self.TweenInfo.Out.EasingStyle = config.TweenInfo.Out.EasingStyle or Enum.EasingStyle.Linear
    self.TweenInfo.Out.EasingDirection = config.TweenInfo.Out.EasingDirection or Enum.EasingDirection.Out
    self.TweenInfo.Out.Duration = config.TweenInfo.Out.Duration or 1
    self.TweenInfo.Out.TargetSize = UDim2.new(1,0,0,0)

    if self.TweenInfo.DropIcon == nil then
         self.TweenInfo.DropIcon = {}
    end

    self.TweenInfo.DropIcon.EasingStyle = config.TweenInfo.Out.EasingStyle or Enum.EasingStyle.Linear
    self.TweenInfo.DropIcon.EasingDirection = config.TweenInfo.DropIcon.EasingDirection or Enum.EasingDirection.Out
    self.TweenInfo.DropIcon.Duration = config.TweenInfo.DropIcon.Duration or 1

    --warn(self, config)

    return self
end



function DropDown.CloseAll(id)
    local instance = nil
    for _, dropDown in pairs(game:GetDescendants()) do
        if dropDown:IsA("GuiObject") and dropDown:HasTag(dropdownTag) then
            local info = DropDown._Info[dropDown:GetAttribute("ID")]

            local conf = info.Object
            if info.IsOpen then
                --TODO: here it should close the curent instance dropdown
                if conf.TweeningEnabled then
                 local tween = TM.V2.tweenSize(conf.TweenInfo.Out.TargetSize, {conf.TweenInfo.Out.EasingStyle, conf.TweenInfo.Out.EasingDirection}, {conf.TweenInfo.In.Duration}, {}, {true},  dropDown.DropDown.Options)
                 TM.V2.tweenRotation(0, {conf.TweenInfo.Out.EasingStyle, conf.TweenInfo.Out.EasingDirection}, {conf.TweenInfo.Out.Duration}, {}, {false}, dropDown.DropDown.Top.Content.DropIcon.dropd)
                tween:Play()
                tween.Completed:Wait()
                dropDown.DropDown.Options.Visible = false
                else
                 dropDown.DropDown.Options.Visible = false
                 dropDown.DropDown.Top.Content.DropIcon.dropd.Rotation = 0
                end
                
                info.IsOpen = false

                --dropDown.DropDown.Top.Content.DropIcon.dropd.Rotation = 0
            end

            if dropDown:GetAttribute("ID") == id then
                instance = dropDown
            end

        end
    end

    return instance
end

function DropDown:Toggle()
    local thisDropDownInfo = DropDown._Info[self._ID]

    if thisDropDownInfo.IsOpen then
        DropDown.CloseAll(self._ID)
        else
           local curInstance = DropDown.CloseAll(self._ID)

           curInstance.DropDown.Options.Visible = true
           thisDropDownInfo.IsOpen = true

           if self.TweeningEnabled then
            TM.V2.tweenSize(self.TweenInfo.In.TargetSize, {self.TweenInfo.In.EasingStyle, self.TweenInfo.In.EasingDirection}, {self.TweenInfo.In.Duration}, {}, {false},  curInstance.DropDown.Options)
            TM.V2.tweenRotation(180, {self.TweenInfo.In.EasingStyle, self.TweenInfo.In.EasingDirection}, {self.TweenInfo.In.Duration}, {}, {false}, curInstance.DropDown.Top.Content.DropIcon.dropd)
           else
            curInstance.DropDown.Top.Content.DropIcon.dropd.Rotation = 180

        end

           

    end
end

function DropDown:ChangeValue(selectedOption)
   -- local thisDropDownInfo = DropDown._Info[self._ID]

    local curInstance = DropDown.CloseAll(self._ID)

    local display = curInstance.DropDown.Top.Content.Display

    display.Text = selectedOption:GetAttribute("DisplayName")
    curInstance:SetAttribute("SelectedOption",  selectedOption:GetAttribute("SelectedText"))
end

function DropDown:Mounth(parent)
    local newUI:GuiObject = self._Instance:Clone() ::typeof(script.DropDownTemp)
    newUI.Name = self.Name

    newUI.Title.Text = self.Title
    local dropIcon = newUI.DropDown.Top.Content.DropIcon.dropd
    dropIcon.Image = self.DropIcon
    dropIcon.ImageRectOffset = self.DropIconRO
    dropIcon.ImageRectSize = self.DropIconRS

    newUI.LayoutOrder = self.LayoutOrder

    local optionsMain = newUI.DropDown.Options

    local function buildOptions(options:options)
        local optionParent:GuiObject = optionsMain.Options
        for _, newOption in pairs(options) do
            local newOptionUI:TextButton = optionParent:FindFirstChildWhichIsA("TextButton"):Clone()
            newOptionUI.Name = newOption.Name
            newOptionUI.Text = newOption.Text

            newOptionUI:SetAttribute("DisplayName", newOption.DisplayText)
            newOptionUI:SetAttribute("SelectedText", newOption.SelectedOptionText)

            if newOption.Defould then
                newUI.DropDown.Top.Content.Display.Text = newOption.DisplayText
                newUI:SetAttribute("SelectedOption", newOption.SelectedOptionText)
            end

            newUI:AddTag(dropdownTag)
            newUI:SetAttribute("ID", self._ID)

            newOptionUI.Visible = true

            newOptionUI.Parent = optionParent

            newOptionUI.MouseButton1Click:Connect(function(...: any)  
                self:ChangeValue(newOptionUI)
            end)

        end
    end

    buildOptions(self.Options)

    self.TweenInfo.In.TargetSize = optionsMain.Size

    if self.TweeningEnabled then
        optionsMain.Size = self.TweenInfo.Out.TargetSize
    end
    

    if DropDown._Info[self._ID] then
        warn("Failed to mounth Dropdown, such dropdown with the same config already exist")
    else
        newUI.Parent = parent
        DropDown._Info[self._ID] = {}
        local info = DropDown._Info[self._ID]
        info.Object = self
        info.IsOpen = false
    end

    newUI.DropDown.Top.Content.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
end

return DropDown