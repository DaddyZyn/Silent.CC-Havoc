--[[
    Zee Hood (ZHD) / Da Hood Environment & DataModel Diagnostic Dumper
    Dumps modules, remotes, replicated items, and tool properties into workspace/zhd_dump.json
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local function safeWrite(filename, content)
    local write = writefile or (syn and syn.writefile)
    if write then
        pcall(write, filename, content)
        print("[Dumper] Saved: " .. filename)
    else
        warn("[Dumper] writefile not supported on this executor.")
    end
end

local function scanRemotes()
    local remotes = {}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            table.insert(remotes, {
                Name = obj.Name,
                ClassName = obj.ClassName,
                FullName = obj:GetFullName()
            })
        end
    end
    return remotes
end

local function scanModules()
    local modules = {}
    local modFolder = ReplicatedStorage:FindFirstChild("Modules")
    local searchTargets = modFolder and modFolder:GetDescendants() or ReplicatedStorage:GetDescendants()
    
    for _, obj in ipairs(searchTargets) do
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
            end
            table.insert(modules, info)
        end
    end
    return modules
end

local function scanTools()
    local tools = {}
    local function inspectContainer(container, sourceName)
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local toolData = {
                    Name = item.Name,
                    Location = sourceName,
                    Attributes = item:GetAttributes(),
                    Values = {}
                }
                for _, desc in ipairs(item:GetDescendants()) do
                    if desc:IsA("ValueBase") then
                        toolData.Values[desc.Name] = tostring(desc.Value) .. " (" .. desc.ClassName .. ")"
                    end
                end
                table.insert(tools, toolData)
            end
        end
    end

    if LP:FindFirstChild("Backpack") then
        inspectContainer(LP.Backpack, "Backpack")
    end
    if LP.Character then
        inspectContainer(LP.Character, "Character")
    end
    local shopFolder = workspace:FindFirstChild("Ignored") or workspace:FindFirstChild("Shop")
    if shopFolder then
        inspectContainer(shopFolder, "WorldShop")
    end

    return tools
end

local function runDump()
    print("[Dumper] Starting Zee Hood diagnostic dump...")
    local report = {
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        Timestamp = os.time(),
        Remotes = scanRemotes(),
        Modules = scanModules(),
        Tools = scanTools()
    }

    local encoded = HttpService:JSONEncode(report)
    safeWrite("zhd_dump.json", encoded)
    print(string.format("[Dumper] Complete! Remotes: %d, Modules: %d, Tools: %d", #report.Remotes, #report.Modules, #report.Tools))
end

runDump()
