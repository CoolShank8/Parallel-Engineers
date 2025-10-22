local DropDownClass = require(game.ReplicatedStorage.GameClasses.CustomUI.Dropdown)

local scroller = script.Parent.Parent.Frame.ScrollingFrame
local toggler:GuiButton = script.Parent.Parent.TextButton
local main:GuiObject = scroller.parent

toggler.MouseButton1Click:Connect(function(...: any)  
    main.Visible = not main.Visible
end)

local newDropdown1 = DropDownClass.new({
    Name = "Random_Dropdown",
    Title = "Random DropDown",
    Options = {
        [1] = {
            Name = "hi-drop",
            Defould = true,
            Text = "hi",
            Index = 1,
            DisplayText = "hi is selected",
            SelectedOptionText = "hi-sel"
        },
        [2] = {
            Name = "yo-drop",
            Defould = false,
            Text = "yo",
            Index = 3,
            DisplayText = "yo is selected",
            SelectedOptionText = "yo-sel"
        },
         [3] = {
            Name = "bye-drop",
            Defould = false,
            Text = "bye",
            Index = 2,
            DisplayText = "bye is selected",
            SelectedOptionText = "bye-sel"
        }
    },
    TweeningEnabled = true,
    TweenInfo = {
        In = {
            EasingStyle = Enum.EasingStyle.Sine,
            EasingDirection = Enum.EasingDirection.InOut,
            Duration = 0.5
        },
        Out = {
            EasingStyle = Enum.EasingStyle.Sine,
            EasingDirection = Enum.EasingDirection.Out,
            Duration = 0.5
        },
        DropIcon = {
            EasingStyle = Enum.EasingStyle.Bounce,
            EasingDirection = Enum.EasingDirection.In,
            Duration = 0.5
        }
    }
})

newDropdown1:Mounth(scroller)

local newDropdown2 = DropDownClass.new({
    Name = "Another_Dropdown",
    Title = "another DropDown",
    LayoutOrder = -2,
    Options = {
        [1] = {
            Name = "hi-drop",
            Defould = false,
            Text = "hi",
            Index = 1,
            DisplayText = "hi is selected",
            SelectedOptionText = "hi-sel"
        },
        [2] = {
            Name = "yo-drop",
            Defould = true,
            Text = "yo",
            Index = 2,
            DisplayText = "yo is selected",
            SelectedOptionText = "yo-sel"
        },
         [3] = {
            Name = "bye-drop",
            Defould = false,
            Text = "bye",
            Index = 3,
            DisplayText = "bye is selected",
            SelectedOptionText = "bye-sel"
        }
    },
    TweeningEnabled = true,
    TweenInfo = {
        In = {
            EasingStyle = Enum.EasingStyle.Bounce,
            EasingDirection = Enum.EasingDirection.InOut,
            Duration = 0.5
        },
        Out = {
            EasingStyle = Enum.EasingStyle.Back,
            EasingDirection = Enum.EasingDirection.In,
            Duration = 0.5
        },
        DropIcon = {
            EasingStyle = Enum.EasingStyle.Bounce,
            EasingDirection = Enum.EasingDirection.In,
            Duration = 30
        }
    }
})

newDropdown2:Mounth(scroller)