-- this be used for buttons there will be two diferent buttons an nav button what will be used to navigate between menus while closing all desedants of an frame and opens teh target frmae with tweens
-- and the function button what we make working for now cuz we need tp use that for the color picker so we can complete the text editor class

local RequestRemote = game.ReplicatedStorage.Remotes.RequestRemote

local TM = require(game.ReplicatedStorage.Packages.FirstParty.tweenModule)

local ColorPickerTag = "Button_Unv"

local VSTypes = require(game.ReplicatedStorage.Modules.TypesForVSCode)

type TextButton = VSTypes.CustomUI_TextButton

local Button = {}
Button.__index = Button

Button._Info = {}::{
	[number]:{
		Object:any
	}    
}

function Button.new(config)
	local self = setmetatable(config, Button)

	self.Name = config.Name or "newButton" -- instance name
    self.Type = config.Type or "ImageTextButton" -- the button type
	self.Instance = nil -- instance after cloning
	self._Instance = script:FindFirstChild(self.Type.."Temp") -- template
	self._ID = RequestRemote:InvokeServer("GetGuid", false) -- uniqeu track id

    self.Enabled = if config.Enabled ~= nil then config.Enabled else true -- wheter teh button is enabled and can handle stuff when clicked
    self.ErrorEnabeld = if config.ErrorEnabeld ~= nil then config.ErrorEnabeld else true -- wheter to show an error masage when button is disabled given an disabled reason
    self.DisabledReason = config.DisabledReason or "this button is not enabled not what you expected? if your a dev pls resheck if the butto is configured corectly"

    self.ButtonType = config.ButtonType or "Action" -- "Action" | "Nav"

    self.ButtonText = config.ButtonText or "Button"

    self.ButtonImage = config.ButtonImage or ""
    self.ButtonImagePressed = config.ButtonImagePressed or ""
    self.ButtonImageHover = config.ButtonImageHover or ""

    self.Action = config.Action or function() warn("no action provided make sure to disable this button or add an function") end

	return self
end 

return Button
