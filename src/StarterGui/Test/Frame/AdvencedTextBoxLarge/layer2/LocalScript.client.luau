local ColorPickerClass = require(game.ReplicatedStorage.GameClasses.CustomUI.ColorPicker)

local newColorPicker = ColorPickerClass.new({
    Name = "newPicker",
    UseDefouldColors = false,
    CustomPalate = {
        Config = {}, -- is this needed?
        Values = {
            Color3.new(0,0,0),
            Color3.fromHex("#06c46f")
        }
    },
    ColorCodesEnabled = true
})

newColorPicker:Mounth(script.Parent)