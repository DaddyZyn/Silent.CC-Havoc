--!strict
--[[
    silent.cc - Havoc [Season 2] Controller
    Modular entry point requiring src/ui/library.luau
]]

local Library = require(script.Parent.ui.library)

local Window = Library.CreateWindow({
    Title = "silent.cc",
    Game = "Havoc",
    Link = "discord.gg/silentcc",
    Size = Vector2.new(680, 720),
    ToggleKey = Enum.KeyCode.RightShift,
})

local MainTab = Window:CreateTab("Main")
local AimbotGroup = MainTab:CreateGroupbox("Aimbot", "Left")
AimbotGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.E })
AimbotGroup:AddDropdown("Aim mode", { "Camera", "Mouse" }, "Camera")
AimbotGroup:AddDropdown("Aim part", { "Head", "Torso", "HumanoidRootPart" }, "Head")
AimbotGroup:AddSlider("Circle Size", 50, 500, 150)
AimbotGroup:AddSlider("Smoothing", 1, 100, 30)
AimbotGroup:AddSlider("Mouse Sensitivity", 10, 400, 100, "%")
AimbotGroup:AddToggle("Prediction", false)
AimbotGroup:AddSlider("Prediction X", 0, 50, 17, "%")
AimbotGroup:AddSlider("Prediction Y", 0, 50, 2, "%")
AimbotGroup:AddToggle("Sticky Aim", false)
AimbotGroup:AddSlider("Sticky Range", 100, 1000, 400)
AimbotGroup:AddToggle("Show Circle", false)
AimbotGroup:AddColorPicker("Circle Colour", Color3.fromRGB(0, 110, 255))
AimbotGroup:AddSlider("Circle Y Offset", 0, 60, 0)

local SilentGroup = MainTab:CreateGroupbox("Silent Aim", "Right")
SilentGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.Q })
SilentGroup:AddSlider("Circle Size", 50, 600, 300)
SilentGroup:AddDropdown("Hit limb", { "HumanoidRootPart", "Head", "Torso" }, "HumanoidRootPart")
SilentGroup:AddSlider("Hit Rate", 10, 100, 100, "%")
SilentGroup:AddToggle("Sticky Aim", false)
SilentGroup:AddSlider("Sticky Range", 100, 1000, 400)
SilentGroup:AddToggle("Show Circle", false)
SilentGroup:AddColorPicker("Circle Colour", Color3.fromRGB(0, 255, 170))
SilentGroup:AddSlider("Circle Y Offset", 0, 60, 0)

local EspTab = Window:CreateTab("Esp")
local PlayerEspGroup = EspTab:CreateGroupbox("Player ESP", "Left")
PlayerEspGroup:AddToggle("Enabled", false)
PlayerEspGroup:AddToggle("Box ESP", false)
PlayerEspGroup:AddToggle("Health Bar", false)
PlayerEspGroup:AddToggle("Name Tags", false)
PlayerEspGroup:AddToggle("Distance Tags", false)
PlayerEspGroup:AddToggle("Snapline Tracers", false)

local VisualsTab = Window:CreateTab("Visuals")
local ChamsGroup = VisualsTab:CreateGroupbox("Chams & Highlights", "Left")
ChamsGroup:AddToggle("Enable Chams", false)
ChamsGroup:AddColorPicker("Visible Color", Color3.fromRGB(120, 87, 255))
ChamsGroup:AddColorPicker("Hidden Color", Color3.fromRGB(255, 60, 60))

local CharTab = Window:CreateTab("Character")
local MovementGroup = CharTab:CreateGroupbox("Movement", "Left")
MovementGroup:AddToggle("WalkSpeed Override", false)
MovementGroup:AddSlider("Speed Value", 16, 100, 24, " studs")

local SettingsTab = Window:CreateTab("settings")
local ProfileGroup = SettingsTab:CreateGroupbox("Profile Manager", "Left")
ProfileGroup:AddButton("Save Default Config", function() end)
ProfileGroup:AddButton("Load Default Config", function() end)

return Window
