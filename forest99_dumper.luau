--[[ snow.cc | 99 Nights dumper - confirms paths, remotes and call signatures.
     Run in-game (ideally near the campfire). Writes to the executor workspace:
       forest99_confirm.txt  - remotes, world, mobs, items, named structures, player, lighting
       forest99_calls.txt    - decompiled source lines that call the remotes (real argument shapes)
]]
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

local out, calls = {}, {}
local function w(s) out[#out + 1] = s end
local function sec(s) w(""); w("=== " .. s .. " ===") end
local function path(i) local ok, p = pcall(function() return i:GetFullName() end) return ok and p or tostring(i) end
local function pos(i)
    local ok, p = pcall(function()
        if i:IsA("BasePart") then return i.Position end
        if i:IsA("Model") then return i:GetPivot().Position end
        local a = i.Parent
        if a and a:IsA("Attachment") then return a.WorldPosition end
    end)
    if ok and p then return string.format("(%d, %d, %d)", p.X, p.Y, p.Z) end
    return "?"
end

w("PlaceId " .. game.PlaceId .. " | JobId " .. tostring(game.JobId))

-- 1. Expected remotes
sec("EXPECTED REMOTES")
local RE = RS:FindFirstChild("RemoteEvents")
w("ReplicatedStorage.RemoteEvents: " .. (RE and "FOUND" or "MISSING"))
local expected = {
    "ToolDamageObject", "RegisterProjectile", "ProjectileDamageEnemy", "ExplosiveProjectileDamageEnemy",
    "DamagePlayer", "HurtDeerTorch", "MonsterHitByTorch", "RequestBurnItem", "BurnItemInFire",
    "RequestConsumeItem", "RequestPullSawmillLever", "RequestClearWeather", "RequestRepairAlienShip",
    "ClaimAlienItem", "AttemptGiveKidItem", "SelectKidTask", "FadeOutFogBlock", "MapCellsDiscovered",
    "ClaimPrizeBoothReward", "CarnivalCompleteShootingGallery", "CarnivalCompleteBasketballGallery",
    "CarnivalCompleteRingToss", "RequestPullAlienAirlockLever", "RequestPullAlienPrisonLever",
}
for _, n in ipairs(expected) do
    local r = RE and RE:FindFirstChild(n)
    if not r then
        for _, d in ipairs(RS:GetDescendants()) do
            if d.Name == n then r = d break end
        end
    end
    w(string.format("%-36s %s", n, r and (r.ClassName .. "  " .. path(r)) or "MISSING"))
end

sec("ALL REMOTES")
for _, d in ipairs(RS:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
        w(d.ClassName .. "  " .. path(d))
    end
end

-- 2. World
sec("WORKSPACE CHILDREN")
for _, c in ipairs(Workspace:GetChildren()) do
    w(string.format("%-28s %-14s children=%d", c.Name, c.ClassName, #c:GetChildren()))
end

local function distinct(folder, label)
    sec(label)
    if not folder then w("MISSING") return end
    local seen, order = {}, {}
    for _, c in ipairs(folder:GetChildren()) do
        local k = c.Name .. "|" .. c.ClassName
        if not seen[k] then
            seen[k] = { n = 0, c = c }
            order[#order + 1] = k
        end
        seen[k].n = seen[k].n + 1
    end
    table.sort(order)
    for _, k in ipairs(order) do
        local e = seen[k]
        local hum = e.c:FindFirstChildOfClass("Humanoid") and "Humanoid" or "noHum"
        local root = e.c:IsA("Model") and (e.c.PrimaryPart and "PrimaryPart" or (e.c:FindFirstChild("HumanoidRootPart") and "HRP" or "noRoot")) or "-"
        w(string.format("%-32s x%-3d %-10s %s %s attrs=%d", e.c.Name, e.n, e.c.ClassName, hum, root, (function() local n = 0 for _ in pairs(e.c:GetAttributes()) do n = n + 1 end return n end)()))
    end
end
distinct(Workspace:FindFirstChild("Characters"), "Workspace.Characters (distinct)")
distinct(Workspace:FindFirstChild("Items"), "Workspace.Items (distinct)")
distinct(Workspace:FindFirstChild("Structures"), "Workspace.Structures (distinct)")

-- 3. Named structures
sec("NAMED STRUCTURES (first 8 per keyword)")
local keys = { "campfire", "fire", "trader", "sawmill", "stronghold", "carnival", "alien", "crafting", "bench", "chest", "scrap", "lost child", "deer", "tree" }
local hits = {}
for _, k in ipairs(keys) do hits[k] = {} end
for _, d in ipairs(Workspace:GetDescendants()) do
    if d:IsA("Model") or d:IsA("BasePart") then
        local n = string.lower(d.Name)
        for _, k in ipairs(keys) do
            if #hits[k] < 8 and n:find(k, 1, true) then
                hits[k][#hits[k] + 1] = d
            end
        end
    end
end
for _, k in ipairs(keys) do
    w("-- " .. k)
    for _, d in ipairs(hits[k]) do w(string.format("   %s %s %s", d.ClassName, path(d), pos(d))) end
end

sec("PROXIMITY PROMPTS (first 60)")
local pc = 0
for _, d in ipairs(Workspace:GetDescendants()) do
    if d:IsA("ProximityPrompt") then
        pc = pc + 1
        if pc <= 60 then w(string.format("%s | %s | %s", d.ActionText, path(d), pos(d))) end
    end
end

-- 4. Player
sec("PLAYER")
for k, v in pairs(LP:GetAttributes()) do w("LP attr " .. k .. " = " .. tostring(v)) end
local ch = LP.Character
if ch then
    for k, v in pairs(ch:GetAttributes()) do w("Char attr " .. k .. " = " .. tostring(v)) end
    for _, c in ipairs(ch:GetChildren()) do w("Char child " .. c.ClassName .. " " .. c.Name) end
end
for _, cn in ipairs({ "Backpack", "Inventory" }) do
    local c = LP:FindFirstChild(cn)
    w(cn .. ": " .. (c and "present" or "missing"))
    if c then
        for _, i in ipairs(c:GetChildren()) do w("   " .. i.ClassName .. " " .. i.Name) end
    end
end

-- 5. Lighting
sec("LIGHTING")
for _, p in ipairs({ "Brightness", "ClockTime", "FogStart", "FogEnd", "GlobalShadows", "Ambient", "OutdoorAmbient" }) do
    w(p .. " = " .. tostring(Lighting[p]))
end
for _, c in ipairs(Lighting:GetChildren()) do w("child " .. c.ClassName .. " " .. c.Name) end

-- 6. Call sites (needs decompile)
local decompileFn = decompile or (getgenv and getgenv().decompile)
local searchNames = {}
for _, n in ipairs(expected) do searchNames[#searchNames + 1] = n end
searchNames[#searchNames + 1] = "RequestCollectCoints"
sec("CALL-SITE SCAN")
if not decompileFn then
    w("decompile() unavailable - skipped")
else
    local scanned, found = 0, 0
    local srcs = {}
    for _, root in ipairs({ RS, LP:FindFirstChildOfClass("PlayerScripts"), LP.Character, LP:FindFirstChild("PlayerGui") }) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("LocalScript") or d:IsA("ModuleScript") then srcs[#srcs + 1] = d end
            end
        end
    end
    for _, s in ipairs(srcs) do
        if scanned >= 400 then break end
        scanned = scanned + 1
        local ok, code = pcall(decompileFn, s)
        if ok and type(code) == "string" then
            local lineNo = 0
            local lines = {}
            for line in (code .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
            for i, line in ipairs(lines) do
                for _, n in ipairs(searchNames) do
                    if line:find(n, 1, true) then
                        found = found + 1
                        calls[#calls + 1] = "## " .. path(s) .. ":" .. i .. "  [" .. n .. "]"
                        for j = math.max(1, i - 2), math.min(#lines, i + 3) do calls[#calls + 1] = "    " .. lines[j] end
                        calls[#calls + 1] = ""
                        break
                    end
                end
            end
        end
        if scanned % 25 == 0 then task.wait() end
    end
    w(string.format("scanned %d scripts, %d call-site hits (see forest99_calls.txt)", scanned, found))
end

local wf = writefile
if wf then
    wf("forest99_confirm.txt", table.concat(out, "\n"))
    wf("forest99_calls.txt", #calls > 0 and table.concat(calls, "\n") or "no hits")
    print("[forest99 dumper] wrote forest99_confirm.txt and forest99_calls.txt")
else
    print(table.concat(out, "\n"))
end
