-- client/client.lua
local ox_inventory = exports.ox_inventory
local isVisionActive = false
local isToggling = false
local currentItemSlot = nil
local nvgScaleform = 0

---
-- Safely requests an animation dictionary and plays the animation.
---
local function tryPlayAnimation(ped, animation)
    RequestAnimDict(animation.dict)
    local timeout = 0
    while not HasAnimDictLoaded(animation.dict) and timeout < 1000 do
        Citizen.Wait(50)
        timeout = timeout + 50
    end

    if HasAnimDictLoaded(animation.dict) then
        local duration = GetAnimDuration(animation.dict, animation.name)
        TaskPlayAnim(ped, animation.dict, animation.name, 8.0, -8.0, -1, 16, 0, false, false, false)
        return duration * 1000
    end
    
    return 0
end

---
-- Turns on the night vision effect after a successful battery check.
---
local function ActivateGoggles()
    local playerPed = PlayerPedId()
    lib.notify({ title = 'NVG System', description = 'Equipping helmet...', type = 'inform' })
    local animTime = tryPlayAnimation(playerPed, Config.AnimationOn)
    
    Citizen.Wait(Config.HelmetOnDelay)
    SetPedPropIndex(playerPed, Config.Prop.propId, Config.Prop.drawable, Config.Prop.texture, true)
    Citizen.Wait(animTime - Config.HelmetOnDelay)
    
    SetNightvision(true)
    PlaySoundFrontend(-1, Config.SoundOn.name, Config.SoundOn.set, true)

    nvgScaleform = lib.requestScaleformMovie(Config.ScaleformName)
    isVisionActive = true
    lib.notify({ title = 'NVG System', description = 'Night vision activated.', type = 'success' })

    CreateThread(function()
        while isVisionActive do
            if nvgScaleform ~= 0 then
                DrawScaleformMovieFullscreen(nvgScaleform, 255, 255, 255, 255, 0)
            end
            Citizen.Wait(0)
        end
    end)

    -- Thread for the decay loop.
    CreateThread(function()
        while isVisionActive do
            Citizen.Wait(Config.DecayInterval)
            if isVisionActive and currentItemSlot then
                TriggerServerEvent('clappy_nightvision:decayGoggles', currentItemSlot)
            end
        end
    end)
end

---
-- Turns off the night vision effect.
---
local function DeactivateGoggles()
    if not isVisionActive then return end

    local playerPed = PlayerPedId()
    lib.notify({ title = 'NVG System', description = 'Removing helmet...', type = 'inform' })
    local animTime = tryPlayAnimation(playerPed, Config.AnimationOff)
    
    Citizen.Wait(Config.HelmetOffDelay)
    ClearPedProp(playerPed, Config.Prop.propId)
    Citizen.Wait(animTime - Config.HelmetOffDelay)
    
    SetNightvision(false)
    PlaySoundFrontend(-1, Config.SoundOff.name, Config.SoundOff.set, true)
    
    if nvgScaleform ~= 0 then
        SetScaleformMovieAsNoLongerNeeded(nvgScaleform)
        nvgScaleform = 0
    end

    isVisionActive = false
    currentItemSlot = nil
end

---
-- Main event triggered by ox_inventory when the item is used.
---
RegisterNetEvent('clappy_nightvision:useGoggles', function(data)
    local itemSlot = data.slot
    if isToggling then return end
    if isVisionActive and currentItemSlot ~= itemSlot then
        lib.notify({ title = 'NVG System', description = 'Another pair of goggles is already active.', type = 'warning' })
        return
    end

    isToggling = true

    if not isVisionActive then
        -- Turning ON: Ask the server if there's enough charge.
        lib.notify({ title = 'NVG System', description = 'Checking charge...', type = 'inform' })
        
        local hasCharge = lib.callback.await('clappy_nightvision:checkCharge', false, itemSlot)

        if hasCharge then
            currentItemSlot = itemSlot
            ActivateGoggles()
        else
            lib.notify({ title = 'NVG System', description = 'No charge remaining.', type = 'error' })
        end
    else
        -- Turning OFF: Just do it locally.
        DeactivateGoggles()
    end

    isToggling = false
end)

---
-- Event called by the server when charge reaches zero to force the goggles off.
---
RegisterNetEvent('clappy_nightvision:forceDeactivate', function()
    DeactivateGoggles()
end)

-- Clean up effects if the resource is stopped.
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DeactivateGoggles()
    end
end)
