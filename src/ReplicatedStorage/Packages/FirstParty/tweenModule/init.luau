--[[
tween module to use one line of code like tweensize and tweenposition but with tweenservice
]]

type TweenSize = UDim2 | Vector2 | Vector3

type TweenPosition = UDim2 | Vector3


type EasingOptions = Enum.EasingStyle? | Enum.EasingDirection?

type NumberOptions = number? | number? | number?

type BoolOptions = boolean?

type Settings = boolean


local TS = game:GetService("TweenService")

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local SOURCE_LOCALE = "en"
local translator = nil

local module = {
	V1 = {
		--[[v1 makes use of strings for enums use v2 for enum version as that write more easily
		
		--]]
		tweenSize = function(Size, EasingStyle, EasingDirection, duration, repeatCount, reverses, delayTime, instance)

			local tweeninfo = TweenInfo.new(duration,Enum.EasingStyle[EasingStyle], Enum.EasingDirection[EasingDirection], repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {Size = Size})

			tween:Play()
		end,

		tweenPosition = function(Position, EasingStyle, EasingDirection, duration, repeatCount, reverses, delayTime, instance)

			local tweeninfo = TweenInfo.new(duration,Enum.EasingStyle[EasingStyle], Enum.EasingDirection[EasingDirection], repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {Position = Position})

			tween:Play()
		end,

		tweenRotation = function(rotation, EasingStyle, EasingDirection, duration, repeatCount, reverses, delayTime, instance)


			local tweeninfo = TweenInfo.new(duration,Enum.EasingStyle[EasingStyle], Enum.EasingDirection[EasingDirection], repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {Rotation = rotation})

			tween:Play()
		end, 

		tweenCFrame = function (CFrame, EasingStyle, EasingDirection, duration, repeatCount, reverses, delayTime, instance)
			local tweeninfo = TweenInfo.new(duration,Enum.EasingStyle[EasingStyle], Enum.EasingDirection[EasingDirection], repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {CFrame = CFrame})

			tween:Play()
		end,

	},

	--[[
		
		v2 makes use of enums instead of strings
		
		updates
		
		* removed strings for enums suport enums now
		
		--]]
	V2 = {
		
		customTween = function(Properties, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, Properties)

			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,


			--[==[
			Example:
			<code>
			<strong>tweenSize</strong>(
			   UDim2.new(1, 0, 1, 0), <em> -- Size </em>
			   {Enum.EasingStyle.Quad, Enum.EasingDirection.InOut}, <em> -- EasingOptions </em>
			   {2, 0, 0.5}, <em> -- duration, repeatCount, delayTime </em>
			   {true}, <em> -- reverses </em>
			   {false}, <em> -- UseOnce </em>
			   instance <em> -- Instance </em>
			)
			</code>
			Example skipping optional valeus:
			<code>
			<strong>tweenSize</strong>(
			   UDim2.new(1, 0, 1, 0), <em> -- Size </em>
			   {nil, Enum.EasingDirection.InOut}, <em> -- EasingOptions </em>
			   {2, nil, 0.5}, <em> -- duration, repeatCount, delayTime </em>
			   {true}, <em> -- reverses </em>
			   {false}, <em> -- UseOnce </em>
			   instance <em> -- Instance </em>
			)
			</code>
			tweensize can be used to size things think about
		
			parts grow parts (with scale) use propertie vector3
		
			UIs grow uis like an process bar use properties udim2
		
			Gradients or rect sizes use propertie vector2
			
			--------------------------------------------------------------
			only <em>Reqeured</em> arguments are needed if you dont use <em>Optional</em> arguments the <em>Defould,s</em> will be used
			
			Arguments:
			<strong>Position</strong><em>(Reqeured)</em> - this the position to tween
			<strong>EasingOptions:</strong><em>(Reqeured)</em>
			this are the EasingOptions
			   <strong>EasingStyle</strong><em>(Optional)</em> - These enum values are passed to control the motion of a Tween*
		           Linear(Defould): Moves at a constant speed.*
		           Sine: Speed is determined by a sine wave for a gentle easing motion.*
		           Back: Slightly overshoots the target, then backs into place.*
		           Quad: Similar to Sine but with a slightly sharper curve based on quadratic interpolation.*
		           Quart: Similar to Cubic but with an even sharper curve based on quartic interpolation.*
		           Quint: Similar to Quart but with an even sharper curve based on quintic interpolation.*
		           Bounce: Bounces backwards multiple times after reaching the target, before eventually settling.*
		           Elastic: Moves as if attached to a rubber band, overshooting the target several times.*
		           Exponential: The sharpest curve based on exponential interpolation.*
		           Circular: Follows a circular arc, such that acceleration is more sudden and deceleration more gradual versus Quint or Exponential.*
		           Cubic: Similar to Quad but with a slightly sharper curve based on cubic interpolation.*
					
			   <strong>EasingDirection</strong><em>(Optional)</em> - These enum values are passed to control the direction*
		            In(Defould): The easing style is applied in a forward direction.*
		            Out: The easing style is applied in a reverse direction.*
		            InOut: The easing style is applied forward for the first half and in reverse for the second half.*
					
			<strong>NumberOptions</strong><em>(Reqeured)</em>:
			this are the number options
			   <strong>duration</strong><em>(Optional)</em> - Duration of the tween, in seconds.*
			      Defould = 1
			   <strong>repeatCount</strong><em>(optional)</em> - Number of times the tween repeats. -1 indicates indefinite repetition.*
			         The correct way to make a tween play indefinitely is to set RepeatCount to -1. 
			         You should avoid using large numbers or math.huge() 
			         as a substitute as this is unstable and may stop working at any point.*
					
			      Defould = 0
			
			   <strong>delayTime</strong><em>(Optional)</em> - Time of delay until the tween begins, in seconds.*
			      Defould = 0
			
			<strong>BoolOptions:</strong><em>(reqeured)</em>
			this are the boolean options
			   <strong>reverses</strong><em>(Optional)</em> - Whether or not the tween interpolates in reverse tween once the initial tween completes.*
			      Defoult = false
					
			<strong>Settings</strong><em>(Reqeured)</em>:
			this are the settings for the tween 
			whatever you use it once ore use it repetively
			
			   <strong>UseOnce</strong><em>(Reqeured)</em> - if false it returns the tween so
				
				<code>
				local tween = -- call the module
				tween:Play()
				</code>
				
				when its treu it inmiditly plays the tween so
				
				<code>
				-- call the module
				</code>
				
			<strong>instance</strong><em>(Reqeured)</em>:
			this the instance to tween
			
			good luck creating your tweens with the module that makes it esier
			- <em>foodeggs7</em>
			
			<em><strong>*</strong> comming from roblox documentation</em
			
			---------------------------------------------
			<strong>Created:</strong> 19-04-2025
			<strong>Updated:</strong> 22-04-2025
			<strong>Function Version:</strong> 1.0.0
			<strong>Description version:</strong> 1.1.0
			]==]
		tweenSize = function(Size:TweenSize, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {Size = Size})

			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,

			--[==[

			Example:
			<code>
			<strong>tweenPosition</strong>(
			   UDim2.new(0.5, 0, 1, 0), <em> -- Size </em>
		       {Enum.EasingStyle.Quad, Enum.EasingDirection.InOut}, <em> -- EasingOptions </em>
			   {2, -1, 0.5}, <em> -- duration, repeatCount, delayTime </em>
			   {true}, <em> -- reverses </em>
			   {true}, <em> -- UseOnce </em>
			   instance <em> -- Instance </em>
			)
			</code>
			
			Example skipping optional valeus:
			<code>
			<strong>tweenPosition</strong>(
			   UDim2.new(1, 0, 1, 0), <em> -- Size </em>
		       {nil, Enum.EasingDirection.InOut}, <em> -- EasingOptions </em>
			   {2, nil, 0.5}, <em> -- duration, repeatCount, delayTime </em>
			   {false}, <em> -- reverses </em>
			   {false}, <em> -- UseOnce </em>
			   instance <em> -- Instance </em>
			)
			</code>

			tweenposition can be used to position things think about
		
			parts move parts use propertie vector3
		
			UIs move uis like an frame use properties udim2
			
			--------------------------------------------------------------
			only <em>Reqeured</em> arguments are needed if you dont use <em>Optional</em> arguments the <em>Defould,s</em> will be used
			
			Arguments:
			<strong>Position</strong><em>(Reqeured)</em> - this the position to tween
			<strong>EasingOptions:</strong><em>(Reqeured)</em>
			this are the EasingOptions
			   <strong>EasingStyle</strong><em>(Optional)</em> - These enum values are passed to control the motion of a Tween*
		           Linear(Defould): Moves at a constant speed.*
		           Sine: Speed is determined by a sine wave for a gentle easing motion.*
		           Back: Slightly overshoots the target, then backs into place.*
		           Quad: Similar to Sine but with a slightly sharper curve based on quadratic interpolation.*
		           Quart: Similar to Cubic but with an even sharper curve based on quartic interpolation.*
		           Quint: Similar to Quart but with an even sharper curve based on quintic interpolation.*
		           Bounce: Bounces backwards multiple times after reaching the target, before eventually settling.*
		           Elastic: Moves as if attached to a rubber band, overshooting the target several times.*
		           Exponential: The sharpest curve based on exponential interpolation.*
		           Circular: Follows a circular arc, such that acceleration is more sudden and deceleration more gradual versus Quint or Exponential.*
		           Cubic: Similar to Quad but with a slightly sharper curve based on cubic interpolation.*
					
			   <strong>EasingDirection</strong><em>(Optional)</em> - These enum values are passed to control the direction*
		            In(Defould): The easing style is applied in a forward direction.*
		            Out: The easing style is applied in a reverse direction.*
		            InOut: The easing style is applied forward for the first half and in reverse for the second half.*
					
			<strong>NumberOptions</strong><em>(Reqeured)</em>:
			this are the number options
			   <strong>duration</strong><em>(Optional)</em> - Duration of the tween, in seconds.*
			      Defould = 1
			   <strong>repeatCount</strong><em>(optional)</em> - Number of times the tween repeats. -1 indicates indefinite repetition.*
			         The correct way to make a tween play indefinitely is to set RepeatCount to -1. 
			         You should avoid using large numbers or math.huge() 
			         as a substitute as this is unstable and may stop working at any point.*
					
			      Defould = 0
			
			   <strong>delayTime</strong><em>(Optional)</em> - Time of delay until the tween begins, in seconds.*
			      Defould = 0
			
			<strong>BoolOptions:</strong><em>(reqeured)</em>
			this are the boolean options
			   <strong>reverses</strong><em>(Optional)</em> - Whether or not the tween interpolates in reverse tween once the initial tween completes.*
			      Defoult = false
					
			<strong>Settings</strong><em>(Reqeured)</em>:
			this are the settings for the tween 
			whatever you use it once ore use it repetively
			
			   <strong>UseOnce</strong><em>(Reqeured)</em> - if false it returns the tween so
				
				<code>
				local tween = -- call the module
				tween:Play()
				</code>
				
				when its treu it inmiditly plays the tween so
				
				<code>
				-- call the module
				</code>
				
			<strong>instance</strong><em>(Reqeured)</em>:
			this the instance to tween
			
			good luck creating your tweens with the module that makes it esier
			- <em>foodeggs7</em>
			
			<em><strong>*</strong> comming from roblox documentation</em
			
			---------------------------------------------
			<strong>Created:</strong> 19-04-2025
			<strong>Updated:</strong> 22-04-2025
			<strong>Function Version:</strong> 1.0.0
			<strong>Description version:</strong> 1.1.0
			]==]
		tweenPosition = function(Position:TweenPosition, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {Position = Position})
			--			warn(tween)
			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,

		--tweenRotation = function(rotation, EasingStyle, EasingDirection, duration, repeatCount, reverses, delayTime, instance)


		--	local tweeninfo = TweenInfo.new(duration,Enum.EasingStyle[EasingStyle], Enum.EasingDirection[EasingDirection], repeatCount, reverses, delayTime)

		--	local tween = TS:Create(instance, tweeninfo, {Rotation = rotation})

		--	tween:Play()
		--end, 

		tweenRotation = function(rotation:number, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {Rotation = rotation})
			--warn(tween)
			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,
		
		tweenColor = function(Propertie, Color:number, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {[Propertie] = Color})
			--warn(tween)
			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,

		--tweenCFrame = function (CFrame, EasingStyle, EasingDirection, duration, repeatCount, reverses, delayTime, instance)
		--	local tweeninfo = TweenInfo.new(duration,Enum.EasingStyle[EasingStyle], Enum.EasingDirection[EasingDirection], repeatCount, reverses, delayTime)

		--	local tween = TS:Create(instance, tweeninfo, {CFrame = CFrame})

		--	tween:Play()
		--end,

		tweenCFrame = function(CFrame:CFrame, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {CFrame = CFrame})
			--warn(tween)
			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,
		
		tweenRotationAngle = function(XYZ, RotationSpeed, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance)
			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

		
			local angleValue = Instance.new("NumberValue")
			angleValue.Value = 0

			local tweenInfo = TweenInfo.new(
				duration,
				EasingStyle,
				EasingDirection,
				repeatCount,
				reverses,
				delayTime
			)
			
			local tween = TS:Create(angleValue, tweenInfo, {Value = 360 * RotationSpeed})
			
			

			local initialCFrame = instance.CFrame

		
			local conn
			conn = angleValue.Changed:Connect(function()
				if XYZ == "X" then
					instance.CFrame = initialCFrame * CFrame.Angles(math.rad(angleValue.Value), 0, 0)
				elseif XYZ == "Y" then
					instance.CFrame = initialCFrame * CFrame.Angles(0, math.rad(angleValue.Value), 0)
				elseif XYZ == "Z" then
					instance.CFrame = initialCFrame * CFrame.Angles(0, 0, math.rad(angleValue.Value))
				else
					warn("No valid axis axis needs to be X, Y or Z | ", script)
				end
				
			end)

			if UseOnce then
				return tween, angleValue
			else
				task.spawn(function()
					tween:Play()
					tween.Completed:Wait()
					angleValue:Destroy()
				end)
			end
		end,

		tweenTransparency = function(Transparency, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {Transparency = Transparency})
			--warn(tween)
			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,

		tweenImageTransparency = function(Transparency, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {ImageTransparency = Transparency})
			--warn(tween)
			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,

		tweenGroupsTransparency = function(GroupTransparency:number, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {GroupTransparency = GroupTransparency})
			--warn(tween)
			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,

		tweenBrightness = function(Brightness, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Instance)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(instance, tweeninfo, {Brightness = Brightness})
			--warn(tween)
			if UseOnce then
				return tween
			else
				tween:Play()
			end
		end,
		
		tweenModelPivot = function(StartValeu, Value, EasingOptions:{EasingOptions}, NumberOptions:{NumberOptions}, BoolOptions:{BoolOptions},  Settings:{Settings}, instance:Model)

			local EasingStyle = if EasingOptions[1] ~= nil then EasingOptions[1] else Enum.EasingStyle.Linear
			local EasingDirection = if EasingOptions[2] ~= nil then EasingOptions[2] else Enum.EasingDirection.In
			local duration = if NumberOptions[1] ~= nil then NumberOptions[1] else 1
			local repeatCount = if NumberOptions[2] ~= nil then NumberOptions[2] else 0
			local reverses = BoolOptions[1] or false
			local delayTime = if NumberOptions[3] ~= nil then NumberOptions[3] else 0

			local UseOnce = Settings[1]
			
			local pivotValue = Instance.new("CFrameValue")
			pivotValue.Value = StartValeu

			local tweeninfo = TweenInfo.new(duration,EasingStyle, EasingDirection, repeatCount, reverses, delayTime)

			local tween = TS:Create(pivotValue, tweeninfo, {Value = Value})
			
			
			pivotValue:GetPropertyChangedSignal("Value"):Connect(function()
				instance:PivotTo(pivotValue.Value)
			end)
			--warn(tween)
			if UseOnce then
				return tween, pivotValue
			else
				task.spawn(function()
					tween:Play()
					tween.Completed:Wait()
					pivotValue:Destroy()
				end)
			
			end
		end,

		--[=[
		TypeWriter that suports richtext markup so it wont show you the rich text tags when typewritting
		
		<strong>guiObject</strong><em>(Reqeured)</em>: this the <em>TextLabel</em> or <em>TextButton</em> to apply the typewriter on
		<strong>text</strong><em>(Reqeured)</em>: this the <em>text</em> to typewrite
		<strong>delayBetweenChars</strong><em>(Reqeured)</em>: this the <em>Delay</em> between each character recomend to keep it in 0 + decimals
		<strong>Localize</strong><em>(Optional)</em>: this will change the text to the localized version of the text if set to true

		]=]
		typeWritter = function(guiObject, text, delayBetweenChars)
			if guiObject:GetAttribute("IsTyping") then return end
			guiObject:SetAttribute("IsTyping", true)
			guiObject.Visible = true
			guiObject.AutoLocalize = false
			guiObject.TextTransparency = 0
			local displayText = text

			--displayText = displayText:gsub("<br%s*/>", "\n")

			--displayText = displayText:gsub("<[^<>]->", "")

			guiObject.Text = displayText


			local index = 0
			for first, last in utf8.graphemes(displayText) do
				index += 1
				guiObject.MaxVisibleGraphemes = index
				task.wait(delayBetweenChars)
			end
			guiObject:SetAttribute("IsTyping", false)
		end,

		typeWritterWithPouseControl = function(guiObject, text, delayBetweenChars)
			if guiObject:GetAttribute("IsTyping") then return end
			guiObject:SetAttribute("IsTyping", true)

			if not guiObject:GetAttribute("Poused") then
				guiObject:SetAttribute("Poused", false) -- if you wnt to pouse typewriter call then this attribute
			end

			guiObject.Visible = true
			guiObject.AutoLocalize = false
			guiObject.TextTransparency = 0
			local displayText = text

			--displayText = displayText:gsub("<br%s*/>", "\n")

			--displayText = displayText:gsub("<[^<>]->", "")

			guiObject.Text = displayText


			local index = 0
			for first, last in utf8.graphemes(displayText) do
				while guiObject:GetAttribute("Poused") do
					task.wait() -- yields untin poused is false
				end
				index += 1
				guiObject.MaxVisibleGraphemes = index
				task.wait(delayBetweenChars)
			end
			guiObject:SetAttribute("IsTyping", false)
		end,

	}


}

return module
