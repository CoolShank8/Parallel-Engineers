local EntityAdmin = {}
EntityAdmin.AllWorlds = {}

function EntityAdmin.GetWorld()
    -- Placeholder for getting the world instance
    return {}
end

function EntityAdmin.CreateWorld(name: string)
    local world = {name = name, entities = {}}
    EntityAdmin.AllWorlds[name] = world
    return world
end 