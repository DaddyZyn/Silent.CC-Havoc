--[[
    ========================================================================
    99 NIGHTS IN THE FOREST — DEEP DIAGNOSTIC DUMPER (Volt / Luau)
    Place ID: 79546208627805 | Universe ID: 7326934954
    Developer: Grandma's Favourite Games
    
    Extracts:
      1. Network Remotes (RemoteEvents, RemoteFunctions, UnreliableRemoteEvents, Bindables)
      2. ModuleScripts (Exported tables, function names, keys, dependencies)
      3. Items, Campfire, Structures, Fuel, Tools & Interactables (ProximityPrompts, ClickDetectors)
      4. Enemies, NPCs, Wildlife & Children (The Deer, Cultists, Wolves, Bears, Lost Children)
      5. Player Character & Inventory Attributes, Values, Leaderstats, Currency (Diamonds/Gems)
      6. Game State & Environment (Day/Night cycle timers, lighting settings, world folders)
    
    Saves automatically to: workspace/99_nights_dump.json
    ========================================================================
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LP = Players.LocalPlayer

local function safeWrite(filename, content)
    local write = writefile or (syn and syn.writefile)
    if write then
        local ok, err = pcall(write, filename, content)
        if ok then
            print(string.format("[Dumper] >>> Saved dump successfully to: %s", filename))
        else
            warn(string.format("[Dumper] Failed to write file %s: %s", filename, tostring(err)))
        end
    else
        warn("[Dumper] writefile function not supported on this executor.")
    end
end

local function cleanVal(v)
    local tv = typeof(v)
    if tv == "Vector3" then
        return string.format("Vector3(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
    elseif tv == "CFrame" then
        local p = v.Position
        return string.format("CFrame(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
    elseif tv == "Color3" then
        return string.format("RGB(%d, %d, %d)", math.floor(v.R * 255), math.floor(v.G * 255), math.floor(v.B * 255))
    elseif tv == "Instance" then
        return string.format("Instance(%s | %s)", v.ClassName, v.Name)
    elseif tv == "EnumItem" then
        return tostring(v)
    elseif tv == "table" then
        return "table"
    elseif tv == "function" then
        return "function"
    end
    return tostring(v)
end

-- 1. Scan Remotes across entire DataModel
local function scanRemotes()
    local remotes = {}
    local scanned = 0
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            scanned = scanned + 1
            local parentName = obj.Parent and obj.Parent.Name or "None"
            table.insert(remotes, {
                Name = obj.Name,
                ClassName = obj.ClassName,
                FullName = obj:GetFullName(),
                Parent = parentName
            })
        end
    end
    return remotes
end

-- 2. Scan & Inspect ModuleScripts (with safe require)
local function scanModules()
    local modules = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") then
            local info = {
                Name = obj.Name,
                FullName = obj:GetFullName(),
                ExportedKeys = {}
            }
            local ok, res = pcall(require, obj)
            if ok and type(res) == "table" then
                for k, v in pairs(res) do
                    table.insert(info.ExportedKeys, tostring(k) .. " (" .. typeof(v) .. ")")
                end
            elseif not ok then
                info.RequireError = tostring(res):sub(1, 100)
            end
            table.insert(modules, info)
        end
    end
    return modules
end

-- 3. Scan Tools & Inventory
local function scanTools()
    local tools = {}
    local function inspectContainer(container, loc)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local data = {
                    Name = item.Name,
                    Location = loc,
                    Attributes = {},
                    Values = {}
                }
                for k, v in pairs(item:GetAttributes()) do
                    data.Attributes[k] = cleanVal(v)
                end
                for _, desc in ipairs(item:GetDescendants()) do
                    if desc:IsA("ValueBase") then
                        data.Values[desc.Name] = cleanVal(desc.Value) .. " (" .. desc.ClassName .. ")"
                    end
                end
                table.insert(tools, data)
            end
        end
    end

    inspectContainer(LP:FindFirstChild("Backpack"), "Backpack")
    inspectContainer(LP.Character, "Character")
    return tools
end

-- 4. Scan Interactables (Campfire, Lost Children, Fuel, Chests, ProximityPrompts)
local function scanInteractables()
    local interactables = {}
    local promptCount = 0

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
            promptCount = promptCount + 1
            local parent = obj.Parent
            local model = parent and parent:FindFirstAncestorOfClass("Model") or parent
            local pos = Vector3.zero
            if parent and parent:IsA("BasePart") then
                pos = parent.Position
            elseif model and model.PrimaryPart then
                pos = model.PrimaryPart.Position
            end

            table.insert(interactables, {
                Type = obj.ClassName,
                ActionText = obj:IsA("ProximityPrompt") and obj.ActionText or "Click",
                ObjectText = obj:IsA("ProximityPrompt") and obj.ObjectText or parent.Name,
                Parent = parent and parent.Name or "Unknown",
                Model = model and model.Name or "Unknown",
                Position = cleanVal(pos),
                FullName = obj:GetFullName()
            })
            if promptCount >= 200 then break end
        end
    end
    return interactables
end

-- 5. Scan World Entities & Mobs (The Deer, Cultists, Wolves, Bears, Lost Children)
local function scanEntities()
    local entities = {}
    local commonMobKeywords = { "deer", "cultist", "wolf", "bear", "child", "kid", "lost", "boss", "juggernaut", "stalker", "enemy", "mob", "npc" }

    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model ~= LP.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local nameLower = model.Name:lower()
            local matched = false

            for _, kw in ipairs(commonMobKeywords) do
                if nameLower:find(kw) then
                    matched = true
                    break
                end
            end

            if hum or matched then
                local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
                local data = {
                    Name = model.Name,
                    ClassName = model.ClassName,
                    Health = hum and hum.Health or nil,
                    MaxHealth = hum and hum.MaxHealth or nil,
                    Position = root and cleanVal(root.Position) or "None",
                    Attributes = {},
                    Children = {}
                }
                for k, v in pairs(model:GetAttributes()) do
                    data.Attributes[k] = cleanVal(v)
                end
                for _, ch in ipairs(model:GetChildren()) do
                    if ch:IsA("ValueBase") then
                        data.Children[ch.Name] = cleanVal(ch.Value)
                    end
                end
                table.insert(entities, data)
            end
        end
    end
    return entities
end

-- 6. Scan Workspace Folders (Map, Loot, Spawns, Camp, Resource Nodes)
local function scanWorldStructure()
    local folders = {}
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Configuration") or (child:IsA("Model") and not child:FindFirstChildOfClass("Humanoid")) then
            local folderInfo = {
                Name = child.Name,
                ClassName = child.ClassName,
                ChildCount = #child:GetChildren(),
                SampleChildren = {}
            }
            local sample = child:GetChildren()
            for i = 1, math.min(10, #sample) do
                table.insert(folderInfo.SampleChildren, sample[i].Name .. " (" .. sample[i].ClassName .. ")")
            end
            table.insert(folders, folderInfo)
        end
    end
    return folders
end

-- 7. Scan LocalPlayer State, Attributes, & Leaderstats
local function scanPlayerState()
    local data = {
        Name = LP.Name,
        UserId = LP.UserId,
        Attributes = {},
        Values = {},
        Leaderstats = {}
    }
    for k, v in pairs(LP:GetAttributes()) do
        data.Attributes[k] = cleanVal(v)
    end
    if LP.Character then
        data.CharacterAttributes = {}
        for k, v in pairs(LP.Character:GetAttributes()) do
            data.CharacterAttributes[k] = cleanVal(v)
        end
    end
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, val in ipairs(ls:GetChildren()) do
            if val:IsA("ValueBase") then
                data.Leaderstats[val.Name] = cleanVal(val.Value)
            end
        end
    end
    return data
end

-- Main Execution Routine
local function main()
    print("=======================================================================")
    print("[Dumper] Starting 99 Nights in the Forest Diagnostic Recon...")
    print("=======================================================================")
    
    local report = {
        GameTitle = "99 Nights in the Forest",
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        JobId = game.JobId,
        Timestamp = os.time(),
        Lighting = {
            ClockTime = Lighting.ClockTime,
            TimeOfDay = Lighting.TimeOfDay,
            Brightness = Lighting.Brightness,
            FogEnd = Lighting.FogEnd
        },
        Player = scanPlayerState(),
        Remotes = scanRemotes(),
        Modules = scanModules(),
        Tools = scanTools(),
        Interactables = scanInteractables(),
        Entities = scanEntities(),
        WorldFolders = scanWorldStructure()
    }

    local json = HttpService:JSONEncode(report)
    safeWrite("99_nights_dump.json", json)

    print(string.format("[Dumper] Scan Finished!"))
    print(string.format("  - Remotes:        %d", #report.Remotes))
    print(string.format("  - Modules:        %d", #report.Modules))
    print(string.format("  - Tools:          %d", #report.Tools))
    print(string.format("  - Interactables:  %d", #report.Interactables))
    print(string.format("  - Entities/Mobs:  %d", #report.Entities))
    print(string.format("  - World Folders:  %d", #report.WorldFolders))
    print("=======================================================================")
end

main()
