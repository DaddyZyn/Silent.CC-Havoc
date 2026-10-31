--[[
    silent.cc - Havoc [Season 2] Universal Loader
    Safe execution wrapper with error assertion
]]

local success, content = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/DaddyZyn/Silent.CC-Havoc/main/dist/silent_cc.luau", true)
end)

if not success or not content or content == "" or string.find(content, "404") then
    warn("[silent.cc] Failed to fetch source from GitHub. CDN may still be syncing.")
    return
end

local execute, compileErr = loadstring(content)
if not execute then
    error("[silent.cc] Compilation error: " .. tostring(compileErr))
end

return execute()
