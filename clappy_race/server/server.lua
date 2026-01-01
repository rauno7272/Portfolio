local QBCore = exports['qb-core']:GetCoreObject()
local RaceUpdateThread = nil
local RaceVehicles = {} -- Store player source -> vehicle net ID

local Lobby = {
    leader = nil,
    players = {},
    laps = 3,
    status = 'waiting', -- 'waiting', 'racing', 'finished'
    finishOrder = {},
    dnfPlayers = {}
}

local RaceHistory = {}
local HistoryFile = 'history.json'

-- Load history from file on start
local historyJson = LoadResourceFile(GetCurrentResourceName(), HistoryFile)
if historyJson then
    RaceHistory = json.decode(historyJson) or {}
end

local function saveHistory()
    SaveResourceFile(GetCurrentResourceName(), HistoryFile, json.encode(RaceHistory), -1)
end

local function resetLobby()
    RaceUpdateThread = nil
    RaceVehicles = {}
    Lobby = {
        leader = nil, players = {}, laps = 3,
        status = 'waiting', finishOrder = {}, dnfPlayers = {}
    }
    -- Trigger a final update to clear the lobby for anyone still in it
    TriggerClientEvent('clappy_race:client:updateLobby', -1, Lobby)
end

local function updateLobbyState()
    for _, p in pairs(Lobby.players) do
        TriggerClientEvent('clappy_race:client:updateLobby', p.source, Lobby)
    end
end

local function startRaceUpdater()
    RaceUpdateThread = CreateThread(function()
        while Lobby.status == 'racing' do
            -- Filter out DNF players before sorting
            local activeRacers = {}
            for _, p in ipairs(Lobby.players) do
                if not Lobby.dnfPlayers[p.source] then
                    table.insert(activeRacers, p)
                end
            end

            if #activeRacers > 0 then
                table.sort(activeRacers, function(a, b)
                    if not a or not a.progress or not b or not b.progress then return false end
                    if a.progress.lap == b.progress.lap then
                        return a.progress.checkpoint > b.progress.checkpoint
                    end
                    return a.progress.lap > b.progress.lap
                end)
            end

            local clientRaceData = {}
            for i, p in ipairs(activeRacers) do
                p.progress.place = i
                
                local totalTime = 0
                if p.progress.startTime and p.progress.startTime > 0 then
                    totalTime = GetGameTimer() - p.progress.startTime
                end

                clientRaceData[p.source] = {
                    place = p.progress.place, totalPlayers = #activeRacers,
                    lap = p.progress.lap, totalLaps = Lobby.laps,
                    checkpoint = p.progress.checkpoint, totalCheckpoints = #Config.RaceTrack.Checkpoints,
                    bestLap = p.progress.bestLap,
                    totalTime = totalTime
                }
            end
            
            for _, p in ipairs(activeRacers) do
                if not p.progress.finished then
                    TriggerClientEvent('clappy_race:client:updateRaceHud', p.source, clientRaceData[p.source])
                end
            end
            Wait(1000)
        end
    end)
end

RegisterNetEvent('clappy_race:server:joinLobby', function(data)
    local src = source
    local customName = data.name
    local intent = data.intent or 'join'

    if intent == 'create' and Lobby.status ~= 'waiting' then
        QBCore.Functions.Notify(src, "A race lobby is already active.", "error")
        return
    end

    if intent == 'join' and Lobby.status ~= 'waiting' then
        QBCore.Functions.Notify(src, "You cannot join a race that is already in progress.", "error")
        return
    end

    if intent == 'create' then
        if #Lobby.players > 0 then
             QBCore.Functions.Notify(src, "A race lobby already exists. Try joining it instead.", "error")
             return
        else
             -- This player is creating the lobby, make them leader
             Lobby.leader = src
        end
    else -- intent == 'join'
        if #Lobby.players == 0 then
            QBCore.Functions.Notify(src, "No race lobby found to join. Try creating one.", "error")
            return
        end
    end

    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    for _, p in pairs(Lobby.players) do
        if p.source == src then return end
    end

    local racerName = customName and customName:gsub("^%s*(.-)%s*$", "%1") or nil
    if not racerName or racerName == "" then
        racerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    end

    local playerData = {
        source = src, citizenid = player.PlayerData.citizenid, name = racerName,
        vehicle = Config.Vehicles[1].spawncode,
        progress = { lap = 1, checkpoint = 1, finished = false, place = #Lobby.players + 1, bestLap = 0, lapTimes = {}, startTime = 0 }
    }
    
    if not Lobby.leader then Lobby.leader = src end -- Fallback in case
    
    table.insert(Lobby.players, playerData)
    updateLobbyState()
end)

local function removePlayerFromLobby(src)
    local playerFound = false
    for i, p in ipairs(Lobby.players) do
        if p.source == src then
            playerFound = true
            if Lobby.status == 'racing' and not p.progress.finished then
                Lobby.dnfPlayers[src] = true
                table.insert(Lobby.finishOrder, { name = p.name, totalTime = 'DNF', bestLap = p.progress.bestLap })
            end
            table.remove(Lobby.players, i)
            if Lobby.leader == src then
                Lobby.leader = #Lobby.players > 0 and Lobby.players[1].source or nil
            end
            updateLobbyState()
            break
        end
    end

    -- Remove their keys if they exist
    if Config.KeyScript == 'qbx' and RaceVehicles[src] then
        -- *** FIX: Use NetworkGetEntityFromNetworkId instead of NetToVeh ***
        local vehicle = NetworkGetEntityFromNetworkId(RaceVehicles[src])
        if vehicle and DoesEntityExist(vehicle) then
            if exports.qbx_vehiclekeys then
                exports.qbx_vehiclekeys:RemoveKeys(src, vehicle, true)
            end
        end
        RaceVehicles[src] = nil
    end

    -- Check if the race should end
    if Lobby.status == 'racing' then
        local allFinishedOrDnf = true
        if #Lobby.players == 0 then
             allFinishedOrDnf = true 
        else
            for _, player in ipairs(Lobby.players) do
                if not player.progress.finished and not Lobby.dnfPlayers[player.source] then 
                    allFinishedOrDnf = false; 
                    break 
                end
            end
        end

        if allFinishedOrDnf then
            Lobby.status = 'finished'
            TriggerEvent('clappy_race:server:endRace')
        end
    end
    
    return playerFound
end

RegisterNetEvent('clappy_race:server:leaveLobby', function()
    removePlayerFromLobby(source)
end)

RegisterNetEvent('clappy_race:server:setLaps', function(data)
    if Lobby.leader ~= source then return end
    local lapCount = tonumber(data.laps)
    if lapCount and lapCount > 0 and lapCount <= 20 then Lobby.laps = lapCount; updateLobbyState() end
end)

RegisterNetEvent('clappy_race:server:setVehicle', function(data)
    for _, p in ipairs(Lobby.players) do
        if p.source == source then p.vehicle = data.vehicle; updateLobbyState(); return; end
    end
end)

RegisterNetEvent('clappy_race:server:startRace', function()
    if Lobby.leader ~= source then return end
    if #Lobby.players > #Config.RaceTrack.StartPositions then
        QBCore.Functions.Notify(source, "Not enough start positions for all players.", "error")
        return
    end

    Lobby.status = 'racing'
    for i, p in ipairs(Lobby.players) do
        p.progress = { lap = 1, checkpoint = 1, finished = false, place = i, bestLap = 0, lapTimes = {}, startTime = 0 }
        TriggerClientEvent('clappy_race:client:startRace', p.source, {
            vehicle = p.vehicle,
            startPos = Config.RaceTrack.StartPositions[i],
            totalLaps = Lobby.laps,
            initialPlace = i
        })
    end
    startRaceUpdater()
end)

RegisterNetEvent('clappy_race:server:playerReady', function()
    local src = source
    for _, p in ipairs(Lobby.players) do
        if p.source == src then
            p.progress.startTime = GetGameTimer()
            return
        end
    end
end)

RegisterNetEvent('clappy_race:server:playerHitCheckpoint', function(data)
    local src = source
    local checkpointIndex, lapTime = data.checkpoint, data.lapTime
    local totalCheckpoints = #Config.RaceTrack.Checkpoints
    
    for _, p in ipairs(Lobby.players) do
        if p.source == src and not p.progress.finished then
            if checkpointIndex ~= p.progress.checkpoint then return end
            
            if checkpointIndex == totalCheckpoints and lapTime > 0 then
                table.insert(p.progress.lapTimes, lapTime)
                if p.progress.bestLap == 0 or lapTime < p.progress.bestLap then
                    p.progress.bestLap = lapTime
                end
            end

            if p.progress.checkpoint == totalCheckpoints then
                p.progress.checkpoint = 1
                p.progress.lap = p.progress.lap + 1
            else
                p.progress.checkpoint = p.progress.checkpoint + 1
            end

            if p.progress.lap > Lobby.laps and not p.progress.finished then
                p.progress.finished = true
                local totalTime = GetGameTimer() - p.progress.startTime
                
                local bestLap = p.progress.bestLap
                if Lobby.laps == 1 and totalTime > 0 then
                    bestLap = totalTime
                end
                
                table.insert(Lobby.finishOrder, { name = p.name, totalTime = totalTime, bestLap = bestLap })
                p.progress.place = #Lobby.finishOrder
                TriggerClientEvent('clappy_race:client:finishedRace', src, p.progress.place)
                
                if #Lobby.finishOrder == 1 then
                    for _, player in ipairs(Lobby.players) do
                        if not player.progress.finished and player.source ~= src then
                            TriggerClientEvent('clappy_race:client:startDnfTimer', player.source)
                        end
                    end
                end

                local allFinishedOrDnf = true
                for _, player in ipairs(Lobby.players) do
                    if not player.progress.finished and not Lobby.dnfPlayers[player.source] then 
                        allFinishedOrDnf = false; 
                        break 
                    end
                end

                if allFinishedOrDnf then
                    Lobby.status = 'finished'
                    TriggerEvent('clappy_race:server:endRace')
                end
            end
            return
        end
    end
end)

RegisterNetEvent('clappy_race:server:quitRace', function(playerId)
    local src = playerId or source
    if removePlayerFromLobby(src) then
        TriggerClientEvent('clappy_race:client:quitRace', src)
    end
end)


AddEventHandler('clappy_race:server:endRace', function()
    if #Lobby.finishOrder > 0 then
        local raceResult = {
            trackName = Config.RaceTrack.TrackName,
            date = os.date("%Y-%m-%d %H:%M"),
            laps = Lobby.laps,
            results = Lobby.finishOrder
        }
        table.insert(RaceHistory, 1, raceResult)
        
        while #RaceHistory > 10 do table.remove(RaceHistory) end
        saveHistory()
    end
    
    -- *** FIX: Add a delay to resetLobby to prevent UI race condition ***
    CreateThread(function()
        Wait(10000) -- Wait 10 seconds before resetting the lobby
        resetLobby()
    end)
end)

RegisterNetEvent('clappy_race:server:getHistory', function()
    TriggerClientEvent('clappy_race:client:showHistory', source, RaceHistory)
end)

AddEventHandler('QBCore:Player:Server:OnPlayerLogout', function(player)
    local src = player.PlayerData.source
    removePlayerFromLobby(src)
end)

-- =========================================================================
-- QBX VEHICLE KEY EVENTS
-- =========================================================================

-- Event to give keys to the player for their spawned race vehicle
RegisterNetEvent('clappy_race:server:giveRaceKeys', function(vehicleNetId)
    local src = source
    if Config.KeyScript ~= 'qbx' then return end

    -- *** FIX: Use NetworkGetEntityFromNetworkId instead of NetToVeh ***
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    
    if exports.qbx_vehiclekeys then
        exports.qbx_vehiclekeys:GiveKeys(src, vehicle, true) -- true = skip notification
        RaceVehicles[src] = vehicleNetId -- Store vehicle for later removal
    else
        print('[clappy_race] ERROR: Config.KeyScript is "qbx", but "qbx_vehiclekeys" export was not found on server!')
    end
end)

-- Event to remove keys from the player after the race
RegisterNetEvent('clappy_race:server:removeRaceKeys', function(vehicleNetId)
    local src = source
    if Config.KeyScript ~= 'qbx' then return end

    -- *** FIX: Use NetworkGetEntityFromNetworkId instead of NetToVeh ***
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    if exports.qbx_vehiclekeys then
        exports.qbx_vehiclekeys:RemoveKeys(src, vehicle, true) -- true = skip notification
    end
    RaceVehicles[src] = nil -- Clear stored vehicle
end)

