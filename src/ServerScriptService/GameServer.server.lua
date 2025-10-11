while true do
    local CurrentPlayers = game:GetService('Players'):GetPlayers()

    if (#CurrentPlayers >= 2) then
      
    else
        print('Waiting for more players to join...')
    end

    task.wait()
end