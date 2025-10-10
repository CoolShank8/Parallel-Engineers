print("hello world")

local maxTicks = 10
local tickCount = 0

while tickCount < maxTicks do
    wait(1)
    print("tick")
    tickCount = tickCount + 1
end