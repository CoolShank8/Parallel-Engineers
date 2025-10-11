local MinimumAmountOfPlayersNeeded = 1

while true do
    local CurrentPlayers = game:GetService('Players'):GetPlayers()
	local GamemodeChoosen = require(game.ServerScriptService.GameModes:GetChildren())
	
    print('Teleporting players soon ')
    task.wait(4)

    if (#CurrentPlayers >= MinimumAmountOfPlayersNeeded) then
  		   GamemodeChoosen:Start()
    else
        print('Waiting for more players to join...')
    end

    task.wait()
end