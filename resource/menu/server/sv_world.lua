-- Prevent running in monitor mode
if not TX_SERVER_MODE then return end

-- =============================================
--  Server-side world sync (weather + time of day)
--  The server is the source of truth: it advances the clock and
--  replicates the state to all clients through GlobalState.txWorld.
--  Late joiners get the current state automatically (state bags).
--
--  Disable with: set txAdmin-menuWorldSync false
-- =============================================

if IS_REDM then return end
if GetConvar('txAdmin-menuWorldSync', 'true') == 'false' then
    GlobalState.txWorld = nil
    return
end

local KVP_KEY = 'txAdmin:worldState'
local MS_PER_GAME_MINUTE = 2000 -- same speed as the default GTA clock
local REPLICATE_INTERVAL = 10000

-- Must match the list in nui/src/utils/worldWeather.ts
TX_WEATHER_TYPES = {
    'EXTRASUNNY', 'CLEAR', 'NEUTRAL', 'SMOG', 'FOGGY', 'OVERCAST', 'CLOUDS', 'CLEARING',
    'RAIN', 'THUNDER', 'SNOW', 'BLIZZARD', 'SNOWLIGHT', 'XMAS', 'HALLOWEEN',
}
local validWeather = {}
for _, w in ipairs(TX_WEATHER_TYPES) do validWeather[w] = true end

-- Current state
local world = {
    weather = 'EXTRASUNNY',
    hour = 12,
    minute = 0,
    frozen = false,
}

-- Restore the last state saved before a restart
local saved = GetResourceKvpString(KVP_KEY)
if saved then
    local ok, data = pcall(json.decode, saved)
    if ok and type(data) == 'table' then
        if validWeather[data.weather] then world.weather = data.weather end
        if type(data.hour) == 'number' then world.hour = math.floor(data.hour) % 24 end
        if type(data.minute) == 'number' then world.minute = math.floor(data.minute) % 60 end
        world.frozen = data.frozen == true
    end
end

local function saveState()
    SetResourceKvp(KVP_KEY, json.encode(world))
end

--- Pushes the state to every client
---@param transition boolean|nil whether clients should blend into the new weather
local function replicate(transition)
    GlobalState.txWorld = {
        weather = world.weather,
        hour = world.hour,
        minute = world.minute,
        frozen = world.frozen,
        transition = transition == true,
        msPerMinute = MS_PER_GAME_MINUTE,
        -- bumps on every admin change, so clients know it's not just a clock tick
        rev = (GlobalState.txWorld and GlobalState.txWorld.rev or 0) + (transition ~= nil and 1 or 0),
    }
end

-- Clock thread
CreateThread(function()
    replicate(false)
    local lastTick = GetGameTimer()
    local lastReplicate = lastTick
    local lastSave = lastTick
    while true do
        Wait(250)
        local now = GetGameTimer()
        if world.frozen then
            lastTick = now
        else
            local elapsed = now - lastTick
            if elapsed >= MS_PER_GAME_MINUTE then
                local minutes = math.floor(elapsed / MS_PER_GAME_MINUTE)
                lastTick = lastTick + minutes * MS_PER_GAME_MINUTE
                local total = (world.hour * 60 + world.minute + minutes) % 1440
                world.hour = math.floor(total / 60)
                world.minute = total % 60
            end
        end
        if now - lastReplicate >= REPLICATE_INTERVAL then
            lastReplicate = now
            replicate()
        end
        if now - lastSave >= 60000 then
            lastSave = now
            saveState()
        end
    end
end)

AddEventHandler('onResourceStop', function(resName)
    if resName == GetCurrentResourceName() then saveState() end
end)


-- =============================================
--  Menu requests
-- =============================================
if not TX_MENU_ENABLED then return end

RegisterNetEvent('txsv:req:world:setWeather', function(weather)
    local src = source
    if type(weather) ~= 'string' then return end
    weather = weather:upper()
    if not validWeather[weather] then return end

    local allow = PlayerHasTxPermission(src, 'menu.world')
    TriggerEvent('txsv:logger:menuEvent', src, 'worldSetWeather', allow, weather)
    if not allow then return end

    world.weather = weather
    replicate(true)
    saveState()
end)

RegisterNetEvent('txsv:req:world:setTime', function(hour, minute)
    local src = source
    if type(hour) ~= 'number' or type(minute) ~= 'number' then return end
    hour = math.floor(hour)
    minute = math.floor(minute)
    if hour < 0 or hour > 23 or minute < 0 or minute > 59 then return end

    local allow = PlayerHasTxPermission(src, 'menu.world')
    TriggerEvent('txsv:logger:menuEvent', src, 'worldSetTime', allow, ('%02d:%02d'):format(hour, minute))
    if not allow then return end

    world.hour = hour
    world.minute = minute
    replicate(false)
    saveState()
end)

RegisterNetEvent('txsv:req:world:setFrozen', function(frozen)
    local src = source
    if type(frozen) ~= 'boolean' then return end

    local allow = PlayerHasTxPermission(src, 'menu.world')
    TriggerEvent('txsv:logger:menuEvent', src, 'worldFreezeTime', allow, frozen)
    if not allow then return end

    world.frozen = frozen
    replicate(false)
    saveState()
end)
