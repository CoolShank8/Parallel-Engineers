local MinimumAmountOfPlayersNeeded = 1

while true do
    local CurrentPlayers = game:GetService('Players'):GetPlayers()
	local AllGameModes = game.ServerScriptService.GameModes:GetChildren()
	local GameModeChoosen = require(AllGameModes[math.random(1, #AllGameModes)])
	
    print('Teleporting players soon ')
    task.wait(4)

    if (#CurrentPlayers >= MinimumAmountOfPlayersNeeded) then
		GameModeChoosen:Start()
		
		task.wait(20)
    else
        print('Waiting for more players to join...')
    end

    task.wait()
end