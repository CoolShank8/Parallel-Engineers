--!strict

local module = {}

print(script.Parent.Parent.StarterGui.FeedbackPanelUI.UITemplate.TextBoxInput.Send)

local element = script.Parent.Parent.StarterGui.FeedbackPanelUI.newUIModel.Whee1


element.Position = Vector3.new(1,2,3) + Vector3.new(4,5,6)


type function wow(x)
    return types.singleton('wow')
end



type cool = wow<string>;

local x: cool = 'wow'
x = x 


return module
