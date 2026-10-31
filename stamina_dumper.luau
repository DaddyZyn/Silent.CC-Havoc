--[[
    silent.cc - Havoc Stamina & Movement Subsystem Dumper
    Dumps character scripts, attributes, values, player scripts, and memory tables
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local function copyText(str)
    local methods = {
        setclipboard,
        toclipboard,
        set_clipboard,
    }
    for _, fn in ipairs(methods) do
        if typeof(fn) == "function" then
            local s = pcall(fn, str)
            if s then return true end
        end
    end
    return false
end

local dump = {
    CharacterAttributes = {},
    CharacterChildren = {},
    CharacterScripts = {},
    PlayerScripts = {},
    RelevantModules = {},
    GC_Stamina_Matches = {},
}

-- 1. Character Attributes & Values
if LocalPlayer and LocalPlayer.Character then
    local char = LocalPlayer.Character
    for attr, val in pairs(char:GetAttributes()) do
        dump.CharacterAttributes[attr] = tostring(val)
    end

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("ValueObject") or obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("StringValue") or obj:IsA("BoolValue") then
            table.insert(dump.CharacterChildren, {
                Name = obj.Name,
                Class = obj.ClassName,
                Value = tostring(obj.Value),
                Path = obj:GetFullName(),
            })
        elseif obj:IsA("LocalScript") or obj:IsA("Script") or obj:IsA("ModuleScript") then
            table.insert(dump.CharacterScripts, {
                Name = obj.Name,
                Class = obj.ClassName,
                Path = obj:GetFullName(),
            })
        end
    end
end

-- 2. PlayerScripts
if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") then
    for _, s in ipairs(LocalPlayer.PlayerScripts:GetDescendants()) do
        if s:IsA("LocalScript") or s:IsA("ModuleScript") then
            local lower = string.lower(s.Name)
            if string.find(lower, "stamina") or string.find(lower, "move") or string.find(lower, "sprint") or string.find(lower, "char") or string.find(lower, "player") or string.find(lower, "client") then
                table.insert(dump.PlayerScripts, {
                    Name = s.Name,
                    Class = s.ClassName,
                    Path = s:GetFullName(),
                })
            end
        end
    end
end

-- 3. ReplicatedStorage Modules
for _, m in ipairs(ReplicatedStorage:GetDescendants()) do
    if m:IsA("ModuleScript") then
        local lower = string.lower(m.Name)
        if string.find(lower, "stamina") or string.find(lower, "energy") or string.find(lower, "sprint") or string.find(lower, "movement") or string.find(lower, "speed") then
            table.insert(dump.RelevantModules, {
                Name = m.Name,
                Path = m:GetFullName(),
            })
        end
    end
end

-- 4. GC Table Scanner (if getgc exists)
pcall(function()
    local getgc_fn = getgc or (getgenv and getgenv().getgc)
    if typeof(getgc_fn) == "function" then
        for _, t in ipairs(getgc_fn(true)) do
            if typeof(t) == "table" then
                for k, v in pairs(t) do
                    local strK = tostring(k)
                    local lower = string.lower(strK)
                    if lower == "stamina" or lower == "maxstamina" or lower == "energy" or lower == "sprintspeed" or lower == "walkspeed" then
                        table.insert(dump.GC_Stamina_Matches, {
                            Key = strK,
                            Value = tostring(v),
                        })
                        if #dump.GC_Stamina_Matches >= 15 then break end
                    end
                end
                if #dump.GC_Stamina_Matches >= 15 then break end
            end
        end
    end
end)

local json = HttpService:JSONEncode(dump)
copyText(json)
print("--------------------------------------------------")
print("[silent.cc] Havoc Stamina & Movement Dump Completed:")
print(json)
print("--------------------------------------------------")
print("[silent.cc] Dump copied to clipboard automatically!")
return json
