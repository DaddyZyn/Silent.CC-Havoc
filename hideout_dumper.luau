--[[
    silent.cc - Havoc Hideout Deep Subsystem & Vault Dumper
    Dumps TraderStashRequest, InventoryFunction, Stash Data, Hideout Hierarchy,
    Client & Server Scripts, Remotes, GC Memory Tables, and Network Contracts.
    Built for Havoc PlaceId: 13927562399 (Hideout / Menu).
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
    Timestamp = os.date("!%Y-%m-%d %H:%M:%SZ"),
    PlaceId = game.PlaceId,
    GameId = game.GameId,
    LocalPlayer = LocalPlayer and LocalPlayer.Name or "Unknown",
    TraderStashRequest = {
        Found = false,
        Path = "",
        Type = "",
        Introspection = {},
    },
    InventoryRemotes = {},
    HideoutModules = {},
    TraderModules = {},
    StashDataStructures = {},
    GC_Vault_Tables = {},
    PlayerGui_HideoutTree = {},
}

-- 1. Introspect TraderStashRequest specifically
pcall(function()
    local stash = ReplicatedStorage:FindFirstChild("TraderStashRequest")
    if stash then
        dump.TraderStashRequest.Found = true
        dump.TraderStashRequest.Path = stash:GetFullName()
        dump.TraderStashRequest.Type = stash.ClassName

        -- Inspect attributes
        local attrs = {}
        for k, v in pairs(stash:GetAttributes()) do
            attrs[k] = tostring(v)
        end
        dump.TraderStashRequest.Attributes = attrs

        -- Search for any client scripts or modules that reference TraderStashRequest
        local getgc_fn = getgc or (getgenv and getgenv().getgc)
        local getconstants_fn = debug.getconstants or getconstants
        local getinfo_fn = debug.getinfo or getinfo

        if typeof(getgc_fn) == "function" and typeof(getconstants_fn) == "function" then
            for _, fn in ipairs(getgc_fn(false)) do
                if typeof(fn) == "function" and islclosure and islclosure(fn) then
                    local s = pcall(function()
                        local consts = getconstants_fn(fn)
                        for _, c in ipairs(consts) do
                            if tostring(c) == "TraderStashRequest" or tostring(c) == "TraderStashClose" then
                                local info = typeof(getinfo_fn) == "function" and getinfo_fn(fn) or {}
                                table.insert(dump.TraderStashRequest.Introspection, {
                                    Source = tostring(info.source),
                                    Name = tostring(info.name),
                                    LineDefined = info.linedefined,
                                    Constants = consts,
                                })
                                break
                            end
                        end
                    end)
                end
            end
        end
    end
end)

-- 2. Scan all Remotes related to Inventory, Stash, Traders, Vault, Economy
local function scanRemotes(container)
    for _, obj in ipairs(container:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            local lower = string.lower(obj.Name)
            local pathLower = string.lower(obj:GetFullName())
            if string.find(lower, "stash") or string.find(lower, "trader") or string.find(lower, "inv") or string.find(lower, "market") or string.find(lower, "item") or string.find(lower, "store") or string.find(lower, "vault") or string.find(pathLower, "stash") or string.find(pathLower, "trader") or string.find(pathLower, "inventory") then
                table.insert(dump.InventoryRemotes, {
                    Name = obj.Name,
                    Class = obj.ClassName,
                    Path = obj:GetFullName(),
                })
            end
        end
    end
end

pcall(scanRemotes, ReplicatedStorage)
if LocalPlayer then pcall(scanRemotes, LocalPlayer) end

-- 3. Scan ReplicatedStorage Modules for Hideout, Stash, Traders, Items
pcall(function()
    for _, mod in ipairs(ReplicatedStorage:GetDescendants()) do
        if mod:IsA("ModuleScript") then
            local lower = string.lower(mod.Name)
            local pathLower = string.lower(mod:GetFullName())

            if string.find(lower, "stash") or string.find(lower, "trader") or string.find(pathLower, "trader") then
                local dataPreview = nil
                -- Try requiring if safe
                pcall(function()
                    local res = require(mod)
                    if typeof(res) == "table" then
                        local keys = {}
                        for k, _ in pairs(res) do
                            table.insert(keys, tostring(k))
                        end
                        dataPreview = keys
                    end
                end)

                table.insert(dump.TraderModules, {
                    Name = mod.Name,
                    Path = mod:GetFullName(),
                    Keys = dataPreview,
                })
            elseif string.find(lower, "item") or string.find(lower, "weapon") or string.find(lower, "gear") or string.find(lower, "storage") then
                table.insert(dump.HideoutModules, {
                    Name = mod.Name,
                    Path = mod:GetFullName(),
                })
            end
        end
    end
end)

-- 4. GC Memory Table Scan for Stash/Vault Keys
pcall(function()
    local getgc_fn = getgc or (getgenv and getgenv().getgc)
    if typeof(getgc_fn) == "function" then
        local count = 0
        for _, t in ipairs(getgc_fn(true)) do
            if typeof(t) == "table" and count < 100 then
                local isMatch = false
                for k, _ in pairs(t) do
                    local strK = string.lower(tostring(k))
                    if strK == "stash" or strK == "traders" or strK == "inventory" or strK == "slots" or strK == "storage" or strK == "vault" then
                        isMatch = true
                        break
                    end
                end

                if isMatch then
                    count = count + 1
                    local preview = {}
                    for k, v in pairs(t) do
                        if typeof(v) == "string" or typeof(v) == "number" or typeof(v) == "boolean" then
                            preview[tostring(k)] = v
                        elseif typeof(v) == "table" then
                            local subKeys = {}
                            for sk, _ in pairs(v) do
                                table.insert(subKeys, tostring(sk))
                                if #subKeys >= 10 then break end
                            end
                            preview[tostring(k)] = subKeys
                        end
                    end
                    table.insert(dump.GC_Vault_Tables, preview)
                end
            end
        end
    end
end)

-- 5. PlayerGui Hideout Stash UI Tree
pcall(function()
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local lower = string.lower(gui.Name)
                if string.find(lower, "stash") or string.find(lower, "trader") or string.find(lower, "menu") or string.find(lower, "inv") or string.find(lower, "ui") then
                    local frames = {}
                    for _, f in ipairs(gui:GetDescendants()) do
                        if f:IsA("Frame") or f:IsA("ScrollingFrame") or f:IsA("TextButton") then
                            local fLower = string.lower(f.Name)
                            if string.find(fLower, "stash") or string.find(fLower, "vault") or string.find(fLower, "item") or string.find(fLower, "slot") or string.find(fLower, "grid") then
                                table.insert(frames, {
                                    Name = f.Name,
                                    Class = f.ClassName,
                                    Path = f:GetFullName(),
                                })
                            end
                        end
                    end
                    table.insert(dump.PlayerGui_HideoutTree, {
                        GuiName = gui.Name,
                        MatchedElements = frames,
                    })
                end
            end
        end
    end
end)

local rawJson = HttpService:JSONEncode(dump)
copyText(rawJson)

-- Save to executor workspace file if writefile exists
if typeof(writefile) == "function" then
    pcall(writefile, "havoc_hideout_dump.json", rawJson)
end

print("--------------------------------------------------")
print("[silent.cc] Havoc Hideout & TraderStashRequest Dump Complete!")
print(string.format("Remotes: %d | TraderModules: %d | GC Vault Tables: %d", #dump.InventoryRemotes, #dump.TraderModules, #dump.GC_Vault_Tables))
print("[+] Full JSON copied to clipboard and saved to havoc_hideout_dump.json")
print("--------------------------------------------------")
