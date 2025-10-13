local EntityAdmin = require(game.ReplicatedStorage.Packages.EntityAdmin)
local PlayerClass = require(game.ReplicatedStorage.GameClasses.Player)

local World = EntityAdmin:CreateWorld("GameWorld")

game:GetService("Players").PlayerAdded:Connect(function(Player)
   local PlayerEntity: PlayerClass.Player = World:CreateEntityOfClass(PlayerClass, Player)

   PlayerEntity.Cash = 500
end)



return World