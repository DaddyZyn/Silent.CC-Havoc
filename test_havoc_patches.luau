--!nocheck
--[[
    snow.cc | Havoc Realism & Client Engine Patches Test
    Tests recoil reduction, zero stamina drain, fall damage nullification,
    and BaseCamera recoil neutralization discovered from memory dumps.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local function log(s)
    print("[snow.cc-patch] " .. tostring(s))
end

log("Starting memory patcher...")

local patchedTables = {
    Realism = 0,
    Stamina = 0,
    BaseCamera = false,
    Ergonomics = false,
}

-- 1. Scan GC for the Realism and Stamina tables
local getgc_fn = getgc or (getgenv and getgenv().getgc)
if typeof(getgc_fn) == "function" then
    for _, obj in ipairs(getgc_fn(true)) do
        if type(obj) == "table" then
            -- Check for Realism table: { damageBlur, fallDamage, recoilReductionRatio }
            if rawget(obj, "recoilReductionRatio") ~= nil and rawget(obj, "fallDamage") ~= nil then
                rawset(obj, "recoilReductionRatio", 0)
                rawset(obj, "fallDamage", 0)
                patchedTables.Realism = patchedTables.Realism + 1
            end

            -- Check for Stamina table: { drainRate, regenRate }
            if rawget(obj, "drainRate") ~= nil and rawget(obj, "regenRate") ~= nil then
                rawset(obj, "drainRate", 0)
                rawset(obj, "regenRate", 100)
                patchedTables.Stamina = patchedTables.Stamina + 1
            end
        end
    end
end

log(string.format("Patched %d Realism tables (Recoil & FallDamage nullified).", patchedTables.Realism))
log(string.format("Patched %d Stamina tables (Zero drain, instant regen).", patchedTables.Stamina))

-- 2. Patch BaseCamera recoil CFrame
local function hookCamera()
    if not (LocalPlayer and LocalPlayer.Character) then return end
    local scripts = LocalPlayer.Character:FindFirstChild("Scripts")
    local camScript = scripts and scripts:FindFirstChild("Camera")
    local baseCam = camScript and camScript:FindFirstChild("BaseCamera")
    if baseCam and baseCam:IsA("ModuleScript") then
        local ok, camMod = pcall(require, baseCam)
        if ok and type(camMod) == "table" then
            RunService.RenderStepped:Connect(function()
                if camMod._recoilCF then
                    camMod._recoilCF = CFrame.identity
                end
            end)
            patchedTables.BaseCamera = true
            log("BaseCamera._recoilCF locked to CFrame.identity on RenderStepped.")
        end
    end
end
pcall(hookCamera)

-- 3. Patch getMagErgonomics in Scripts.Client
local function patchClientScript()
    if not (LocalPlayer and LocalPlayer.Character) then return end
    local scripts = LocalPlayer.Character:FindFirstChild("Scripts")
    local clientScript = scripts and scripts:FindFirstChild("Client")
    local getsenv_fn = getsenv or (getgenv and getgenv().getsenv)
    if clientScript and typeof(getsenv_fn) == "function" then
        local env = getsenv_fn(clientScript)
        if env and typeof(env.getMagErgonomics) == "function" then
            local oldErgo = env.getMagErgonomics
            env.getMagErgonomics = function(...)
                return 100 -- Max ergonomics for ultra-fast handling
            end
            patchedTables.Ergonomics = true
            log("Scripts.Client.getMagErgonomics hooked -> returns 100.")
        end
    end
end
pcall(patchClientScript)

log("=====================================================")
log("Test patches fully deployed:")
log("  - No Recoil (Realism table + BaseCamera lock)")
log("  - Zero Fall Damage (Realism table)")
log("  - Infinite Stamina (Stamina table drain=0, regen=100)")
log("  - Max Ergonomics / Fast Handling (getMagErgonomics=100)")
log("=====================================================")
