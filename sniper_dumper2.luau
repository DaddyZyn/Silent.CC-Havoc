--[[
    snow.cc | Sniper Arena dumper #2 (combat internals)
    Run it IN A MATCH with a gun equipped, then shoot, scope, reload and jump.
    Writes to your executor workspace:
      snowcc_src_<Module>.lua   decompiled source of the combat modules
      snowcc_combat.txt         CombatService remote calls (args + shot data)
      snowcc_weapon.txt         config of your equipped weapon
]]

local RS = game:GetService("ReplicatedStorage")
local LocalPlayer = game:GetService("Players").LocalPlayer
local SPY_SECONDS = 90

local function path(i) local ok, r = pcall(function() return i:GetFullName() end) return ok and r or tostring(i) end

local function ser(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "string" then return string.format("%q", #v > 60 and v:sub(1, 60) .. "..." or v) end
    if t == "Instance" then return "<" .. v.ClassName .. " " .. v.Name .. ">" end
    if t == "buffer" then return "buffer(" .. buffer.len(v) .. ")" end
    if t == "table" then
        if d >= 3 then return "{...}" end
        local p, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 25 then p[#p + 1] = "..."; break end
            p[#p + 1] = "[" .. ser(k, d + 1) .. "]=" .. ser(x, d + 1)
        end
        return "{" .. table.concat(p, ", ") .. "}"
    end
    if t == "Vector3" or t == "CFrame" or t == "Vector2" or t == "Color3" then return t .. "(" .. tostring(v) .. ")" end
    return tostring(v)
end

-- 1. Decompile key modules
local targets = {
    "Client.CombatController.ClientComponent.ClientShootableComponent",
    "Client.CombatController.ClientComponent.ClientReloadableComponent",
    "Client.CombatController.ClientWeapon",
    "Client.CombatController",
    "Common.CombatService.CommonComponent.CommonShootableComponent",
    "Common.CombatService.CommonComponent.CommonAmmoComponent",
    "Common.CombatService.CommonComponent.CommonReloadableComponent",
    "Client.CameraController",
    "Client.LocalCharacterController",
    "Client.AntiPeekController",
    "Util.RaycastUtils",
    "Remote.CombatService",
}
local done = 0
for _, p in ipairs(targets) do
    local inst = RS
    for part in p:gmatch("[^%.]+") do inst = inst and inst:FindFirstChild(part) end
    if inst and decompile then
        local ok, src = pcall(decompile, inst)
        if ok and type(src) == "string" and writefile then
            writefile("snowcc_src_" .. p:gsub("%.", "_") .. ".lua", src)
            done = done + 1
        end
    end
end
print("[dumper2] decompiled " .. done .. "/" .. #targets .. " modules")

-- 2. Equipped weapon info
local weaponLines = {}
pcall(function()
    local char = LocalPlayer.Character
    for _, o in ipairs({ char, LocalPlayer, workspace.CurrentCamera }) do
        if o then
            for _, d in ipairs(o:GetDescendants()) do
                if d:IsA("ValueBase") or next(d:GetAttributes()) then
                    local attrs = {}
                    for k, v in pairs(d:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
                    weaponLines[#weaponLines + 1] = path(d) .. " " .. (d:IsA("ValueBase") and tostring(d.Value) or "") .. " " .. table.concat(attrs, ",")
                end
            end
        end
    end
end)
if writefile then writefile("snowcc_weapon.txt", table.concat(weaponLines, "\n")) end

-- 3. Combat remote spy (outgoing + incoming), no per-remote cap
local log = {}
local function add(s) log[#log + 1] = s end
local function isCombat(r)
    local n = path(r)
    return n:find("CombatService") or n:find("ByteNet") or n:find("EntityService") or n:find("BetterReplication") or n:find("Replicate")
end

if hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" and isCombat(self) then
            local args = table.pack(...)
            local parts = {}
            for i = 1, math.min(args.n, 8) do parts[#parts + 1] = ser(args[i]) end
            add(string.format("[%.2f] OUT %s %s(%s)", os.clock(), m, path(self), table.concat(parts, ", ")))
        end
        return old(self, ...)
    end))
end

for _, d in ipairs(RS:GetDescendants()) do
    if d:IsA("RemoteEvent") and path(d):find("CombatService") then
        pcall(function()
            d.OnClientEvent:Connect(function(...)
                local args = table.pack(...)
                local parts = {}
                for i = 1, math.min(args.n, 8) do parts[#parts + 1] = ser(args[i]) end
                add(string.format("[%.2f] IN  %s(%s)", os.clock(), path(d), table.concat(parts, ", ")))
            end)
        end)
    end
end

-- 4. Trace the weapon modules themselves
local function traceModule(modPath, names)
    local inst = RS
    for part in modPath:gmatch("[^%.]+") do inst = inst and inst:FindFirstChild(part) end
    if not inst then return end
    local ok, mod = pcall(require, inst)
    if not ok or type(mod) ~= "table" then return end
    for _, fname in ipairs(names) do
        local f = rawget(mod, fname)
        if type(f) == "function" and hookfunction then
            local orig
            local okh = pcall(function()
                orig = hookfunction(f, newcclosure(function(...)
                    local args = table.pack(...)
                    local parts = {}
                    for i = 2, math.min(args.n, 6) do parts[#parts + 1] = ser(args[i]) end
                    add(string.format("[%.2f] CALL %s.%s(%s)", os.clock(), modPath:match("[^%.]+$"), fname, table.concat(parts, ", ")))
                    return orig(...)
                end))
            end)
        end
    end
end

traceModule("Client.CombatController.ClientComponent.ClientShootableComponent", { "Shoot", "LocalShoot", "GetRecoil", "GetCurrentRecoil", "requestInShooting" })
traceModule("Common.CombatService.CommonComponent.CommonShootableComponent", { "GetCurrentSpread", "CanShootNow", "BroadcastShooted", "Shoot" })
traceModule("Common.CombatService.CommonComponent.CommonAmmoComponent", { "TakeAmmo", "HasAmmo" })
traceModule("Client.CombatController.ClientWeapon", { "FireAction", "FireUnreliableAction" })

print(("[dumper2] spying %ds - shoot, scope, reload, jump now"):format(SPY_SECONDS))
task.spawn(function()
    local t0 = os.clock()
    while os.clock() - t0 < SPY_SECONDS do
        task.wait(5)
        if writefile then writefile("snowcc_combat.txt", table.concat(log, "\n")) end
    end
    if writefile then writefile("snowcc_combat.txt", table.concat(log, "\n")) end
    print("[dumper2] finished, " .. #log .. " entries")
end)
