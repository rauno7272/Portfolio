Config = {}

-- =========================================================================
-- Key Script Compatibility
-- =========================================================================
-- Set this to match the key script you are using on your server.
-- Options: 'qbx', 'qs', 'custom'
Config.KeyScript = 'qs'

-- =========================================================================
-- Target & Blip Configuration
-- =========================================================================

-- This is where the race lobby will be accessed from.
Config.TargetPoint = {
    coords = vector3(873.3, 2356.56, 51.7),
    size = { x = 2.0, y = 2.0, z = 2.0 }
}

-- Target Options for ox_target
Config.TargetOptions = {
    {
        name = 'create_lobby',
        label = 'Create Race Lobby',
        icon = 'fas fa-plus',
        event = 'clappy_race:client:openLobbyPrompt',
        metadata = { intent = 'create' } -- Pass intent to client
    },
    {
        name = 'join_lobby',
        label = 'Join Race Lobby',
        icon = 'fas fa-sign-in-alt',
        event = 'clappy_race:client:openLobbyPrompt',
        metadata = { intent = 'join' } -- Pass intent to client
    },
    {
        name = 'view_history',
        label = 'View Race History',
        icon = 'fas fa-history',
        event = 'clappy_race:server:getHistory'
    }
}

-- Blip Configuration for the Target Point
Config.Blip = {
    label = "Dirtbike Races",
    sprite = 315,
    display = 2,
    scale = 0.8,
    color = 1,
}

-- =========================================================================
-- Race & Vehicle Configuration
-- =========================================================================

-- List of allowed vehicles for the race.
Config.Vehicles = {
    { spawncode = 'sanchez', label = 'Maibatsu Sanchez' },
    { spawncode = 'manchez', label = 'Maibatsu Manchez' },
    { spawncode = 'bf400', label = 'BF400' },
    { spawncode = 'blazer', label = 'Nagasaki Blazer' },
}

-- Race Track Configuration
Config.RaceTrack = {
    TrackName = "Redwood racetrack",

    -- DNF (Did Not Finish) Timer in seconds.
    -- This timer starts for all other racers after the first person finishes.
    DNFTimer = 120,

    StartPositions = {
        vector4(894.0, 2420.94, 49.75, 13.89),
        vector4(890.14, 2420.01, 49.85, 12.17),
        vector4(891.1, 2415.29, 49.85, 10.16),
        vector4(893.77, 2415.89, 49.76, 9.36),
        vector4(895.66, 2411.96, 49.75, 7.96),
        vector4(898.34, 2412.54, 49.75, 7.96),
        vector4(900.23, 2408.61, 49.75, 7.96),
        vector4(898.59, 2407.99, 49.96, 13.66),
        vector4(893.85, 2406.84, 49.81, 9.45),
        vector4(891.21, 2406.22, 49.81, 9.45),
    },
    Checkpoints = {
        vector3(889.14, 2435.81, 49.87),
        vector3(971.54, 2460.99, 50.11),
        vector3(1025.92, 2439.76, 44.41),
        vector3(1101.27, 2465.9, 49.21),
        vector3(1164.98, 2363.33, 57.02),
        vector3(1167.86, 2279.59, 51.53),
        vector3(1139.12, 2343.15, 53.84),
        vector3(1119.15, 2452.05, 50.63),
        vector3(1022.08, 2409.05, 55.43),
        vector3(950.09, 2386.98, 48.34),
        vector3(981.93, 2335.46, 48.3),
        vector3(938.45, 2291.8, 45.12),
        vector3(1002.0, 2253.78, 46.61),
        vector3(1113.76, 2248.73, 49.02),
        vector3(1148.66, 2218.96, 49.01),
        vector3(1146.1, 2156.71, 52.7),
        vector3(1091.89, 2170.65, 53.22),
        vector3(1087.86, 2211.9, 48.21),
        vector3(1027.98, 2188.63, 44.75),
        vector3(966.34, 2239.16, 46.21),
        vector3(898.54, 2326.43, 49.04),
    },

    -- Configuration for the new CreateCheckpoint native
    NewCheckpoint = {
        type = 14, -- Cylinder with arrow
        finishType = 21, -- Cylinder with checkered flag
        diameter = 15.0,
        height = 5.0,
        color = { r = 0, g = 150, b = 255, a = 100 },
    }
}

