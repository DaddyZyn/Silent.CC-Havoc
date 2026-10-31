--[[
    silent.cc Havoc Introspection & Structure Dumper
    Dumps:
    1. Network Remotes (RemoteEvents / RemoteFunctions) in ReplicatedStorage & Workspace
    2. Weapon & Ballistics ModuleScripts (scans require() return tables)
    3. Garbage Collector (getgc) search for weapon/damage tables
    4. LocalPlayer character bones and weapon instances
    5. Saves to havoc_dump.json and copies summary to clipboard
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Dump = {
    Timestamp = os.date("!%Y-%m-%d %H:%M:%SZ"),
    PlaceId = game.PlaceId,
    GameId = game.GameId,
    Remotes = {},
    WeaponModules = {},
    GCTables = {},
    CharacterRig = {},
    WorkspaceEntities = {},
}

local function getFullName(instance: Instance): string
    local names = {}
    local current: Instance? = instance
    while current and current ~= game do
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    return table.concat(names, ".")
end

-- =========================================================================
-- 1. REMOTE EVENTS & FUNCTIONS DUMP
-- =========================================================================
print("[silent.cc dumper] Scanning Network Remotes...")
local remoteCount = 0

local function scanRemotesIn(container: Instance)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            remoteCount += 1
            table.insert(Dump.Remotes, {
                Class = obj.ClassName,
                Name = obj.Name,
                Path = getFullName(obj),
            })
        end
    end
end

pcall(scanRemotesIn, ReplicatedStorage)
pcall(scanRemotesIn, Workspace)
if LocalPlayer then
    pcall(scanRemotesIn, LocalPlayer)
end

-- =========================================================================
-- 2. WEAPON & BALLISTICS MODULES SCAN
-- =========================================================================
print("[silent.cc dumper] Scanning Weapon & Client Modules...")
local moduleKeywords = {
    "gun", "weapon", "bullet", "ballistics", "damage", "hit", "recoil",
    "spread", "fire", "ammo", "reload", "inventory", "framework", "config", "client"
}

local function isRelevantModule(name: string): boolean
    local lower = string.lower(name)
    for _, kw in ipairs(moduleKeywords) do
        if string.find(lower, kw) then
            return true
        end
    end
    return false
end

local function scanModulesIn(container: Instance)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("ModuleScript") and isRelevantModule(obj.Name) then
            local moduleInfo = {
                Name = obj.Name,
                Path = getFullName(obj),
                DumpedKeys = {},
                RawTablePreview = {},
            }

            -- Safely attempt require
            local reqSuccess, reqResult = pcall(function()
                return require(obj :: any)
            end)

            if reqSuccess and typeof(reqResult) == "table" then
                for k, v in pairs(reqResult) do
                    table.insert(moduleInfo.DumpedKeys, tostring(k))
                    if typeof(v) ~= "function" and typeof(v) ~= "table" then
                        moduleInfo.RawTablePreview[tostring(k)] = tostring(v)
                    elseif typeof(v) == "table" then
                        local sub = {}
                        for sk, sv in pairs(v) do
                            if typeof(sv) ~= "function" and typeof(sv) ~= "table" then
                                sub[tostring(sk)] = tostring(sv)
                            end
                        end
                        moduleInfo.RawTablePreview[tostring(k)] = sub
                    end
                end
            end

            table.insert(Dump.WeaponModules, moduleInfo)
        end
    end
end

pcall(scanModulesIn, ReplicatedStorage)
if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") then
    pcall(scanModulesIn, LocalPlayer.PlayerScripts)
end

-- =========================================================================
-- 3. GC SCAN FOR WEAPON / BALLISTICS TABLES (getgc)
-- =========================================================================
local getgc = (rawget(getfenv(), "getgc") :: any)
if typeof(getgc) == "function" then
    print("[silent.cc dumper] Scanning Garbage Collector tables...")
    pcall(function()
        local gcItems = getgc(true)
        for _, item in ipairs(gcItems) do
            if typeof(item) == "table" then
                local isGunTable = false
                local preview = {}
                for k, v in pairs(item) do
                    local strKey = string.lower(tostring(k))
                    if strKey == "damage" or strKey == "firerate" or strKey == "recoil"
                       or strKey == "spread" or strKey == "muzzlevelocity" or strKey == "bulletspeed"
                       or strKey == "ammo" or strKey == "reloadtime" or strKey == "magsize" then
                        isGunTable = true
                    end
                    if typeof(v) ~= "function" and typeof(v) ~= "table" then
                        preview[tostring(k)] = tostring(v)
                    end
                end

                if isGunTable then
                    table.insert(Dump.GCTables, preview)
                end
            end
        end
    end)
end

-- =========================================================================
-- 4. CHARACTER RIG & BONES DUMP
-- =========================================================================
if LocalPlayer and LocalPlayer.Character then
    for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(Dump.CharacterRig, {
                Name = child.Name,
                Class = child.ClassName,
                Size = tostring(child.Size),
            })
        end
    end
end

-- =========================================================================
-- 5. SERIALIZE & EXPORT
-- =========================================================================
local json = HttpService:JSONEncode(Dump)

local writefile = (rawget(getfenv(), "writefile") :: any)
if typeof(writefile) == "function" then
    pcall(writefile, "havoc_dump.json", json)
    print("[silent.cc dumper] Successfully saved dump to: havoc_dump.json")
end

local setclipboard = (rawget(getfenv(), "setclipboard") :: any)
if typeof(setclipboard) == "function" then
    pcall(setclipboard, json)
    print("[silent.cc dumper] Dump copied to clipboard!")
end

print("--------------------------------------------------")
print(string.format("[silent.cc dumper] DUMP COMPLETE:\n- Remotes: %d\n- Modules: %d\n- GC Tables: %d\n- Bones: %d",
    #Dump.Remotes, #Dump.WeaponModules, #Dump.GCTables, #Dump.CharacterRig))
print("--------------------------------------------------")

return Dump
