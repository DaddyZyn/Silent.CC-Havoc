--[[
    silent.cc - Havoc CharacterController & Movement Subsystem Deep Inspector
    Dumps getsenv, upvalues, constants, and internal tables of CharacterController
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local function copyText(str)
    local methods = { setclipboard, toclipboard, set_clipboard }
    for _, fn in ipairs(methods) do
        if typeof(fn) == "function" then
            local s = pcall(fn, str)
            if s then return true end
        end
    end
    return false
end

local dump = {
    CharacterPath = "",
    ControllerFound = false,
    EnvKeys = {},
    UpvaluesFound = {},
    ConstantsFound = {},
    Attributes = {},
}

if LocalPlayer and LocalPlayer.Character then
    local char = LocalPlayer.Character
    dump.CharacterPath = char:GetFullName()

    for k, v in pairs(char:GetAttributes()) do
        dump.Attributes[k] = tostring(v)
    end

    local scripts = char:FindFirstChild("Scripts")
    local cc = scripts and scripts:FindFirstChild("CharacterController")
    if cc and cc:IsA("LocalScript") then
        dump.ControllerFound = true

        -- 1. getsenv inspection
        pcall(function()
            local getsenv_fn = getsenv or (getgenv and getgenv().getsenv)
            if typeof(getsenv_fn) == "function" then
                local env = getsenv_fn(cc)
                for k, v in pairs(env) do
                    dump.EnvKeys[tostring(k)] = {
                        Type = typeof(v),
                        Value = typeof(v) == "table" and HttpService:JSONEncode(v) or tostring(v),
                    }
                end
            end
        end)

        -- 2. getgc & upvalues inspection
        pcall(function()
            local getgc_fn = getgc or (getgenv and getgenv().getgc)
            local getupvalues_fn = debug.getupvalues or getupvalues
            local getconstants_fn = debug.getconstants or getconstants

            if typeof(getgc_fn) == "function" and typeof(getupvalues_fn) == "function" then
                for _, obj in ipairs(getgc_fn(false)) do
                    if typeof(obj) == "function" and islclosure and islclosure(obj) then
                        local s = getfenv(obj).script
                        if s == cc then
                            local upvals = getupvalues_fn(obj)
                            for idx, u in pairs(upvals) do
                                local uType = typeof(u)
                                if uType == "number" or uType == "string" or uType == "boolean" then
                                    table.insert(dump.UpvaluesFound, {
                                        Index = idx,
                                        Type = uType,
                                        Value = tostring(u),
                                    })
                                elseif uType == "table" then
                                    local keys = {}
                                    for tk, _ in pairs(u) do
                                        table.insert(keys, tostring(tk))
                                    end
                                    table.insert(dump.UpvaluesFound, {
                                        Index = idx,
                                        Type = "table",
                                        Keys = keys,
                                    })
                                end
                            end

                            if typeof(getconstants_fn) == "function" then
                                for _, c in ipairs(getconstants_fn(obj)) do
                                    local sc = tostring(c)
                                    local lower = string.lower(sc)
                                    if string.find(lower, "speed") or string.find(lower, "stamina") or string.find(lower, "walk") or string.find(lower, "run") or string.find(lower, "sprint") then
                                        table.insert(dump.ConstantsFound, sc)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

local json = HttpService:JSONEncode(dump)
copyText(json)
print("[silent.cc] CharacterController dump complete! Copied to clipboard.")
warn("--- DUMP PREVIEW ---")
print(string.sub(json, 1, 500))
