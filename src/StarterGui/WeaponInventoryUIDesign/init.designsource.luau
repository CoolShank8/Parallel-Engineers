local UI = script.Parent
local TextureSheet = extract("TextureSheet.psd")

return {
    publish_images = true,
    
    [UI.UIFrame.BG] = {
        Image = TextureSheet.layer("UI/BG").upload(634, 761)
    },

    [UI.UIFrame.WeaponPanel] = {
        Image = TextureSheet.layer("UI/GunSelectionPanel").upload(1000, 1000)
    },

    [UI.UIFrame.WeaponPanel.Slot1] = {
        Image = TextureSheet.layer("UI/PanelSlots/Slot1")
    }
}