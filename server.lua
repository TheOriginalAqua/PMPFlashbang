local ammo      = {}
local pending   = {}
local lastThrow = {}
local casings   = {}

local function deleteCasing(netId)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    for i = #casings, 1, -1 do
        if casings[i] == netId then table.remove(casings, i) end
    end
end

local function trackCasing(netId)
    casings[#casings + 1] = netId
    while #casings > Config.MaxCasings do deleteCasing(casings[1]) end
    if Config.CasingLifetime > 0 then
        SetTimeout(Config.CasingLifetime, function() deleteCasing(netId) end)
    end
end

RegisterCommand(Config.GiveCommand, function(src, args)
    if src == 0 then return end

    local amount = math.floor(tonumber(args[1]) or Config.DefaultAmmo)
    amount = math.max(1, math.min(Config.MaxAmmo, amount))

    ammo[src] = amount
    TriggerClientEvent('flashbang:give', src, amount, amount)
    TriggerClientEvent('flashbang:notify', src, ('Given %d flashbangs'):format(amount))
end, false)

RegisterNetEvent('flashbang:thrown', function()
    local src = source
    local now = GetGameTimer()
    if lastThrow[src] and now - lastThrow[src] < 500 then return end

    if Config.ServerAmmoCheck then
        if (ammo[src] or 0) < 1 then return end
        ammo[src] = ammo[src] - 1
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    lastThrow[src] = now

    local list = pending[src] or {}
    for i = #list, 1, -1 do
        if now - list[i].t > Config.FuseTime + 5000 then table.remove(list, i) end
    end
    list[#list + 1] = { t = now, at = GetEntityCoords(ped) }
    pending[src] = list
end)

RegisterNetEvent('flashbang:detonate', function(netId, coords)
    local src = source
    if type(coords) ~= 'vector3' or type(netId) ~= 'number' then return end

    local list = pending[src]
    if not list then return end

    local now, match = GetGameTimer(), nil
    for i, p in ipairs(list) do
        local age = now - p.t
        if age >= Config.FuseTime - 300 and age <= Config.FuseTime + 4000
           and #(coords - p.at) <= Config.MaxThrowDistance then
            match = i
            break
        end
    end
    if not match then return end
    table.remove(list, match)

    local pattern, t = {}, 0
    for i = 1, Config.Bangs do
        pattern[i] = t
        t = t + math.random(Config.BangInterval.min, Config.BangInterval.max)
    end

    TriggerClientEvent('flashbang:sequence', -1, src, netId, coords, pattern)
    trackCasing(netId)
end)

AddEventHandler('explosionEvent', function(sender, ev)
    if ev and ev.explosionType == 0 then CancelEvent() end
end)

AddEventHandler('playerDropped', function()
    ammo[source]      = nil
    pending[source]   = nil
    lastThrow[source] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = #casings, 1, -1 do deleteCasing(casings[i]) end
end)