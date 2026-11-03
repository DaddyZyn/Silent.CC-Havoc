--[[
    snow.cc | Sniper Arena internals dumper
    Run it in-game (ideally in a match, and shoot / reload / jump a few times).
    Writes snowcc_dump.txt (structure + modules + weapon info) and
    snowcc_remotes.txt (live remote spy log) to your executor workspace folder.
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local OUT = "snowcc_dump.txt"
local SPY_OUT = "snowcc_remotes.txt"
local SPY_SECONDS = 120

local buffer = {}
local function w(s) buffer[#buffer + 1] = s end

local function save(name, lines)
    local text = table.concat(lines, "\n")
    if writefile then
        pcall(writefile, name, text)
    end
    return text
end

local function path(inst)
    local ok, r = pcall(function() return inst:GetFullName() end)
    return ok and r or tostring(inst)
end

local function ser(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then return string.format("%q", #v > 80 and v:sub(1, 80) .. "..." or v) end
    if t == "Instance" then return "<" .. v.ClassName .. " " .. path(v) .. ">" end
    if t == "table" then
        if depth >= 2 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 12 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = "[" .. ser(k, depth + 1) .. "]=" .. ser(x, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function tree(inst, indent, maxDepth, depth)
    depth = depth or 0
    if depth > maxDepth then return end
    local children = inst:GetChildren()
    for i, c in ipairs(children) do
        if i > 60 then
            w(indent .. "... (" .. (#children - 60) .. " more)")
            break
        end
        w(indent .. c.Name .. " [" .. c.ClassName .. "]")
        tree(c, indent .. "  ", maxDepth, depth + 1)
    end
end

local function section(title)
    w("")
    w("==================== " .. title .. " ====================")
end

-- 1. Basic info
section("GAME")
w("PlaceId: " .. game.PlaceId .. "  GameId: " .. game.GameId .. "  JobId: " .. game.JobId)
w("Executor: " .. tostring(identifyexecutor and select(1, identifyexecutor()) or "unknown"))
local caps = {}
for _, fn in ipairs({ "hookfunction", "hookmetamethod", "getgc", "getconnections", "getupvalues", "getconstants", "getnamecallmethod",
    "checkcaller", "newcclosure", "firesignal", "fireclickdetector", "mousemoverel", "mouse1click", "Drawing", "getrenv", "getsenv", "getloadedmodules", "decompile", "writefile", "setclipboard" }) do
    caps[#caps + 1] = fn .. "=" .. tostring(getfenv()[fn] ~= nil or (_G[fn] ~= nil))
end
w("Capabilities: " .. table.concat(caps, " "))

-- 2. ReplicatedStorage tree + remotes
section("REPLICATEDSTORAGE TREE")
tree(RS, "", 6)

section("ALL REMOTES")
for _, svc in ipairs({ RS, workspace, game:GetService("StarterPlayer"), game:GetService("ReplicatedFirst") }) do
    for _, d in ipairs(svc:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") or d:IsA("BindableEvent") then
            w(d.ClassName .. "  " .. path(d))
        end
    end
end

-- 3. Workspace overview
section("WORKSPACE (depth 2)")
tree(workspace, "", 2)

section("PLAYERS / CHARACTERS")
for _, p in ipairs(Players:GetPlayers()) do
    local c = p.Character
    w(p.Name .. " team=" .. tostring(p.Team) .. " char=" .. tostring(c and c.Name))
    if c then
        local attrs = {}
        for k, v in pairs(c:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
        w("  attrs: " .. table.concat(attrs, ", "))
        for _, ch in ipairs(c:GetChildren()) do
            w("  " .. ch.Name .. " [" .. ch.ClassName .. "]")
        end
    end
end

section("LOCAL PLAYER ATTRIBUTES / LEADERSTATS")
for k, v in pairs(LocalPlayer:GetAttributes()) do w(k .. " = " .. tostring(v)) end
for _, ch in ipairs(LocalPlayer:GetChildren()) do w(ch.Name .. " [" .. ch.ClassName .. "]") end

section("LOCAL PLAYER SCRIPTS (PlayerScripts + PlayerGui scripts)")
local ps = LocalPlayer:FindFirstChild("PlayerScripts")
if ps then tree(ps, "", 4) end
for _, d in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
    if d:IsA("LocalScript") or d:IsA("ModuleScript") then w(d.ClassName .. " " .. path(d)) end
end

-- 4. Tools / weapons the player holds
section("EQUIPPED TOOL / BACKPACK")
local function dumpTool(tool)
    w("Tool: " .. path(tool))
    for k, v in pairs(tool:GetAttributes()) do w("  attr " .. k .. " = " .. tostring(v)) end
    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("ValueBase") then
            w("  " .. path(d) .. " = " .. tostring(d.Value))
        elseif d:IsA("LuaSourceContainer") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            w("  " .. d.ClassName .. " " .. path(d))
        end
    end
end
if LocalPlayer.Character then
    for _, t in ipairs(LocalPlayer.Character:GetChildren()) do if t:IsA("Tool") then dumpTool(t) end end
end
for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do if t:IsA("Tool") then dumpTool(t) end end

-- 5. Modules: keys and function info
section("MODULESCRIPTS (require + shape)")
local seen = 0
for _, m in ipairs(RS:GetDescendants()) do
    if m:IsA("ModuleScript") and seen < 120 then
        seen = seen + 1
        local ok, res = pcall(require, m)
        if ok then
            if type(res) == "table" then
                local keys = {}
                for k, v in pairs(res) do
                    keys[#keys + 1] = tostring(k) .. ":" .. type(v) .. (type(v) ~= "table" and type(v) ~= "function" and ("=" .. ser(v)) or "")
                    if #keys >= 40 then keys[#keys + 1] = "..."; break end
                end
                w(path(m) .. "  {" .. table.concat(keys, ", ") .. "}")
            else
                w(path(m) .. "  " .. type(res))
            end
        else
            w(path(m) .. "  <require failed>")
        end
    end
end

-- 6. Interesting functions in memory
if getgc then
    section("GC: FUNCTIONS WITH GAMEPLAY-LIKE NAMES")
    local words = { "recoil", "spread", "reload", "ammo", "fire", "shoot", "damage", "raycast", "bullet", "hit", "jump", "sprint", "stamina", "fall" }
    local count = 0
    local ok = pcall(function()
        for _, f in ipairs(getgc(true)) do
            if type(f) == "function" and not (iscclosure and iscclosure(f)) then
                local info = debug.getinfo(f)
                local n = (info and info.name or ""):lower()
                if n ~= "" then
                    for _, word in ipairs(words) do
                        if n:find(word, 1, true) then
                            count = count + 1
                            if count <= 150 then
                                w(string.format("%s  (%s:%d)", info.name, tostring(info.short_src), info.linedefined or 0))
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
    if not ok then w("getgc scan failed") end

    section("GC: TABLES WITH GAMEPLAY-LIKE KEYS (weapon / config tables)")
    local keysOfInterest = { "Recoil", "Spread", "FireRate", "Damage", "ReloadTime", "MaxAmmo", "Ammo", "Range", "BulletSpeed", "Accuracy" }
    local found = 0
    pcall(function()
        for _, t in ipairs(getgc(true)) do
            if type(t) == "table" and found < 40 then
                local hit = 0
                for _, k in ipairs(keysOfInterest) do
                    if rawget(t, k) ~= nil then hit = hit + 1 end
                end
                if hit >= 2 then
                    found = found + 1
                    w(ser(t))
                end
            end
        end
    end)
end

-- Write the static dump
local dumpText = save(OUT, buffer)
if setclipboard and not writefile then setclipboard(dumpText) end
print(("[snow.cc dumper] static dump written to %s (%d lines)"):format(OUT, #buffer))

-- 7. Remote spy
local spyLog = {}
local seenKey = {}
local function logCall(kind, remote, args)
    local key = path(remote)
    seenKey[key] = (seenKey[key] or 0) + 1
    if seenKey[key] > 25 then return end
    local parts = {}
    for i = 1, math.min(#args, 8) do parts[#parts + 1] = ser(args[i]) end
    spyLog[#spyLog + 1] = string.format("[%.1f] %s %s (%s)", os.clock(), kind, key, table.concat(parts, ", "))
end

if hookmetamethod and getnamecallmethod then
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" then
            local args = table.pack(...)
            pcall(logCall, m, self, args)
        end
        return old(self, ...)
    end)
    print(("[snow.cc dumper] remote spy active for %ds - shoot, reload, jump, sprint, swap weapons"):format(SPY_SECONDS))
else
    print("[snow.cc dumper] hookmetamethod unavailable, remote spy skipped")
end

-- Incoming remotes
for _, d in ipairs(RS:GetDescendants()) do
    if d:IsA("RemoteEvent") then
        pcall(function()
            d.OnClientEvent:Connect(function(...)
                local args = table.pack(...)
                local key = "IN " .. path(d)
                seenKey[key] = (seenKey[key] or 0) + 1
                if seenKey[key] <= 10 then
                    local parts = {}
                    for i = 1, math.min(#args, 6) do parts[#parts + 1] = ser(args[i]) end
                    spyLog[#spyLog + 1] = string.format("[%.1f] OnClientEvent %s (%s)", os.clock(), path(d), table.concat(parts, ", "))
                end
            end)
        end)
    end
end

task.spawn(function()
    local t0 = os.clock()
    while os.clock() - t0 < SPY_SECONDS do
        task.wait(5)
        save(SPY_OUT, spyLog)
    end
    save(SPY_OUT, spyLog)
    print(("[snow.cc dumper] spy finished, %d entries saved to %s"):format(#spyLog, SPY_OUT))
end)
