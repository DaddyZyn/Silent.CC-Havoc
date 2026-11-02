--!nocheck
--[[
    snow.cc | Havoc Weapon & Controller Deep Inspector
    Dumps character weapon controllers, modules, getsenv, upvalues, and ammo/firerate tables.
    Outputs structured report to "havoc_weapon_dump.txt".
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local function log(s)
    print("[snow.cc-inspector] " .. tostring(s))
end

local function saveToFile(filename, content)
    local fn = writefile or (getgenv and getgenv().writefile)
    if typeof(fn) == "function" then
        local ok, err = pcall(fn, filename, content)
        if ok then
            log("Saved dump to: " .. filename)
            return true
        else
            log("Error writing file: " .. tostring(err))
        end
    else
        log("writefile is not supported in this executor environment")
    end
    return false
end

local dumpLines = {}
local function addLine(line)
    table.insert(dumpLines, line or "")
end

addLine("=====================================================================")
addLine("snow.cc - Havoc Weapon & Controller Diagnostic Dump")
addLine("PlaceId: " .. tostring(game.PlaceId) .. " | JobId: " .. tostring(game.JobId))
addLine("Timestamp: " .. os.date("!%Y-%m-%d %H:%M:%SZ"))
addLine("=====================================================================\n")

if not (LocalPlayer and LocalPlayer.Character) then
    addLine("[!] Error: LocalPlayer or Character not found. Ensure you are spawned in the lobby/hideout.")
    local finalReport = table.concat(dumpLines, "\n")
    saveToFile("havoc_weapon_dump.txt", finalReport)
    return
end

local char = LocalPlayer.Character
addLine("[Character]: " .. char:GetFullName())

-- 1. Character Attributes
addLine("\n--- Character Attributes ---")
local charAttrs = char:GetAttributes()
for k, v in pairs(charAttrs) do
    addLine(string.format("  [%s] = %s (%s)", tostring(k), tostring(v), typeof(v)))
end

-- 2. Equipped Tools & Backpack Items
addLine("\n--- Equipped Tools & Backpack Items ---")
local tools = {}
for _, child in ipairs(char:GetChildren()) do
    if child:IsA("Tool") then
        table.insert(tools, { Tool = child, Location = "Character" })
    end
end
if LocalPlayer:FindFirstChild("Backpack") then
    for _, child in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if child:IsA("Tool") then
            table.insert(tools, { Tool = child, Location = "Backpack" })
        end
    end
end

if #tools == 0 then
    addLine("  [Notice] No equipped Tool or Backpack weapons detected. If weapons are stored in a custom container, checking character hierarchy...")
else
    for _, item in ipairs(tools) do
        local t = item.Tool
        addLine(string.format("  * Tool: %s (Location: %s)", t.Name, item.Location))
        local attrs = t:GetAttributes()
        for ak, av in pairs(attrs) do
            addLine(string.format("      Attribute [%s] = %s", tostring(ak), tostring(av)))
        end
        for _, desc in ipairs(t:GetChildren()) do
            if desc:IsA("ValueBase") then
                addLine(string.format("      ValueBase [%s (%s)] = %s", desc.Name, desc.ClassName, tostring(desc.Value)))
            end
        end
    end
end

-- 3. Scripts Inspection (getsenv & environments)
addLine("\n--- Character Scripts & Environment Scan ---")
local getsenv_fn = getsenv or (getgenv and getgenv().getsenv)
local getupvals_fn = debug.getupvalues or getupvalues
local getconsts_fn = debug.getconstants or getconstants
local getgc_fn = getgc or (getgenv and getgenv().getgc)

local weaponKeywords = {
    "ammo", "mag", "clip", "bullet", "round", "capacity",
    "rate", "rpm", "delay", "cooldown", "interval", "firerate", "cadence",
    "reload", "reloading", "spread", "recoil", "damage", "velocity"
}

local function matchesKeyword(str)
    local lower = string.lower(tostring(str))
    for _, kw in ipairs(weaponKeywords) do
        if string.find(lower, kw, 1, true) then
            return true, kw
        end
    end
    return false, nil
end

local allScripts = {}
for _, desc in ipairs(char:GetDescendants()) do
    if desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
        table.insert(allScripts, desc)
    end
end

addLine(string.format("Found %d LocalScripts/ModuleScripts under Character.", #allScripts))

for _, scr in ipairs(allScripts) do
    addLine(string.format("\n[Script]: %s (%s)", scr:GetFullName(), scr.ClassName))

    -- If LocalScript, inspect via getsenv
    if scr:IsA("LocalScript") and typeof(getsenv_fn) == "function" then
        local ok, env = pcall(getsenv_fn, scr)
        if ok and type(env) == "table" then
            addLine("  [getsenv Variables]:")
            local matchedCount = 0
            for k, v in pairs(env) do
                local match, kw = matchesKeyword(k)
                if match or type(v) == "table" or type(v) == "number" then
                    local valStr = tostring(v)
                    if type(v) == "table" then
                        local keys = {}
                        for tk, _ in pairs(v) do
                            table.insert(keys, tostring(tk))
                            if #keys >= 8 then break end
                        end
                        valStr = "Table { " .. table.concat(keys, ", ") .. " }"
                    end
                    addLine(string.format("    - %s (%s) = %s", tostring(k), typeof(v), valStr))
                    matchedCount = matchedCount + 1
                end
            end
            if matchedCount == 0 then
                addLine("    (No matching weapon variables directly in top-level env)")
            end
        else
            addLine("  [getsenv] Failed or unavailable for this script")
        end
    end

    -- If ModuleScript, attempt require safely
    if scr:IsA("ModuleScript") then
        local ok, mod = pcall(function() return require(scr) end)
        if ok and type(mod) == "table" then
            addLine("  [require() Table Keys]:")
            for k, v in pairs(mod) do
                local match, kw = matchesKeyword(k)
                local valStr = tostring(v)
                if type(v) == "table" then
                    local subkeys = {}
                    for subk, _ in pairs(v) do
                        table.insert(subkeys, tostring(subk))
                        if #subkeys >= 8 then break end
                    end
                    valStr = "Table { " .. table.concat(subkeys, ", ") .. " }"
                end
                addLine(string.format("    - %s (%s) = %s", tostring(k), typeof(v), valStr))
            end
        else
            addLine("  [require()] Not accessible or module returned non-table")
        end
    end
end

-- 4. Deep Upvalues & Constants Analysis via getgc
addLine("\n--- Deep Upvalues & Constants Search (Matching Weapon Signatures) ---")
if typeof(getgc_fn) == "function" and typeof(getupvals_fn) == "function" then
    local matchesFound = 0
    for _, obj in ipairs(getgc_fn(false)) do
        if typeof(obj) == "function" and (not islclosure or islclosure(obj)) then
            local fnEnv = pcall(getfenv, obj) and getfenv(obj)
            local ownerScript = fnEnv and fnEnv.script
            if ownerScript and typeof(ownerScript) == "Instance" and ownerScript:IsDescendantOf(char) then
                local upvals = getupvals_fn(obj)
                for idx, u in pairs(upvals) do
                    local match, kw = matchesKeyword(idx)
                    if not match and (type(u) == "string" or type(u) == "number") then
                        match, kw = matchesKeyword(u)
                    end

                    if match then
                        matchesFound = matchesFound + 1
                        addLine(string.format("  Function in [%s] -> Upval [%s] (%s) = %s (Keyword: %s)",
                            ownerScript.Name, tostring(idx), typeof(u), tostring(u), tostring(kw)))
                        if matchesFound >= 50 then
                            addLine("  ... (Clamped output at 50 matched upvalues)")
                            break
                        end
                    end
                end
                if matchesFound >= 50 then break end
            end
        end
    end
    if matchesFound == 0 then
        addLine("  No direct script upvalues matched weapon keyword signatures.")
    end
else
    addLine("  getgc or debug.getupvalues unavailable.")
end

-- 5. Outgoing Remotes Map
addLine("\n--- Communication & Weapon Remotes in ReplicatedStorage ---")
local repStorage = game:GetService("ReplicatedStorage")
local comm = repStorage:FindFirstChild("Communication") or repStorage:FindFirstChild("Remotes") or repStorage:FindFirstChild("Events")
if comm then
    for _, desc in ipairs(comm:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") or desc:IsA("UnreliableRemoteEvent") then
            addLine(string.format("  Remote: %s (%s)", desc:GetFullName(), desc.ClassName))
        end
    end
else
    addLine("  No standard Communication/Remotes folder found; scanning top-level ReplicatedStorage...")
    for _, child in ipairs(repStorage:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
            addLine(string.format("  Remote: %s (%s)", child.Name, child.ClassName))
        end
    end
end

addLine("\n=====================================================================")
addLine("Diagnostic dump complete.")
addLine("=====================================================================")

local finalReport = table.concat(dumpLines, "\n")
saveToFile("havoc_weapon_dump.txt", finalReport)
log("Scan finished! Check 'havoc_weapon_dump.txt' in your executor workspace folder.")
