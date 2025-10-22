local ServerRemoteEventsHandler = require(game.ServerStorage.Modules.RemoteEventsHandling)
print(ServerRemoteEventsHandler)

local RequestRemote:RemoteFunction = game.ReplicatedStorage.Remotes.RequestRemote
print(RequestRemote)

RequestRemote.OnServerInvoke = function(player:Player, funct, ...:any)
    return ServerRemoteEventsHandler:Run(player, funct, ...)
end
