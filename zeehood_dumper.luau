-- snow.cc | Zee Hood dumper
-- Run it, equip a gun, SHOOT at a player/dummy ~5 times, then check the files in the Volt workspace:
--   zeehood_dump.txt   (modules, GunHandler internals, remotes)
--   zeehood_calls.txt  (every remote call made while you shoot, with arguments)
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local out, calls = {}, {}
local function P(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    out[#out + 1] = table.concat(t, " ")
end
local function save()
    pcall(writefile, "zeehood_dump.txt", table.concat(out, "\n"))
    pcall(writefile, "zeehood_calls.txt", table.concat(calls, "\n"))
end

local function ser(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "Instance" then return "Instance<" .. v.ClassName .. ">" .. v:GetFullName() end
    if t == "table" then
        if d > 2 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 14 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. ser(x, d + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return t .. ":" .. tostring(v)
end

-- 1. remotes
P("=== REMOTES (ReplicatedStorage) ===")
for _, o in ipairs(RS:GetDescendants()) do
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") or o:IsA("BindableEvent") then
        P(o.ClassName, o:GetFullName())
    end
end

-- 2. modules
P("\n=== MODULES (ReplicatedStorage.Modules) ===")
local mods = RS:FindFirstChild("Modules")
if mods then
    for _, o in ipairs(mods:GetDescendants()) do P(o.ClassName, o:GetFullName()) end
end

-- 3. GunHandler
P("\n=== GunHandler ===")
local gh = mods and mods:FindFirstChild("GunHandler")
local ok, G = pcall(require, gh)
if ok and type(G) == "table" then
    for k, v in pairs(G) do
        P("key", tostring(k), typeof(v), type(v) == "table" and ser(v) or "")
        if type(v) == "function" then
            if debug and debug.getinfo then
                local okI, info = pcall(debug.getinfo, v)
                if okI and info then P("   info: params=" .. tostring(info.numparams) .. " src=" .. tostring(info.short_src)) end
            end
            if getconstants then
                local okC, c = pcall(getconstants, v)
                if okC then
                    local s = {}
                    for _, x in pairs(c) do if type(x) == "string" or type(x) == "number" then s[#s + 1] = tostring(x) end end
                    P("   constants: " .. table.concat(s, " | "))
                end
            end
            if getupvalues then
                local okU, u = pcall(getupvalues, v)
                if okU then
                    for i, x in pairs(u) do P("   upvalue", i, ser(x)) end
                end
            end
        end
    end
else
    P("require failed:", tostring(G))
end
if decompile and gh then
    local okD, src = pcall(decompile, gh)
    if okD then P("\n=== GunHandler decompile ===\n" .. tostring(src)) end
end

-- 4. equipped tool info
P("\n=== TOOLS ===")
local function dumpTool(t)
    P("Tool", t:GetFullName())
    for k, v in pairs(t:GetAttributes()) do P("   attr", k, tostring(v)) end
    for _, d in ipairs(t:GetDescendants()) do P("   ", d.ClassName, d:GetFullName()) end
    if decompile then
        for _, d in ipairs(t:GetDescendants()) do
            if d:IsA("LocalScript") then
                local okD, src = pcall(decompile, d)
                if okD then P("--- decompile " .. d:GetFullName() .. " ---\n" .. tostring(src)) end
            end
        end
    end
end
for _, c in ipairs({ LP.Backpack, LP.Character }) do
    if c then for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") then dumpTool(t) end end end
end
save()

-- 5. remote spy while you shoot
local gnm = getnamecallmethod
local old
old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local m = gnm()
    if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" then
        local a = table.pack(...)
        local parts = {}
        for i = 1, a.n do parts[#parts + 1] = ser(a[i]) end
        calls[#calls + 1] = string.format("[%.2f] %s:%s(%s)", os.clock(), self:GetFullName(), m, table.concat(parts, ", "))
        if #calls % 5 == 0 then task.defer(save) end
    end
    return old(self, ...)
end))

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "snow.cc dumper", Text = "Equip a gun and shoot ~5 times. Dump saved to workspace.", Duration = 8,
    })
end)
task.spawn(function()
    for _ = 1, 60 do task.wait(1) save() end
end)
print("[zeehood dumper] done - shoot a gun now, files: zeehood_dump.txt / zeehood_calls.txt")
