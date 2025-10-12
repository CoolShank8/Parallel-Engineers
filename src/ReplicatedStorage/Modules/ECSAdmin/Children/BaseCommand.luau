local RunService = game:GetService('RunService')

local BaseCommand = {}
local CommandType = {}

local CommandRegisteryFns = {}
local CommunicationRemote: RemoteEvent = script:FindFirstChild("CommunicationRemote")

if RunService:IsServer() then
	CommunicationRemote = Instance.new("RemoteEvent")
	CommunicationRemote.Name = "CommunicationRemote"
	CommunicationRemote.Parent = script
	
	CommunicationRemote.OnServerEvent:Connect(function(Command)
		setmetatable(Command, CommandType)
		
		table.insert(Command.World.PredictedCommandQue, Command)
	end)
end

function CommandType.new(World, Module, Path, Args)
	local Command = {}
	Command.World = World
	Command.Args = Args
	Command.Module = Module
	Command.ModulePath = Path
	Command.SentCommandFrame = 0
	
	
	setmetatable(Command, CommandType)
	return Command
end

function CommandType:Execute()
	local CommandGenerator = self.Module
	for x = 1, self.ModulePath do
		CommandGenerator = CommandGenerator[self.ModulePath[x]]
	end

	CommandGenerator(self.World, unpack(self.Args))
end

function CommandType:PredictExecute()
	if game:GetService('RunService'):IsClient() == false then error("Have to be on client to predict") end
	
	
	
	CommunicationRemote:FireServer(self)
end

function BaseCommand.Define(Module, ...)
	local CommandPath = {...}
		
	local FnHolder = Module
	
	for i ,v in CommandPath do
		if i == #CommandPath then break end
		FnHolder = FnHolder[v]
	end
	
	local Fn = FnHolder[CommandPath[#CommandPath]]
	
	local NewCommandGenerator = function(World, ...)
		return CommandType.new(World, Module, CommandPath, ...)
	end
	
	rawset(FnHolder, CommandPath[#CommandPath], NewCommandGenerator)
end


return BaseCommand