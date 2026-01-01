-- config.lua

Config = {}

Config.Prop = { propId = 0, drawable = 116, texture = 0 }
Config.AnimationOn = { dict = "veh@common@fp_helmet@", name = "put_on_helmet" }
Config.AnimationOff = { dict = "veh@common@fp_helmet@", name = "take_off_helmet_stand" }
Config.SoundOn = { name = "Turn", set = "DLC_HEIST_HACKING_SNAKE_SOUNDS" }
Config.SoundOff = { name = "Power_Down", set = "DLC_HEIST_HACKING_SNAKE_SOUNDS" }
Config.ScaleformName = 'BINOCULARS'
Config.HelmetOnDelay = 1800
Config.HelmetOffDelay = 600

-- Durability & Recharge Settings
Config.GogglesItemName = 'nightvision_goggles'
Config.BatteryItemName = 'battery'
Config.DecayAmount = 1 -- The percentage of charge to remove per interval.
Config.DecayInterval = 1 * 60 * 1000 -- The time between each decay cycle in milliseconds (1 * 60 * 1000 = 1 minute).
Config.RechargeAmount = 50 -- The amount of charge a single battery restores.
