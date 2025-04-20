ESX = exports['es_extended']:getSharedObject()
lib.locale()
lib.versionCheck('gabovrs/midofey_garage')

local activeVehicles = {}


lib.callback.register('midofey_garage:checkOwner', function(source, plate)
    local plate = string.gsub(plate, ' ', '')
    local result = CustomSQL('query', "SELECT owner FROM owned_vehicles WHERE REPLACE(plate, ' ','') = ?", {plate})
    if #result > 0 then
        return result[1].owner
    end
end)

lib.callback.register('midofey_garage:getVehicles', function(source, job, type)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    local result
    if job then
        result = CustomSQL('query', 'SELECT * FROM owned_vehicles WHERE owner = ? and job = ? and type = ? ORDER BY `stored` DESC',
            {identifier, job, type})
    else
        result = CustomSQL('query', 'SELECT * FROM owned_vehicles WHERE owner = ? and type = ? ORDER BY `stored` DESC', {identifier, type})
    end
    for _, vehicle in ipairs(result) do
        if vehicle.stored == 1 or vehicle.stored == true then
            vehicle.state = 'in_garage'
        elseif activeVehicles[vehicle.plate] then
            local entity = activeVehicles[vehicle.plate]
            if not DoesEntityExist(entity) then
                activeVehicles[vehicle.plate] = nil
                vehicle.state = 'in_impound'
            elseif GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                DeleteEntity(entity)
                activeVehicles[vehicle.plate] = nil
                vehicle.state = 'in_impound'
            else
                vehicle.state = 'out_garage'
            end
        else
            vehicle.state = 'in_impound'
        end
    end
    return result
end)

lib.callback.register('midofey_garage:getImpoundedVehicles', function(source, type)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    local result = CustomSQL('query', 'SELECT * FROM owned_vehicles WHERE owner = ? and type = ?', {identifier, type})
    for _, vehicle in ipairs(result) do
        if vehicle.stored == 1 or vehicle.stored == true then
            vehicle.state = 'in_garage'
        elseif activeVehicles[vehicle.plate] then
            local entity = activeVehicles[vehicle.plate]
            if not DoesEntityExist(entity) then
                activeVehicles[vehicle.plate] = nil
                vehicle.state = 'in_impound'
            elseif GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                DeleteEntity(entity)
                activeVehicles[vehicle.plate] = nil
                vehicle.state = 'in_impound'
            else
                vehicle.state = 'out_garage'
            end
        else
            vehicle.state = 'in_impound'
        end
    end
    return result
end)

lib.callback.register('midofey_garage:spawnVehicle', function(source, vehicleData, plate, coords)
    local vehicleId = nil
    ESX.OneSync.SpawnVehicle(vehicleData.model, vector3(coords), coords.w, vehicleData, function(NetworkId)
        Wait(500)
        local Vehicle = NetworkGetEntityFromNetworkId(NetworkId)
        -- NetworkId is sent over, since then it can also be sent to a client for them to use, vehicle handles cannot.
        local Exists = DoesEntityExist(Vehicle)
        vehicleId = NetworkId
        activeVehicles[plate] = Vehicle
        print(Exists and 'Successfully Spawned Vehicle!' or 'Failed to Spawn Vehicle!')
        local xPlayer = ESX.GetPlayerFromId(source)
        local identifier = xPlayer.getIdentifier()
        CustomSQL('update',
            "UPDATE owned_vehicles SET `stored` = 0, parking = NULL WHERE REPLACE(plate, ' ','') = ? and owner = ?",
            {plate, identifier})
    end)
    while vehicleId == nil do Wait(100) end
    return vehicleId
end)

lib.callback.register('midofey_garage:canPay', function(source, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local PlayerMoney = xPlayer.getMoney() -- Get the Current Player`s Balance.
    if PlayerMoney >= amount then -- check if the Player`s Money is more or equal to the cost.
        xPlayer.removeMoney(amount) -- remove Cost from balance
        return true
    else
        return false
    end
end)

lib.callback.register('midofey_garage:getVehicle', function(source, plate)
    local plate = string.gsub(plate, ' ', '')
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    local result = CustomSQL('query', "SELECT * FROM owned_vehicles WHERE REPLACE(plate, ' ','') = ? and owner = ?", {plate, identifier})
    local vehicle = result[1]
    if vehicle.stored == 1 or vehicle.stored == true then
        vehicle.state = 'in_garage'
    elseif activeVehicles[vehicle.plate] then
        local entity = activeVehicles[vehicle.plate]
        if not DoesEntityExist(entity) then
            activeVehicles[vehicle.plate] = nil
            vehicle.state = 'in_impound'
        elseif GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
            DeleteEntity(entity)
            activeVehicles[vehicle.plate] = nil
            vehicle.state = 'in_impound'
        else
            vehicle.state = 'out_garage'
        end
    else
        vehicle.state = 'in_impound'
    end
    return vehicle
end)

RegisterServerEvent('midofey_garage:updateVehicle', function(plate, vehicle, parking, stored)
    local plate = string.gsub(plate, ' ', '')
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    CustomSQL('update', "UPDATE owned_vehicles SET vehicle = ?, parking = ?, `stored` = ? WHERE REPLACE(plate, ' ','') = ? and owner = ?",
        {vehicle, parking, stored, plate, identifier})
    if stored and activeVehicles[plate] ~= nil then
        activeVehicles[plate] = nil
    end
end)

RegisterServerEvent('midofey_garage:buyVehicle', function(plate, vehicle, parking, job)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    CustomSQL('insert',
        'INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored, parking, impound, job) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        {identifier, plate, json.encode(vehicle), 'car', 1, parking, 0, job})
end)

RegisterServerEvent('midofey_garage:setVehicleParking', function(plate, parking)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    CustomSQL('update', 'UPDATE owned_vehicles SET parking = ? WHERE plate = ? and owner = ?',
        {parking, plate, identifier})
    if activeVehicles[plate] ~= nil then
        activeVehicles[plate] = nil
    end
end)

RegisterServerEvent('midofey_garage:setVehicleImpound', function(plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    CustomSQL('update', 'UPDATE owned_vehicles SET state = "in_impound" WHERE plate = ? and owner = ?',
        {plate, identifier})
    if activeVehicles[plate] ~= nil then
        activeVehicles[plate] = nil
    end
end)

lib.callback.register('midofey_garage:setPlayerRoutingBucket', function(source, bucket)
    if not bucket then
        bucket = math.random(1000)
    end
    SetPlayerRoutingBucket(source, bucket)
    return true
end)

function CustomSQL(type, action, placeholder)
    local result = nil
    if Config.MySQL == 'oxmysql' then
        if type == 'query' then
            result = exports.oxmysql:query_async(action, placeholder)
        elseif type == 'update' then
            result = exports.oxmysql:update(action, placeholder)
        elseif type == 'insert' then
            result = exports.oxmysql:insert(action, placeholder)
        end
    elseif Config.MySQL == 'mysql-async' then
        if type == 'query' then
            result = MySQL.Sync.query(action, placeholder)
        elseif type == 'update' then
            result = MySQL.Async.execute(action, placeholder)
        elseif type == 'insert' then
            result = MySQL.Async.insert(action, placeholder)
        end
    elseif Config.MySQL == 'ghmattisql' then
        if type == 'query' then
            result = exports.ghmattimysql:executeSync(action, placeholder)
        elseif type == 'update' then
            result = exports.ghmattimysql:execute(action, placeholder)
        elseif type == 'insert' then
            result = exports.ghmattimysql:execute(action, placeholder)
        end
    end
    return result
end


if Config.ImpoundCommandEnabled then
    ESX.RegisterCommand(Config.ImpoundCommand.command, 'user', function(xPlayer, args, showError)
        for k, job in pairs(Config.ImpoundCommand.jobs) do
            if xPlayer.getJob().name == job then
                xPlayer.triggerEvent('midofey_garage:impoundVehicle')
            end
        end
    end, false, {
        help = locale('command_impound')
    })    
end

if Config.NpwdIntegration then
    RegisterNetEvent("npwd:midofey-garage:getVehicles", function()
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        local identifier = xPlayer.getIdentifier()
        local result = CustomSQL('query', 'SELECT * FROM owned_vehicles WHERE owner = ? ORDER BY `stored` DESC', {identifier})
        for _, vehicle in ipairs(result) do
            local props = json.decode(vehicle.vehicle)
            if vehicle.stored == 1 or vehicle.stored == true then
                vehicle.state = 'garaged'
            elseif activeVehicles[vehicle.plate] then
                local entity = activeVehicles[vehicle.plate]
                if not DoesEntityExist(entity) then
                    activeVehicles[vehicle.plate] = nil
                    vehicle.state = 'impounded'
                elseif GetVehiclePetrolTankHealth(entity) <= 0 or GetVehicleBodyHealth(entity) <= 0 then
                    DeleteEntity(entity)
                    activeVehicles[vehicle.plate] = nil
                    vehicle.state = 'impounded'
                else
                    vehicle.state = 'out'
                end
            else
                vehicle.state = 'impounded'
            end
            vehicle.hash = props.model
            vehicle.fuel = props.fuelLevel
            vehicle.body = props.bodyHealth
            vehicle.engine = props.engineHealth
            vehicle.vehicle = "Unknown"
            vehicle.brand = "Unknown"
            vehicle.props = props
            if vehicle.parking ~= nil then
                vehicle.garage = locale(vehicle.parking)
            elseif vehicle.state == 'impounded' then
                vehicle.garage = "Parking Servis"
            end
        end
        TriggerClientEvent('npwd:midofey-garage:sendVehicles', src, result)
    end)
    lib.callback.register("midofey_garage:valetVehicle", function(source, plate, vehicleData, coords, heading)
        local src = source
        local vehicleId = nil
        ESX.OneSync.SpawnVehicle(vehicleData.hash, coords, heading, vehicleData.props, function(NetworkId)
            Wait(500)
            local Vehicle = NetworkGetEntityFromNetworkId(NetworkId)
            -- NetworkId is sent over, since then it can also be sent to a client for them to use, vehicle handles cannot.
            local Exists = DoesEntityExist(Vehicle)
            vehicleId = NetworkId
            activeVehicles[plate] = Vehicle
            print(Exists and 'Successfully Spawned Vehicle!' or 'Failed to Spawn Vehicle!')
            local xPlayer = ESX.GetPlayerFromId(src)
            local identifier = xPlayer.getIdentifier()
            CustomSQL('update',
                "UPDATE owned_vehicles SET `stored` = 0, parking = NULL WHERE REPLACE(plate, ' ','') = ? and owner = ?",
                {plate, identifier})
        end)
        while vehicleId == nil do Wait(100) end
        return vehicleId
    end)
end