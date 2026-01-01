local QBCore = exports['qb-core']:GetCoreObject()
local inLobby, isLeader, inRace = false, false, false
local lobbyData = {}
local activeCheckpoint = nil
local nextCheckpointCoord = nil
local lastRaceVehicle = nil
local dnfTimer = 0
local raceStartTime = 0
local currentLap = 1
local lastLobbyIntent = 'join' -- Default to 'join'
local activeCheckpointBlip = nil -- Stores the blip for the *next* checkpoint

-- =========================================================================
-- HELPER FUNCTIONS
-- =========================================================================

local function sendNuiMessage(action, data)
    local message = data or {}
    message.action = action
    SendNUIMessage(message)
end

-- When NUI has focus (hasFocus = true), we want to *stop* game input.
local function setNuiFocus(hasFocus, hasCursor)
    SetNuiFocus(hasFocus, hasCursor)
    SetNuiFocusKeepInput(false)
end

-- Reliable ordinal suffix helper
local function getOrdinalSuffix(i)
    local j, k = i % 10, i % 100
    if j == 1 and k ~= 11 then return 'st' end
    if j == 2 and k ~= 12 then return 'nd' end
    if j == 3 and k ~= 13 then return 'rd' end
    return 'th'
end

-- Applies max performance upgrades to a vehicle
local function applyMaxTuning(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    SetVehicleModKit(vehicle, 0)
    SetVehicleMod(vehicle, 11, GetNumVehicleMods(vehicle, 11) - 1, false) -- Engine
    SetVehicleMod(vehicle, 12, GetNumVehicleMods(vehicle, 12) - 1, false) -- Brakes
    SetVehicleMod(vehicle, 13, GetNumVehicleMods(vehicle, 13) - 1, false) -- Transmission
    SetVehicleMod(vehicle, 15, GetNumVehicleMods(vehicle, 15) - 3, false) -- Suspension (don't slam it)
    SetVehicleMod(vehicle, 16, GetNumVehicleMods(vehicle, 16) - 1, false) -- Armor
    ToggleVehicleMod(vehicle, 18, true) -- Turbo
    SetVehicleEnginePowerMultiplier(vehicle, 1.25)
    SetVehicleEngineTorqueMultiplier(vehicle, 1.25)
end

-- *** MODIFIED: Cleans up the active blip and checkpoint ***
local function cleanupCheckpointBlips()
    if activeCheckpoint then
        DeleteCheckpoint(activeCheckpoint)
        activeCheckpoint = nil
    end

    if activeCheckpointBlip and DoesBlipExist(activeCheckpointBlip) then
        RemoveBlip(activeCheckpointBlip)
        activeCheckpointBlip = nil
    end
end

-- Cleans up all race-related entities and data
local function cleanupRace()
    cleanupCheckpointBlips() -- *** MODIFIED: Call new cleanup function ***
    inRace = false
    nextCheckpointCoord = nil
    dnfTimer = 0
    raceStartTime = 0
    sendNuiMessage('updateHUD', { visible = false })
    TriggerEvent('clappy_race:client:quitRaceCleanup')
end

-- Teleports player to spawn and cleans up their race vehicle
function cleanupAndTeleport()
    cleanupRace()
    local playerPed = PlayerPedId()
    local vehicleToDelete = nil
    local vehiclePlate = nil

    -- 1. Find the vehicle the player was using
    if lastRaceVehicle and DoesEntityExist(lastRaceVehicle) then
        vehicleToDelete = lastRaceVehicle
    elseif IsPedInAnyVehicle(playerPed, false) then
        vehicleToDelete = GetVehiclePedIsIn(playerPed, false)
    end

    if vehicleToDelete and DoesEntityExist(vehicleToDelete) then
        vehiclePlate = GetVehicleNumberPlateText(vehicleToDelete)
    end

    -- 2. Teleport the player FIRST
    if Config and Config.TargetPoint and Config.TargetPoint.coords then
        local targetCoords = Config.TargetPoint.coords
        local randomOffsetX = math.random() * 4.0 - 2.0
        local randomOffsetY = math.random() * 4.0 - 2.0
        SetEntityCoords(playerPed, targetCoords.x + randomOffsetX, targetCoords.y + randomOffsetY, targetCoords.z, false, false, false, true)
    else
        QBCore.Functions.Notify("Error: Race spawn point not found in config.", "error")
    end

    -- 3. Wait a moment for the teleport to complete
    Wait(500)

    -- 4. Remove keys based on config
    if vehiclePlate and vehicleToDelete then
        if Config.KeyScript == 'qs' then
            if exports['qs-vehiclekeys'] then
                local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicleToDelete))
                exports['qs-vehiclekeys']:RemoveKeys(vehiclePlate, model)
            else
                print('[clappy_race] ERROR: Config.KeyScript is "qs", but "qs-vehiclekeys" export was not found for key removal!')
            end
        elseif Config.KeyScript == 'qbx' then
            -- For qbx_vehiclekeys (Trigger Server Event)
            local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicleToDelete)
            if vehicleNetId then
                TriggerServerEvent('clappy_race:server:removeRaceKeys', vehicleNetId)
            end
        end
    end

    -- 5. NOW delete the vehicle
    if vehicleToDelete and DoesEntityExist(vehicleToDelete) then
        QBCore.Functions.DeleteVehicle(vehicleToDelete)
        lastRaceVehicle = nil
    end

    inLobby, isLeader, inRace = false, false, false
end

-- =========================================================================
-- NUI CALLBACKS
-- =========================================================================

RegisterNUICallback('closeMenu', function(_, cb)
    setNuiFocus(false, false)
    sendNuiMessage('hardResetUI')
    TriggerServerEvent('clappy_race:server:leaveLobby')
    inLobby = false
    cb({})
end)

RegisterNUICallback('leaveLobby', function(_, cb)
    setNuiFocus(false, false)
    sendNuiMessage('updateLobby', { visible = false })
    TriggerServerEvent('clappy_race:server:leaveLobby')
    inLobby = false
    cb({})
end)

RegisterNUICallback('startRace', function(_, cb)
    if isLeader then
        setNuiFocus(false, false)
        sendNuiMessage('updateLobby', { visible = false })
        TriggerServerEvent('clappy_race:server:startRace')
    end
    cb({})
end)

RegisterNUICallback('setLaps', function(data, cb)
    if isLeader then TriggerServerEvent('clappy_race:server:setLaps', data) end
    cb({})
end)

RegisterNUICallback('setVehicle', function(data, cb)
    TriggerServerEvent('clappy_race:server:setVehicle', data)
    cb({})
end)

RegisterNUICallback('submitName', function(data, cb)
    TriggerServerEvent('clappy_race:server:joinLobby', { name = data.name, intent = lastLobbyIntent })
    cb({})
end)

RegisterNUICallback('getHistory', function(_, cb)
    TriggerServerEvent('clappy_race:server:getHistory')
    cb({})
end)

RegisterNUICallback('closeHistory', function(_, cb)
    setNuiFocus(false, false)
    sendNuiMessage('showHistory', { visible = false })
    cb({})
end)

-- =========================================================================
-- RACE LOGIC
-- =========================================================================

local function highlightCheckpoint(checkpointIndex)
    -- *** MODIFIED: Clean up old checkpoint and blip ***
    if activeCheckpoint then
        DeleteCheckpoint(activeCheckpoint)
        activeCheckpoint = nil
    end
    if activeCheckpointBlip and DoesBlipExist(activeCheckpointBlip) then
        RemoveBlip(activeCheckpointBlip)
        activeCheckpointBlip = nil
    end

    local isFinishLine = false
    if currentLap >= lobbyData.laps and checkpointIndex == #Config.RaceTrack.Checkpoints then
        isFinishLine = true
    end

    activeCheckpointCoord = Config.RaceTrack.Checkpoints[checkpointIndex]

    local nextIndex = checkpointIndex + 1
    if nextIndex > #Config.RaceTrack.Checkpoints then
        nextIndex = 1
    end
    nextCheckpointCoord = Config.RaceTrack.Checkpoints[nextIndex]

    local checkpointType = isFinishLine and Config.RaceTrack.NewCheckpoint.finishType or Config.RaceTrack.NewCheckpoint.type
    local cfg = Config.RaceTrack.NewCheckpoint
    local heightOffset = cfg.height / 2.0

    activeCheckpoint = CreateCheckpoint(
        checkpointType,
        activeCheckpointCoord.x, activeCheckpointCoord.y, activeCheckpointCoord.z + heightOffset,
        nextCheckpointCoord.x, nextCheckpointCoord.y, nextCheckpointCoord.z,
        cfg.diameter,
        cfg.color.r, cfg.color.g, cfg.color.b, cfg.color.a,
        0
    )

    -- *** MODIFIED: Create new blip for next checkpoint and set route ***
    activeCheckpointBlip = AddBlipForCoord(activeCheckpointCoord.x, activeCheckpointCoord.y, activeCheckpointCoord.z)
    SetBlipSprite(activeCheckpointBlip, 1) -- Small dot
    SetBlipColour(activeCheckpointBlip, 5) -- Yellow
    SetBlipScale(activeCheckpointBlip, 1.0)
    SetBlipAsShortRange(activeCheckpointBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Checkpoint " .. checkpointIndex)
    EndTextCommandSetBlipName(activeCheckpointBlip)
    
    -- Set route to the *physical checkpoint entity* (the cylinder)
    SetBlipRoute(activeCheckpoint, true)
end

local function startRaceLogic(raceInfo, vehicle)
    CreateThread(function()
        inRace = true
        currentLap = 1
        local playerPed = PlayerPedId()

        sendNuiMessage('updateHUD', {
            visible = true,
            data = {
                place = raceInfo.initialPlace, totalPlayers = #lobbyData.players,
                lap = 1, totalLaps = raceInfo.totalLaps,
                checkpoint = 1, totalCheckpoints = #Config.RaceTrack.Checkpoints,
                bestLap = 0,
            }
        })

        FreezeEntityPosition(vehicle, true)
        
        -- *** REMOVED: Loop that created all checkpoint blips ***

        for i = 5, 1, -1 do
            sendNuiMessage('countdown', { value = tostring(i) })
            PlaySoundFrontend(-1, "COUNTDOWN", "HUD_MINI_GAME_SOUNDSET", true)
            Wait(1000)
        end
        sendNuiMessage('countdown', { value = 'GO!' })
        PlaySoundFrontend(-1, "GO", "HUD_MINI_GAME_SOUNDSET", true)
        Wait(1000)
        sendNuiMessage('countdown', { value = false })
        FreezeEntityPosition(vehicle, false)

        TriggerServerEvent('clappy_race:server:playerReady')
        raceStartTime = GetGameTimer()

        highlightCheckpoint(1) -- This will create the first checkpoint and blip

        local currentCheckpoint = 1
        local currentLapStartTime = GetGameTimer()
        local totalCheckpoints = #Config.RaceTrack.Checkpoints

        CreateThread(function()
            while inRace do
                Wait(5)
                local currentTime = GetGameTimer() - raceStartTime
                sendNuiMessage('updateTime', { time = currentTime })

                if dnfTimer > 0 then
                    dnfTimer = dnfTimer - 5
                    sendNuiMessage('updateDnfTime', { time = dnfTimer })
                    if dnfTimer <= 0 then
                        sendNuiMessage('showResultText', { main = 'DNF', sub = 'Time ran out!' })
                        TriggerServerEvent('clappy_race:server:quitRace', GetPlayerServerId(PlayerId()))
                        Wait(5000)
                        cleanupAndTeleport()
                        break
                    end
                end
            end
        end)

        while inRace do
            local playerPos = GetEntityCoords(playerPed)
            local checkpointPos = Config.RaceTrack.Checkpoints[currentCheckpoint]
            if #(playerPos - checkpointPos) < (Config.RaceTrack.NewCheckpoint.diameter / 2.0) then
                PlaySoundFrontend(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", true)

                local lapTime = 0
                if currentCheckpoint == totalCheckpoints then
                    lapTime = GetGameTimer() - currentLapStartTime
                    currentLapStartTime = GetGameTimer()
                end

                TriggerServerEvent('clappy_race:server:playerHitCheckpoint', { checkpoint = currentCheckpoint, lapTime = lapTime })

                currentCheckpoint = currentCheckpoint + 1
                if currentCheckpoint > totalCheckpoints then
                    currentCheckpoint = 1
                end
                highlightCheckpoint(currentCheckpoint)
            end
            Wait(100)
        end
    end)
end

local function loadModel(modelHash)
    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then return false end
    RequestModel(modelHash)
    local timeout = 2000
    while not HasModelLoaded(modelHash) and timeout > 0 do Wait(100); timeout = timeout - 100 end
    return HasModelLoaded(modelHash)
end

-- =========================================================================
-- NET EVENTS
-- =========================================================================

RegisterNetEvent('clappy_race:client:updateLobby', function(newLobbyState)
    if not newLobbyState then return end

    inRace = false -- Ensure we are not in a race when lobby is open
    sendNuiMessage('updateHUD', { visible = false }) -- Hide HUD when lobby opens

    inLobby = false
    local player = QBCore.Functions.GetPlayerData()
    if not player then return end

    for _, p in pairs(newLobbyState.players) do
        if p.citizenid == player.citizenid then inLobby = true; break; end
    end
    if not inLobby then
        setNuiFocus(false, false); sendNuiMessage('updateLobby', { visible = false })
        isLeader, lobbyData = false, {}
        return
    end
    lobbyData = newLobbyState
    isLeader = (lobbyData.leader == GetPlayerServerId(PlayerId()))
    sendNuiMessage('updateLobby', {
        visible = true, isLeader = isLeader, laps = lobbyData.laps,
        players = lobbyData.players, vehicles = Config.Vehicles, leader = lobbyData.leader,
        self = GetPlayerServerId(PlayerId())
    })
    sendNuiMessage('showNamePrompt', { visible = false })
    setNuiFocus(true, true)
end)

RegisterNetEvent('clappy_race:client:startRace', function(raceInfo)
    inLobby, isLeader = false, false
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        QBCore.Functions.DeleteVehicle(GetVehiclePedIsIn(playerPed, false))
    end
    local modelHash = GetHashKey(raceInfo.vehicle)
    if loadModel(modelHash) then
        local newVeh = CreateVehicle(modelHash, raceInfo.startPos.x, raceInfo.startPos.y, raceInfo.startPos.z, raceInfo.startPos.w, true, true)
        lastRaceVehicle = newVeh
        SetPedIntoVehicle(playerPed, newVeh, -1)
        SetModelAsNoLongerNeeded(modelHash)
        SetVehicleEngineOn(newVeh, true, true, false)

        -- Apply Tuning
        applyMaxTuning(newVeh)

        -- Set plate and ownership
        local plate = "RACE" .. math.random(100, 999)
        SetVehicleNumberPlateText(newVeh, plate)
        SetVehicleIsStolen(newVeh, false)
        SetVehicleNeedsToBeHotwired(newVeh, false)
        SetVehicleHasBeenOwnedByPlayer(newVeh, true)
        SetEntityAsMissionEntity(newVeh, true, true)

        -- Configurable Key Logic
        if Config.KeyScript == 'qbx' then
            -- For qbx_vehiclekeys (Trigger Server Event)
            local vehicleNetId = NetworkGetNetworkIdFromEntity(newVeh)
            if vehicleNetId then
                TriggerServerEvent('clappy_race:server:giveRaceKeys', vehicleNetId)
            else
                print('[clappy_race] ERROR: Config.KeyScript is "qbx" (for qbx_vehiclekeys), but could not get vehicle net ID!')
            end
        elseif Config.KeyScript == 'qs' then
            -- For qs-vehiclekeys
            if exports['qs-vehiclekeys'] then
                local model = GetDisplayNameFromVehicleModel(modelHash)
                exports['qs-vehiclekeys']:GiveKeys(plate, model, true)
            else
                print('[clappy_race] ERROR: Config.KeyScript is "qs", but "qs-vehiclekeys" export was not found!')
            end
        elseif Config.KeyScript == 'custom' then
            -- Add your custom key logic here
            -- Example: TriggerEvent('my_keys:client:AddKeys', plate, raceInfo.vehicle)
        end

        startRaceLogic(raceInfo, newVeh)
    else
        QBCore.Functions.Notify(("Error: Could not load vehicle model %s"):format(raceInfo.vehicle), "error")
    end
end)

RegisterNetEvent('clappy_race:client:updateRaceHud', function(data)
    if inRace and data then
        currentLap = data.lap
        local currentTime = GetGameTimer() - raceStartTime
        data.totalTime = currentTime
        sendNuiMessage('updateHUD', { visible = true, data = data })
    end
end)

RegisterNetEvent('clappy_race:client:finishedRace', function(place)
    inRace = false -- Immediately stop race loops

    -- *** MODIFIED: Call full cleanup function ***
    cleanupCheckpointBlips()

    sendNuiMessage('showResultText', { main = 'Finished', sub = ('%s%s Place'):format(place, getOrdinalSuffix(place)) })
    Wait(5000)
    cleanupAndTeleport()
end)

RegisterNetEvent('clappy_race:client:showHistory', function(history)
    sendNuiMessage('showHistory', { visible = true, history = history })
    setNuiFocus(true, true)
end)

RegisterNetEvent('clappy_race:client:openLobbyPrompt', function(data)
    if inLobby or inRace then return end

    lastLobbyIntent = data.metadata.intent or 'join'

    local player = QBCore.Functions.GetPlayerData()
    local defaultName = "Racer"
    if player and player.charinfo and player.charinfo.firstname and player.charinfo.lastname then
        defaultName = player.charinfo.firstname .. ' ' .. player.charinfo.lastname
    end

    sendNuiMessage('showNamePrompt', { visible = true, defaultName = defaultName })
    setNuiFocus(true, true)
end)

RegisterNetEvent('clappy_race:client:startDnfTimer', function()
    if inRace then
        dnfTimer = Config.RaceTrack.DNFTimer * 1000
    end
end)

RegisterNetEvent('clappy_race:client:quitRace', function()
    inRace = false
    CreateThread(function()
        -- Find vehicle to remove keys from before teleporting
        local vehicleToQuit = nil
        if lastRaceVehicle and DoesEntityExist(lastRaceVehicle) then
            vehicleToQuit = lastRaceVehicle
        elseif IsPedInAnyVehicle(PlayerPedId(), false) then
            -- *** FIX: Corrected typo 'PlayerIndented' to 'PlayerPedId' and added missing parenthesis ***
            vehicleToQuit = GetVehiclePedIsIn(PlayerPedId(), false)
        end

        if vehicleToQuit and DoesEntityExist(vehicleToQuit) then
             if Config.KeyScript == 'qbx' then
                local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicleToQuit)
                if vehicleNetId then
                    TriggerServerEvent('clappy_race:server:removeRaceKeys', vehicleNetId)
                end
            end
        end

        sendNuiMessage('startTeleportCountdown', { duration = 5 })
        Wait(5000)
        sendNuiMessage('showResultText', { main = 'Left the Race' })
        cleanupAndTeleport()
    end)
end)

RegisterNetEvent('clappy_race:client:quitRaceCleanup', function()
    inLobby, isLeader, inRace = false, false, false
end)


-- =========================================================================
-- COMMANDS
-- =========================================================================

RegisterCommand('quitrace', function()
    if inRace then
        TriggerServerEvent('clappy_race:server:quitRace', GetPlayerServerId(PlayerId()))
    else
        QBCore.Functions.Notify("You are not in a race.", "error")
    end
end, false)


-- =========================================================================
-- MAIN THREAD
-- =========================================================================

CreateThread(function()
    Wait(1000)

    local blipCfg = Config.Blip
    local blip = AddBlipForCoord(Config.TargetPoint.coords.x, Config.TargetPoint.coords.y, Config.TargetPoint.coords.z)
    SetBlipSprite(blip, blipCfg.sprite)
    SetBlipDisplay(blip, blipCfg.display)
    SetBlipScale(blip, blipCfg.scale)
    SetBlipColour(blip, blipCfg.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipCfg.label)
    EndTextCommandSetBlipName(blip)

    local targetOptions = {}
    if Config.TargetOptions then
        for _, option in ipairs(Config.TargetOptions) do
            table.insert(targetOptions, {
                name = 'clappy_race:' .. option.name,
                label = option.label,
                icon = option.icon,
                onSelect = function(data) -- Pass target data
                    if option.event and string.find(option.event, "server") then
                        TriggerServerEvent(option.event)
                    elseif option.event then
                        TriggerEvent(option.event, data) -- Pass data to client event
                    end
                end,
                metadata = option.metadata -- Include metadata for the onSelect function
            })
        end
    end

    exports.ox_target:addBoxZone({
        coords = Config.TargetPoint.coords,
        size = Config.TargetPoint.size,
        options = targetOptions
    })
end)

