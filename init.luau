--[[
    silent.cc - Havoc [Season 2] Universal Loader
    Bypasses Fastly CDN cache locks & surfaces compile diagnostics
]]

local timestamp = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))
local url = "https://raw.githubusercontent.com/DaddyZyn/Silent.CC-Havoc/main/dist/silent_cc.luau?v=" .. timestamp

local success, source = pcall(function()
    return game:HttpGet(url, true)
end)

if not success or not source or source == "" or string.find(source, "404") then
    source = game:HttpGet("https://raw.githubusercontent.com/DaddyZyn/Silent.CC-Havoc/main/dist/silent_cc.luau", true)
end

local execute, compileErr = loadstring(source)
if not execute then
    warn("[silent.cc] Compilation error caught:")
    warn(tostring(compileErr))
    return
end

return execute()
