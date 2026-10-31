--!strict
--[[
    silent.cc - Havoc [Season 2] Entry Point
    Engineered for tactical combat and ballistics management in Havoc.
]]

local Library = require(script.Parent.ui.library)

-- Master State Cache
local Config = {
    Combat = {
        SilentAim = false,
        TargetPart = "Head",
        FOVRadius = 120,
        PredictionMultiplier = 1.15,
        WallCheck = true,
        HitChance = 100,
        RecoilComp = 100,
        SpreadReduction = true,
        AutoShoot = false,
    },
    Visuals = {
        BoxESP = true,
        HealthBar = true,
        NameTag = true,
        DistanceTag = true,
        Tracers = false,
        TracerOrigin = "Bottom",
        Chams = false,
        WeaponESP = false,
    },
    Misc = {
        SpeedMultiplier = 16,
        FastReload = false,
        InfiniteStamina = false,
        UnlockFiremode = false,
    }
}

-- Initialize Havoc Obsidian Window
local Window = Library.CreateWindow({
    Title = "SILENT.CC",
    SubTitle = "HAVOC [S2]",
    Size = Vector2.new(680, 480),
    ToggleKey = Enum.KeyCode.RightShift,
})

-- =========================================================================
-- TAB 1: COMBAT
-- =========================================================================
local CombatTab = Window:CreateTab("Combat")

-- Combat Column 1: Silent Aim Core
local AimGroup = CombatTab:CreateGroupbox("Targeting Engine", "Left")

AimGroup:AddToggle("Enable Silent Aim", Config.Combat.SilentAim, function(val)
    Config.Combat.SilentAim = val
    Window:SetFooterStatus(val and "AIM ENGINE: ARMED" or "AIM ENGINE: STANDBY")
end)

AimGroup:AddDropdown("Target Bone", { "Head", "UpperTorso", "HumanoidRootPart", "Randomize" }, Config.Combat.TargetPart, function(part)
    Config.Combat.TargetPart = part
end)

AimGroup:AddSlider("FOV Radius", 30, 450, Config.Combat.FOVRadius, "px", function(val)
    Config.Combat.FOVRadius = val
end)

AimGroup:AddSlider("Lead Velocity Scale", 0, 300, 115, "%", function(val)
    Config.Combat.PredictionMultiplier = val / 100
end)

AimGroup:AddToggle("Visible Check Only", Config.Combat.WallCheck, function(val)
    Config.Combat.WallCheck = val
end)

-- Combat Column 2: Accuracy & Ballistics
local BallisticsGroup = CombatTab:CreateGroupbox("Ballistics Control", "Right")

BallisticsGroup:AddSlider("Hitchance", 10, 100, Config.Combat.HitChance, "%", function(val)
    Config.Combat.HitChance = val
end)

BallisticsGroup:AddSlider("Recoil Neutralizer", 0, 100, Config.Combat.RecoilComp, "%", function(val)
    Config.Combat.RecoilComp = val
end)

BallisticsGroup:AddToggle("Spread Nullification", Config.Combat.SpreadReduction, function(val)
    Config.Combat.SpreadReduction = val
end)

BallisticsGroup:AddToggle("Auto Fire Trigger", Config.Combat.AutoShoot, function(val)
    Config.Combat.AutoShoot = val
end)

-- =========================================================================
-- TAB 2: VISUALS
-- =========================================================================
local VisualsTab = Window:CreateTab("Visuals")

-- Visuals Column 1: Player ESP
local EspGroup = VisualsTab:CreateGroupbox("Player ESP", "Left")

EspGroup:AddToggle("Bounding 2D Box", Config.Visuals.BoxESP, function(val)
    Config.Visuals.BoxESP = val
end)

EspGroup:AddToggle("Health Bar Indicator", Config.Visuals.HealthBar, function(val)
    Config.Visuals.HealthBar = val
end)

EspGroup:AddToggle("Player Tags (Name)", Config.Visuals.NameTag, function(val)
    Config.Visuals.NameTag = val
end)

EspGroup:AddToggle("Distance Readout", Config.Visuals.DistanceTag, function(val)
    Config.Visuals.DistanceTag = val
end)

EspGroup:AddToggle("Snapline Tracers", Config.Visuals.Tracers, function(val)
    Config.Visuals.Tracers = val
end)

EspGroup:AddDropdown("Tracer Origin", { "Bottom", "Center", "Cursor" }, Config.Visuals.TracerOrigin, function(origin)
    Config.Visuals.TracerOrigin = origin
end)

-- Visuals Column 2: World & Models
local WorldGroup = VisualsTab:CreateGroupbox("World & Chams", "Right")

WorldGroup:AddToggle("Wall Chams (Highlight)", Config.Visuals.Chams, function(val)
    Config.Visuals.Chams = val
end)

WorldGroup:AddToggle("Dropped Weapons ESP", Config.Visuals.WeaponESP, function(val)
    Config.Visuals.WeaponESP = val
end)

-- =========================================================================
-- TAB 3: MISC
-- =========================================================================
local MiscTab = Window:CreateTab("Misc")

local PlayerModsGroup = MiscTab:CreateGroupbox("Player Physics", "Left")

PlayerModsGroup:AddSlider("WalkSpeed Override", 16, 50, Config.Misc.SpeedMultiplier, " studs", function(val)
    Config.Misc.SpeedMultiplier = val
end)

PlayerModsGroup:AddToggle("Infinite Stamina", Config.Misc.InfiniteStamina, function(val)
    Config.Misc.InfiniteStamina = val
end)

local GunModsGroup = MiscTab:CreateGroupbox("Weapon Handling", "Right")

GunModsGroup:AddToggle("Instant Tactical Reload", Config.Misc.FastReload, function(val)
    Config.Misc.FastReload = val
end)

GunModsGroup:AddToggle("Unlock Full-Auto Firemode", Config.Misc.UnlockFiremode, function(val)
    Config.Misc.UnlockFiremode = val
end)

-- =========================================================================
-- TAB 4: SETTINGS / CONFIGS
-- =========================================================================
local SettingsTab = Window:CreateTab("Settings")

local ConfigGroup = SettingsTab:CreateGroupbox("Profile Manager", "Left")

ConfigGroup:AddButton("Save Default Config", function()
    Window:SetFooterStatus("CONFIG: DEFAULT PROFILE SAVED")
end)

ConfigGroup:AddButton("Load Default Config", function()
    Window:SetFooterStatus("CONFIG: DEFAULT PROFILE LOADED")
end)

local SystemGroup = SettingsTab:CreateGroupbox("System / Unload", "Right")

SystemGroup:AddButton("Unload silent.cc", function()
    Window:SetFooterStatus("STATUS: UNLOADED")
    Window.ScreenGui:Destroy()
end)

Window:SetFooterStatus("INITIALIZED // READY FOR HAVOC")

return {
    Window = Window,
    Config = Config,
}
