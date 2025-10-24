local RequestRemote = game.ReplicatedStorage.Remotes.RequestRemote

local TM = require(game.ReplicatedStorage.Packages.FirstParty.tweenModule)

local ButtonClass;

local ColorPickerTag = "ColorPicker_Unv"

local VSTypes = require(game.ReplicatedStorage.Modules.TypesForVSCode)

type Object = VSTypes.CustomUI_ColorPicker

local ColorPicker = {}
ColorPicker.__index = ColorPicker

ColorPicker._Info = {}::{
	[number]:{
		Object:any
	}    
}

function ColorPicker.new(config)
	local self = setmetatable(config, ColorPicker)

	self.Name = config.Name or "newColorPicker"
	self.Instance = nil
	self._Instance = script.ColorPickerTemp
	self._ID = RequestRemote:InvokeServer("GetGuid", false)
	self.UseDefouldColors = if self.UseDefouldColors ~= nil then self.UseDefouldColors else true
	
	local isCustomPalateEnabledCorectly = if config.CustomPalate ~= nil and config.CustomPalate.Values ~= nil and config.CustomPalate.Config ~= nil then true else false
	
	self.CustomPalate = {
		_Enabled = isCustomPalateEnabledCorectly,
		Config = {
			--ColorFormat = if isCustomPalateEnabledCorectly then self.CustomPalate.Config.ColorFormat or "Defould" else "Defould"
		},
		Values = if isCustomPalateEnabledCorectly then config.CustomPalate.Values or {} else {}
	}

	self.ColorCodesEnabled = if config.ColorCodesEnabled ~= nil then config.ColorCodesEnabled else true -- if this is enabled and saving is also enabled loop trough the saved valeus totag it as disabled color if not matching the palate provided
	self.SavingEnabled = if config.SavingEnabled ~= nil then config.SavingEnabled else true
	self.DefouldColor = config.DefouldColor or Color3.new(0,0,0)
	self.DefouldChangeColor = config.DefouldChangeColor or Color3.new(0,0,0)

	return self
end





function ColorPicker:Mounth(parent)
	local newUI = self._Instance:Clone() ::typeof(script.ColorPickerTemp)
	newUI.Name = self.Name

	local newUITyped:Object = newUI

	local ColorPalatePresetColors = newUITyped.AllColors.Scroller

	local function changeColorClickListener(button:GuiButton)
		button.MouseButton1Click:Connect(function(...: any)  
			self:ChangeColor(button.BackgroundColor3)
		end)
	end

	if self.UseDefouldColors then
		--TODO: should get all brick colors here to generate an palate

		for i = 1, 127 do
			local color = BrickColor.palette(i)
			warn(color)

			local newColor = ColorPalatePresetColors.ColorTemp:Clone()
			newColor.BackgroundColor3 = color.Color
			newColor.Visible = true
			newColor.Parent = ColorPalatePresetColors

			changeColorClickListener(newColor)
		end
	else
		if self.CustomPalate._Enabled then
			--TODO: use custom palate
			for _, value in pairs(self.CustomPalate.Values) do
				local newColor = ColorPalatePresetColors.ColorTemp:Clone()
				newColor.BackgroundColor3 = value
				newColor.Visible = true
				newColor.Parent = ColorPalatePresetColors

				changeColorClickListener(newColor)
			end
		else
			ColorPalatePresetColors.Visible = false
			newUITyped.AllColors.ErrorFrame.Visible = true
		end
	end

	
	newUITyped.saveEtc.ColorCode.Code.Visible = self.ColorCodesEnabled
	newUITyped.saveEtc.ColorCode.Disabled.Visible = not self.ColorCodesEnabled

	-- change listeners for color code boxes to chage color
	local hexBox = newUITyped.saveEtc.ColorCode.Code.Hex.TextBox
	hexBox.FocusLost:Connect(function(didUserPressEnter: boolean, lostInputObj: InputObject)  
		
		local stringWithoutHashTag = hexBox:Split("#")

		hexBox.Text = stringWithoutHashTag[1]

		--TODO: chesk amounth chars if all numbers if all numbers apply above else warn error and clear textbox and also not cahnge the color
	end)

	---

	newUITyped.saveEtc.Color.Colors.New.BackgroundColor3 = self.DefouldChangeColor
	newUITyped.saveEtc.Color.Colors.Old.BackgroundColor3 = self.DefouldColor

	newUITyped:SetAttribute("ChangingColor", self.DefouldChangeColor)
	newUITyped:SetAttribute("Color", self.DefouldColor)


	if ColorPicker._Info[self._ID] then
        warn("Failed to mounth ColorPicker, such ColorPicker with the same config already exist")
    else
        newUI.Parent = parent
		self.Instance = newUI
        ColorPicker._Info[self._ID] = {}
        local info = ColorPicker._Info[self._ID]
        info.Object = self
    end

end

function ColorPicker:ChangeColor(newColor) -- doesnt save the color yet just shows it visual
	local colorPicker:Object = self.Instance

	if colorPicker then
		colorPicker.saveEtc.Color.Colors.New.BackgroundColor3 = newColor

		colorPicker:SetAttribute("ChangingColor", newColor)
	else
		warn("Color picker custom Instance not found skipping!")
	end
end

return ColorPicker