-- =============================================
--  Client-side world sync (weather + time of day)
--  Applies the state replicated by the server in GlobalState.txWorld.
--  This runs even with the menu disabled, so all players stay in sync.
-- =============================================
if IS_REDM then return end

local WEATHER_TRANSITION_SECS = 15.0

local worldState = nil    -- last state received from the server
local receivedAt = 0      -- GetGameTimer() when it was received
local currentWeather = nil
local transitionUntil = 0

--- Returns the current hour and minute based on the last state + time elapsed
local function getCurrentTime()
    if not worldState then return 12, 0 end
    local total = worldState.hour * 60 + worldState.minute
    if not worldState.frozen then
        total = total + math.floor((GetGameTimer() - receivedAt) / (worldState.msPerMinute or 2000))
    end
    total = total % 1440
    return math.floor(total / 60), total % 60
end

local function setSnowEffects(weather)
    local snowy = weather == 'XMAS'
    SetForceVehicleTrails(snowy)
    SetForcePedFootstepsTracks(snowy)
end

local function applyWeather(weather, transition)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    if transition and currentWeather then
        SetWeatherTypeOvertimePersist(weather, WEATHER_TRANSITION_SECS)
        transitionUntil = GetGameTimer() + math.floor(WEATHER_TRANSITION_SECS * 1000)
    else
        SetWeatherTypePersist(weather)
        SetWeatherTypeNow(weather)
        SetWeatherTypeNowPersist(weather)
        transitionUntil = 0
    end
    setSnowEffects(weather)
    currentWeather = weather
end

local function sendStateToMenu()
    if not TX_MENU_ENABLED or not worldState then return end
    local hour, minute = getCurrentTime()
    SendNUIMessage({
        action = 'setWorldState',
        data = {
            enabled = true,
            weather = worldState.weather,
            hour = hour,
            minute = minute,
            frozen = worldState.frozen,
            msPerMinute = worldState.msPerMinute or 2000,
        },
    })
end

local function onWorldState(value)
    if type(value) ~= 'table' then
        worldState = nil
        return
    end
    worldState = value
    receivedAt = GetGameTimer()
    if value.weather ~= currentWeather then
        applyWeather(value.weather, value.transition)
    end
    local hour, minute = getCurrentTime()
    NetworkOverrideClockTime(hour, minute, 0)
    sendStateToMenu()
end

AddStateBagChangeHandler('txWorld', 'global', function(_, _, value)
    onWorldState(value)
end)

-- Initial state + enforcement loop
CreateThread(function()
    onWorldState(GlobalState.txWorld)

    local lastWeatherCheck = 0
    while true do
        if worldState then
            -- Time: keep the clock locked to the server's
            local hour, minute = getCurrentTime()
            NetworkOverrideClockTime(hour, minute, 0)

            -- Weather: finish transitions and undo changes from the game/other scripts
            local now = GetGameTimer()
            if transitionUntil > 0 and now >= transitionUntil then
                transitionUntil = 0
                SetWeatherTypePersist(currentWeather)
                SetWeatherTypeNowPersist(currentWeather)
            elseif transitionUntil == 0 and now - lastWeatherCheck > 5000 then
                lastWeatherCheck = now
                if GetNextWeatherTypeHashName() ~= GetHashKey(currentWeather) then
                    applyWeather(currentWeather, false)
                end
            end
        end
        Wait(1000)
    end
end)


-- =============================================
--  Menu callbacks
-- =============================================
if not TX_MENU_ENABLED then return end

RegisterSecureNuiCallback('getWorldState', function(_, cb)
    if not worldState then
        return cb({ enabled = false })
    end
    local hour, minute = getCurrentTime()
    cb({
        enabled = true,
        weather = worldState.weather,
        hour = hour,
        minute = minute,
        frozen = worldState.frozen,
        msPerMinute = worldState.msPerMinute or 2000,
    })
end)

RegisterSecureNuiCallback('setWorldWeather', function(data, cb)
    if type(data) == 'table' and type(data.weather) == 'string' then
        TriggerServerEvent('txsv:req:world:setWeather', data.weather)
    end
    cb({})
end)

RegisterSecureNuiCallback('setWorldTime', function(data, cb)
    if type(data) == 'table' and type(data.hour) == 'number' and type(data.minute) == 'number' then
        TriggerServerEvent('txsv:req:world:setTime', data.hour, data.minute)
    end
    cb({})
end)

RegisterSecureNuiCallback('setWorldFrozen', function(data, cb)
    if type(data) == 'table' and type(data.frozen) == 'boolean' then
        TriggerServerEvent('txsv:req:world:setFrozen', data.frozen)
    end
    cb({})
end)
