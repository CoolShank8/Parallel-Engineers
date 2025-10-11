for x = 1,10 do
    print 'i am a goblin'
    print('i am a better goblin')
end

print 'done'
print('no u aint better')

local x = 0

while true do
    x += 1
    for i,v in game:GetService('Players'):GetPlayerByUserId(x) do
        print('found player ' .. v.UserId)
    end 
end