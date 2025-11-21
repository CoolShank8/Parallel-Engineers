local UI = script.Parent
local TextureSheet = extract("TextureSheet.psd")

return {
    [UI.PromptFrame.PromptImage] = {
        Image = TextureSheet.layer("BG").upload(1000, 1000)
    },

    [UI.PromptFrame.Title] = {
        Image = TextureSheet.layer("GunSelectionPanel").upload(1000, 1000)
    }
}