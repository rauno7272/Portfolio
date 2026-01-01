-- =================================================================
--  CONFIGURATION (MPH)
--  Define the max speed for each class that your function can return.
--  I've added the 'M' class for motorcycles.
-- =================================================================
local classSpeedLimits = {
    ['D'] = 90.0,
    ['C'] = 90.0,
    ['B'] = 110.0,
    ['A'] = 130.0,
    ['S'] = 150.0,
    ['S+'] = 180.0,
    ['M'] = 180.0, -- Class for Motorcycles
}

-- =================================================================
--  DYNAMIC CLASS CALCULATION FUNCTION (From your image)
--  This function calculates a performance rating and returns a class.
-- =================================================================
function getClass(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return "D" end

    -- Using the standard native GetVehicleHandlingFloat(vehicle, handling_class, property_name)
    local fInitialDriveMaxFlatVel = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
    local fInitialDriveForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
    local fDriveBiasFront = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveBiasFront")
    local fInitialDragCoeff = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDragCoeff")
    local fTractionCurveMax = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
    local fTractionCurveMin = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin")
    local fSuspensionReboundDamp = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSuspensionReboundDamp")
    local fBrakeForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")

    local force = fInitialDriveForce
    if fInitialDriveForce > 0 and fInitialDriveMaxFlatVel < 1 then
        force = force * 1.1
    end

    local accel = ((fInitialDriveMaxFlatVel * force) / 10)
    local speed = (((fInitialDriveMaxFlatVel / fInitialDragCoeff) * (fTractionCurveMax + fTractionCurveMin)) / 40)
    
    local isMotorCycle = (GetVehicleClass(vehicle) == 8)
    if isMotorCycle then
        speed = speed * 2
    end
    
    local handling = ((fTractionCurveMax + fSuspensionReboundDamp) * fTractionCurveMin)
    if isMotorCycle then
        handling = handling / 2
    end
    
    local braking = (((fTractionCurveMin / fInitialDragCoeff) * fBrakeForce) * 7)
    
    local perfRating = ((accel * 5) + speed + handling + braking) * 15
    local vehClass = "D"

    if isMotorCycle then
        vehClass = "M"
    elseif perfRating > 770 then
        vehClass = "S+"
    elseif perfRating > 525 then
        vehClass = "S"
    elseif perfRating > 410 then
        vehClass = "A"
    elseif perfRating > 310 then
        vehClass = "B"
    elseif perfRating > 210 then
        vehClass = "C"
    else
        vehClass = "D"
    end
    
    return vehClass
end

-- =================================================================
--  MAIN SCRIPT LOGIC
--  This loop runs, gets the vehicle's dynamic class, and applies the limit.
-- =================================================================
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Check every second is enough for this

        local playerPed = PlayerPedId()

        if IsPedInAnyVehicle(playerPed, false) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            -- Dynamically get the vehicle's class by calling your function
            local vehicleClass = getClass(vehicle)

            if vehicleClass then
                -- Find the speed limit in MPH for that class
                local speedLimitMph = classSpeedLimits[vehicleClass]

                if speedLimitMph then
                    -- Get current speed and convert it to MPH
                    local currentSpeedMph = GetEntitySpeed(vehicle) * 2.23694

                    -- We only need to apply the limit if the car is already over speed
                    if currentSpeedMph > speedLimitMph then
                        SetEntityMaxSpeed(vehicle, speedLimitMph / 2.23694)
                    end
                end
            end
        end
    end
end)