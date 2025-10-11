print 'adding maanagement system'

type ManagementSystem = {
    Name: string,
    Version: number,
}

local ManagementSystem: ManagementSystem = {
    Name = "ManagementSystem",
    Version = 1.0,
}

for i,v in game:GetService('Players'):GetPlayers()
do
    print('hello ' .. v.UserId)
end

print 'hello from management system'
print 'wow'

ManagementSystem.Name = 'something else'