-- server/server.lua
local ox_inventory = exports.ox_inventory

---
-- This callback is triggered by the client to check if the goggles have charge.
---
lib.callback.register('clappy_nightvision:checkCharge', function(source, itemSlot)
    local PlayerInventory = ox_inventory:GetInventory(source)
    if not PlayerInventory or not PlayerInventory.items[itemSlot] then return false end

    local item = PlayerInventory.items[itemSlot]
    local durability = (item.metadata and item.metadata.durability) or item.durability or 100

    return durability > 0
end)

---
-- This event is called by the client's timer loop to decay the charge.
---
RegisterNetEvent('clappy_nightvision:decayGoggles', function(itemSlot)
    local src = source
    local PlayerInventory = ox_inventory:GetInventory(src)
    if not PlayerInventory or not PlayerInventory.items[itemSlot] then return end

    local item = PlayerInventory.items[itemSlot]
    local durability = (item.metadata and item.metadata.durability) or item.durability or 100

    durability = durability - Config.DecayAmount
    if durability < 0 then durability = 0 end

    local newMetadata = item.metadata or {}
    newMetadata.durability = durability
    ox_inventory:SetMetadata(src, itemSlot, newMetadata)

    if durability <= 0 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'NVG System', description = 'The goggles have run out of power!', type = 'error' })
        TriggerClientEvent('clappy_nightvision:forceDeactivate', src)
    end
end)
