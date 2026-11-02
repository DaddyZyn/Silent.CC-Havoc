--!nocheck
--[[
    snow.cc - Targeted Client Script & Ammo Deep Inspector
    Dumps upvalues, constants, and closures inside Scripts.Client and BaseCamera
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function log(s)
    print("[snow.cc-client-dump] " .. tostring(s))
end

local dumpLines = {}
local function addLine(s)
    table.insert(dumpLines, s or "")
end

addLine("=====================================================================")
addLine("snow.cc - Scripts.Client & Weapon Upvalue Deep Dump")
addLine("=====================================================================\n")

if not (LocalPlayer and LocalPlayer.Character) then
    addLine("Error: LocalPlayer.Character not found.")
    return
end

local char = LocalPlayer.Character
local clientScript = char:FindFirstChild("Scripts") and char.Scripts:FindFirstChild("Client")

if not clientScript then
    addLine("Error: Scripts.Client not found.")
else
    addLine("Target: " .. clientScript:GetFullName())

    local getsenv_fn = getsenv or (getgenv and getgenv().getsenv)
    local getupvals = debug.getupvalues or getupvalues
    local getconsts = debug.getconstants or getconstants
    local getprotos = debug.getprotos or getprotos

    if typeof(getsenv_fn) == "function" then
        local env = getsenv_fn(clientScript)
        addLine("\n--- Scripts.Client Top-Level Environment ---")
        for k, v in pairs(env) do
            addLine(string.format("  [%s] (%s) = %s", tostring(k), typeof(v), tostring(v)))
        end

        -- Deep inspect loadAmmoFunction
        if typeof(env.loadAmmoFunction) == "function" and typeof(getupvals) == "function" then
            addLine("\n--- Upvalues of loadAmmoFunction ---")
            local uvals = getupvals(env.loadAmmoFunction)
            for idx, val in pairs(uvals) do
                local valStr = tostring(val)
                if type(val) == "table" then
                    local keys = {}
                    for tk, tv in pairs(val) do
                        table.insert(keys, string.format("%s = %s", tostring(tk), tostring(tv)))
                        if #keys >= 15 then break end
                    end
                    valStr = "Table { " .. table.concat(keys, ", ") .. " }"
                end
                addLine(string.format("  [%s] (%s) = %s", tostring(idx), typeof(val), valStr))
            end
        end

        -- Deep inspect getMagErgonomics
        if typeof(env.getMagErgonomics) == "function" and typeof(getupvals) == "function" then
            addLine("\n--- Upvalues of getMagErgonomics ---")
            local uvals = getupvals(env.getMagErgonomics)
            for idx, val in pairs(uvals) do
                addLine(string.format("  [%s] (%s) = %s", tostring(idx), typeof(val), tostring(val)))
            end
        end
    end

    -- Scan GC for all closures belonging to Scripts.Client
    local getgc_fn = getgc or (getgenv and getgenv().getgc)
    if typeof(getgc_fn) == "function" and typeof(getupvals) == "function" then
        addLine("\n--- Scanned Closures in Scripts.Client ---")
        local count = 0
        for _, obj in ipairs(getgc_fn(false)) do
            if typeof(obj) == "function" and (not islclosure or islclosure(obj)) then
                local fenv = pcall(getfenv, obj) and getfenv(obj)
                if fenv and fenv.script == clientScript then
                    count = count + 1
                    local fnName = debug.info(obj, "n") or "anon"
                    local uvals = getupvals(obj)
                    local matched = {}
                    for idx, uv in pairs(uvals) do
                        local uvType = typeof(uv)
                        if uvType == "number" or uvType == "boolean" or uvType == "string" then
                            table.insert(matched, string.format("%s:%s", tostring(idx), tostring(uv)))
                        elseif uvType == "table" then
                            local subkeys = {}
                            for sk, sv in pairs(uv) do
                                local sName = string.lower(tostring(sk))
                                if string.find(sName, "ammo") or string.find(sName, "mag") or string.find(sName, "fire") or string.find(sName, "rate") or string.find(sName, "recoil") or string.find(sName, "delay") then
                                    table.insert(subkeys, string.format("%s=%s", tostring(sk), tostring(sv)))
                                end
                            end
                            if #subkeys > 0 then
                                table.insert(matched, "Table{" .. table.concat(subkeys, ", ") .. "}")
                            end
                        end
                    end
                    if #matched > 0 then
                        addLine(string.format("  Closure #%d [%s]: %s", count, fnName, table.concat(matched, " | ")))
                    end
                end
            end
        end
    end
end

-- Inspect BaseCamera Module for recoil nullification
local cameraScript = char:FindFirstChild("Scripts") and char.Scripts:FindFirstChild("Camera")
local baseCamera = cameraScript and cameraScript:FindFirstChild("BaseCamera")
if baseCamera and baseCamera:IsA("ModuleScript") then
    addLine("\n--- BaseCamera Module State ---")
    local ok, camMod = pcall(require, baseCamera)
    if ok and type(camMod) == "table" then
        for k, v in pairs(camMod) do
            addLine(string.format("  [%s] (%s) = %s", tostring(k), typeof(v), tostring(v)))
        end
    end
end

addLine("\n=====================================================================")
addLine("End of Client Deep Dump")
addLine("=====================================================================")

local output = table.concat(dumpLines, "\n")
local saveFn = writefile or (getgenv and getgenv().writefile)
if typeof(saveFn) == "function" then
    saveFn("havoc_client_deep_dump.txt", output)
    log("Saved deep dump to havoc_client_deep_dump.txt")
else
    print(output)
end
