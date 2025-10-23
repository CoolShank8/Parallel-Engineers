local RequestRemote = game.ReplicatedStorage.Remotes.RequestRemote

local TM = require(game.ReplicatedStorage.Packages.FirstParty.tweenModule)

local ButtonClass;

local ColorPickerTag = "ColorPicker_Unv"

type Object = Frame & {
    AllColors: GuiObject & {
        Scroller: GuiObject & {
            ColorTemp: ImageButton,
        },
    },
    SaveOrUseChoose: GuiObject & {
        SaveNew: Frame,
        Use: Frame,
    },
    SavedColors: GuiObject & {
        Colors: GuiObject & {
            ["1"]: ImageButton,
            ["2"]: ImageButton,
            ["3"]: ImageButton,
            ["4"]: ImageButton,
            ["5"]: ImageButton,
            ["6"]: ImageButton,
            ["7"]: ImageButton,
            ["8"]: ImageButton,
            ["9"]: ImageButton,
            ["10"]: ImageButton,
        },
        Disabled: GuiObject & {
            msg: TextLabel,
        },
    },
    Title: TextLabel,
    TotalSaved: TextLabel,
    saveEtc: GuiObject & {
        ButtonMount: Frame,
        Color: GuiObject & {
            Colors: GuiObject & {
                New: Frame,
                Old: Frame,
            },
            colorTitle: TextLabel,
        },
        ColorCode: GuiObject & {
            Code: GuiObject & {
                Hex: GuiObject & {
                    HashTag: TextLabel,
                    TextBox: TextBox,
                },
                SizeToggle: TextButton,
            },
            Disabled: GuiObject & {
                msg: TextLabel,
            },
        },
    },
    savedTitle: TextLabel,
}

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
	self._Instance = script.ColorPickerTemp
	self._ID = RequestRemote:InvokeServer("GetGuid", false)
	self.UseDefouldColors = if self.UseDefouldColors ~= nil then self.UseDefouldColors else true
	

	return self
end





function ColorPicker:Mounth(parent)
	local newUI = self._Instance:Clone() ::typeof(script.ColorPickerTemp)
	newUI.Name = self.Name

	local newUITyped:Object = newUI

	local ColorPalatePresetColors = newUITyped.AllColors.Scroller

	if self.UseDefouldColors then
		--TODO: should get all brick colors here to generate an palate
	end

	newUI.Parent = parent

end

return ColorPicker