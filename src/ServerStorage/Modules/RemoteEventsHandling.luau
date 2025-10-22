local HTTP = game:GetService("HttpService")

local RemoteEventFunctions = {}

function RemoteEventFunctions:Run(player:Player, funct, ...:any)
    if self[funct] then
        return self[funct](self, player, ...)
    else
        warn(funct..", is not found in the module this is an serious error that might break things consider checking it!")
        return nil
    end
end

function RemoteEventFunctions:GetGuid(player:Player, useBrackets:boolean)
    return HTTP:GenerateGUID(useBrackets)
end

return RemoteEventFunctions