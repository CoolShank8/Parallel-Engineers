--!strict

local PlayerClass = {}
local EntityAdmin = require(game.ReplicatedStorage.Modules.EntityAdmin)

export type Player = {
    Cash: number,
    Kills: number,

    MaterialsOwned: {
        Wood: number,
        Stone: number,
        Metal: number,
    },
} & EntityAdmin.GEntity<Player>

function PlayerClass.OnInit(self, Env, PlayerInstance: Player) 
    self.Cash = 100
    self.Kills = 2

    self.MaterialsOwned = {
        Wood = 0,
        Stone = 0,
        Metal = 0,
    }
end

return PlayerClass