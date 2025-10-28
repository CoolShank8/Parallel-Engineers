local ColorPickerClass = require(game.ReplicatedStorage.GameClasses.CustomUI.ColorPicker)

local newColorPicker = ColorPickerClass.new({
    Name = "newPicker",
    UseDefouldColors = false,
    CustomPalate = {
        Config = {}, -- is this needed?
        Values = {
            Color3.new(0,0,0),
            Color3.fromHex("#06c46f"),
            Color3.fromRGB(123,123,123)
        }
    },
    ColorCodesEnabled = true,
    SavingEnabled = true -- will save colors so soon as the feature is enabled automaticaly wothout doing anything
})

newColorPicker:Mounth(script.Parent)

script.Parent.FontOptions.TextColor.ColorPickerOpen.MouseButton1Click:Connect(function()
    newColorPicker:Open()
end)
