local ColorPickerClass = require(game.ReplicatedStorage.GameClasses.CustomUI.ColorPicker)

local newColorPicker = ColorPickerClass.new({
    Name = "newPicker",
    UseDefouldColors = true
})

newColorPicker:Mounth(script.Parent)