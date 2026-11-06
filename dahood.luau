--[[
    snow.cc | Zee Hood
    Place: 138014591158268
    UI: silent.cc framework (embedded, rebranded)
    Toggle: RightShift
]]

if getgenv then
    if getgenv().SnowHoodLoaded then pcall(function() getgenv().SnowHoodLoaded.Unload() end) end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

local hookfunction = hookfunction
local restorefunction = restorefunction
local hookmetamethod = hookmetamethod
local getrawmetatable = getrawmetatable
local getnamecallmethod = getnamecallmethod
local newcclosure = newcclosure or function(f) return f end
local SAFE = false

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if workspace.CurrentCamera then Camera = workspace.CurrentCamera end
end)

local function cam()
    return workspace.CurrentCamera or Camera
end

local function cursorPoint()
    local ok, loc = pcall(function()
        return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
    end)
    if ok and loc then return loc end
    return Vector2.new(Mouse.X, Mouse.Y)
end

--=====================================================================
-- STATE / HELPERS
--=====================================================================
local state = {
    aimbot = false, aimMode = "Camera", aimPart = "Head", aimFov = 150,
    aimSmooth = 25, aimPrediction = false, aimTeamCheck = true, aimVisible = false,
    aimCircle = true, aimColor = Color3.fromRGB(0, 175, 255), aimCircleY = 0,
    aimSnapline = false, aimSnaplineOrigin = "Gun", aimSnaplineWidth = 1,
    aimSnaplineColor = Color3.fromRGB(0, 175, 255),
    trigger = false, triggerDelay = 0.08, triggerPart = "Head", triggerFov = 150, triggerTeamCheck = true,
    silent = false, silentFov = 300, silentPart = "Hitbox", silentChance = 100,
    silentTeamCheck = true, wallbangMode = "Remote", silentPrediction = true, silentPredictionFactor = 1,
    silentVisibleOnly = false, wallbangMax = 28, shiftHandle = true, debugShots = false,
    knockCheck = true, adaptiveHitbox = false, spreadCondenser = true,
    silentCircle = false, silentColor = Color3.fromRGB(0, 200, 255), silentCircleY = 0,
    silentSnapline = false, silentSnaplineOrigin = "Gun", silentSnaplineWidth = 1,
    silentSnaplineColor = Color3.fromRGB(0, 200, 255),
    antiAimViewer = false, antiAimColor = Color3.fromRGB(0, 200, 255), antiAimLength = 80,
    autoReload = false, infiniteAmmo = false, maxAmmo = 999, autoAttack = false, attackRange = 14,
    rapidFire = false, fireCooldown = 0.03,
    damageOverride = false, damageValue = 100,
    rangeOverride = false, rangeValue = 500,
    esp = false, espBox = true, espBoxStyle = "Full", espName = true, espHealth = true,
    espHealthBar = true, espDist = true,
    espTracer = false, espTracerOrigin = "Bottom", espTool = true, espMaxDist = 1500, espChams = false,
    espOutline = true, espSkeleton = false,
    espEnemy = Color3.fromRGB(255, 60, 60), espTeam = Color3.fromRGB(60, 255, 120),
    speed = false, speedValue = 24, speedMode = "CFrame", jump = false, jumpValue = 55,
    hipHeight = false, hipValue = 2, fly = false, flySpeed = 60,
    flyVertical = false, flySmooth = 11,
    spinbot = false, spinSpeed = 720, spinAxis = "Yaw",
    tracer = false, tracerStyle = "Line", tracerColor = Color3.fromRGB(255, 220, 90),
    tracerWidth = 2, tracerLife = 0.35,
    gunGlow = false, gunGlowColor = Color3.fromRGB(0, 200, 255), gunGlowRainbow = false,
    charGlow = false, charGlowColor = Color3.fromRGB(0, 200, 255), charGlowRainbow = false,
    rainbowSpeed = 30,
    hat = false, hatColor = Color3.fromRGB(255, 210, 90), hatRainbow = true,
    hatSize = 1, hatTransparency = 0.35, hatHeight = 0,
    hitSound = false, hitSoundId = "", hitSoundVolume = 0.6, hitSoundPitch = 1,
    skyPreset = "Default", skyCustom = "", skyStars = 3000, skySun = true,
    noclip = false, infJump = false, antiAfk = true,
    tpOffset = 4,
    fullbright = false, noFog = false,
    hookMode = "Off",
    unloaded = false,
}

-- Every group of related state lives in one table. The chunk sits hard against
-- Luau's 200 local register ceiling, so a dozen siblings are worth more than the
-- readability they cost, and a new feature has to share a slot rather than take
-- a fresh one.
local reg = { flags = {}, setters = {}, getters = {} }
local function register(key, ctl, initial)
    reg.flags[key] = initial
    reg.setters[key] = ctl.SetValue
    reg.getters[key] = ctl.GetValue
end

local con = { live = {}, ui = {} }
local function track(c) table.insert(con.live, c) return c end

-- UI input connections live on UserInputService, so they outlive the ScreenGui.
-- They are collected separately and cut on unload.
local function uiconn(c) table.insert(con.ui, c) return c end

local Window

local function getChar() return LP.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function isKnocked(char)
    if not char then return false end
    local be = char:FindFirstChild("BodyEffects")
    if be then
        local ko = be:FindFirstChild("K.O") or be:FindFirstChild("KO") or be:FindFirstChild("Dead")
        if ko and (ko:IsA("BoolValue") and ko.Value or ko:IsA("ValueBase") and ko.Value == true) then
            return true
        end
    end
    if char:FindFirstChild("KO") or char:FindFirstChild("Dead") then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and (hum.PlatformStand or hum:GetState() == Enum.HumanoidStateType.Physics) then
        return true
    end
    return false
end

local function alive(plr)
    local c = plr and plr.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not (h ~= nil and h.Health > 0) then return false end
    if state.knockCheck then
        if isKnocked(c) then return false end
        local be = c:FindFirstChild("BodyEffects")
        local d = be and be:FindFirstChild("Dead")
        if d and d.Value then return false end
    end
    return true
end

-- Zee Hood has no Roblox teams; it tags players with a BRTeam attribute and
-- keeps crew membership under DataFolder.Information.Crew.
local function sameTeam(plr)
    local myBR, theirBR = LP:GetAttribute("BRTeam"), plr:GetAttribute("BRTeam")
    if myBR ~= nil and theirBR ~= nil then return myBR == theirBR end
    if LP.Team ~= nil and plr.Team ~= nil then return LP.Team == plr.Team end
    return false
end

-- Declared above getPart: a local function referenced from an earlier
-- definition compiles to a global there and would be nil at call time.
local InVisRay = false

-- RaycastParams are rebuilt dozens of times per frame, so the three sets are
-- allocated once and only their filter lists are rewritten.
local rp = {
    vis = RaycastParams.new(),
    los = RaycastParams.new(),
    inc = RaycastParams.new(),
}
rp.vis.FilterType = Enum.RaycastFilterType.Exclude
rp.los.FilterType = Enum.RaycastFilterType.Exclude
rp.inc.FilterType = Enum.RaycastFilterType.Include

local function visible(part)
    local ignore = { LP.Character }
    if part.Parent then table.insert(ignore, part.Parent) end
    rp.vis.FilterDescendantsInstances = ignore
    InVisRay = true
    local res = workspace:Raycast(cam().CFrame.Position, part.Position - cam().CFrame.Position, rp.vis)
    InVisRay = false
    return res == nil
end

local function losParams(part)
    rp.los.FilterDescendantsInstances = { part.Parent, LP.Character }
    return rp.los
end

local function incParams(part)
    rp.inc.FilterDescendantsInstances = { part.Parent }
    return rp.inc
end

-- Ordered by preference for "Closest": body first, the oversized Hitbox last so
-- it only wins when it genuinely is the nearest thing under the crosshair.
local CLOSEST_CANDIDATES = {
    "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    "Hitbox",
}

local function closestPart(c)
    local mpos = cursorPoint()
    local best, bestD = nil, math.huge
    for _, n in ipairs(CLOSEST_CANDIDATES) do
        local p = c:FindFirstChild(n)
        if p and p:IsA("BasePart") then
            local sp, on = cam():WorldToViewportPoint(p.Position)
            if on and sp.Z > 0 then
                local d = (mpos - Vector2.new(sp.X, sp.Y)).Magnitude
                if d < bestD then best, bestD = p, d end
            end
        end
    end
    return best
end

local function getPart(plr, name)
    local c = plr and plr.Character
    if not c then return nil end
    if name == "Closest" then
        local p = closestPart(c)
        if p then return p end
    end
    if (state.adaptiveHitbox or name == "Adaptive") then
        local candidates = { "Hitbox", "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" }
        for _, n in ipairs(candidates) do
            local p = c:FindFirstChild(n)
            if p and p:IsA("BasePart") and visible(p) then return p end
        end
    end
    local p = c:FindFirstChild(name)
    if p and p:IsA("BasePart") then return p end
    p = c:FindFirstChild("Hitbox")
    if p and p:IsA("BasePart") then return p end
    p = c:FindFirstChild("Head")
    if p and p:IsA("BasePart") then return p end
    return c:FindFirstChild("HumanoidRootPart")
end
local function mouseFree()
    return UserInputService:GetFocusedTextBox() == nil
end
local pings = { v = 60, at = 0 }
local function smoothPing()
    if os.clock() - pings.at > 0.2 then
        pings.at = os.clock()
        local ok, v = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        pings.v = ok and v or pings.v
    end
    return pings.v
end
local function predict(part, factor, mode)
    local usePred = (mode == "aim" and state.aimPrediction) or (mode == "silent" and state.silentPrediction)
    if not mode then usePred = state.aimPrediction or state.silentPrediction end
    if not usePred then return part.Position end
    local mult = factor or 1
    if mode == "silent" and state.silentPredictionFactor then
        mult = mult * state.silentPredictionFactor
    end
    return part.Position + (part.AssemblyLinearVelocity * ((smoothPing() / 1000) * mult))
end

-- The part that was actually scored is returned alongside the player, so the
-- caller never re-resolves a different bone than the one the FOV test used.
-- findTarget's visCheck: true means the target must be in line of sight.
local function findTarget(partName, fov, teamCheck, visCheck, fromPoint)
    local best, bestDist, bestPart = nil, math.huge, nil
    local mpos = fromPoint or cursorPoint()
    local myChar = getChar()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.UserId ~= LP.UserId and plr.Name ~= LP.Name and alive(plr) then
            local char = plr.Character
            if char and char ~= myChar and not (myChar and char:IsDescendantOf(myChar)) then
                local skip = teamCheck and sameTeam(plr)
                if not skip then
                    local part = getPart(plr, partName)
                    if part and part.Parent ~= myChar then
                        local sp, on = cam():WorldToViewportPoint(part.Position)
                        if on and sp.Z > 0 then
                            local d = (mpos - Vector2.new(sp.X, sp.Y)).Magnitude
                            if d <= fov and d < bestDist and (not visCheck or visible(part)) then
                                best, bestDist, bestPart = plr, d, part
                            end
                        end
                    end
                end
            end
        end
    end
    return best, bestPart
end

local function toolEquipped()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Tool")
end

local function overGui()
    if not Window then return false end
    local loc = cursorPoint()
    local ok, objs = pcall(function()
        return Window.ScreenGui:GetGuiObjectsAtPosition(loc.X, loc.Y)
    end)
    if not ok or type(objs) ~= "table" then return false end
    for _, o in ipairs(objs) do
        -- The popup overlay is a full-screen transparent frame, so it would
        -- always report a hit if it were counted.
        if o ~= Window.PopupOverlay then
            if o == Window.MainFrame or o:IsA("GuiButton") or o:IsA("TextBox")
                or o:IsA("ScrollingFrame") then
                return true
            end
        end
    end
    return false
end

local function glowColor(base, rainbow, offset)
    if not rainbow then return base end
    local h = (os.clock() * (state.rainbowSpeed / 100) + (offset or 0)) % 1
    return Color3.fromHSV(h, 1, 1)
end

--=====================================================================
-- ADONIS SHIELD
--=====================================================================
local Shield = {
    zombied = {}, cands = {}, lastFull = 0, count = 0, armed = false, on = true,
    detect = {
        namecallInstance = true, indexInstance = true, newindexInstance = true,
        namecallEnum = true, indexEnum = true, newindexEnum = true,
        eqEnum = true, checkStack = true, isMethamethodValid = true,
        getgcInstance = true, fireServerInstance = true, invokeServerInstance = true,
    },
}

local ProtectedFns = {}

local function zombify(fn)
    if type(fn) ~= "function" or Shield.zombied[fn] or ProtectedFns[fn] then return false end
    local ok, old = pcall(hookfunction, fn, newcclosure(function() return false end))
    if ok and old then
        Shield.zombied[fn] = old
        return true
    end
    return false
end

local function fullSweep()
    local found, n = {}, 0
    for _, obj in pairs(getgc(true)) do
        if type(obj) == "table" then
            if obj.namecallInstance ~= nil or obj.indexInstance ~= nil
                or obj.checkStack ~= nil or obj.isMethamethodValid ~= nil
                or obj.namecallEnum ~= nil then
                n = n + 1
                found[n] = obj
                if n >= 30 then break end
            end
        end
    end
    if n > 0 then
        local names = {}
        for k in pairs(found[1]) do
            if type(k) == "string" and Shield.detect[k] then table.insert(names, k) end
        end
        print("[snow] shield candidate:", table.concat(names, ","))
    end
    Shield.cands = {}
    for i = 1, n do Shield.cands[i] = { t = found[i], s = 0 } end
    Shield.lastFull = os.clock()
end

local function applyShield()
    if #Shield.cands == 0 or os.clock() - Shield.lastFull > 25 then fullSweep() end
    local n = 0
    for _, c in ipairs(Shield.cands) do
        for k, v in pairs(c.t) do
            if type(k) == "string" and Shield.detect[k] then
                if type(v) == "function" then
                    if zombify(v) then n = n + 1 end
                elseif type(v) == "table" then
                    for _, vv in pairs(v) do
                        if type(vv) == "function" and zombify(vv) then n = n + 1 end
                    end
                end
            end
        end
    end
    Shield.count = n
    return n
end

local function restoreShield()
    for fn, old in pairs(Shield.zombied) do
        pcall(restorefunction, fn)
        pcall(hookfunction, fn, old)
    end
    Shield.zombied = {}
    Shield.count = 0
    Shield.lastFull = 0
    Shield.armed = false
end

local function sanityOk()
    local ok, res = pcall(function()
        local svc = game:GetService("Players")
        if typeof(svc) ~= "Instance" then return false end
        if Players.LocalPlayer == nil then return false end
        local sig = workspace:GetPropertyChangedSignal("CurrentCamera")
        if typeof(sig) ~= "RBXScriptSignal" then return false end
        return true
    end)
    return ok and res == true
end

local function safeApplyShield()
    applyShield()
    if not sanityOk() then
        restoreShield()
        print("[snow] shield broke engine calls - reverted")
        return false
    end
    return true
end

local function armShield()
    if not Shield.on then return end
    for i = 1, 60 do
        if state.unloaded then return end
        pcall(safeApplyShield)
        if Shield.count > 0 then
            Shield.armed = true
            print("[snow] shield armed:", Shield.count, "on attempt", i)
            return
        end
        task.wait(0.25)
    end
    print("[snow] shield never found detectors")
end

--=====================================================================
-- UI LIBRARY
--=====================================================================
local Library = {}
Library.Conns = {}

local function guard(tag, fn)
    return function(...)
        if type(fn) ~= "function" then
            warn("[snow] " .. tag .. ": nil callback")
            return
        end
        local ok, err = pcall(fn, ...)
        if not ok then warn("[snow] " .. tag .. ": " .. tostring(err)) end
    end
end

local LocalPlayer = LP
local isMenuVisible = true
local gethui = gethui
local Workspace = workspace
local function libProxy(svc)
    return setmetatable({}, { __index = function(_, k)
        local v = svc[k]
        if typeof(v) == "RBXScriptSignal" then
            return { Connect = function(_, f)
                local c = v:Connect(f)
                table.insert(Library.Conns, c)
                return c
            end }
        end
        if type(v) == "function" then return function(_, ...) return v(svc, ...) end end
        return v
    end })
end
local LibUIS = libProxy(UserInputService)
local LibRS = libProxy(RunService)

Library.Theme = {
    WindowBg = Color3.fromRGB(9, 11, 17),
    WindowBorder = Color3.fromRGB(0, 0, 0),
    WindowStroke = Color3.fromRGB(28, 36, 54),
    WindowGlow = Color3.fromRGB(140, 200, 255),

    SidebarBg = Color3.fromRGB(7, 9, 14),
    SidebarBorder = Color3.fromRGB(22, 28, 42),

    TitlebarBg = Color3.fromRGB(7, 9, 14),
    TitlebarText = Color3.fromRGB(240, 246, 255),

    NavbarBg = Color3.fromRGB(7, 9, 14),
    TabActiveBg = Color3.fromRGB(16, 22, 34),
    TabActiveBorder = Color3.fromRGB(44, 70, 110),
    TabInactiveText = Color3.fromRGB(122, 134, 156),
    TabActiveText = Color3.fromRGB(255, 255, 255),
    TabHoverBg = Color3.fromRGB(13, 18, 28),

    Accent = Color3.fromRGB(120, 190, 255),
    AccentGlow = Color3.fromRGB(180, 220, 255),
    AccentDim = Color3.fromRGB(60, 110, 180),
    AccentSecondary = Color3.fromRGB(205, 232, 255),

    GroupboxBg = Color3.fromRGB(12, 15, 23),
    GroupboxBorder = Color3.fromRGB(24, 31, 46),
    GroupboxTitle = Color3.fromRGB(225, 238, 255),

    LabelText = Color3.fromRGB(196, 206, 224),
    MutedText = Color3.fromRGB(110, 122, 146),
    WarnText = Color3.fromRGB(255, 95, 95),

    InputBg = Color3.fromRGB(7, 9, 14),
    InputBorder = Color3.fromRGB(30, 38, 56),

    SliderTrack = Color3.fromRGB(16, 21, 32),
    SliderFill = Color3.fromRGB(120, 190, 255),
    SliderText = Color3.fromRGB(240, 246, 255),

    FontTitle = Enum.Font.GothamBold,
    FontTab = Enum.Font.GothamMedium,
    FontBody = Enum.Font.GothamMedium,
}

Library.Binds = {}

local function getSafeParent()
    if typeof(gethui) == "function" then
        local success, hui = pcall(gethui)
        if success and hui then return hui end
    end

    local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if success and coreGui then return coreGui end

    if LocalPlayer then return LocalPlayer:WaitForChild("PlayerGui") end
    error("[snow.cc] Failed to find UI container.")
end

local function makeDraggable(dragHandle, container)
    local dragging = false
    local dragStart = Vector2.zero
    local startPos = UDim2.new()

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = container.Position
        end
    end)

    LibUIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    LibUIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

function Library.CreateWindow(config)
    local title = config.Title or "snow.cc"
    local gameName = config.Game or "Havoc"
    local link = config.Link or "discord.gg/snowcc"
    local windowSize = config.Size or Vector2.new(680, 720)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "silent_cc_" .. tostring(math.random(100000, 999999))
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999999
    screenGui.Parent = getSafeParent()

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y)
    mainFrame.Position = UDim2.new(0.5, -windowSize.X / 2, 0.5, -windowSize.Y / 2)
    mainFrame.BackgroundColor3 = Library.Theme.WindowBg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = false
    mainFrame.Parent = screenGui

    local windowStroke = Instance.new("UIStroke")
    windowStroke.Color = Library.Theme.WindowStroke
    windowStroke.Thickness = 1
    windowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    windowStroke.Parent = mainFrame

    -- Vertical Sidebar Layout (havoc.dead style)
    -- Outer Glow effect behind MainWindow
    local windowGlow = Instance.new("ImageLabel")
    windowGlow.Name = "WindowGlow"
    windowGlow.Size = UDim2.new(1, 36, 1, 36)
    windowGlow.Position = UDim2.new(0, -18, 0, -18)
    windowGlow.BackgroundTransparency = 1
    windowGlow.Image = "rbxassetid://5028857084"
    windowGlow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    windowGlow.ImageTransparency = 0.25
    windowGlow.ScaleType = Enum.ScaleType.Slice
    windowGlow.SliceCenter = Rect.new(24, 24, 276, 276)
    windowGlow.ZIndex = mainFrame.ZIndex - 1
    windowGlow.Parent = mainFrame

    -- Vertical Sidebar Layout (havoc.dead style)
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 160, 1, 0)
    sidebar.Position = UDim2.new(0, 0, 0, 0)
    sidebar.BackgroundColor3 = Library.Theme.SidebarBg
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    -- Subtle gradient highlight on sidebar
    local sbGrad = Instance.new("UIGradient")
    sbGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 220))
    })
    sbGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0.1)
    })
    sbGrad.Rotation = 90
    sbGrad.Parent = sidebar

    local sidebarBorder = Instance.new("Frame")
    sidebarBorder.Name = "SidebarBorder"
    sidebarBorder.Size = UDim2.new(0, 1, 1, 0)
    sidebarBorder.Position = UDim2.new(1, -1, 0, 0)
    sidebarBorder.BackgroundColor3 = Library.Theme.SidebarBorder
    sidebarBorder.BorderSizePixel = 0
    sidebarBorder.Parent = sidebar

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 52)
    titleBar.BackgroundTransparency = 1
    titleBar.Parent = sidebar

    local titleGlow = Instance.new("Frame")
    titleGlow.Name = "TitleAccentDot"
    titleGlow.Size = UDim2.new(0, 6, 0, 6)
    titleGlow.Position = UDim2.new(0, 16, 0.5, -3)
    titleGlow.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
    titleGlow.BorderSizePixel = 0
    titleGlow.Parent = titleBar

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = titleGlow

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -36, 0, 30)
    titleLabel.Position = UDim2.new(0, 28, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Library.Theme.FontTitle
    titleLabel.TextSize = 15
    titleLabel.TextColor3 = Library.Theme.TitlebarText
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.RichText = true
    titleLabel.TextSize = 17
    titleLabel.Text = '<font color="rgb(255,255,255)">snow</font><font color="rgb(120,190,255)">.cc</font>'
    titleLabel.Parent = titleBar

    local gameLabel = Instance.new("TextLabel")
    gameLabel.Name = "GameLabel"
    gameLabel.Size = UDim2.new(1, -36, 0, 14)
    gameLabel.Position = UDim2.new(0, 28, 0, 28)
    gameLabel.BackgroundTransparency = 1
    gameLabel.Font = Library.Theme.FontBody
    gameLabel.TextSize = 10
    gameLabel.TextColor3 = Library.Theme.MutedText
    gameLabel.TextXAlignment = Enum.TextXAlignment.Left
    gameLabel.Text = gameName
    gameLabel.Parent = titleBar

    titleGlow.BackgroundColor3 = Library.Theme.Accent
    titleGlow.Position = UDim2.new(0, 16, 0, 17)

    local accentLine = Instance.new("Frame")
    accentLine.Name = "AccentLine"
    accentLine.Size = UDim2.new(1, 0, 0, 2)
    accentLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    accentLine.BorderSizePixel = 0
    accentLine.ZIndex = 5
    accentLine.Parent = mainFrame

    local accentGrad = Instance.new("UIGradient")
    accentGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Library.Theme.Accent),
        ColorSequenceKeypoint.new(1, Library.Theme.AccentSecondary),
    })
    accentGrad.Parent = accentLine

    makeDraggable(titleBar, mainFrame)

    local navBar = Instance.new("Frame")
    navBar.Name = "NavList"
    navBar.Size = UDim2.new(1, -16, 1, -120)
    navBar.Position = UDim2.new(0, 8, 0, 56)
    navBar.BackgroundTransparency = 1
    navBar.Parent = sidebar

    local navLayout = Instance.new("UIListLayout")
    navLayout.FillDirection = Enum.FillDirection.Vertical
    navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    navLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, 4)
    navLayout.Parent = navBar

    -- User profile card at sidebar bottom with shading & glow
    local profileCard = Instance.new("Frame")
    profileCard.Name = "ProfileCard"
    profileCard.Size = UDim2.new(1, -16, 0, 46)
    profileCard.Position = UDim2.new(0, 8, 1, -54)
    profileCard.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
    profileCard.BorderSizePixel = 0
    profileCard.Parent = sidebar

    local pStroke = Instance.new("UIStroke")
    pStroke.Color = Color3.fromRGB(30, 30, 36)
    pStroke.Thickness = 1
    pStroke.Parent = profileCard

    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 6)
    pCorner.Parent = profileCard

    local userAvatar = Instance.new("ImageLabel")
    userAvatar.Name = "Avatar"
    userAvatar.Size = UDim2.new(0, 32, 0, 32)
    userAvatar.Position = UDim2.new(0, 7, 0.5, -16)
    userAvatar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    userAvatar.BorderSizePixel = 0
    userAvatar.ScaleType = Enum.ScaleType.Crop
    userAvatar.ZIndex = 5
    userAvatar.Image = LocalPlayer and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId) or ""
    task.spawn(function()
        if not LocalPlayer then return end
        local ok, content = pcall(function()
            return (Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150))
        end)
        if ok and content and userAvatar.Parent then
            userAvatar.Image = content
        end
    end)
    userAvatar.Parent = profileCard

    local avCorner = Instance.new("UICorner")
    avCorner.CornerRadius = UDim.new(0, 5)
    avCorner.Parent = userAvatar

    local avStroke = Instance.new("UIStroke")
    avStroke.Color = Color3.fromRGB(40, 40, 48)
    avStroke.Thickness = 1
    avStroke.Parent = userAvatar

    local userLabel = Instance.new("TextLabel")
    userLabel.Name = "UserLabel"
    userLabel.Size = UDim2.new(1, -48, 0, 16)
    userLabel.Position = UDim2.new(0, 46, 0, 8)
    userLabel.BackgroundTransparency = 1
    userLabel.Font = Library.Theme.FontTitle
    userLabel.TextSize = 11
    userLabel.TextColor3 = Library.Theme.LabelText
    userLabel.TextXAlignment = Enum.TextXAlignment.Left
    userLabel.TextTruncate = Enum.TextTruncate.AtEnd
    userLabel.Text = LocalPlayer and ("@" .. LocalPlayer.Name) or "@user"
    userLabel.Parent = profileCard

    local userRole = Instance.new("TextLabel")
    userRole.Name = "UserRole"
    userRole.Size = UDim2.new(1, -48, 0, 12)
    userRole.Position = UDim2.new(0, 46, 0, 24)
    userRole.BackgroundTransparency = 1
    userRole.Font = Library.Theme.FontBody
    userRole.TextSize = 9
    userRole.TextColor3 = Library.Theme.MutedText
    userRole.TextXAlignment = Enum.TextXAlignment.Left
    userRole.Text = "subscriber"
    userRole.Parent = profileCard

    local function setVisibility(visible)
        isMenuVisible = visible
        if visible then
            mainFrame.Visible = true
            mainFrame.Size = UDim2.new(0, windowSize.X * 0.98, 0, windowSize.Y * 0.98)
            mainFrame.BackgroundTransparency = 0.3
            TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, windowSize.X, 0, windowSize.Y),
                BackgroundTransparency = 0
            }):Play()
            LibUIS.MouseBehavior = Enum.MouseBehavior.Default
            LibUIS.MouseIconEnabled = true
        else
            local tw = TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Size = UDim2.new(0, windowSize.X * 0.98, 0, windowSize.Y * 0.98),
                BackgroundTransparency = 1
            })
            tw:Play()
            tw.Completed:Connect(function()
                if not isMenuVisible then mainFrame.Visible = false end
            end)
        end
    end

    LibUIS.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            setVisibility(not isMenuVisible)
        end
    end)

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -175, 1, -16)
    contentArea.Position = UDim2.new(0, 168, 0, 8)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    -- Top-level Popup Overlay Frame (Bypasses scrolling frame clipping)
    local popupOverlay = Instance.new("Frame")
    popupOverlay.Name = "PopupOverlay"
    popupOverlay.Size = UDim2.new(1, 0, 1, 0)
    popupOverlay.Position = UDim2.new(0, 0, 0, 0)
    popupOverlay.BackgroundTransparency = 1
    popupOverlay.ZIndex = 9000
    popupOverlay.Parent = screenGui

    -- Notifications (bottom-right stack)
    local notifyHolder = Instance.new("Frame")
    notifyHolder.Name = "Notifications"
    notifyHolder.Size = UDim2.new(0, 260, 1, -24)
    notifyHolder.Position = UDim2.new(1, -272, 0, 0)
    notifyHolder.BackgroundTransparency = 1
    notifyHolder.ZIndex = 9500
    notifyHolder.Parent = screenGui

    local notifyLayout = Instance.new("UIListLayout")
    notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifyLayout.Padding = UDim.new(0, 6)
    notifyLayout.Parent = notifyHolder

    local notifyCount = 0
    function Library.Notify(text, duration)
        notifyCount = notifyCount + 1
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 34)
        card.LayoutOrder = notifyCount
        card.BackgroundColor3 = Library.Theme.GroupboxBg
        card.BackgroundTransparency = 1
        card.BorderSizePixel = 0
        card.ZIndex = 9501
        card.Parent = notifyHolder

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = Library.Theme.Accent
        cStroke.Transparency = 1
        cStroke.Parent = card

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 6)
        cCorner.Parent = card

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 1, -12)
        bar.Position = UDim2.new(0, 6, 0, 6)
        bar.BackgroundColor3 = Library.Theme.Accent
        bar.BackgroundTransparency = 1
        bar.BorderSizePixel = 0
        bar.ZIndex = 9502
        bar.Parent = card

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -24, 1, 0)
        lbl.Position = UDim2.new(0, 18, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Library.Theme.FontBody
        lbl.TextSize = 11
        lbl.TextColor3 = Library.Theme.TitlebarText
        lbl.TextTransparency = 1
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = tostring(text)
        lbl.ZIndex = 9502
        lbl.Parent = card

        local info = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        TweenService:Create(card, info, { BackgroundTransparency = 0.05 }):Play()
        TweenService:Create(cStroke, info, { Transparency = 0.5 }):Play()
        TweenService:Create(bar, info, { BackgroundTransparency = 0 }):Play()
        TweenService:Create(lbl, info, { TextTransparency = 0 }):Play()

        task.delay(duration or 3, function()
            local out = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            TweenService:Create(card, out, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(cStroke, out, { Transparency = 1 }):Play()
            TweenService:Create(bar, out, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(lbl, out, { TextTransparency = 1 }):Play()
            task.wait(0.3)
            card:Destroy()
        end)
    end

    -- Keybind list HUD (shows enabled features that have a key)
    local bindHud = Instance.new("Frame")
    bindHud.Name = "KeybindList"
    bindHud.Size = UDim2.new(0, 0, 0, 0)
    bindHud.AutomaticSize = Enum.AutomaticSize.XY
    bindHud.AnchorPoint = Vector2.new(1, 0)
    bindHud.Position = UDim2.new(1, -12, 0, 12)
    bindHud.BackgroundColor3 = Library.Theme.WindowBg
    bindHud.BackgroundTransparency = 0.1
    bindHud.BorderSizePixel = 0
    bindHud.Visible = false
    bindHud.ZIndex = 9400
    bindHud.Parent = screenGui

    local bhCorner = Instance.new("UICorner")
    bhCorner.CornerRadius = UDim.new(0, 5)
    bhCorner.Parent = bindHud

    local bhStroke = Instance.new("UIStroke")
    bhStroke.Color = Library.Theme.Accent
    bhStroke.Transparency = 0.55
    bhStroke.Parent = bindHud

    local bhPad = Instance.new("UIPadding")
    bhPad.PaddingTop = UDim.new(0, 6)
    bhPad.PaddingBottom = UDim.new(0, 6)
    bhPad.PaddingLeft = UDim.new(0, 10)
    bhPad.PaddingRight = UDim.new(0, 10)
    bhPad.Parent = bindHud

    local bhLayout = Instance.new("UIListLayout")
    bhLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bhLayout.Padding = UDim.new(0, 3)
    bhLayout.Parent = bindHud

    local bhTitle = Instance.new("TextLabel")
    bhTitle.Size = UDim2.new(1, 0, 0, 14)
    bhTitle.LayoutOrder = 0
    bhTitle.BackgroundTransparency = 1
    bhTitle.Font = Enum.Font.GothamBold
    bhTitle.TextSize = 11
    bhTitle.TextColor3 = Library.Theme.Accent
    bhTitle.TextXAlignment = Enum.TextXAlignment.Left
    bhTitle.Text = "KEYBINDS"
    bhTitle.ZIndex = 9401
    bhTitle.Parent = bindHud

    local bindRows = {}
    Library.BindHudEnabled = true
    function Library.RefreshBinds()
        for _, r in ipairs(bindRows) do r:Destroy() end
        table.clear(bindRows)
        local shown = 0
        for i, b in ipairs(Library.Binds) do
            local key = b.GetKey()
            if key and b.GetState() then
                shown = shown + 1
                local row = Instance.new("TextLabel")
                row.Size = UDim2.new(0, 0, 0, 14)
                row.AutomaticSize = Enum.AutomaticSize.X
                row.LayoutOrder = i
                row.BackgroundTransparency = 1
                row.Font = Library.Theme.FontBody
                row.TextSize = 11
                row.TextColor3 = Library.Theme.LabelText
                row.TextXAlignment = Enum.TextXAlignment.Left
                row.RichText = true
                local name = typeof(key) == "EnumItem" and key.Name:gsub("MouseButton", "MB") or tostring(key)
                row.Text = string.format("%s  <font color=\"rgb(120,190,255)\">[%s]</font>", b.Label, name)
                row.ZIndex = 9401
                row.Parent = bindHud
                table.insert(bindRows, row)
            end
        end
        bindHud.Visible = Library.BindHudEnabled and shown > 0
    end

    -- Watermark (name | game | fps | ping)
    local watermark = Instance.new("Frame")
    watermark.Name = "Watermark"
    watermark.AutomaticSize = Enum.AutomaticSize.X
    watermark.Size = UDim2.new(0, 0, 0, 24)
    watermark.Position = UDim2.new(0, 12, 0, 12)
    watermark.BackgroundColor3 = Library.Theme.WindowBg
    watermark.BackgroundTransparency = 0.1
    watermark.BorderSizePixel = 0
    watermark.ZIndex = 9400
    watermark.Parent = screenGui

    local wmCorner = Instance.new("UICorner")
    wmCorner.CornerRadius = UDim.new(0, 5)
    wmCorner.Parent = watermark

    local wmStroke = Instance.new("UIStroke")
    wmStroke.Color = Library.Theme.Accent
    wmStroke.Transparency = 0.55
    wmStroke.Parent = watermark

    local wmPad = Instance.new("UIPadding")
    wmPad.PaddingLeft = UDim.new(0, 10)
    wmPad.PaddingRight = UDim.new(0, 10)
    wmPad.Parent = watermark

    local wmLabel = Instance.new("TextLabel")
    wmLabel.AutomaticSize = Enum.AutomaticSize.X
    wmLabel.Size = UDim2.new(0, 0, 1, 0)
    wmLabel.BackgroundTransparency = 1
    wmLabel.Font = Library.Theme.FontBody
    wmLabel.TextSize = 11
    wmLabel.TextColor3 = Library.Theme.TitlebarText
    wmLabel.RichText = true
    wmLabel.ZIndex = 9401
    wmLabel.Parent = watermark

    local frames, lastWm = 0, os.clock()
    LibRS.RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - lastWm >= 0.5 then
            local fps = math.floor(frames / (now - lastWm) + 0.5)
            frames, lastWm = 0, now
            local ping = 0
            pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 2000) end)
            wmLabel.Text = string.format('<font color="rgb(120,190,255)">snow.cc</font>  |  %s  |  %d fps  |  %d ms', gameName, fps, ping)
        end
    end)

    local Window = {
        Watermark = watermark,
        SetToggleKey = function(_, k) toggleKey = k or toggleKey end,
        ScreenGui = screenGui,
        MainFrame = mainFrame,
        PopupOverlay = popupOverlay,
        Tabs = {},
        CurrentTab = nil,
    }

    function Window:CreateTab(tabName)
        local tabIndex = #Window.Tabs + 1

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = string.format("Tab_%02d_%s", tabIndex, tabName)
        tabBtn.Size = UDim2.new(1, 0, 0, 32)
        tabBtn.LayoutOrder = tabIndex
        tabBtn.BackgroundColor3 = Library.Theme.TabHoverBg
        tabBtn.BackgroundTransparency = 1
        tabBtn.BorderSizePixel = 0
        tabBtn.AutoButtonColor = false
        tabBtn.Text = ""
        tabBtn.Parent = navBar

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 6)
        tabCorner.Parent = tabBtn

        local tabStroke = Instance.new("UIStroke")
        tabStroke.Color = Library.Theme.TabActiveBorder
        tabStroke.Thickness = 1
        tabStroke.Transparency = 1
        tabStroke.Parent = tabBtn

        -- Glowing indicator strip on the left edge
        local tabGlowBar = Instance.new("Frame")
        tabGlowBar.Name = "GlowBar"
        tabGlowBar.Size = UDim2.new(0, 3, 0, 16)
        tabGlowBar.Position = UDim2.new(0, 4, 0.5, -8)
        tabGlowBar.BackgroundColor3 = Library.Theme.Accent
        tabGlowBar.BorderSizePixel = 0
        tabGlowBar.BackgroundTransparency = 1
        tabGlowBar.Parent = tabBtn

        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(1, 0)
        barCorner.Parent = tabGlowBar

        local tabLabel = Instance.new("TextLabel")
        tabLabel.Name = "Label"
        tabLabel.Size = UDim2.new(1, -22, 1, 0)
        tabLabel.Position = UDim2.new(0, 14, 0, 0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.Font = Library.Theme.FontTab
        tabLabel.TextSize = 13
        tabLabel.TextColor3 = Library.Theme.TabInactiveText
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.Text = tabName
        tabLabel.Parent = tabBtn

        -- Top-level container for this Tab (Houses fixed Top Nav Bar + Scrolling Content Area)
        local tabContainer = Instance.new("Frame")
        tabContainer.Name = "TabContainer_" .. tabName
        tabContainer.Size = UDim2.new(1, 0, 1, 0)
        tabContainer.Position = UDim2.new(0, 0, 0, 0)
        tabContainer.BackgroundTransparency = 1
        tabContainer.Visible = false
        tabContainer.Parent = contentArea

        -- Fixed Top Navigation Bar for Subtabs (Always visible at the top, never occluded by scrolling)
        local subtabBar = Instance.new("Frame")
        subtabBar.Name = "SubtabBar"
        subtabBar.Size = UDim2.new(1, 0, 0, 28)
        subtabBar.Position = UDim2.new(0, 0, 0, 0)
        subtabBar.BackgroundTransparency = 1
        subtabBar.Visible = false
        subtabBar.ZIndex = 50
        subtabBar.Parent = tabContainer

        local subBaseline = Instance.new("Frame")
        subBaseline.Name = "Baseline"
        subBaseline.Position = UDim2.new(0, 0, 0, 35)
        subBaseline.Size = UDim2.new(1, 0, 0, 1)
        subBaseline.BackgroundColor3 = Library.Theme.GroupboxBorder
        subBaseline.BorderSizePixel = 0
        subBaseline.ZIndex = 49
        subBaseline.Visible = false
        subBaseline.Parent = tabContainer

        local subLayout = Instance.new("UIListLayout")
        subLayout.FillDirection = Enum.FillDirection.Horizontal
        subLayout.SortOrder = Enum.SortOrder.LayoutOrder
        subLayout.Padding = UDim.new(0, 6)
        subLayout.Parent = subtabBar

        local tabContent = Instance.new("ScrollingFrame")
        tabContent.Name = "TabContent_" .. tabName
        tabContent.Size = UDim2.new(1, 0, 1, 0)
        tabContent.Position = UDim2.new(0, 0, 0, 0)
        tabContent.BackgroundTransparency = 1
        tabContent.BorderSizePixel = 0
        tabContent.ScrollBarThickness = 2
        tabContent.ScrollBarImageColor3 = Library.Theme.Accent
        tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tabContent.ClipsDescendants = true
        tabContent.Parent = tabContainer

        local tabCanvasGroup = Instance.new("CanvasGroup")
        tabCanvasGroup.Name = "TabCanvasGroup"
        tabCanvasGroup.Size = UDim2.new(1, 0, 0, 0)
        tabCanvasGroup.AutomaticSize = Enum.AutomaticSize.Y
        tabCanvasGroup.Position = UDim2.new(0, 0, 0, 0)
        tabCanvasGroup.BackgroundTransparency = 1
        tabCanvasGroup.GroupTransparency = 0
        tabCanvasGroup.BorderSizePixel = 0
        tabCanvasGroup.Parent = tabContent

        local columns = Instance.new("Frame")
        columns.Name = "Columns"
        columns.Size = UDim2.new(1, 0, 0, 0)
        columns.AutomaticSize = Enum.AutomaticSize.Y
        columns.BackgroundTransparency = 1
        columns.Parent = tabCanvasGroup

        local leftCol = Instance.new("Frame")
        leftCol.Name = "LeftCol"
        leftCol.Size = UDim2.new(0.5, -6, 0, 0)
        leftCol.Position = UDim2.new(0, 0, 0, 0)
        leftCol.AutomaticSize = Enum.AutomaticSize.Y
        leftCol.BackgroundTransparency = 1
        leftCol.Parent = columns

        local leftLayout = Instance.new("UIListLayout")
        leftLayout.FillDirection = Enum.FillDirection.Vertical
        leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
        leftLayout.Padding = UDim.new(0, 10)
        leftLayout.Parent = leftCol

        local rightCol = Instance.new("Frame")
        rightCol.Name = "RightCol"
        rightCol.Size = UDim2.new(0.5, -6, 0, 0)
        rightCol.Position = UDim2.new(0.5, 6, 0, 0)
        rightCol.AutomaticSize = Enum.AutomaticSize.Y
        rightCol.BackgroundTransparency = 1
        rightCol.Parent = columns

        local rightLayout = Instance.new("UIListLayout")
        rightLayout.FillDirection = Enum.FillDirection.Vertical
        rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rightLayout.Padding = UDim.new(0, 10)
        rightLayout.Parent = rightCol

        local tabData = {
            Name = tabName,
            Button = tabBtn,
            Label = tabLabel,
            GlowBar = tabGlowBar,
            Stroke = tabStroke,
            Content = tabContainer,
            Scroll = tabContent,
            Canvas = tabCanvasGroup,
            Left = leftCol,
            Right = rightCol,
        }

        local function updateTabAppearance(active, hovered)
            if active then
                TweenService:Create(tabBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Library.Theme.TabActiveBg,
                    BackgroundTransparency = 0
                }):Play()
                TweenService:Create(tabLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    TextColor3 = Library.Theme.TabActiveText,
                    Position = UDim2.new(0, 16, 0, 0)
                }):Play()
                TweenService:Create(tabGlowBar, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 0,
                    Size = UDim2.new(0, 3, 0, 16)
                }):Play()
                TweenService:Create(tabStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Transparency = 0
                }):Play()
            elseif hovered then
                TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Library.Theme.TabHoverBg,
                    BackgroundTransparency = 0.5
                }):Play()
                TweenService:Create(tabLabel, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    TextColor3 = Color3.fromRGB(220, 220, 230),
                    Position = UDim2.new(0, 15, 0, 0)
                }):Play()
                TweenService:Create(tabGlowBar, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 0.6,
                    Size = UDim2.new(0, 3, 0, 8)
                }):Play()
            else
                TweenService:Create(tabBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 1
                }):Play()
                TweenService:Create(tabLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    TextColor3 = Library.Theme.TabInactiveText,
                    Position = UDim2.new(0, 14, 0, 0)
                }):Play()
                TweenService:Create(tabGlowBar, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 3, 0, 4)
                }):Play()
                TweenService:Create(tabStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Transparency = 1
                }):Play()
            end
        end

        tabBtn.MouseEnter:Connect(function()
            if Window.CurrentTab ~= tabData then
                updateTabAppearance(false, true)
            end
        end)

        tabBtn.MouseLeave:Connect(function()
            if Window.CurrentTab ~= tabData then
                updateTabAppearance(false, false)
            end
        end)

        local function selectTab()
            if Window.CurrentTab == tabData then return end
            local prevTab = Window.CurrentTab

            for _, t in ipairs(Window.Tabs) do
                if t ~= tabData then
                    if t == prevTab then
                        local outTween = TweenService:Create(t.Canvas, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                            GroupTransparency = 1,
                            Position = UDim2.new(0, -10, 0, 0)
                        })
                        outTween:Play()
                        outTween.Completed:Connect(function()
                            if Window.CurrentTab ~= t then
                                t.Content.Visible = false
                            end
                        end)
                    else
                        t.Content.Visible = false
                    end

                    TweenService:Create(t.Button, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 1
                    }):Play()
                    TweenService:Create(t.Label, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        TextColor3 = Library.Theme.TabInactiveText,
                        Position = UDim2.new(0, 14, 0, 0)
                    }):Play()
                    TweenService:Create(t.GlowBar, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, 3, 0, 4)
                    }):Play()
                    TweenService:Create(t.Stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Transparency = 1
                    }):Play()
                end
            end

            tabData.Content.Visible = true
            tabData.Canvas.Position = UDim2.new(0, 14, 0, 0)
            tabData.Canvas.GroupTransparency = 1

            TweenService:Create(tabData.Canvas, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                GroupTransparency = 0,
                Position = UDim2.new(0, 0, 0, 0)
            }):Play()

            updateTabAppearance(true, false)
            Window.CurrentTab = tabData
        end

        tabBtn.MouseButton1Click:Connect(selectTab)
        if #Window.Tabs == 0 then selectTab() end

        table.insert(Window.Tabs, tabData)

        local Tab = {}
        local groupboxCount = 0
        local hasSubtabs = false
        local subtabs = {}
        local currentSubtab = nil

        function Tab:CreateSubtab(subName)
            if not hasSubtabs then
                hasSubtabs = true
                columns.Visible = false
                subtabBar.Visible = true
                subBaseline.Visible = true
                -- Offset the scrolling pane below the fixed top navbar
                tabContent.Position = UDim2.new(0, 0, 0, 36)
                tabContent.Size = UDim2.new(1, 0, 1, -36)
            end

            local subIdx = #subtabs + 1

            local subBtn = Instance.new("TextButton")
            subBtn.Name = string.format("SubTab_%02d_%s", subIdx, subName)
            subBtn.Size = UDim2.new(0, 0, 1, 0)
            subBtn.AutomaticSize = Enum.AutomaticSize.X
            subBtn.BackgroundTransparency = 1
            subBtn.BorderSizePixel = 0
            subBtn.AutoButtonColor = false
            subBtn.Font = Library.Theme.FontTab
            subBtn.TextSize = 12
            subBtn.TextColor3 = Library.Theme.TabInactiveText
            subBtn.Text = subName
            subBtn.LayoutOrder = subIdx
            subBtn.ZIndex = 51
            subBtn.Parent = subtabBar

            local sPad = Instance.new("UIPadding")
            sPad.PaddingLeft = UDim.new(0, 16)
            sPad.PaddingRight = UDim.new(0, 16)
            sPad.Parent = subBtn

            local sStroke = { Color = Library.Theme.Accent }

            local underGlow = Instance.new("Frame")
            underGlow.Name = "UnderlineGlow"
            underGlow.AnchorPoint = Vector2.new(0.5, 1)
            underGlow.Position = UDim2.new(0.5, 0, 1, 1)
            underGlow.Size = UDim2.new(0, 0, 0, 9)
            underGlow.BackgroundColor3 = Library.Theme.Accent
            underGlow.BackgroundTransparency = 1
            underGlow.BorderSizePixel = 0
            underGlow.ZIndex = 50
            underGlow.Parent = subBtn

            local ugCorner = Instance.new("UICorner")
            ugCorner.CornerRadius = UDim.new(1, 0)
            ugCorner.Parent = underGlow

            local ugGrad = Instance.new("UIGradient")
            ugGrad.Rotation = 90
            ugGrad.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0.35),
            })
            ugGrad.Parent = underGlow

            local underline = Instance.new("Frame")
            underline.Name = "Underline"
            underline.AnchorPoint = Vector2.new(0.5, 1)
            underline.Position = UDim2.new(0.5, 0, 1, 0)
            underline.Size = UDim2.new(0, 0, 0, 2)
            underline.BackgroundColor3 = Library.Theme.AccentGlow
            underline.BackgroundTransparency = 1
            underline.BorderSizePixel = 0
            underline.ZIndex = 52
            underline.Parent = subBtn

            local subCols = Instance.new("Frame")
            subCols.Name = "Columns_" .. subName
            subCols.Size = UDim2.new(1, 0, 0, 0)
            subCols.AutomaticSize = Enum.AutomaticSize.Y
            subCols.BackgroundTransparency = 1
            subCols.Visible = false
            subCols.LayoutOrder = subIdx + 10
            subCols.Parent = tabCanvasGroup

            local sLeft = Instance.new("Frame")
            sLeft.Name = "LeftCol"
            sLeft.Size = UDim2.new(0.5, -6, 0, 0)
            sLeft.Position = UDim2.new(0, 0, 0, 0)
            sLeft.AutomaticSize = Enum.AutomaticSize.Y
            sLeft.BackgroundTransparency = 1
            sLeft.Parent = subCols

            local sLeftLayout = Instance.new("UIListLayout")
            sLeftLayout.FillDirection = Enum.FillDirection.Vertical
            sLeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
            sLeftLayout.Padding = UDim.new(0, 10)
            sLeftLayout.Parent = sLeft

            local sRight = Instance.new("Frame")
            sRight.Name = "RightCol"
            sRight.Size = UDim2.new(0.5, -6, 0, 0)
            sRight.Position = UDim2.new(0.5, 6, 0, 0)
            sRight.AutomaticSize = Enum.AutomaticSize.Y
            sRight.BackgroundTransparency = 1
            sRight.Parent = subCols

            local sRightLayout = Instance.new("UIListLayout")
            sRightLayout.FillDirection = Enum.FillDirection.Vertical
            sRightLayout.SortOrder = Enum.SortOrder.LayoutOrder
            sRightLayout.Padding = UDim.new(0, 10)
            sRightLayout.Parent = sRight

            local subObj = {
                Name = subName,
                Button = subBtn,
                Stroke = sStroke,
                Columns = subCols,
                Left = sLeft,
                Right = sRight,
            }

            local barTween = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            local function setSubActive(active)
                subCols.Visible = active
                TweenService:Create(subBtn, barTween, {
                    TextColor3 = active and Color3.fromRGB(255, 255, 255) or Library.Theme.TabInactiveText
                }):Play()
                TweenService:Create(underline, barTween, {
                    Size = active and UDim2.new(1, -16, 0, 2) or UDim2.new(0, 0, 0, 2),
                    BackgroundTransparency = active and 0 or 1
                }):Play()
                TweenService:Create(underGlow, barTween, {
                    Size = active and UDim2.new(1, -8, 0, 9) or UDim2.new(0, 0, 0, 9),
                    BackgroundTransparency = active and 0.45 or 1
                }):Play()
            end

            subBtn.MouseButton1Click:Connect(function()
                for _, s in ipairs(subtabs) do
                    s.SetActive(s == subObj)
                end
                currentSubtab = subObj
            end)

            subBtn.MouseEnter:Connect(function()
                if currentSubtab ~= subObj then
                    TweenService:Create(subBtn, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(215, 228, 245) }):Play()
                end
            end)

            subBtn.MouseLeave:Connect(function()
                if currentSubtab ~= subObj then
                    TweenService:Create(subBtn, TweenInfo.new(0.12), { TextColor3 = Library.Theme.TabInactiveText }):Play()
                end
            end)

            subObj.SetActive = setSubActive
            table.insert(subtabs, subObj)

            if #subtabs == 1 then
                subObj.SetActive(true)
                currentSubtab = subObj
            else
                subObj.SetActive(false)
            end

            function subObj:CreateGroupbox(title, colSide)
                return Tab:_InternalCreateGroupbox(title, colSide, sLeft, sRight)
            end

            return subObj
        end

        function Tab:CreateGroupbox(groupTitleText, columnSide)
            return Tab:_InternalCreateGroupbox(groupTitleText, columnSide, leftCol, rightCol)
        end

        function Tab:_InternalCreateGroupbox(groupTitleText, columnSide, targetLeftCol, targetRightCol)
            local parentCol = (columnSide == "Right") and (targetRightCol or rightCol) or (targetLeftCol or leftCol)
            groupboxCount = groupboxCount + 1
            local parentCol = (columnSide == "Right") and (targetRightCol or rightCol) or (targetLeftCol or leftCol)

            local groupbox = Instance.new("Frame")
            groupbox.Name = string.format("Group_%02d_%s", groupboxCount, groupTitleText)
            groupbox.LayoutOrder = groupboxCount
            groupbox.Size = UDim2.new(1, 0, 0, 0)
            groupbox.AutomaticSize = Enum.AutomaticSize.Y
            groupbox.BackgroundColor3 = Library.Theme.GroupboxBg
            groupbox.BorderSizePixel = 0
            groupbox.Parent = parentCol

            local groupCorner = Instance.new("UICorner")
            groupCorner.CornerRadius = UDim.new(0, 4)
            groupCorner.Parent = groupbox

            local groupStroke = Instance.new("UIStroke")
            groupStroke.Color = Library.Theme.GroupboxBorder
            groupStroke.Thickness = 1
            groupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            groupStroke.Parent = groupbox

            local groupTitle = Instance.new("TextLabel")
            groupTitle.Name = "GroupTitle"
            groupTitle.Size = UDim2.new(1, -16, 0, 22)
            groupTitle.Position = UDim2.new(0, 10, 0, 4)
            groupTitle.BackgroundTransparency = 1
            groupTitle.Font = Enum.Font.GothamBold
            groupTitle.TextSize = 11
            groupTitle.TextColor3 = Library.Theme.GroupboxTitle
            groupTitle.TextXAlignment = Enum.TextXAlignment.Left
            groupTitle.Text = string.upper(groupTitleText)
            groupTitle.Parent = groupbox

            local itemsContainer = Instance.new("Frame")
            itemsContainer.Name = "Items"
            itemsContainer.Size = UDim2.new(1, -20, 0, 0)
            itemsContainer.Position = UDim2.new(0, 10, 0, 28)
            itemsContainer.AutomaticSize = Enum.AutomaticSize.Y
            itemsContainer.BackgroundTransparency = 1
            itemsContainer.Parent = groupbox

            local itemsLayout = Instance.new("UIListLayout")
            itemsLayout.FillDirection = Enum.FillDirection.Vertical
            itemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
            itemsLayout.Padding = UDim.new(0, 7)
            itemsLayout.Parent = itemsContainer

            local bottomPad = Instance.new("UIPadding")
            bottomPad.PaddingBottom = UDim.new(0, 10)
            bottomPad.Parent = itemsContainer

            local Group = {}
            local itemOrder = 0
            local function nextOrder()
                itemOrder = itemOrder + 1
                return itemOrder
            end

            local function formatKeyName(key)
                if not key then return "None" end
                if typeof(key) == "EnumItem" then
                    if key == Enum.UserInputType.MouseButton1 then
                        return "MB1"
                    elseif key == Enum.UserInputType.MouseButton2 then
                        return "MB2"
                    elseif key == Enum.UserInputType.MouseButton3 then
                        return "MB3"
                    elseif key.EnumType == Enum.KeyCode then
                        if key == Enum.KeyCode.RightShift then return "RShift" end
                        if key == Enum.KeyCode.LeftShift then return "LShift" end
                        if key == Enum.KeyCode.RightControl then return "RCtrl" end
                        if key == Enum.KeyCode.LeftControl then return "LCtrl" end
                        if key == Enum.KeyCode.RightAlt then return "RAlt" end
                        if key == Enum.KeyCode.LeftAlt then return "LAlt" end
                        return key.Name
                    end
                end
                return tostring(key)
            end

            function Group:AddToggle(label, default, options)
                local state = default or false
                local keybind = options and options.Keybind or nil
                local onKeyChanged = options and options.OnKeyChanged
                local callback = options and options.Callback
                local order = nextOrder()

                local row = Instance.new("Frame")
                row.Name = string.format("%03d_Toggle_%s", order, label)
                row.LayoutOrder = order
                row.Size = UDim2.new(1, 0, 0, 19)
                row.BackgroundTransparency = 1
                row.Parent = itemsContainer

                local box = Instance.new("TextButton")
                box.Name = "CheckSquare"
                box.Size = UDim2.new(0, 13, 0, 13)
                box.Position = UDim2.new(0, 0, 0.5, -6)
                box.BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.InputBg
                box.BorderSizePixel = 0
                box.Text = ""
                box.AutoButtonColor = false
                box.Parent = row

                local boxStroke = Instance.new("UIStroke")
                boxStroke.Color = state and Library.Theme.Accent or Library.Theme.InputBorder
                boxStroke.Thickness = 1
                boxStroke.Parent = box

                local boxCorner = Instance.new("UICorner")
                boxCorner.CornerRadius = UDim.new(0, 3)
                boxCorner.Parent = box

                local textBtn = Instance.new("TextButton")
                textBtn.Name = "LabelBtn"
                textBtn.Size = UDim2.new(1, -55, 1, 0)
                textBtn.Position = UDim2.new(0, 22, 0, 0)
                textBtn.BackgroundTransparency = 1
                textBtn.Font = Library.Theme.FontBody
                textBtn.TextSize = 11
                textBtn.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                textBtn.TextXAlignment = Enum.TextXAlignment.Left
                textBtn.Text = label
                textBtn.Parent = row

                local function paintToggle()
                    TweenService:Create(box, TweenInfo.new(0.12), { BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.InputBg }):Play()
                    TweenService:Create(boxStroke, TweenInfo.new(0.12), { Color = state and Library.Theme.Accent or Library.Theme.InputBorder }):Play()
                    textBtn.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                end

                local currentKey = keybind
                local listening = false
                local toggleState
                if keybind ~= nil or onKeyChanged ~= nil or (options and options.HasKeybind) then
                    local listenStartTime = 0

                    local keybindBtn = Instance.new("TextButton")
                    keybindBtn.Name = "Keybind"
                    keybindBtn.Size = UDim2.new(0, 42, 0, 16)
                    keybindBtn.Position = UDim2.new(1, -42, 0.5, -8)
                    keybindBtn.BackgroundColor3 = Library.Theme.InputBg
                    keybindBtn.BorderSizePixel = 0
                    keybindBtn.Font = Library.Theme.FontBody
                    keybindBtn.TextSize = 10
                    keybindBtn.TextColor3 = Library.Theme.MutedText
                    keybindBtn.Text = formatKeyName(currentKey)
                    keybindBtn.Parent = row

                    local kbStroke = Instance.new("UIStroke")
                    kbStroke.Color = Library.Theme.InputBorder
                    kbStroke.Thickness = 1
                    kbStroke.Parent = keybindBtn

                    keybindBtn.MouseButton1Click:Connect(function()
                        listening = true
                        listenStartTime = tick()
                        keybindBtn.Text = "..."
                        keybindBtn.TextColor3 = Library.Theme.Accent
                    end)

                    LibUIS.InputBegan:Connect(function(input, gpe)
                        if not listening then return end
                        if tick() - listenStartTime < 0.12 then return end

                        local chosen = nil
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            if input.KeyCode == Enum.KeyCode.Escape then
                                keybindBtn.Text = formatKeyName(currentKey)
                                keybindBtn.TextColor3 = Library.Theme.MutedText
                                listening = false
                                return
                            elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                                chosen = nil
                            else
                                chosen = input.KeyCode
                            end
                        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                            chosen = Enum.UserInputType.MouseButton1
                        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                            chosen = Enum.UserInputType.MouseButton2
                        elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                            chosen = Enum.UserInputType.MouseButton3
                        end

                        if chosen ~= nil or input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                            currentKey = chosen
                            keybindBtn.Text = formatKeyName(currentKey)
                            keybindBtn.TextColor3 = Library.Theme.MutedText
                            listening = false
                            if onKeyChanged then pcall(onKeyChanged, currentKey) end
                            if Library.RefreshBinds then Library.RefreshBinds() end
                        end
                    end)
                end

                toggleState = function()
                    state = not state
                    paintToggle()
                    if callback then pcall(callback, state) end
                    if Library.RefreshBinds then Library.RefreshBinds() end
                end

                local bindEntry = {
                    Label = label,
                    GetState = function() return state end,
                    GetKey = function() return currentKey end,
                }
                table.insert(Library.Binds, bindEntry)

                LibUIS.InputBegan:Connect(function(input, gpe)
                    if gpe or listening or not currentKey then return end
                    if input.KeyCode == currentKey or input.UserInputType == currentKey then
                        toggleState()
                    end
                end)

                box.MouseButton1Click:Connect(toggleState)
                textBtn.MouseButton1Click:Connect(toggleState)

                return {
                    SetValue = function(newVal)
                        state = newVal
                        paintToggle()
                        if callback then pcall(callback, state) end
                        if Library.RefreshBinds then Library.RefreshBinds() end
                    end,
                    GetValue = function() return state end,
                }
            end

            function Group:AddKeybind(label, default, callback)
                local currentKey = default or nil
                local listening = false
                local listenStartTime = 0
                local order = nextOrder()

                local row = Instance.new("Frame")
                row.Name = string.format("%03d_Keybind_%s", order, label)
                row.LayoutOrder = order
                row.Size = UDim2.new(1, 0, 0, 20)
                row.BackgroundTransparency = 1
                row.Parent = itemsContainer

                local labelText = Instance.new("TextLabel")
                labelText.Name = "Label"
                labelText.Size = UDim2.new(1, -50, 1, 0)
                labelText.BackgroundTransparency = 1
                labelText.Font = Library.Theme.FontBody
                labelText.TextSize = 11
                labelText.TextColor3 = Library.Theme.LabelText
                labelText.TextXAlignment = Enum.TextXAlignment.Left
                labelText.Text = label
                labelText.Parent = row

                local keyBtn = Instance.new("TextButton")
                keyBtn.Name = "KeyButton"
                keyBtn.Size = UDim2.new(0, 42, 0, 18)
                keyBtn.Position = UDim2.new(1, -42, 0.5, -9)
                keyBtn.BackgroundColor3 = Library.Theme.InputBg
                keyBtn.BorderSizePixel = 0
                keyBtn.Font = Library.Theme.FontBody
                keyBtn.TextSize = 10
                keyBtn.TextColor3 = Library.Theme.MutedText
                keyBtn.Text = formatKeyName(currentKey)
                keyBtn.Parent = row

                local kbStroke = Instance.new("UIStroke")
                kbStroke.Color = Library.Theme.InputBorder
                kbStroke.Thickness = 1
                kbStroke.Parent = keyBtn

                keyBtn.MouseButton1Click:Connect(function()
                    listening = true
                    listenStartTime = tick()
                    keyBtn.Text = "..."
                    keyBtn.TextColor3 = Library.Theme.Accent
                end)

                LibUIS.InputBegan:Connect(function(input, gpe)
                    if not listening then return end
                    if tick() - listenStartTime < 0.12 then return end

                    local chosen = nil
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode == Enum.KeyCode.Escape then
                            keyBtn.Text = formatKeyName(currentKey)
                            keyBtn.TextColor3 = Library.Theme.MutedText
                            listening = false
                            return
                        elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                            chosen = nil
                        else
                            chosen = input.KeyCode
                        end
                    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                        chosen = Enum.UserInputType.MouseButton1
                    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                        chosen = Enum.UserInputType.MouseButton2
                    elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                        chosen = Enum.UserInputType.MouseButton3
                    end

                    if chosen ~= nil or input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                        currentKey = chosen
                        keyBtn.Text = formatKeyName(currentKey)
                        keyBtn.TextColor3 = Library.Theme.MutedText
                        listening = false
                        if callback then pcall(callback, currentKey) end
                    end
                end)

                return {
                    SetKey = function(newKey)
                        currentKey = newKey
                        keyBtn.Text = formatKeyName(currentKey)
                        if callback then pcall(callback, currentKey) end
                    end,
                    GetKey = function() return currentKey end,
                }
            end

            function Group:AddSlider(label, min, max, default, unit, callback)
                local currentVal = math.clamp(default or min, min, max)
                local u = unit or ""
                local order = nextOrder()

                local sliderContainer = Instance.new("Frame")
                sliderContainer.Name = string.format("%03d_Slider_%s", order, label)
                sliderContainer.LayoutOrder = order
                sliderContainer.Size = UDim2.new(1, 0, 0, 38)
                sliderContainer.BackgroundTransparency = 1
                sliderContainer.Parent = itemsContainer

                -- Header row: Label on left, editable value box on right
                local headerRow = Instance.new("Frame")
                headerRow.Size = UDim2.new(1, 0, 0, 16)
                headerRow.BackgroundTransparency = 1
                headerRow.Parent = sliderContainer

                local labelText = Instance.new("TextLabel")
                labelText.Name = "Label"
                labelText.Size = UDim2.new(1, -70, 1, 0)
                labelText.BackgroundTransparency = 1
                labelText.Font = Library.Theme.FontBody
                labelText.TextSize = 11
                labelText.TextColor3 = Library.Theme.LabelText
                labelText.TextXAlignment = Enum.TextXAlignment.Left
                labelText.Text = label
                labelText.Parent = headerRow

                local valueBox = Instance.new("TextBox")
                valueBox.Name = "ValueBox"
                valueBox.Size = UDim2.new(0, 68, 1, 0)
                valueBox.Position = UDim2.new(1, -68, 0, 0)
                valueBox.BackgroundTransparency = 1
                valueBox.Font = Library.Theme.FontBody
                valueBox.TextSize = 10
                valueBox.TextColor3 = Library.Theme.Accent
                valueBox.TextXAlignment = Enum.TextXAlignment.Right
                valueBox.Text = string.format("%d%s / %d%s", currentVal, u, max, u)
                valueBox.ClearTextOnFocus = false
                valueBox.Parent = headerRow

                -- Streamlined Thin Track (5px height, clean minimalist profile)
                local track = Instance.new("TextButton")
                track.Name = "Track"
                track.Size = UDim2.new(1, 0, 0, 6)
                track.Position = UDim2.new(0, 0, 0, 22)
                track.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                track.BorderSizePixel = 0
                track.AutoButtonColor = false
                track.Text = ""
                track.ClipsDescendants = false
                track.Parent = sliderContainer

                local tCorner = Instance.new("UICorner")
                tCorner.CornerRadius = UDim.new(1, 0)
                tCorner.Parent = track

                local trackStroke = Instance.new("UIStroke")
                trackStroke.Color = Color3.fromRGB(32, 32, 38)
                trackStroke.Thickness = 1
                trackStroke.Parent = track

                -- Active Fill Bar (Clean gradient bar without circle knob)
                local fill = Instance.new("Frame")
                fill.Name = "Fill"
                local alpha = (currentVal - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                fill.BackgroundColor3 = Library.Theme.Accent
                fill.BorderSizePixel = 0
                fill.ClipsDescendants = false
                fill.Parent = track

                local fCorner = Instance.new("UICorner")
                fCorner.CornerRadius = UDim.new(1, 0)
                fCorner.Parent = fill

                local fGrad = Instance.new("UIGradient")
                fGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Library.Theme.Accent),
                    ColorSequenceKeypoint.new(1, Library.Theme.AccentGlow)
                })
                fGrad.Parent = fill

                -- Right-edge vertical accent bar for subtle high-contrast terminus
                local fillCap = Instance.new("Frame")
                fillCap.Name = "Cap"
                fillCap.Size = UDim2.new(0, 2, 1, 2)
                fillCap.AnchorPoint = Vector2.new(1, 0.5)
                fillCap.Position = UDim2.new(1, 0, 0.5, 0)
                fillCap.BackgroundColor3 = Library.Theme.AccentGlow
                fillCap.BorderSizePixel = 0
                fillCap.Parent = fill

                local cCorner = Instance.new("UICorner")
                cCorner.CornerRadius = UDim.new(1, 0)
                cCorner.Parent = fillCap

                local sliding = false
                local function updateSlide(input)
                    local trackX = track.AbsolutePosition.X
                    local trackW = track.AbsoluteSize.X
                    if trackW <= 0 then return end

                    local mouseX = input.Position.X
                    local pct = math.clamp((mouseX - trackX) / trackW, 0, 1)
                    local val = math.floor(min + ((max - min) * pct))
                    currentVal = val

                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    valueBox.Text = string.format("%d%s / %d%s", val, u, max, u)
                    if callback then pcall(callback, val) end
                end

                track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        TweenService:Create(track, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(24, 24, 30) }):Play()
                        TweenService:Create(trackStroke, TweenInfo.new(0.12), { Color = Library.Theme.Accent }):Play()
                        TweenService:Create(valueBox, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
                        updateSlide(input)
                    end
                end)

                track.MouseEnter:Connect(function()
                    if not sliding then
                        TweenService:Create(trackStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(65, 65, 78) }):Play()
                        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(22, 22, 28) }):Play()
                    end
                end)

                track.MouseLeave:Connect(function()
                    if not sliding then
                        TweenService:Create(trackStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(32, 32, 38) }):Play()
                        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(18, 18, 22) }):Play()
                    end
                end)

                LibUIS.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if sliding then
                            sliding = false
                            TweenService:Create(trackStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(32, 32, 38) }):Play()
                            TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(18, 18, 22) }):Play()
                            TweenService:Create(valueBox, TweenInfo.new(0.15), { TextColor3 = Library.Theme.Accent }):Play()
                        end
                    end
                end)

                LibUIS.InputChanged:Connect(function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateSlide(input)
                    end
                end)

                -- Allow direct numeric editing
                valueBox.FocusLost:Connect(function()
                    local num = tonumber(valueBox.Text:match("%d+"))
                    if num then
                        local clamped = math.clamp(num, min, max)
                        currentVal = clamped
                        local pct = (currentVal - min) / (max - min)
                        fill.Size = UDim2.new(pct, 0, 1, 0)
                        valueBox.Text = string.format("%d%s / %d%s", currentVal, u, max, u)
                        if callback then pcall(callback, currentVal) end
                    else
                        valueBox.Text = string.format("%d%s / %d%s", currentVal, u, max, u)
                    end
                end)

                return {
                    SetValue = function(val)
                        currentVal = math.clamp(val, min, max)
                        local pct = (currentVal - min) / (max - min)
                        fill.Size = UDim2.new(pct, 0, 1, 0)
                        valueBox.Text = string.format("%d%s / %d%s", currentVal, u, max, u)
                        if callback then pcall(callback, currentVal) end
                    end,
                    GetValue = function() return currentVal end,
                }
            end

            function Group:AddTextbox(label, default, placeholder, callback)
                local currentVal = default or ""
                local order = nextOrder()

                local row = Instance.new("Frame")
                row.Name = string.format("%03d_Text_%s", order, label)
                row.LayoutOrder = order
                row.Size = UDim2.new(1, 0, 0, 40)
                row.BackgroundTransparency = 1
                row.Parent = itemsContainer

                local labelText = Instance.new("TextLabel")
                labelText.Name = "Label"
                labelText.Size = UDim2.new(1, 0, 0, 14)
                labelText.BackgroundTransparency = 1
                labelText.Font = Library.Theme.FontBody
                labelText.TextSize = 11
                labelText.TextColor3 = Library.Theme.LabelText
                labelText.TextXAlignment = Enum.TextXAlignment.Left
                labelText.Text = label
                labelText.Parent = row

                local box = Instance.new("TextBox")
                box.Name = "Box"
                box.Size = UDim2.new(1, 0, 0, 22)
                box.Position = UDim2.new(0, 0, 0, 16)
                box.BackgroundColor3 = Library.Theme.InputBg
                box.BorderSizePixel = 0
                box.Font = Library.Theme.FontBody
                box.TextSize = 10
                box.TextColor3 = Library.Theme.LabelText
                box.PlaceholderColor3 = Library.Theme.MutedText
                box.PlaceholderText = placeholder or ""
                box.Text = currentVal
                box.ClearTextOnFocus = false
                box.TextXAlignment = Enum.TextXAlignment.Left
                box.Parent = row

                local pad = Instance.new("UIPadding")
                pad.PaddingLeft = UDim.new(0, 6)
                pad.Parent = box

                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 4)
                corner.Parent = box

                local stroke = Instance.new("UIStroke")
                stroke.Color = Library.Theme.InputBorder
                stroke.Thickness = 1
                stroke.Parent = box

                box.Focused:Connect(function()
                    stroke.Color = Library.Theme.Accent
                end)

                box.FocusLost:Connect(function()
                    stroke.Color = Library.Theme.InputBorder
                    currentVal = box.Text
                    if callback then pcall(callback, currentVal) end
                end)

                return {
                    SetValue = function(v)
                        currentVal = tostring(v)
                        box.Text = currentVal
                        if callback then pcall(callback, currentVal) end
                    end,
                    GetValue = function() return currentVal end,
                }
            end

            function Group:AddSegmented(label, options, default, callback)
                local selected = default or options[1]
                local order = nextOrder()

                local row = Instance.new("Frame")
                row.Name = string.format("%03d_Seg_%s", order, label)
                row.LayoutOrder = order
                row.Size = UDim2.new(1, 0, 0, 42)
                row.BackgroundTransparency = 1
                row.Parent = itemsContainer

                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, 0, 0, 14)
                title.BackgroundTransparency = 1
                title.Font = Library.Theme.FontBody
                title.TextSize = 11
                title.TextColor3 = Library.Theme.LabelText
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.Text = label
                title.Parent = row

                local bar = Instance.new("Frame")
                bar.Size = UDim2.new(1, 0, 0, 22)
                bar.Position = UDim2.new(0, 0, 0, 16)
                bar.BackgroundColor3 = Library.Theme.InputBg
                bar.BorderSizePixel = 0
                bar.Parent = row

                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(0, 4)
                bCorner.Parent = bar

                local bStroke = Instance.new("UIStroke")
                bStroke.Color = Library.Theme.InputBorder
                bStroke.Thickness = 1
                bStroke.Parent = bar

                local layout = Instance.new("UIListLayout")
                layout.FillDirection = Enum.FillDirection.Horizontal
                layout.SortOrder = Enum.SortOrder.LayoutOrder
                layout.Padding = UDim.new(0, 3)
                layout.Parent = bar

                local pad = Instance.new("UIPadding")
                pad.PaddingLeft = UDim.new(0, 3)
                pad.PaddingRight = UDim.new(0, 3)
                pad.PaddingTop = UDim.new(0, 3)
                pad.PaddingBottom = UDim.new(0, 3)
                pad.Parent = bar

                local buttons = {}
                local function paint()
                    for name, btn in pairs(buttons) do
                        local on = (name == selected)
                        btn.BackgroundColor3 = on and Color3.fromRGB(40, 40, 48) or Color3.fromRGB(14, 14, 18)
                        btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Library.Theme.MutedText
                    end
                end

                for idx, name in ipairs(options) do
                    local btn = Instance.new("TextButton")
                    btn.Name = "Seg_" .. name
                    btn.LayoutOrder = idx
                    btn.Size = UDim2.new(1 / #options, -4, 1, 0)
                    btn.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
                    btn.BorderSizePixel = 0
                    btn.AutoButtonColor = false
                    btn.Font = Library.Theme.FontBody
                    btn.TextSize = 10
                    btn.TextColor3 = Library.Theme.MutedText
                    btn.Text = name
                    btn.Parent = bar

                    local c = Instance.new("UICorner")
                    c.CornerRadius = UDim.new(0, 3)
                    c.Parent = btn

                    btn.MouseButton1Click:Connect(function()
                        selected = name
                        paint()
                        if callback then pcall(callback, selected) end
                    end)

                    buttons[name] = btn
                end

                paint()

                return {
                    SetValue = function(v)
                        if buttons[v] then
                            selected = v
                            paint()
                            if callback then pcall(callback, selected) end
                        end
                    end,
                    GetValue = function() return selected end,
                }
            end

            function Group:AddDropdown(label, items, default, callback)
                local currentItems = items or {}
                local selected = default or currentItems[1] or "None"
                local isOpen = false
                local order = nextOrder()

                local dropContainer = Instance.new("Frame")
                dropContainer.Name = string.format("%03d_Dropdown_%s", order, label)
                dropContainer.LayoutOrder = order
                dropContainer.Size = UDim2.new(1, 0, 0, 44)
                dropContainer.BackgroundTransparency = 1
                dropContainer.ClipsDescendants = false
                dropContainer.Parent = itemsContainer

                local dropTitle = Instance.new("TextLabel")
                dropTitle.Name = "Label"
                dropTitle.Size = UDim2.new(1, 0, 0, 14)
                dropTitle.BackgroundTransparency = 1
                dropTitle.Font = Library.Theme.FontBody
                dropTitle.TextSize = 11
                dropTitle.TextColor3 = Library.Theme.LabelText
                dropTitle.TextXAlignment = Enum.TextXAlignment.Left
                dropTitle.Text = label
                dropTitle.Parent = dropContainer

                local dropBtn = Instance.new("TextButton")
                dropBtn.Name = "SelectBox"
                dropBtn.Size = UDim2.new(1, 0, 0, 26)
                dropBtn.Position = UDim2.new(0, 0, 0, 16)
                dropBtn.BackgroundColor3 = Library.Theme.InputBg
                dropBtn.BorderSizePixel = 0
                dropBtn.AutoButtonColor = false
                dropBtn.Text = ""
                dropBtn.Parent = dropContainer

                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 4)
                btnCorner.Parent = dropBtn

                local dropStroke = Instance.new("UIStroke")
                dropStroke.Color = Library.Theme.InputBorder
                dropStroke.Thickness = 1
                dropStroke.Parent = dropBtn

                local valLabel = Instance.new("TextLabel")
                valLabel.Name = "ValueLabel"
                valLabel.Size = UDim2.new(1, -26, 1, 0)
                valLabel.Position = UDim2.new(0, 8, 0, 0)
                valLabel.BackgroundTransparency = 1
                valLabel.Font = Library.Theme.FontBody
                valLabel.TextSize = 11
                valLabel.TextColor3 = Library.Theme.LabelText
                valLabel.TextXAlignment = Enum.TextXAlignment.Left
                valLabel.Text = tostring(selected)
                valLabel.Parent = dropBtn

                local arrow = Instance.new("TextLabel")
                arrow.Name = "Arrow"
                arrow.Size = UDim2.new(0, 20, 1, 0)
                arrow.Position = UDim2.new(1, -22, 0, 0)
                arrow.BackgroundTransparency = 1
                arrow.Font = Library.Theme.FontBody
                arrow.TextSize = 10
                arrow.TextColor3 = Library.Theme.MutedText
                arrow.Text = "▼"
                arrow.Parent = dropBtn

                -- Floating Overlay Options Menu (Parented to popupOverlay to avoid scroll clipping)
                local popMenu = Instance.new("Frame")
                popMenu.Name = "DropPopup_" .. label
                popMenu.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
                popMenu.BorderSizePixel = 0
                popMenu.Visible = false
                popMenu.ZIndex = 10000
                popMenu.Parent = Window.PopupOverlay

                local popCorner = Instance.new("UICorner")
                popCorner.CornerRadius = UDim.new(0, 4)
                popCorner.Parent = popMenu

                local popStroke = Instance.new("UIStroke")
                popStroke.Color = Library.Theme.WindowStroke
                popStroke.Thickness = 1
                popStroke.Parent = popMenu

                local scrollList = Instance.new("ScrollingFrame")
                scrollList.Name = "Scroll"
                scrollList.Size = UDim2.new(1, 0, 1, 0)
                scrollList.BackgroundTransparency = 1
                scrollList.BorderSizePixel = 0
                scrollList.ScrollBarThickness = 3
                scrollList.ScrollBarImageColor3 = Library.Theme.Accent
                scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
                scrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
                scrollList.ZIndex = 9501
                scrollList.Parent = popMenu

                local listPad = Instance.new("UIPadding")
                listPad.PaddingTop = UDim.new(0, 3)
                listPad.PaddingBottom = UDim.new(0, 3)
                listPad.PaddingLeft = UDim.new(0, 3)
                listPad.PaddingRight = UDim.new(0, 3)
                listPad.Parent = scrollList

                local optLayout = Instance.new("UIListLayout")
                optLayout.FillDirection = Enum.FillDirection.Vertical
                optLayout.SortOrder = Enum.SortOrder.LayoutOrder
                optLayout.Padding = UDim.new(0, 2)
                optLayout.Parent = scrollList

                local function closeDropdown()
                    isOpen = false
                    popMenu.Visible = false
                    arrow.Text = "▼"
                    TweenService:Create(dropStroke, TweenInfo.new(0.15), { Color = Library.Theme.InputBorder }):Play()
                end

                local function updatePopupPosition()
                    local absPos = dropBtn.AbsolutePosition
                    local absSize = dropBtn.AbsoluteSize
                    popMenu.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
                    popMenu.Size = UDim2.new(0, absSize.X, 0, math.clamp(#currentItems * 26 + 6, 26, 180))
                end

                dropBtn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                    if isOpen then updatePopupPosition() end
                end)

                local function populateOptions()
                    for _, c in ipairs(scrollList:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end

                    for idx, item in ipairs(currentItems) do
                        local isSel = (item == selected)
                        local optBtn = Instance.new("TextButton")
                        optBtn.Name = "Opt_" .. tostring(item)
                        optBtn.LayoutOrder = idx
                        optBtn.Size = UDim2.new(1, 0, 0, 24)
                        optBtn.BackgroundColor3 = isSel and Color3.fromRGB(24, 24, 30) or Color3.fromRGB(14, 14, 18)
                        optBtn.BackgroundTransparency = isSel and 0 or 1
                        optBtn.BorderSizePixel = 0
                        optBtn.AutoButtonColor = false
                        optBtn.Font = Library.Theme.FontBody
                        optBtn.TextSize = 11
                        optBtn.TextColor3 = isSel and Library.Theme.Accent or Library.Theme.LabelText
                        optBtn.TextXAlignment = Enum.TextXAlignment.Left
                        optBtn.Text = "  " .. tostring(item)
                        optBtn.ZIndex = 9502
                        optBtn.Parent = scrollList

                        local oCorner = Instance.new("UICorner")
                        oCorner.CornerRadius = UDim.new(0, 3)
                        oCorner.Parent = optBtn

                        optBtn.MouseEnter:Connect(function()
                            if item ~= selected then
                                optBtn.BackgroundTransparency = 0
                                optBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
                            end
                        end)
                        optBtn.MouseLeave:Connect(function()
                            if item ~= selected then
                                optBtn.BackgroundTransparency = 1
                            end
                        end)

                        optBtn.MouseButton1Click:Connect(function()
                            selected = item
                            valLabel.Text = tostring(selected)
                            closeDropdown()
                            populateOptions()
                            if callback then pcall(callback, selected) end
                        end)
                    end
                end

                populateOptions()

                dropBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        updatePopupPosition()
                        popMenu.Visible = true
                        arrow.Text = "▲"
                        TweenService:Create(dropStroke, TweenInfo.new(0.15), { Color = Library.Theme.Accent }):Play()
                    else
                        closeDropdown()
                    end
                end)

                -- Auto close when clicking outside or resizing
                LibUIS.InputBegan:Connect(function(input)
                    if isOpen and input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mPos = LibUIS:GetMouseLocation()
                        local pPos = popMenu.AbsolutePosition
                        local pSize = popMenu.AbsoluteSize
                        local bPos = dropBtn.AbsolutePosition
                        local bSize = dropBtn.AbsoluteSize

                        local inPop = mPos.X >= pPos.X and mPos.X <= pPos.X + pSize.X and mPos.Y >= pPos.Y and mPos.Y <= pPos.Y + pSize.Y
                        local inBtn = mPos.X >= bPos.X and mPos.X <= bPos.X + bSize.X and mPos.Y >= bPos.Y and mPos.Y <= bPos.Y + bSize.Y

                        if not inPop and not inBtn then
                            closeDropdown()
                        end
                    end
                end)

                return {
                    SetValue = function(newVal)
                        selected = newVal
                        valLabel.Text = tostring(selected)
                        populateOptions()
                        if callback then pcall(callback, selected) end
                    end,
                    SetOptions = function(newList, newDefault)
                        currentItems = newList or {}
                        selected = newDefault or currentItems[1] or "None"
                        valLabel.Text = tostring(selected)
                        populateOptions()
                    end,
                    GetValue = function() return selected end,
                }
            end

            function Group:AddColorPicker(label, default, callback)
                local currentColor = default or Color3.fromRGB(0, 255, 170)
                local currentH, currentS, currentV = currentColor:ToHSV()
                local order = nextOrder()
                local isOpen = false

                local colorRow = Instance.new("Frame")
                colorRow.Name = string.format("%03d_Color_%s", order, label)
                colorRow.LayoutOrder = order
                colorRow.Size = UDim2.new(1, 0, 0, 24)
                colorRow.BackgroundTransparency = 1
                colorRow.Parent = itemsContainer

                local colorLabel = Instance.new("TextLabel")
                colorLabel.Name = "Label"
                colorLabel.Size = UDim2.new(1, -30, 1, 0)
                colorLabel.BackgroundTransparency = 1
                colorLabel.Font = Library.Theme.FontBody
                colorLabel.TextSize = 11
                colorLabel.TextColor3 = Library.Theme.LabelText
                colorLabel.TextXAlignment = Enum.TextXAlignment.Left
                colorLabel.Text = label
                colorLabel.Parent = colorRow

                local colorPreview = Instance.new("TextButton")
                colorPreview.Name = "Preview"
                colorPreview.Size = UDim2.new(0, 18, 0, 18)
                colorPreview.Position = UDim2.new(1, -18, 0.5, -9)
                colorPreview.BackgroundColor3 = currentColor
                colorPreview.BorderSizePixel = 0
                colorPreview.AutoButtonColor = false
                colorPreview.Text = ""
                colorPreview.Parent = colorRow

                local cpCorner = Instance.new("UICorner")
                cpCorner.CornerRadius = UDim.new(0, 4)
                cpCorner.Parent = colorPreview

                local previewStroke = Instance.new("UIStroke")
                previewStroke.Color = Library.Theme.InputBorder
                previewStroke.Thickness = 1
                previewStroke.Parent = colorPreview

                -- Professional Pro-Grade Color Picker Dialog Frame
                local pickerPopup = Instance.new("Frame")
                pickerPopup.Name = "ColorPopup_" .. label
                pickerPopup.Size = UDim2.new(0, 224, 0, 218)
                pickerPopup.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
                pickerPopup.BorderSizePixel = 0
                pickerPopup.Visible = false
                pickerPopup.ZIndex = 9600
                pickerPopup.Parent = Window.PopupOverlay

                local pkCorner = Instance.new("UICorner")
                pkCorner.CornerRadius = UDim.new(0, 6)
                pkCorner.Parent = pickerPopup

                local pkStroke = Instance.new("UIStroke")
                pkStroke.Color = Color3.fromRGB(34, 34, 42)
                pkStroke.Thickness = 1
                pkStroke.Parent = pickerPopup

                -- Outer drop shadow for color picker modal
                local pkShadow = Instance.new("ImageLabel")
                pkShadow.Name = "Shadow"
                pkShadow.Size = UDim2.new(1, 24, 1, 24)
                pkShadow.Position = UDim2.new(0, -12, 0, -12)
                pkShadow.BackgroundTransparency = 1
                pkShadow.Image = "rbxassetid://5028857084"
                pkShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
                pkShadow.ImageTransparency = 0.3
                pkShadow.ScaleType = Enum.ScaleType.Slice
                pkShadow.SliceCenter = Rect.new(24, 24, 276, 276)
                pkShadow.ZIndex = 9599
                pkShadow.Parent = pickerPopup

                -- Top title bar
                local pkHeader = Instance.new("Frame")
                pkHeader.Size = UDim2.new(1, -16, 0, 22)
                pkHeader.Position = UDim2.new(0, 8, 0, 6)
                pkHeader.BackgroundTransparency = 1
                pkHeader.ZIndex = 9601
                pkHeader.Parent = pickerPopup

                local pkTitle = Instance.new("TextLabel")
                pkTitle.Size = UDim2.new(1, -26, 1, 0)
                pkTitle.BackgroundTransparency = 1
                pkTitle.Font = Library.Theme.FontTitle
                pkTitle.TextSize = 11
                pkTitle.TextColor3 = Library.Theme.TitlebarText
                pkTitle.TextXAlignment = Enum.TextXAlignment.Left
                pkTitle.Text = label
                pkTitle.ZIndex = 9601
                pkTitle.Parent = pkHeader

                local curSwatch = Instance.new("Frame")
                curSwatch.Size = UDim2.new(0, 16, 0, 16)
                curSwatch.Position = UDim2.new(1, -16, 0.5, -8)
                curSwatch.BackgroundColor3 = currentColor
                curSwatch.BorderSizePixel = 0
                curSwatch.ZIndex = 9601
                curSwatch.Parent = pkHeader

                local csCorner = Instance.new("UICorner")
                csCorner.CornerRadius = UDim.new(0, 3)
                csCorner.Parent = curSwatch

                local csStroke = Instance.new("UIStroke")
                csStroke.Color = Color3.fromRGB(45, 45, 55)
                csStroke.Thickness = 1
                csStroke.Parent = curSwatch

                -- 1. Saturation / Value Canvas Field
                local svField = Instance.new("TextButton")
                svField.Name = "SVField"
                svField.Size = UDim2.new(0, 178, 0, 100)
                svField.Position = UDim2.new(0, 8, 0, 32)
                svField.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
                svField.BorderSizePixel = 0
                svField.AutoButtonColor = false
                svField.Text = ""
                svField.ClipsDescendants = true
                svField.ZIndex = 9602
                svField.Parent = pickerPopup

                local svCorner = Instance.new("UICorner")
                svCorner.CornerRadius = UDim.new(0, 4)
                svCorner.Parent = svField

                -- White gradient layer (Horizontal Saturation: Left White -> Right Clear)
                local whiteGradLayer = Instance.new("Frame")
                whiteGradLayer.Size = UDim2.new(1, 0, 1, 0)
                whiteGradLayer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                whiteGradLayer.BorderSizePixel = 0
                whiteGradLayer.ZIndex = 9603
                whiteGradLayer.Parent = svField

                local wGrad = Instance.new("UIGradient")
                wGrad.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1)
                })
                wGrad.Rotation = 0
                wGrad.Parent = whiteGradLayer

                -- Black gradient layer (Vertical Value: Top Clear -> Bottom Black)
                local blackGradLayer = Instance.new("Frame")
                blackGradLayer.Size = UDim2.new(1, 0, 1, 0)
                blackGradLayer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                blackGradLayer.BorderSizePixel = 0
                blackGradLayer.ZIndex = 9604
                blackGradLayer.Parent = svField

                local bGrad = Instance.new("UIGradient")
                bGrad.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0)
                })
                bGrad.Rotation = 90
                bGrad.Parent = blackGradLayer

                -- SV Target Reticle Marker
                local svCursor = Instance.new("Frame")
                svCursor.Name = "Cursor"
                svCursor.Size = UDim2.new(0, 8, 0, 8)
                svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
                svCursor.Position = UDim2.new(currentS, 0, 1 - currentV, 0)
                svCursor.BackgroundTransparency = 1
                svCursor.ZIndex = 9606
                svCursor.Parent = svField

                local curCorner = Instance.new("UICorner")
                curCorner.CornerRadius = UDim.new(1, 0)
                curCorner.Parent = svCursor

                local curStroke = Instance.new("UIStroke")
                curStroke.Color = Color3.fromRGB(255, 255, 255)
                curStroke.Thickness = 1.5
                curStroke.Parent = svCursor

                -- 2. Vertical Hue Rainbow Slider Bar
                local hueBar = Instance.new("TextButton")
                hueBar.Name = "HueBar"
                hueBar.Size = UDim2.new(0, 18, 0, 100)
                hueBar.Position = UDim2.new(0, 196, 0, 32)
                hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                hueBar.BorderSizePixel = 0
                hueBar.AutoButtonColor = false
                hueBar.Text = ""
                hueBar.ClipsDescendants = false
                hueBar.ZIndex = 9602
                hueBar.Parent = pickerPopup

                local hCorner = Instance.new("UICorner")
                hCorner.CornerRadius = UDim.new(0, 4)
                hCorner.Parent = hueBar

                local hGrad = Instance.new("UIGradient")
                hGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
                })
                hGrad.Rotation = 90
                hGrad.Parent = hueBar

                local hueCursor = Instance.new("Frame")
                hueCursor.Name = "HueCursor"
                hueCursor.Size = UDim2.new(1, 4, 0, 4)
                hueCursor.Position = UDim2.new(0, -2, currentH, -2)
                hueCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                hueCursor.BorderSizePixel = 0
                hueCursor.ZIndex = 9605
                hueCursor.Parent = hueBar

                local hcCorner = Instance.new("UICorner")
                hcCorner.CornerRadius = UDim.new(0, 2)
                hcCorner.Parent = hueCursor

                local hcStroke = Instance.new("UIStroke")
                hcStroke.Color = Color3.fromRGB(0, 0, 0)
                hcStroke.Thickness = 1
                hcStroke.Parent = hueCursor

                -- 3. Preset Quick Swatches
                local swatchRow = Instance.new("Frame")
                swatchRow.Size = UDim2.new(1, -16, 0, 18)
                swatchRow.Position = UDim2.new(0, 8, 0, 140)
                swatchRow.BackgroundTransparency = 1
                swatchRow.ZIndex = 9602
                swatchRow.Parent = pickerPopup

                local swLayout = Instance.new("UIListLayout")
                swLayout.FillDirection = Enum.FillDirection.Horizontal
                swLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
                swLayout.Padding = UDim.new(0, 5)
                swLayout.Parent = swatchRow

                local presets = {
                    Color3.fromRGB(255, 255, 255),
                    Color3.fromRGB(0, 200, 255),
                    Color3.fromRGB(0, 255, 170),
                    Color3.fromRGB(255, 75, 75),
                    Color3.fromRGB(255, 180, 50),
                    Color3.fromRGB(200, 100, 255),
                    Color3.fromRGB(255, 230, 80),
                    Color3.fromRGB(80, 80, 95),
                }

                -- 4. Direct RGB & Hex Inputs
                local inputRow = Instance.new("Frame")
                inputRow.Size = UDim2.new(1, -16, 0, 24)
                inputRow.Position = UDim2.new(0, 8, 0, 166)
                inputRow.BackgroundTransparency = 1
                inputRow.ZIndex = 9602
                inputRow.Parent = pickerPopup

                local rgbBox = Instance.new("TextBox")
                rgbBox.Size = UDim2.new(0.65, -4, 1, 0)
                rgbBox.Position = UDim2.new(0, 0, 0, 0)
                rgbBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                rgbBox.BorderSizePixel = 0
                rgbBox.Font = Library.Theme.FontBody
                rgbBox.TextSize = 10
                rgbBox.TextColor3 = Library.Theme.Accent
                rgbBox.PlaceholderColor3 = Library.Theme.MutedText
                rgbBox.PlaceholderText = "R, G, B"
                rgbBox.Text = string.format("%d, %d, %d", math.floor(currentColor.R * 255), math.floor(currentColor.G * 255), math.floor(currentColor.B * 255))
                rgbBox.ZIndex = 9603
                rgbBox.Parent = inputRow

                local rgbCorner = Instance.new("UICorner")
                rgbCorner.CornerRadius = UDim.new(0, 4)
                rgbCorner.Parent = rgbBox

                local rgbStroke = Instance.new("UIStroke")
                rgbStroke.Color = Color3.fromRGB(30, 30, 38)
                rgbStroke.Thickness = 1
                rgbStroke.Parent = rgbBox

                local hexBox = Instance.new("TextBox")
                hexBox.Size = UDim2.new(0.35, 0, 1, 0)
                hexBox.Position = UDim2.new(0.65, 0, 0, 0)
                hexBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
                hexBox.BorderSizePixel = 0
                hexBox.Font = Library.Theme.FontBody
                hexBox.TextSize = 10
                hexBox.TextColor3 = Library.Theme.Accent
                hexBox.PlaceholderColor3 = Library.Theme.MutedText
                hexBox.PlaceholderText = "#HEX"
                hexBox.Text = "#" .. currentColor:ToHex():upper()
                hexBox.ZIndex = 9603
                hexBox.Parent = inputRow

                local hexCorner = Instance.new("UICorner")
                hexCorner.CornerRadius = UDim.new(0, 4)
                hexCorner.Parent = hexBox

                local hexStroke = Instance.new("UIStroke")
                hexStroke.Color = Color3.fromRGB(30, 30, 38)
                hexStroke.Thickness = 1
                hexStroke.Parent = hexBox

                local function applyColor(col, updateHSV)
                    currentColor = col
                    if updateHSV then
                        currentH, currentS, currentV = col:ToHSV()
                    end

                    colorPreview.BackgroundColor3 = currentColor
                    curSwatch.BackgroundColor3 = currentColor
                    svField.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)

                    svCursor.Position = UDim2.new(currentS, 0, 1 - currentV, 0)
                    hueCursor.Position = UDim2.new(0, -2, currentH, -2)

                    rgbBox.Text = string.format("%d, %d, %d", math.floor(currentColor.R * 255), math.floor(currentColor.G * 255), math.floor(currentColor.B * 255))
                    hexBox.Text = "#" .. currentColor:ToHex():upper()

                    if callback then pcall(callback, currentColor) end
                end

                for _, pCol in ipairs(presets) do
                    local swBtn = Instance.new("TextButton")
                    swBtn.Size = UDim2.new(0, 20, 0, 18)
                    swBtn.BackgroundColor3 = pCol
                    swBtn.BorderSizePixel = 0
                    swBtn.AutoButtonColor = false
                    swBtn.Text = ""
                    swBtn.ZIndex = 9603
                    swBtn.Parent = swatchRow

                    local sCorner = Instance.new("UICorner")
                    sCorner.CornerRadius = UDim.new(0, 3)
                    sCorner.Parent = swBtn

                    local sStroke = Instance.new("UIStroke")
                    sStroke.Color = Color3.fromRGB(36, 36, 44)
                    sStroke.Thickness = 1
                    sStroke.Parent = swBtn

                    swBtn.MouseButton1Click:Connect(function()
                        applyColor(pCol, true)
                    end)
                end

                -- Interactive SV Field Dragging
                local draggingSV = false
                local function updateSV(input)
                    local absPos = svField.AbsolutePosition
                    local absSize = svField.AbsoluteSize
                    local relX = math.clamp((input.Position.X - absPos.X) / absSize.X, 0, 1)
                    local relY = math.clamp((input.Position.Y - absPos.Y) / absSize.Y, 0, 1)

                    currentS = relX
                    currentV = 1 - relY
                    local newCol = Color3.fromHSV(currentH, currentS, currentV)
                    applyColor(newCol, false)
                end

                svField.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        draggingSV = true
                        updateSV(input)
                    end
                end)

                -- Interactive Hue Bar Dragging
                local draggingHue = false
                local function updateHue(input)
                    local absPos = hueBar.AbsolutePosition
                    local absSize = hueBar.AbsoluteSize
                    local relY = math.clamp((input.Position.Y - absPos.Y) / absSize.Y, 0, 1)

                    currentH = relY
                    local newCol = Color3.fromHSV(currentH, currentS, currentV)
                    applyColor(newCol, false)
                end

                hueBar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        draggingHue = true
                        updateHue(input)
                    end
                end)

                LibUIS.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                        if draggingSV then
                            updateSV(input)
                        elseif draggingHue then
                            updateHue(input)
                        end
                    end
                end)

                LibUIS.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        draggingSV = false
                        draggingHue = false
                    end
                end)

                -- Manual RGB and Hex parsing
                rgbBox.FocusLost:Connect(function()
                    local r, g, b = rgbBox.Text:match("(%d+)[%s,]+(%d+)[%s,]+(%d+)")
                    if r and g and b then
                        local newC = Color3.fromRGB(
                            math.clamp(tonumber(r), 0, 255),
                            math.clamp(tonumber(g), 0, 255),
                            math.clamp(tonumber(b), 0, 255)
                        )
                        applyColor(newC, true)
                    end
                end)

                hexBox.FocusLost:Connect(function()
                    local cleanHex = hexBox.Text:gsub("#", ""):gsub("%s+", "")
                    pcall(function()
                        if #cleanHex == 6 then
                            local newC = Color3.fromHex(cleanHex)
                            applyColor(newC, true)
                        end
                    end)
                end)

                local function closePicker()
                    isOpen = false
                    pickerPopup.Visible = false
                end

                colorPreview.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        local absPos = colorPreview.AbsolutePosition
                        local popW = 224
                        local popH = 218
                        local posX = absPos.X - popW - 8
                        if posX < 10 then posX = absPos.X + 50 end
                        local posY = math.clamp(absPos.Y - 20, 10, Camera.ViewportSize.Y - popH - 10)

                        pickerPopup.Position = UDim2.new(0, posX, 0, posY)
                        pickerPopup.Visible = true
                        applyColor(currentColor, true)
                    else
                        closePicker()
                    end
                end)

                LibUIS.InputBegan:Connect(function(input)
                    if isOpen and not draggingSV and not draggingHue and input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mPos = LibUIS:GetMouseLocation()
                        local pPos = pickerPopup.AbsolutePosition
                        local pSize = pickerPopup.AbsoluteSize
                        local bPos = colorPreview.AbsolutePosition
                        local bSize = colorPreview.AbsoluteSize

                        local inPop = mPos.X >= pPos.X and mPos.X <= pPos.X + pSize.X and mPos.Y >= pPos.Y and mPos.Y <= pPos.Y + pSize.Y
                        local inBtn = mPos.X >= bPos.X and mPos.X <= bPos.X + bSize.X and mPos.Y >= bPos.Y and mPos.Y <= bPos.Y + bSize.Y

                        if not inPop and not inBtn then
                            closePicker()
                        end
                    end
                end)

                return {
                    SetColor = function(newColor)
                        applyColor(newColor, true)
                    end,
                    GetColor = function() return currentColor end,
                }
            end

            function Group:AddLabel(label)
                local order = nextOrder()
                local lbl = Instance.new("TextLabel")
                lbl.Name = string.format("%03d_Lbl", order)
                lbl.LayoutOrder = order
                lbl.Size = UDim2.new(1, 0, 0, 18)
                lbl.AutomaticSize = Enum.AutomaticSize.Y
                lbl.BackgroundTransparency = 1
                lbl.Font = Library.Theme.FontBody
                lbl.TextSize = 10
                lbl.TextColor3 = Library.Theme.MutedText
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.TextWrapped = true
                lbl.Text = label
                lbl.Parent = itemsContainer
                return lbl
            end

            function Group:AddButton(label, callback)
                local order = nextOrder()
                local btn = Instance.new("TextButton")
                btn.Name = string.format("%03d_Btn_%s", order, label)
                btn.LayoutOrder = order
                btn.Size = UDim2.new(1, 0, 0, 24)
                btn.BackgroundColor3 = Library.Theme.InputBg
                btn.BorderSizePixel = 0
                btn.Font = Library.Theme.FontBody
                btn.TextSize = 11
                btn.TextColor3 = Library.Theme.LabelText
                btn.Text = label
                btn.AutoButtonColor = false
                btn.Parent = itemsContainer

                local stroke = Instance.new("UIStroke")
                stroke.Color = Library.Theme.InputBorder
                stroke.Thickness = 1
                stroke.Parent = btn

                btn.MouseEnter:Connect(function()
                    btn.BackgroundColor3 = Library.Theme.GroupboxBg
                    stroke.Color = Library.Theme.Accent
                end)

                btn.MouseLeave:Connect(function()
                    btn.BackgroundColor3 = Library.Theme.InputBg
                    stroke.Color = Library.Theme.InputBorder
                end)

                btn.MouseButton1Click:Connect(function()
                    if callback then pcall(callback) end
                end)

                return btn
            end

            return Group
        end

        return Tab
    end

    return Window
end


--=====================================================================
-- DRAWINGS
--=====================================================================
local hasDrawing = Drawing ~= nil
local draw = {}

if hasDrawing then
    draw.aimCircle = Drawing.new("Circle")
    draw.aimCircle.Thickness = 1
    draw.aimCircle.NumSides = 48
    draw.aimCircle.Transparency = 1
    draw.aimCircle.Visible = false

    draw.silentCircle = Drawing.new("Circle")
    draw.silentCircle.Thickness = 1
    draw.silentCircle.NumSides = 48
    draw.silentCircle.Transparency = 1
    draw.silentCircle.Visible = false

    draw.aimSnapline = Drawing.new("Line")
    draw.aimSnapline.Thickness = 1
    draw.aimSnapline.Visible = false

    draw.silentSnapline = Drawing.new("Line")
    draw.silentSnapline.Thickness = 1
    draw.silentSnapline.Visible = false

    draw.aaLine = Drawing.new("Line")
    draw.aaLine.Thickness = 2
    draw.aaLine.Visible = false

    draw.aaText = Drawing.new("Text")
    draw.aaText.Size = 12
    draw.aaText.Center = true
    draw.aaText.Outline = true
    draw.aaText.Visible = false
end

--=====================================================================
-- GUN LOCKS
--=====================================================================
local LOCK_KEYS = { "Ammo", "MaxAmmo", "ShootingCooldown", "Damage", "Range" }
local locks = { byTool = {}, last = nil }

local function desiredValues()
    return {
        Ammo = state.infiniteAmmo and state.maxAmmo or nil,
        MaxAmmo = state.infiniteAmmo and state.maxAmmo or nil,
        ShootingCooldown = state.rapidFire and state.fireCooldown or nil,
        Damage = state.damageOverride and state.damageValue or nil,
        Range = state.rangeOverride and state.rangeValue or nil,
    }
end

local function pushLocks(tool)
    if not tool or state.unloaded then return end
    local want = desiredValues()
    for name, val in pairs(want) do
        if val then
            local v = tool:FindFirstChild(name)
            if v and v:IsA("ValueBase") and v.Value ~= val then
                pcall(function() v.Value = val end)
            end
        end
    end
end

local function attachLocks(tool)
    if not tool or locks.byTool[tool] then return end
    local list = {}
    for _, name in ipairs(LOCK_KEYS) do
        local v = tool:FindFirstChild(name)
        if v and v:IsA("ValueBase") then
            local c = v:GetPropertyChangedSignal("Value"):Connect(function()
                local want = desiredValues()[name]
                if want and v.Value ~= want then
                    pcall(function() v.Value = want end)
                end
            end)
            table.insert(list, c)
        end
    end
    locks.byTool[tool] = list
    pushLocks(tool)
end

local function detachLocks(tool)
    local list = locks.byTool[tool]
    if list then
        for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
        locks.byTool[tool] = nil
    end
end

local function releaseStaleLocks(tool)
    if tool == locks.last then return end
    if locks.last then detachLocks(locks.last) end
    locks.last = tool
end

--=====================================================================
-- HIT SOUNDS
--=====================================================================
local HIT_SOUNDS = {
    ["Sword Slash"] = "rbxassetid://12222216",
    ["Sword Lunge"] = "rbxassetid://12222225",
    ["Blade"] = "rbxassetid://12221967",
    ["Click"] = "rbxassetid://877051984",
    ["Bass"] = "rbxassetid://138186576",
    ["Pop"] = "rbxassetid://131961136",
}

local function playHitSound(id)
    local asset = id or state.hitSoundId
    if not asset or asset == "" then return end
    local s = Instance.new("Sound")
    s.SoundId = asset
    s.Volume = state.hitSoundVolume
    s.PlaybackSpeed = state.hitSoundPitch
    s.Parent = SoundService
    s:Play()
    task.delay(2.5, function() pcall(function() s:Destroy() end) end)
end

-- Health is watched rather than the shot itself, so a shot that the server
-- rejects (spread miss, wall, dead target) does not click.
local hitWatch = {}

local function watchHit(part)
    if not state.hitSound or not part then return end
    local model = part:FindFirstAncestorOfClass("Model")
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    table.insert(hitWatch, { hum = hum, hp = hum.Health, at = os.clock() })
end

local function pollHits()
    for i = #hitWatch, 1, -1 do
        local w = hitWatch[i]
        if os.clock() - w.at > 0.7 or not w.hum.Parent then
            table.remove(hitWatch, i)
        elseif w.hum.Health < w.hp - 0.5 then
            playHitSound()
            table.remove(hitWatch, i)
        end
    end
end

--=====================================================================
-- BULLET TRACERS
--=====================================================================
local tracer = { pool = {}, live = {} }

local function tracerOrigin()
    local t = toolEquipped()
    if t then
        local p = t:FindFirstChild("Muzzle") or t:FindFirstChild("Handle")
        if p then return p.Position end
    end
    return cam().CFrame.Position
end

local function takeTracer()
    for _, t in ipairs(tracer.pool) do
        if not t.busy then
            t.busy = true
            return t
        end
    end
    local t = {}
    t.under = Drawing.new("Line")
    t.under.Visible = false
    t.line = Drawing.new("Line")
    t.line.Visible = false
    t.busy = true
    table.insert(tracer.pool, t)
    return t
end

local function spawnTracer(from, to)
    if not state.tracer or not hasDrawing or state.unloaded then return end
    local sp, onA = cam():WorldToViewportPoint(from)
    local ep, onB = cam():WorldToViewportPoint(to)
    if not onA or not onB or sp.Z <= 0 or ep.Z <= 0 then return end

    local t = takeTracer()
    t.from = Vector2.new(sp.X, sp.Y)
    t.to = Vector2.new(ep.X, ep.Y)
    t.born = os.clock()
    table.insert(tracer.live, t)
end

local function renderTracers()
    for i = #tracer.live, 1, -1 do
        local t = tracer.live[i]
        local age = os.clock() - t.born
        if age >= state.tracerLife then
            t.line.Visible = false
            t.under.Visible = false
            t.busy = false
            table.remove(tracer.live, i)
        else
            local fade = 1 - (age / state.tracerLife)
            local w = state.tracerWidth
            t.line.From = t.from
            t.line.To = t.to
            t.line.Color = state.tracerColor
            t.line.Transparency = fade
            t.line.Visible = true

            if state.tracerStyle == "Glow" then
                t.under.From = t.from
                t.under.To = t.to
                t.under.Color = state.tracerColor
                t.under.Thickness = w * 3
                t.under.Transparency = fade * 0.65
                t.under.Visible = true
                t.line.Thickness = w
            elseif state.tracerStyle == "Thick" then
                t.under.Visible = false
                t.line.Thickness = w * 2
            else
                t.under.Visible = false
                t.line.Thickness = w
            end
        end
    end
end

local function clearTracers()
    for _, t in ipairs(tracer.pool) do
        pcall(function() t.under:Remove() end)
        pcall(function() t.line:Remove() end)
    end
    tracer.pool = {}
    tracer.live = {}
end

--=====================================================================
-- GUNHANDLER HOOKS
--=====================================================================
local GunHandler
local function loadGunHandler()
    local ok, modules = pcall(function() return game:GetService("ReplicatedStorage"):FindFirstChild("Modules") end)
    if not ok or not modules then return nil end
    local gh = modules:FindFirstChild("GunHandler")
    if not gh then return nil end
    local ok2, res = pcall(require, gh)
    if ok2 and type(res) == "table" then return res end
    warn("[snow] require GunHandler failed: " .. tostring(res))
    return nil
end

local shots = { originals = {}, count = 0, report = 0 }

local function patchDeep(t, part, dir, pos, depth)
    if (depth or 0) > 3 then return end
    for k, v in pairs(t) do
        local key = tostring(k):lower()
        local tv = typeof(v)
        if tv == "Vector3" then
            if key:find("normal") then
                t[k] = -dir
            elseif key:find("pos") or key:find("point") or key:find("location") then
                t[k] = pos
            end
        elseif tv == "Instance" then
            t[k] = part
        elseif tv == "CFrame" then
            t[k] = CFrame.lookAt(pos, pos + dir)
        elseif tv == "boolean" then
            t[k] = true
        elseif type(v) == "table" then
            patchDeep(v, part, dir, pos, (depth or 0) + 1)
        end
    end
end

local function fillParams(params, part, pos)
    pos = pos or predict(part, 1)
    local origin = params.Origin or params.ForcedOrigin
    local tool = toolEquipped()
    if typeof(origin) ~= "Vector3" and tool then
        local p = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Handle")
            or tool:FindFirstChildWhichIsA("BasePart")
        if p then origin = p.Position end
    end
    if typeof(origin) ~= "Vector3" then origin = cam().CFrame.Position end

    local dir = pos - origin
    if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) else dir = dir.Unit end

    params.AimPosition  = pos
    params.Hit          = part
    params.HitInstance  = part
    params.HitPosition  = pos
    params.HitNormal    = -dir
    params.Normal       = -dir
    params.Target       = part
    params.Precomputed  = nil

    if typeof(params.Origin) == "Vector3" then
        params.ForcedOrigin = params.Origin
    end
    return pos, dir
end

local function report(params, res)
    local keys = {}
    if type(params) == "table" then
        for k in pairs(params) do table.insert(keys, tostring(k)) end
    end
    local rets = {}
    for i = 1, res.n do
        table.insert(rets, typeof(res[i]) .. "(" .. tostring(res[i]) .. ")")
    end
    print(string.format("[snow] shot #%d keys=[%s] returns=%d [%s]",
        shots.count, table.concat(keys, ","), res.n, table.concat(rets, ",")))
end

-- A receiver is either the module itself or a proxy that carries its methods.
-- A plain params table has neither, so it is treated as the first real argument.
local function isSelf(x)
    if type(x) ~= "table" then return false end
    if x == GunHandler then return true end
    return type(rawget(x, "Shoot")) == "function" or type(x.Shoot) == "function"
end

local function split(a, b)
    if isSelf(a) then return a, b end
    return nil, a
end

local function callOrig(orig, self, first, ...)
    if type(orig) ~= "function" then
        if GunHandler and type(GunHandler.Shoot) == "function" then
            orig = GunHandler.Shoot
        else
            return nil
        end
    end
    if self then return orig(self, first, ...) end
    return orig(first, ...)
end

local function isLocalShooter(params)
    local s = params.Shooter
    if s == nil then return true end
    local my = getChar()
    return s == my or s == LP
end

-- The server raycasts from the origin we send and ignores the part we claim, so
-- the origin has to clear the cover itself. It always advances a minimum amount
-- first: the muzzle is usually inside the wall, and a ray starting inside a part
-- doesn't hit that part, so trusting a "clear" reading at the muzzle leaves the
-- origin embedded in the cover.
local function bangOrigin(origin, part, pos, maxMove)
    local d = pos - origin
    local dist = d.Magnitude
    if dist < 6 then return origin end
    local unit = d.Unit
    local ex = losParams(part)
    local inc = incParams(part)

    local cap = maxMove or 28
    if state.wallbangMode == "Soft" then
        cap = math.min(cap, 8)
    elseif state.wallbangMode == "Snap" then
        cap = math.max(cap, 300)
    end

    local limit = math.min(dist - 3, cap, 400)
    if limit <= 1 then return origin end

    local travel = math.min(5, limit)
    for _ = 1, 6 do
        local from = origin + unit * travel
        local remain = pos - from
        local h = workspace:Raycast(from, remain, ex)
        if not h then
            if workspace:Raycast(from, remain, inc) then return from end
            return from
        end
        travel = math.min(travel + h.Distance + 2, limit)
        if travel >= limit then break end
    end
    return origin + unit * travel
end

local function bangHit(part, pos, origin)
    local o = origin
    if state.wallbangMode ~= "Off" then
        o = bangOrigin(origin, part, pos, state.wallbangMax)
    end
    local h = workspace:Raycast(o, pos - o, incParams(part))
    if h and (h.Position - o).Magnitude > 1.5 then
        return o, h.Position, h.Instance, h.Normal
    end
    return o, pos, part, -(pos - o).Unit
end

-- The Handle is welded to the right hand. Writing its CFrame while that weld is
-- live drags the whole character toward the spoofed point, so the joint is cut
-- while a shift is active and restored when it ends. In R15 the grip is a Weld
-- on the RightHand named RightGrip, not a child of the Handle, so it has to be
-- found by scanning the character rather than by name on the Handle.
local grip = { weld = nil, side = nil, part = nil, offset = nil, hold = 0, log = 0 }

local function findGrip(handle)
    local pools = { getChar(), toolEquipped() }
    for _, pool in ipairs(pools) do
        if pool then
            for _, d in ipairs(pool:GetDescendants()) do
                if d:IsA("Weld") or d:IsA("Motor6D") then
                    if d.Part1 == handle then return d, "Part1" end
                    if d.Part0 == handle then return d, "Part0" end
                end
            end
        end
    end
    return nil
end

local function breakGrip(handle, hand)
    if grip.weld and grip.weld.Parent then return true end
    local w, side = findGrip(handle)
    if not w then return false end
    grip.weld, grip.side, grip.part = w, side, w[side]
    if hand then grip.offset = hand.CFrame:Inverse() * handle.CFrame end
    pcall(function() w[side] = nil end)
    return true
end

-- The offset is re-applied before the joint is remade, so a refused re-attach
-- can never leave the gun hanging in mid air away from the hand.
local function restoreGrip(handle, hand)
    if grip.weld and grip.side and grip.part then
        if handle and hand and grip.offset then
            pcall(function() handle.CFrame = hand.CFrame * grip.offset end)
        end
        pcall(function()
            if grip.weld.Parent then grip.weld[grip.side] = grip.part end
        end)
    end
    grip.weld, grip.side, grip.part, grip.offset = nil, nil, nil, nil
end

local sil = { part = nil, pos = nil, at = 0 }

local function liveSilentPart()
    if not state.silent then return nil end
    if sil.part and sil.pos and os.clock() - sil.at < 0.25 then
        if sil.part.Parent and sil.part.Parent.Parent then
            return sil.part, sil.pos
        end
        sil.part, sil.pos = nil, nil
    end
    local originPoint = cursorPoint()
    if state.silentCircleY and state.silentCircleY ~= 0 then
        originPoint = Vector2.new(originPoint.X, originPoint.Y + state.silentCircleY)
    end
    local target, part = findTarget(state.silentPart, state.silentFov, state.silentTeamCheck, state.silentVisibleOnly, originPoint)
    if not target or not part then sil.part, sil.pos = nil, nil; return nil end
    if math.random(1, 100) > state.silentChance then sil.part, sil.pos = nil, nil; return nil end
    local pos = predict(part, 1, "silent")
    sil.part, sil.pos, sil.at = part, pos, os.clock()
    return part, pos
end

-- Per-frame payload, resolved once in RenderStepped so the namecall hook itself
-- never has to touch the engine. The payload lives in one table because the
-- chunk is already at Luau's 200 local register ceiling.
local frameSilentPart, frameSilentPos
local frame = { valid = false, bangOrigin = nil, hitPos = nil, hitPart = nil,
                hitNorm = nil, bodyDist = 0 }

local function currentSilent()
    if not frameSilentPart or not frameSilentPos then return nil end
    if not frameSilentPart.Parent then return nil end
    local model = frameSilentPart:FindFirstAncestorOfClass("Model")
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return nil end
    return frameSilentPart, frameSilentPos
end

--=====================================================================
-- REMOTE FALLBACK SHOT
--=====================================================================
-- The Handle shift only works if the game builds its origin from the Handle, and
-- on this build it does not reliably. So in Remote mode nothing is moved at all:
-- the corrected origin is sent on our own ShootGun call instead, which is the
-- exact path the probe already proved lands damage. Only fired when the muzzle
-- is genuinely blocked, so open shots don't take double damage.
local rem = { event = nil, live = false, at = 0 }

local function getRemoteEvent()
    if rem.event and rem.event.Parent then return rem.event end
    local mr = ReplicatedStorage:FindFirstChild("MainRemotes")
    rem.event = mr and mr:FindFirstChild("MainRemoteEvent")
    return rem.event
end

local function numOn(name, dflt)
    local t = toolEquipped()
    local v = t and t:FindFirstChild(name)
    if v and v:IsA("ValueBase") then
        local n = tonumber(v.Value)
        if n then return n end
    end
    return dflt
end

local function fireRemoteShot()
    if state.unloaded or rem.live then return end
    if not state.silent or state.wallbangMode ~= "Remote" then return end
    local remote = getRemoteEvent()
    if not remote then return end
    local tool = toolEquipped()
    local handle = tool and tool:FindFirstChild("Handle")
    if not handle then return end

    -- Match the gun's own limits so the server never sees a shot the gun could not fire
    if os.clock() - rem.at < math.max(numOn("ShootingCooldown", 0.1), 0.05) then return end
    if numOn("Ammo", 1) < 1 then return end
    if _G.GUN_COMBAT_TOGGLE then return end

    local part, pos = currentSilent()
    if not part or not pos then return end

    local char = getChar()
    local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
    local base = (hand and hand.Position) or handle.Position

    -- The game's own remote still fires from the real muzzle, so an unobstructed
    -- shot already lands and a second one would double the damage.
    if not workspace:Raycast(base, pos - base, losParams(part)) then return end

    local o, hp, hi = bangHit(part, pos, base)
    if (o - base).Magnitude < 0.5 then return end

    -- rawAim is a Vector3 far point, not a CFrame, and arg 4 stays nil for
    -- single-projectile guns. A CFrame or a number here makes the server drop it.
    local unit = (hp - o).Unit
    local dmg = state.damageOverride and state.damageValue or numOn("Damage", 25)
    local rng = state.rangeOverride and state.rangeValue or math.max(numOn("Range", 300), (hp - o).Magnitude + 25)
    local far = o + unit * rng

    rem.at = os.clock()

    local ok, err = pcall(function()
        remote:FireServer("ShootGun", handle, o, nil, hp, hi, -(hp - o).Unit, rng, dmg, far, hi)
    end)

    watchHit(hi)
    spawnTracer(tracerOrigin(), hp)

    if state.debugShots then
        print(string.format("[snow] remote %s | moved %.1f | part %s | dmg %.0f | range %.0f",
            ok and "sent" or ("FAILED " .. tostring(err)),
            (o - base).Magnitude, hi.Name, dmg, rng))
    end
end

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or state.unloaded then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not mouseFree() then return end
    if overGui() then return end
    pcall(fireRemoteShot)
end))

local function safeCall(orig, self, first, ...)
    local packed = table.pack(pcall(callOrig, orig, self, first, ...))
    if not packed[1] then return table.pack() end
    local out = table.pack()
    for i = 2, packed.n do out[i - 1] = packed[i] end
    out.n = math.max(packed.n - 1, 0)
    return out
end

local function isCharPart(p)
    if not p then return false end
    local m = p:FindFirstAncestorOfClass("Model")
    return (m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil)
end

local function install(name, wrapper)
    local fn = GunHandler[name]
    if type(fn) ~= "function" then return false end
    if SAFE then
        shots.originals[name] = fn
        GunHandler[name] = function(...) return wrapper(fn, ...) end
        return true
    end
    local orig = nil
    local hookOk = pcall(function()
        local res = hookfunction(fn, newcclosure(function(...)
            local targetFn = orig or shots.originals[name] or fn
            return wrapper(targetFn, ...)
        end))
        if type(res) == "function" then
            orig = res
        end
    end)
    if not hookOk or type(orig) ~= "function" then
        shots.originals[name] = fn
        GunHandler[name] = function(...) return wrapper(fn, ...) end
        return true
    end
    shots.originals[name] = orig
    return true
end

local shootWrapper = function(orig, a, b, ...)
    local self, params = split(a, b)
    if type(params) == "table" and not isLocalShooter(params) then
        return callOrig(orig, self, params, ...)
    end

    local part, pos, cachedPos, cachedDir

    if not state.unloaded and state.silent then part, pos = currentSilent() end
    if part and type(params) == "table"
        and (state.spreadCondenser or not isCharPart(params.HitInstance)) then
        local ok, p, d = pcall(fillParams, params, part, pos)
        if ok then cachedPos, cachedDir = p, d else part = nil end
    else
        part = nil
    end

    if not state.unloaded and state.infiniteAmmo then pushLocks(toolEquipped()) end

    local res = safeCall(orig, self, params, ...)

    if part and cachedPos then
        for i = 1, res.n do
            local v = res[i]
            if typeof(v) == "Vector3" then
                res[i] = cachedPos
            elseif typeof(v) == "Instance" then
                res[i] = part
            elseif type(v) == "table" then
                pcall(patchDeep, v, part, cachedDir, cachedPos, 0)
            end
        end
        if res.n >= 2 and typeof(res[2]) ~= "Instance" then
            res[2] = part
        end
        watchHit(part)
        spawnTracer(tracerOrigin(), cachedPos)
    end

    shots.count = shots.count + 1
    if state.debugShots and (shots.count <= 10 or os.clock() - shots.report > 3) then
        shots.report = os.clock()
        pcall(report, params, res)
    end

    if not state.unloaded and state.infiniteAmmo then pushLocks(toolEquipped()) end
    return table.unpack(res, 1, res.n)
end

local getAimWrapper = function(orig, a, b, ...)
    local self, origin = split(a, b)
    local res, mag = callOrig(orig, self, origin, ...)

    if not state.unloaded and state.silent and typeof(origin) == "Vector3" then
        local part, pos = currentSilent()
        if part then
            local d = pos - origin
            if d.Magnitude > 0.01 then return d.Unit, d.Magnitude end
        end
    end
    return res, mag
end

local traceWrapper = function(orig, a, b, ...)
    local self, params = split(a, b)
    if not state.unloaded and state.silent and type(params) == "table" and isLocalShooter(params) then
        local part, pos = currentSilent()
        if part and pos then
            local origin = params.ForcedOrigin
                or (params.Handle and params.Handle:FindFirstChild("Muzzle")
                    and params.Handle.Muzzle.WorldPosition)
                or cam().CFrame.Position
            local d = pos - origin
            if typeof(origin) == "Vector3" and d.Magnitude > 0.01 then
                if state.wallbangMode ~= "Off" then
                    local _, hp, hi, hn = bangHit(part, pos, origin)
                    return hp, hi, hn
                end
                return pos, part, -d.Unit
            end
        end
    end
    return callOrig(orig, self, params, ...)
end

-- A reload legitimately blocks the shot, so forcing true through it lets the
-- client fire into a locked gun.
local function canShootWrapper(orig, ...)
    if state.unloaded then return orig(...) end
    if state.infiniteAmmo or state.rapidFire then
        local tool = toolEquipped()
        local rel = tool and (tool:FindFirstChild("Reloading") or tool:FindFirstChild("IsReloading"))
        if rel and rel:IsA("BoolValue") and rel.Value then return orig(...) end
        return true
    end
    return orig(...)
end

--=====================================================================
-- REMOTE HOOK
--=====================================================================
local function redirectRay(a)
    local origin, dir
    if typeof(a[1]) == "Ray" then
        origin, dir = a[1].Origin, a[1].Direction
    elseif typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3" then
        origin, dir = a[1], a[2]
    else
        return nil
    end
    if not origin or not dir or InVisRay then return nil end

    local camPos = cam().CFrame.Position
    local hrp = getRoot()
    local nearCam = (origin - camPos).Magnitude < 24
    local nearBody = hrp and (hrp.Position - origin).Magnitude < 24
    if not (nearCam or nearBody) then return nil end

    local part, pos = currentSilent()
    if not part or not pos then return nil end

    local nd = pos - origin
    if nd.Magnitude < 0.001 then return nil end

    local mag = math.max(dir.Magnitude, nd.Magnitude + 50)
    if state.wallbangMode ~= "Off" then
        mag = math.max(mag, nd.Magnitude + 2000)
    end
    return nd.Unit * mag
end

-- 1 ShootGun | 2 Handle | 3 origin | 4 pellet table (shotguns) |
-- 5 hitPos | 6 hitInstance | 7 hitNormal | 8 range | 9 damage | 10 rawAim | 11 aimLockPart
-- Uses only the per-frame cache: no engine calls, so it is safe inside namecall.
local function rewriteShoot(a)
    if not frame.valid or not frameSilentPart or not frameSilentPos then return nil end
    local part, pos = frameSilentPart, frameSilentPos
    local origin = a[3]
    if typeof(origin) ~= "Vector3" then return nil end
    local d = pos - origin
    local dist = d.Magnitude
    if dist < 0.01 then return nil end
    local unit = d.Unit

    local wall = state.wallbangMode ~= "Off"
    local o = wall and frame.bangOrigin or origin
    local hp = wall and frame.hitPos or pos
    local hi = wall and frame.hitPart or part
    local hn = wall and frame.hitNorm or -unit
    if typeof(o) ~= "Vector3" or typeof(hp) ~= "Vector3" or typeof(hi) ~= "Instance" then
        o, hp, hi, hn = origin, pos, part, -unit
    end

    local out = table.pack(table.unpack(a, 1, a.n))

    out[3] = o
    out[5], out[6], out[7] = hp, hi, hn

    local bodyDist = frame.bodyDist > 0 and frame.bodyDist or dist
    local rangeVal = state.rangeOverride and state.rangeValue or (tonumber(out[8]) or 0)
    if bodyDist + 30 > rangeVal then rangeVal = bodyDist + 30 end
    if rangeVal > 0 then out[8] = math.clamp(rangeVal, 1, 2000) end

    local far = o + unit * (out[8] or dist)
    if out[10] ~= nil then out[10] = far end
    if out[11] ~= nil then out[11] = hi end

    local pellets = out[4]
    if type(pellets) == "table" then
        for _, p in ipairs(pellets) do
            if type(p) == "table" then
                p.AimPosition = hp
                p.RawAimPosition = far
                p.Result1, p.Result2, p.Result3 = hp, hi, hn
                p.AimLockPart = hi
            end
        end
    end

    if state.damageOverride then out[9] = state.damageValue end

    if state.debugShots then
        print(string.format("[snow] bang %s | dist %.1f | moved %.1f | reaches %s | part %s | range %.0f",
            state.wallbangMode, dist, (o - origin).Magnitude,
            tostring(hi.Parent == part.Parent), hi.Name, out[8] or 0))
    end
    return out
end

local hook = { remote = nil, nc = false, origNC = nil }

local function installRemote()
    if hook.remote or hook.nc or state.unloaded then return end
    -- Namecall installs after load and is the one thing that has repeatedly taken
    -- the client down at the five second mark, so it is opt-in. With Hook Mode Off
    -- Remote mode fires its own corrected remote instead of moving anything.
    if state.hookMode == "Off" then return end
    local remote = getRemoteEvent()
    if not remote then
        warn("[snow] MainRemoteEvent missing - remote hook skipped")
        return
    end

    -- rewriteShoot is cache-only, so no engine calls happen inside the hook.
    if hookmetamethod and getrawmetatable then
        local mt = getrawmetatable(game)
        local nc = mt and mt.__namecall
        if type(nc) == "function" then
            hook.origNC = nc
            -- Keep the shield from zombifying our namecall out from under us.
            ProtectedFns[nc] = true
            hook.nc = pcall(hookmetamethod, game, "__namecall", newcclosure(function(self, ...)
                if state.unloaded then return hook.origNC(self, ...) end
                if getnamecallmethod() ~= "FireServer" or self ~= remote then
                    return hook.origNC(self, ...)
                end
                local a = table.pack(...)
                if a[1] ~= "ShootGun" or not state.silent then return hook.origNC(self, ...) end
                local ok, out = pcall(rewriteShoot, a)
                if ok and out then return hook.origNC(self, table.unpack(out, 1, out.n)) end
                return hook.origNC(self, ...)
            end))
            if hook.nc then
                rem.live = true
                print("[snow] remote hook: namecall")
                return
            end
        end
    end

    if type(hookfunction) == "function" then
        local ok, orig = pcall(hookfunction, remote.FireServer, newcclosure(function(self, ...)
            if state.unloaded then return orig(self, ...) end
            local a = table.pack(...)
            if a[1] ~= "ShootGun" or not state.silent then return orig(self, ...) end
            local ok2, out = pcall(rewriteShoot, a)
            if ok2 and out then return orig(self, table.unpack(out, 1, out.n)) end
            return orig(self, ...)
        end))
        if ok and type(orig) == "function" then
            hook.remote = remote
            rem.live = true
            print("[snow] remote hook: instance")
        end
    end
end

local function uninstallRemote()
    rem.live = false
    if hook.remote then
        pcall(function() restorefunction(hook.remote.FireServer) end)
        hook.remote = nil
    end
    if hook.nc and hook.origNC then
        pcall(hookmetamethod, game, "__namecall", hook.origNC)
        hook.nc = false
    end
end

local function installAll()
    GunHandler = GunHandler or loadGunHandler()
    if not GunHandler then
        warn("[snow] GunHandler unavailable")
        return false
    end
    local okShoot = install("Shoot", shootWrapper)
    install("GetCanShoot", canShootWrapper)
    install("GetAim", getAimWrapper)
    install("Trace", traceWrapper)
    pcall(installRemote)
    print("[snow] hooks | Shoot:", okShoot and "yes" or "no",
        "| remote:", hook.nc and "namecall" or (hook.remote and "instance" or "none"))
    return okShoot
end

local function clearAll()
    if GunHandler then
        for name, orig in pairs(shots.originals) do
            if type(orig) == "function" then
                pcall(function()
                    if restorefunction and not SAFE then restorefunction(orig) end
                end)
                pcall(function() GunHandler[name] = orig end)
            end
        end
    end
    shots.originals = {}
end

--=====================================================================
-- ESP
--=====================================================================
local esp = { data = {}, chams = {} }

-- R15 and R6 skeletons. Whichever set the character actually has is the one
-- that gets drawn, so this works on either rig without a setting.
local R15_BONES = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local R6_BONES = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function bonesFor(char)
    if char:FindFirstChild("UpperTorso") then return R15_BONES end
    if char:FindFirstChild("Torso") then return R6_BONES end
    return nil
end

local function colorFor(plr)
    return sameTeam(plr) and state.espTeam or state.espEnemy
end

local function hideESP(t)
    for _, o in pairs(t) do
        local ty = type(o)
        if ty == "table" then
            for _, oo in pairs(o) do pcall(function() oo.Visible = false end) end
        elseif ty == "userdata" then
            pcall(function() o.Visible = false end)
        end
    end
end

local function destroyESP(t)
    for _, o in pairs(t) do
        local ty = type(o)
        if ty == "table" then
            for _, oo in pairs(o) do pcall(function() oo:Remove() end) end
        elseif ty == "userdata" then
            pcall(function() o:Remove() end)
        end
    end
end

track(Players.PlayerRemoving:Connect(function(plr)
    local t = esp.data[plr]
    if t then destroyESP(t); esp.data[plr] = nil end
    local h = esp.chams[plr]
    if h then pcall(function() h:Destroy() end); esp.chams[plr] = nil end
end))

local function buildESP()
    if not hasDrawing then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not esp.data[plr] then
            local t = { bones = { under = {}, line = {} }, corner = { under = {}, line = {} } }
            -- Outline objects are created first so they render behind their fill.
            -- Drawing has no stroke property, so an outline is a thicker black
            -- shape sitting under a thinner coloured one.
            t.boxOutline = Drawing.new("Square"); t.boxOutline.Thickness = 3; t.boxOutline.Filled = false
            t.boxOutline.Color = Color3.new(0, 0, 0); t.boxOutline.Visible = false
            t.box = Drawing.new("Square"); t.box.Thickness = 1; t.box.Filled = false
            t.name = Drawing.new("Text"); t.name.Size = 13; t.name.Center = true; t.name.Outline = true
            t.hpOutline = Drawing.new("Square"); t.hpOutline.Filled = true; t.hpOutline.Color = Color3.new(0, 0, 0)
            t.hpBg = Drawing.new("Square"); t.hpBg.Filled = true
            t.hpGhost = Drawing.new("Square"); t.hpGhost.Filled = true; t.hpGhost.Color = Color3.new(1, 1, 1)
            t.hpFill = Drawing.new("Square"); t.hpFill.Filled = true
            t.hp = Drawing.new("Text"); t.hp.Size = 12; t.hp.Outline = true
            t.dist = Drawing.new("Text"); t.dist.Size = 12; t.dist.Center = true; t.dist.Outline = true
            t.tool = Drawing.new("Text"); t.tool.Size = 11; t.tool.Center = true; t.tool.Outline = true
            t.tracer = Drawing.new("Line"); t.tracer.Thickness = 1
            t.ghostHp = 1
            esp.data[plr] = t
        end
    end
end

local function boneObjects(t, i)
    if not t.bones.line[i] then
        t.bones.under[i] = Drawing.new("Line")
        t.bones.under[i].Thickness = 3
        t.bones.under[i].Color = Color3.new(0, 0, 0)
        t.bones.under[i].Visible = false
        t.bones.line[i] = Drawing.new("Line")
        t.bones.line[i].Thickness = 1
        t.bones.line[i].Visible = false
    end
    return t.bones.under[i], t.bones.line[i]
end

local function renderSkeleton(char, t, col)
    local set = bonesFor(char)
    local used = 0
    if set then
        for _, pair in ipairs(set) do
            local a = char:FindFirstChild(pair[1])
            local b = char:FindFirstChild(pair[2])
            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                local pa, onA = cam():WorldToViewportPoint(a.Position)
                local pb, onB = cam():WorldToViewportPoint(b.Position)
                if onA and onB and pa.Z > 0 and pb.Z > 0 then
                    used = used + 1
                    local under, line = boneObjects(t, used)
                    under.From = Vector2.new(pa.X, pa.Y)
                    under.To = Vector2.new(pb.X, pb.Y)
                    under.Visible = state.espOutline
                    line.From = under.From
                    line.To = under.To
                    line.Color = col
                    line.Visible = true
                end
            end
        end
    end
    for i = used + 1, #R15_BONES do
        if t.bones.line[i] then
            t.bones.line[i].Visible = false
            t.bones.under[i].Visible = false
        end
    end
end

-- Eight short segments, two per corner. Length scales with the box so it stays
-- proportional, but is floored and capped so a tiny box still reads as a corner
-- bracket instead of a dot.
local CORNER_SEGMENTS = 8

local function cornerObjects(t, i)
    if not t.corner.line[i] then
        t.corner.under[i] = Drawing.new("Line")
        t.corner.under[i].Thickness = 3
        t.corner.under[i].Color = Color3.new(0, 0, 0)
        t.corner.under[i].Visible = false
        t.corner.line[i] = Drawing.new("Line")
        t.corner.line[i].Thickness = 1
        t.corner.line[i].Visible = false
    end
    return t.corner.under[i], t.corner.line[i]
end

local function renderCorners(t, x, y, w, h, col)
    local len = math.clamp(w * 0.3, 4, 14)
    local seg = {
        { x, y, x + len, y },
        { x, y, x, y + len },
        { x + w, y, x + w - len, y },
        { x + w, y, x + w, y + len },
        { x, y + h, x + len, y + h },
        { x, y + h, x, y + h - len },
        { x + w, y + h, x + w - len, y + h },
        { x + w, y + h, x + w, y + h - len },
    }
    for i = 1, CORNER_SEGMENTS do
        local s = seg[i]
        local under, line = cornerObjects(t, i)
        under.From = Vector2.new(s[1], s[2])
        under.To = Vector2.new(s[3], s[4])
        under.Visible = state.espOutline
        line.From = under.From
        line.To = under.To
        line.Color = col
        line.Visible = true
    end
end

local function hideCorners(t)
    for i = 1, CORNER_SEGMENTS do
        if t.corner.line[i] then
            t.corner.line[i].Visible = false
            t.corner.under[i].Visible = false
        end
    end
end

local function renderESP()
    if not state.esp or state.unloaded or not hasDrawing then
        for _, t in pairs(esp.data) do hideESP(t) end
        for plr, h in pairs(esp.chams) do pcall(function() h:Destroy() end); esp.chams[plr] = nil end
        return
    end
    buildESP()

    local camPos = cam().CFrame.Position
    local vp = cam().ViewportSize
    local tracerOriginPt = Vector2.new(vp.X / 2, vp.Y)
    if state.espTracerOrigin == "Top" then
        tracerOriginPt = Vector2.new(vp.X / 2, 0)
    elseif state.espTracerOrigin == "Middle" then
        tracerOriginPt = Vector2.new(vp.X / 2, vp.Y / 2)
    elseif state.espTracerOrigin == "Mouse" then
        tracerOriginPt = cursorPoint()
    end

    for plr, t in pairs(esp.data) do
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local head = char and char:FindFirstChild("Head")
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if char and hum and head and root and hum.Health > 0 then
            local dist = (camPos - head.Position).Magnitude
            local top, onScreen = cam():WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
            local bottom = cam():WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
            local col = colorFor(plr)

            if onScreen and top.Z > 0 and dist <= state.espMaxDist then
                -- Floors keep the box readable at range. Without them the width
                -- collapses to a couple of pixels and the outline swallows it.
                local h = math.max(math.abs(bottom.Y - top.Y), 10)
                local w = math.max(h * 0.55, 7)
                local x = top.X - w / 2
                local y = top.Y

                if state.espBox and state.espBoxStyle == "Full" then
                    t.boxOutline.Visible = state.espOutline
                    t.boxOutline.Position = Vector2.new(x - 1, y - 1)
                    t.boxOutline.Size = Vector2.new(w + 2, h + 2)

                    t.box.Visible = true
                    t.box.Color = col
                    t.box.Position = Vector2.new(x, y)
                    t.box.Size = Vector2.new(w, h)

                    hideCorners(t)
                elseif state.espBox then
                    t.box.Visible = false
                    t.boxOutline.Visible = false
                    renderCorners(t, x, y, w, h, col)
                else
                    t.box.Visible = false
                    t.boxOutline.Visible = false
                    hideCorners(t)
                end

                t.name.Visible = state.espName
                t.name.Text = plr.Name
                t.name.Color = col
                t.name.Position = Vector2.new(top.X, y - 15)

                local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
                local frac = math.clamp(hum.Health / maxHp, 0, 1)

                -- Ghost bar drains toward the real value instead of snapping, so
                -- chip damage stays readable for a moment.
                if t.ghostHp < frac then
                    t.ghostHp = frac
                else
                    t.ghostHp = t.ghostHp + (frac - t.ghostHp) * 0.12
                end
                local ghost = math.clamp(t.ghostHp, 0, 1)

                local barCol = frac > 0.6 and Color3.fromRGB(70, 235, 130)
                    or (frac > 0.3 and Color3.fromRGB(245, 215, 90) or Color3.fromRGB(245, 80, 80))

                local bx = x - 8
                local bw = 3

                t.hpOutline.Visible = state.espHealthBar and state.espOutline
                t.hpOutline.Position = Vector2.new(bx - 1, y - 1)
                t.hpOutline.Size = Vector2.new(bw + 2, h + 2)

                t.hpBg.Visible = state.espHealthBar
                t.hpBg.Color = Color3.fromRGB(18, 18, 22)
                t.hpBg.Position = Vector2.new(bx, y)
                t.hpBg.Size = Vector2.new(bw, h)

                t.hpGhost.Visible = state.espHealthBar and ghost > frac + 0.005
                t.hpGhost.Position = Vector2.new(bx, y + h * (1 - ghost))
                t.hpGhost.Size = Vector2.new(bw, h * ghost)

                t.hpFill.Visible = state.espHealthBar
                t.hpFill.Color = barCol
                t.hpFill.Position = Vector2.new(bx, y + h * (1 - frac))
                t.hpFill.Size = Vector2.new(bw, h * frac)

                t.hp.Visible = state.espHealth
                t.hp.Text = string.format("%d/%d", math.floor(hum.Health), math.floor(maxHp))
                t.hp.Color = barCol
                t.hp.Position = Vector2.new(bx - 34, y + h / 2 - 6)

                t.dist.Visible = state.espDist
                t.dist.Text = math.floor(dist) .. "m"
                t.dist.Color = col
                t.dist.Position = Vector2.new(top.X, y + h + 2)

                local eqTool = char:FindFirstChildOfClass("Tool")
                t.tool.Visible = state.espTool and (eqTool ~= nil)
                if t.tool.Visible and eqTool then
                    t.tool.Text = "[" .. eqTool.Name:gsub("%[",""):gsub("%]","") .. "]"
                    t.tool.Color = Color3.fromRGB(225, 225, 230)
                    t.tool.Position = Vector2.new(top.X, y + h + (state.espDist and 14 or 2))
                end

                t.tracer.Visible = state.espTracer
                t.tracer.Color = col
                t.tracer.From = tracerOriginPt
                t.tracer.To = Vector2.new(x + w / 2, y + h)

                if state.espSkeleton then
                    renderSkeleton(char, t, col)
                else
                    for i = 1, #R15_BONES do
                        if t.bones.line[i] then
                            t.bones.line[i].Visible = false
                            t.bones.under[i].Visible = false
                        end
                    end
                end
            else
                hideESP(t)
            end
        else
            hideESP(t)
        end
    end

    if state.espChams then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local h = esp.chams[plr]
                if h and h.Parent ~= plr.Character then
                    h:Destroy(); esp.chams[plr] = nil
                end
                if not esp.chams[plr] then
                    local hl = Instance.new("Highlight")
                    hl.Name = "SnowChams"
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.FillColor = colorFor(plr)
                    hl.OutlineColor = colorFor(plr)
                    hl.FillTransparency = 0.5
                    hl.Parent = plr.Character
                    esp.chams[plr] = hl
                else
                    h.FillColor = colorFor(plr)
                    h.OutlineColor = colorFor(plr)
                end
            end
        end
    else
        for plr, h in pairs(esp.chams) do pcall(function() h:Destroy() end); esp.chams[plr] = nil end
    end
end

--=====================================================================
-- GLOW / FORCEFIELD SKINS
--=====================================================================
-- A Highlight does the colour, a real ForceField does the pulsing shell. The
-- ForceField is purely cosmetic on the client; the server still decides damage.
local glow = { char = nil, ff = nil, gun = nil }

local function clearGlows()
    if glow.char then pcall(function() glow.char:Destroy() end); glow.char = nil end
    if glow.ff then pcall(function() glow.ff:Destroy() end); glow.ff = nil end
    if glow.gun then pcall(function() glow.gun:Destroy() end); glow.gun = nil end
end

local function ensureCharGlow(char)
    if not glow.char or glow.char.Parent ~= char then
        if glow.char then pcall(function() glow.char:Destroy() end) end
        glow.char = Instance.new("Highlight")
        glow.char.Name = "SnowCharGlow"
        glow.char.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        glow.char.FillTransparency = 0.55
        glow.char.OutlineTransparency = 0.15
        glow.char.Parent = char
    end
    if not glow.ff or glow.ff.Parent ~= char then
        if glow.ff then pcall(function() glow.ff:Destroy() end) end
        glow.ff = Instance.new("ForceField")
        glow.ff.Name = "SnowCharFF"
        glow.ff.Visible = true
        glow.ff.Parent = char
    end
end

local function applyGlows()
    local char = getChar()
    if state.charGlow and char then
        ensureCharGlow(char)
        local c = glowColor(state.charGlowColor, state.charGlowRainbow)
        glow.char.FillColor = c
        glow.char.OutlineColor = c
    elseif glow.char or glow.ff then
        if glow.char then pcall(function() glow.char:Destroy() end); glow.char = nil end
        if glow.ff then pcall(function() glow.ff:Destroy() end); glow.ff = nil end
    end

    local tool = toolEquipped()
    if state.gunGlow and tool then
        if not glow.gun or glow.gun.Parent ~= tool then
            if glow.gun then pcall(function() glow.gun:Destroy() end) end
            glow.gun = Instance.new("Highlight")
            glow.gun.Name = "SnowGunGlow"
            glow.gun.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            glow.gun.FillTransparency = 0.4
            glow.gun.OutlineTransparency = 0.1
            glow.gun.Parent = tool
        end
        local c = glowColor(state.gunGlowColor, state.gunGlowRainbow, 0.5)
        glow.gun.FillColor = c
        glow.gun.OutlineColor = c
    elseif glow.gun then
        pcall(function() glow.gun:Destroy() end)
        glow.gun = nil
    end
end

--=====================================================================
-- CHINESE HAT
--=====================================================================
-- A stepped cone of thin cylinders welded to the head. Material.ForceField gives
-- the shell shimmer without needing a ForceField instance per part.
local HAT_SEGMENTS = 10
local hat = { parts = {}, head = nil }

local function clearHat()
    for _, p in ipairs(hat.parts) do pcall(function() p:Destroy() end) end
    hat.parts = {}
    hat.head = nil
end

local function buildHat(head)
    clearHat()
    hat.head = head

    for i = 1, HAT_SEGMENTS do
        local f = (i - 1) / (HAT_SEGMENTS - 1)
        local radius = (1.75 - f * 1.55) * state.hatSize

        local p = Instance.new("Part")
        p.Name = "SnowHat"
        p.Shape = Enum.PartType.Cylinder
        p.Size = Vector3.new(0.12, radius * 2, radius * 2)
        p.Material = Enum.Material.ForceField
        p.Transparency = state.hatTransparency
        p.CanCollide = false
        p.CanQuery = false
        p.Massless = true
        p.Anchored = false
        p.CastShadow = false
        p.Parent = head.Parent

        local offset = CFrame.new(0, 0.55 + f * 0.85 + state.hatHeight, 0) * CFrame.Angles(0, 0, math.rad(90))
        p.CFrame = head.CFrame * offset

        local w = Instance.new("WeldConstraint")
        w.Part0 = head
        w.Part1 = p
        w.Parent = p

        table.insert(hat.parts, p)
    end
end

local function paintHat()
    for i, p in ipairs(hat.parts) do
        if p.Parent then
            p.Color = glowColor(state.hatColor, state.hatRainbow, i / HAT_SEGMENTS)
            p.Transparency = state.hatTransparency
        end
    end
end

local function updateHat()
    if not state.hat or state.unloaded then
        if #hat.parts > 0 then clearHat() end
        return
    end
    local char = getChar()
    local head = char and char:FindFirstChild("Head")
    if not head then
        if #hat.parts > 0 then clearHat() end
        return
    end

    -- Rebuild on respawn, or when a size change makes the existing cone wrong.
    if head ~= hat.head or #hat.parts == 0 then
        buildHat(head)
    else
        local wantR = (1.75) * state.hatSize
        if math.abs(hat.parts[1].Size.Y / 2 - wantR) > 0.05 then
            buildHat(head)
        end
    end
    paintHat()
end

--=====================================================================
-- SKYBOX
--=====================================================================
local SKY_PRESETS = {
    Nebula = { 159454299, 159454300, 159454301, 159454302, 159454303, 159454304 },
    Deep = { 159454299, 159454300, 159454301, 159454302, 159454303, 159454304 },
}

local sky = { inst = nil, saved = nil }

local function applySky()
    if state.unloaded then return end

    if state.skyPreset == "Default" then
        if sky.inst then pcall(function() sky.inst:Destroy() end); sky.inst = nil end
        if sky.saved then
            for _, s in ipairs(sky.saved) do pcall(function() s.Parent = Lighting end) end
            sky.saved = nil
        end
        return
    end

    if not sky.saved then
        sky.saved = {}
        for _, s in ipairs(Lighting:GetChildren()) do
            if s:IsA("Sky") then
                table.insert(sky.saved, s)
                s.Parent = nil
            end
        end
    end

    local ids
    if state.skyPreset == "Custom" then
        ids = {}
        for n in tostring(state.skyCustom):gmatch("%d+") do table.insert(ids, n) end
    else
        ids = SKY_PRESETS[state.skyPreset]
    end
    if not ids or #ids < 6 then return end

    if not sky.inst or not sky.inst.Parent then
        if sky.inst then pcall(function() sky.inst:Destroy() end) end
        sky.inst = Instance.new("Sky")
        sky.inst.Name = "SnowSky"
        sky.inst.Parent = Lighting
    end

    local prefix = "rbxassetid://"
    sky.inst.SkyboxBk = prefix .. ids[1]
    sky.inst.SkyboxDn = prefix .. ids[2]
    sky.inst.SkyboxFt = prefix .. ids[3]
    sky.inst.SkyboxLf = prefix .. ids[4]
    sky.inst.SkyboxRt = prefix .. ids[5]
    sky.inst.SkyboxUp = prefix .. ids[6]
    sky.inst.StarCount = state.skyStars
    sky.inst.CelestialBodiesShown = state.skySun
end

--=====================================================================
-- CHARACTER / WORLD
--=====================================================================
local savedLighting = {}

local function applyCharacter()
    local char = getChar()
    local hum = getHum()
    local root = getRoot()
    if not char or not hum or not root then return end

    if state.speed and not state.fly then
        if state.speedMode == "CFrame" then
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                root.CFrame = root.CFrame + moveDir.Unit * (state.speedValue / 50)
            end
        else
            hum.WalkSpeed = state.speedValue
        end
    end

    if state.jump then
        hum.UseJumpPower = true
        hum.JumpPower = state.jumpValue
        pcall(function() hum.JumpHeight = state.jumpValue / 7 end)
    end

    if state.hipHeight then
        pcall(function() hum.HipHeight = state.hipValue end)
    end

    if state.noclip or state.fly then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end
end

local function applyLighting()
    if state.fullbright then
        if not savedLighting.ambient then
            savedLighting.ambient = Lighting.Ambient
            savedLighting.outdoor = Lighting.OutdoorAmbient
            savedLighting.brightness = Lighting.Brightness
            savedLighting.clock = Lighting.ClockTime
        end
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    elseif savedLighting.ambient then
        Lighting.Ambient = savedLighting.ambient
        Lighting.OutdoorAmbient = savedLighting.outdoor
        Lighting.Brightness = savedLighting.brightness
        Lighting.ClockTime = savedLighting.clock
        savedLighting.ambient, savedLighting.outdoor = nil, nil
        savedLighting.brightness, savedLighting.clock = nil, nil
    end

    if state.noFog then
        if not savedLighting.fog then
            savedLighting.fog = { Lighting.FogStart, Lighting.FogEnd }
            Lighting.FogStart = 0
            Lighting.FogEnd = 1e6
        end
    elseif savedLighting.fog then
        Lighting.FogStart = savedLighting.fog[1]
        Lighting.FogEnd = savedLighting.fog[2]
        savedLighting.fog = nil
    end
end

--=====================================================================
-- FLY
--=====================================================================
-- The humanoid is left running and only its WalkSpeed is zeroed. PlatformStand
-- was the previous approach but it removes the humanoid's own upright force, so
-- the character flops and the gyro has to fight it. With WalkSpeed at 0 there is
-- no MoveDirection to fight either, so the body stays level on its own and the
-- gyro only has to hold the facing.
local fly = { bv = nil, gyro = nil, root = nil, vel = Vector3.zero, yaw = 0 }

local function detachFlyBody()
    if fly.bv then pcall(function() fly.bv:Destroy() end); fly.bv = nil end
    if fly.gyro then pcall(function() fly.gyro:Destroy() end); fly.gyro = nil end
end

local function stopFly()
    detachFlyBody()
    fly.vel = Vector3.zero
    fly.yaw = 0
    fly.root = nil
    local hum = getHum()
    if hum then
        pcall(function() hum.PlatformStand = false end)
        pcall(function()
            hum.WalkSpeed = (state.speed and state.speedMode == "WalkSpeed") and state.speedValue or 16
        end)
    end
end

local function attachFlyBody(root)
    detachFlyBody()
    fly.vel = Vector3.zero

    fly.bv = Instance.new("BodyVelocity")
    fly.bv.Name = "SnowFlyVel"
    fly.bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    fly.bv.Velocity = Vector3.zero
    fly.bv.Parent = root

    -- Enough torque to hold a facing, not enough to snap the body around and
    -- look like it is glitching.
    fly.gyro = Instance.new("BodyGyro")
    fly.gyro.Name = "SnowFlyGyro"
    fly.gyro.MaxTorque = Vector3.new(8e5, 8e5, 8e5)
    fly.gyro.P = 1200
    fly.gyro.D = 70
    fly.gyro.CFrame = root.CFrame
    fly.gyro.Parent = root

    fly.root = root
end

-- Horizontal movement is projected onto the XZ plane unless vertical mode is on,
-- so looking at the floor while holding W keeps you at altitude instead of
-- diving. Space and Ctrl are always the vertical pair.
local function flyInput()
    local dir = Vector3.zero
    local cf = cam().CFrame
    local right = cf.RightVector

    if state.flyVertical then
        local look = cf.LookVector
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= look end
    else
        local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
        if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
        look = look.Unit
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= look end
    end

    local flatRight = Vector3.new(right.X, 0, right.Z)
    if flatRight.Magnitude > 0.01 then
        flatRight = flatRight.Unit
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= flatRight end
    end

    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end

    -- Normalise after summing so diagonals are not 1.41x faster than cardinals.
    if dir.Magnitude > 0 then dir = dir.Unit end
    return dir
end

--=====================================================================
-- SPINBOT
--=====================================================================
-- The root is rotated incrementally rather than driven by a gyro so it composes
-- with the speed feature, which also writes root.CFrame. While flying the gyro
-- owns rotation instead, so the accumulated angle is handed to it and the root
-- write is skipped.
--
-- Humanoid.AutoRotate is cut while spinning. Otherwise the walk controller
-- rewrites the body's facing toward MoveDirection every frame and the spin only
-- survives while standing still. Movement is unaffected: direction comes from
-- camera-relative input, not from which way the model points.
local spin = { angle = 0, autoOff = false }

local function restoreAutoRotate()
    if not spin.autoOff then return end
    spin.autoOff = false
    local hum = getHum()
    if hum then pcall(function() hum.AutoRotate = true end) end
end

local function spinStep(dt)
    if not state.spinbot or state.unloaded then
        restoreAutoRotate()
        return
    end

    local hum = getHum()
    if hum and hum.AutoRotate then
        pcall(function() hum.AutoRotate = false end)
        spin.autoOff = true
    end

    local rad = math.rad(state.spinSpeed) * dt
    if state.spinAxis == "Yaw" then
        spin.angle = (spin.angle + rad) % (math.pi * 2)
    end
    if state.fly then return end

    local root = getRoot()
    if not root then return end

    -- Re-applied after the walk controller has already run this frame, so a
    -- movement update cannot land on top of the spin.
    local cf
    if state.spinAxis == "Pitch" then
        cf = CFrame.Angles(rad, 0, 0)
    elseif state.spinAxis == "Roll" then
        cf = CFrame.Angles(0, 0, rad)
    else
        cf = CFrame.Angles(0, rad, 0)
    end
    root.CFrame = root.CFrame * cf
end

local function updateFly(dt)
    if not state.fly then
        if fly.bv or fly.gyro then stopFly() end
        return
    end

    local root = getRoot()
    local hum = getHum()
    if not root or not hum then
        -- Dead or between respawns: drop the joints so the next frame rebuilds
        -- them against the new root instead of a destroyed one.
        if fly.bv or fly.gyro then detachFlyBody() end
        return
    end

    if root ~= fly.root or not fly.bv or not fly.bv.Parent then
        attachFlyBody(root)
    end

    hum.WalkSpeed = 0

    local target = flyInput() * state.flySpeed
    fly.vel = fly.vel:Lerp(target, 1 - math.exp(-dt * state.flySmooth))
    fly.bv.Velocity = fly.vel

    -- Yaw is smoothed separately from the velocity so a fast mouse flick does
    -- not whip the model around in one frame.
    local flat = Vector3.new(cam().CFrame.LookVector.X, 0, cam().CFrame.LookVector.Z)
    local wantYaw = flat.Magnitude > 0.01 and math.atan2(-flat.X, -flat.Z) or 0
    if state.spinbot then wantYaw += spin.angle end
    local diff = wantYaw - fly.yaw
    while diff > math.pi do diff -= math.pi * 2 end
    while diff < -math.pi do diff += math.pi * 2 end
    fly.yaw = fly.yaw + diff * (1 - math.exp(-dt * 16))

    fly.gyro.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, fly.yaw, 0)
end

--=====================================================================
-- MAIN LOOP
--=====================================================================
local timers = { attack = 0, trigger = 0 }

local function snaplineFrom(origin)
    if origin == "Mouse" then return cursorPoint() end
    if origin == "Bottom" then
        local vp = cam().ViewportSize
        return Vector2.new(vp.X / 2, vp.Y)
    end
    local tool = toolEquipped()
    if tool then
        local p = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
        if p then
            local sp, on = cam():WorldToViewportPoint(p.Position)
            if on and sp.Z > 0 then return Vector2.new(sp.X, sp.Y) end
        end
    end
    return cursorPoint()
end

track(RunService.RenderStepped:Connect(function(dt)
    if state.unloaded then return end

    local mpos = cursorPoint()
    spinStep(dt)
    updateFly(dt)

    if state.silent then
        frameSilentPart, frameSilentPos = liveSilentPart()
    else
        frameSilentPart, frameSilentPos = nil, nil
    end

    -- Build the whole payload here so the namecall hook stays engine-free.
    frame.valid = false
    frame.bangOrigin, frame.hitPos, frame.hitPart, frame.hitNorm = nil, nil, nil, nil
    frame.bodyDist = 0
    if frameSilentPart and frameSilentPos and frameSilentPart.Parent then
        local model = frameSilentPart:FindFirstAncestorOfClass("Model")
        local hum = model and model:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            frame.valid = true

            local char = getChar()
            local tool = toolEquipped()
            local handle = tool and tool:FindFirstChild("Handle")
            local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))

            -- While the joint is cut the Handle floats free, so the true muzzle is
            -- the hand. Otherwise the Handle is still where the game put it.
            local baseOrigin
            if grip.weld then
                baseOrigin = (hand and hand.Position) or cam().CFrame.Position
            elseif handle then
                baseOrigin = handle.Position
            else
                baseOrigin = cam().CFrame.Position
            end

            if state.wallbangMode ~= "Off" then
                frame.bangOrigin, frame.hitPos, frame.hitPart, frame.hitNorm =
                    bangHit(frameSilentPart, frameSilentPos, baseOrigin)
            else
                frame.bangOrigin, frame.hitPos, frame.hitPart, frame.hitNorm =
                    baseOrigin, frameSilentPos, frameSilentPart, nil
            end

            if state.wallbangMode == "Remote" then
                -- Nothing moves in Remote mode; the extra FireServer carries it.
                if grip.weld then restoreGrip(handle, hand) end
            elseif handle and frameSilentPart and frame.bangOrigin
                and state.wallbangMode ~= "Off"
                and state.shiftHandle
                and (frame.bangOrigin - baseOrigin).Magnitude > 0.5 then
                grip.hold = os.clock()
                local gripped = breakGrip(handle, hand)
                handle.CFrame = CFrame.new(frame.bangOrigin) * (handle.CFrame - handle.CFrame.Position)
                if state.debugShots and os.clock() - grip.log > 1 then
                    grip.log = os.clock()
                    print(string.format("[snow] shift %.1f | grip %s | handle %s",
                        (frame.bangOrigin - baseOrigin).Magnitude,
                        gripped and "cut" or "NOT FOUND", handle:GetFullName()))
                end
            elseif grip.weld and os.clock() - grip.hold > 0.25 then
                restoreGrip(handle, hand)
            end

            local root = getRoot()
            frame.bodyDist = root and (frameSilentPos - root.Position).Magnitude or 0
        end
    elseif grip.weld then
        restoreGrip(toolEquipped() and toolEquipped():FindFirstChild("Handle"),
            getChar() and (getChar():FindFirstChild("RightHand") or getChar():FindFirstChild("Right Arm")))
    end

    if hasDrawing then
        draw.aimCircle.Position = Vector2.new(mpos.X, mpos.Y + state.aimCircleY)
        draw.aimCircle.Radius = state.aimFov
        draw.aimCircle.Color = state.aimColor
        draw.aimCircle.Visible = state.aimCircle and state.aimbot

        draw.silentCircle.Position = Vector2.new(mpos.X, mpos.Y + state.silentCircleY)
        draw.silentCircle.Radius = state.silentFov
        draw.silentCircle.Color = state.silentColor
        draw.silentCircle.Visible = state.silentCircle and state.silent
    end

    local aimTarget, aimPart = nil, nil
    if state.aimbot and mouseFree() then
        aimTarget, aimPart = findTarget(state.aimPart, state.aimFov, state.aimTeamCheck, state.aimVisible, mpos)
        if aimTarget and aimPart then
            local pos = predict(aimPart, 1, "aim")
            local alpha = math.clamp(state.aimSmooth / 100, 0.02, 1)
            if state.aimMode == "Mouse" then
                local sp, on = cam():WorldToViewportPoint(pos)
                if on then
                    local dx = sp.X - mpos.X
                    local dy = sp.Y - mpos.Y
                    pcall(function()
                        mousemoverel(dx * alpha, dy * alpha)
                    end)
                end
            else
                local goal = CFrame.lookAt(cam().CFrame.Position, pos)
                cam().CFrame = cam().CFrame:Lerp(goal, alpha)
            end
        end
    end

    if hasDrawing then
        if state.aimSnapline and state.aimbot and aimPart then
            local sp, on = cam():WorldToViewportPoint(aimPart.Position)
            if on and sp.Z > 0 then
                draw.aimSnapline.Visible = true
                draw.aimSnapline.Color = state.aimSnaplineColor
                draw.aimSnapline.Thickness = state.aimSnaplineWidth
                draw.aimSnapline.From = snaplineFrom(state.aimSnaplineOrigin)
                draw.aimSnapline.To = Vector2.new(sp.X, sp.Y)
            else
                draw.aimSnapline.Visible = false
            end
        else
            draw.aimSnapline.Visible = false
        end

        if state.silentSnapline and state.silent then
            local part, pos = currentSilent()
            if part and pos then
                local sp, on = cam():WorldToViewportPoint(pos)
                if on and sp.Z > 0 then
                    draw.silentSnapline.Visible = true
                    draw.silentSnapline.Color = state.silentSnaplineColor
                    draw.silentSnapline.Thickness = state.silentSnaplineWidth
                    draw.silentSnapline.From = snaplineFrom(state.silentSnaplineOrigin)
                    draw.silentSnapline.To = Vector2.new(sp.X, sp.Y)
                else
                    draw.silentSnapline.Visible = false
                end
            else
                draw.silentSnapline.Visible = false
            end
        else
            draw.silentSnapline.Visible = false
        end

        -- Anti-aim viewer: the signed yaw gap between where the body points and
        -- where the camera points, drawn as an arrow from the silent FOV centre.
        -- Positive body yaw is counter-clockwise from above, which is leftward on
        -- screen, so the direction vector is (-sin, -cos).
        local aaRoot = getRoot()
        if state.antiAimViewer and aaRoot then
            local bl = aaRoot.CFrame.LookVector
            local cl = cam().CFrame.LookVector
            local delta = math.atan2(-bl.X, -bl.Z) - math.atan2(-cl.X, -cl.Z)
            while delta > math.pi do delta -= math.pi * 2 end
            while delta < -math.pi do delta += math.pi * 2 end

            local centre = Vector2.new(mpos.X, mpos.Y + state.silentCircleY)
            local tip = centre + Vector2.new(-math.sin(delta), -math.cos(delta)) * state.antiAimLength

            draw.aaLine.Visible = true
            draw.aaLine.Color = state.antiAimColor
            draw.aaLine.From = centre
            draw.aaLine.To = tip

            draw.aaText.Visible = true
            draw.aaText.Text = string.format("%.0f", math.deg(delta))
            draw.aaText.Color = state.antiAimColor
            draw.aaText.Position = tip + Vector2.new(0, -14)
        else
            draw.aaLine.Visible = false
            draw.aaText.Visible = false
        end

        renderTracers()
    end

    if state.trigger and mouseFree() and os.clock() - timers.trigger > state.triggerDelay then
        local t = findTarget(state.triggerPart, state.triggerFov, state.triggerTeamCheck, true, mpos)
        if t then
            timers.trigger = os.clock()
            task.spawn(function()
                pcall(fireRemoteShot)
                pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
                task.wait(0.02)
                pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
            end)
        end
    end

    if state.autoAttack then
        local tool = toolEquipped()
        if tool and os.clock() - timers.attack >= 0.15 then
            timers.attack = os.clock()
            pcall(fireRemoteShot)
            pcall(function() tool:Activate() end)
        end
    end

    renderESP()
end))

track(RunService.Heartbeat:Connect(function()
    if state.unloaded then return end
    applyCharacter()
    applyLighting()
    applyGlows()
    updateHat()
    pollHits()

    local tool = toolEquipped()
    releaseStaleLocks(tool)
    if tool then
        attachLocks(tool)
        if state.infiniteAmmo then
            for _, v in ipairs(tool:GetDescendants()) do
                if v:IsA("IntValue") and v.Name:lower():find("ammo") then v.Value = state.maxAmmo end
                if v:IsA("NumberValue") and v.Name:lower():find("ammo") then v.Value = state.maxAmmo end
            end
        end
        if state.autoReload then
            local ammo = tool:FindFirstChild("Ammo")
            if ammo and ammo:IsA("ValueBase") and ammo.Value <= 0 then
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                end)
            end
        end
    end
end))

track(UserInputService.JumpRequest:Connect(function()
    if state.unloaded or state.fly then return end
    if state.infJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

track(LP.Idled:Connect(function()
    if state.antiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

--=====================================================================
-- WINDOW
--=====================================================================
Window = Library.CreateWindow({
    Title = "snow.cc",
    Game = "Zee Hood",
    Link = "discord.gg/snowcc",
    Size = Vector2.new(700, 600),
    ToggleKey = Enum.KeyCode.RightShift,
})
Library.CurrentWindow = Window

-- Unload is defined below the tab builders but the Settings tab's button needs a
-- reference to it, so it is forward-declared here and assigned further down. The
-- button wraps it rather than capturing it directly, because the local is still
-- nil at the moment the button is built.
local Unload

--=====================================================================
-- AIMBOT TAB
--=====================================================================
-- Each tab is built inside its own block. The tab objects are all reachable
-- through Window.Tabs once CreateTab returns, so nothing outside needs the
-- locals, and letting them go out of scope at the block end is what keeps this
-- region from exhausting the register budget on its own.
do
    local AimTab = Window:CreateTab("Aimbot")
    local AimGroup = AimTab:CreateGroupbox("Aimbot", "Left")
    local aimToggle = AimGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.E, Callback = function(v) state.aimbot = v end })
    register("aim.enabled", aimToggle, false)
    AimGroup:AddDropdown("Aim mode", { "Camera", "Mouse" }, "Camera", function(v) state.aimMode = v end)
    AimGroup:AddDropdown("Aim part", { "Head", "Closest", "Hitbox", "Torso", "HumanoidRootPart", "Adaptive" }, "Head", function(v) state.aimPart = v end)
    local fovS = AimGroup:AddSlider("FOV", 20, 800, 150, "px", function(v) state.aimFov = v end)
    register("aim.fov", fovS, 150)
    local smoothS = AimGroup:AddSlider("Smoothing", 1, 100, 25, "%", function(v) state.aimSmooth = v end)
    register("aim.smooth", smoothS, 25)
    AimGroup:AddToggle("Prediction", true, { Callback = function(v) state.aimPrediction = v end })
    AimGroup:AddToggle("Team Check", true, { Callback = function(v) state.aimTeamCheck = v end })
    AimGroup:AddToggle("Visible Only", false, { Callback = function(v) state.aimVisible = v end })
    AimGroup:AddToggle("FOV Circle", true, { Callback = function(v) state.aimCircle = v end })
    local aimCY = AimGroup:AddSlider("Circle Y Offset", -300, 300, 0, "px", function(v) state.aimCircleY = v end)
    register("aim.circley", aimCY, 0)
    AimGroup:AddColorPicker("Circle Colour", Color3.fromRGB(0, 175, 255), function(c) state.aimColor = c end)

    local AimVis = AimTab:CreateGroupbox("Aim Snapline", "Right")
    AimVis:AddToggle("Show", false, { Callback = function(v) state.aimSnapline = v end })
    AimVis:AddDropdown("From", { "Gun", "Mouse", "Bottom" }, "Gun", function(v) state.aimSnaplineOrigin = v end)
    local asw = AimVis:AddSlider("Width", 1, 6, 1, "px", function(v) state.aimSnaplineWidth = v end)
    register("aim.snapwidth", asw, 1)
    AimVis:AddColorPicker("Colour", Color3.fromRGB(0, 175, 255), function(c) state.aimSnaplineColor = c end)

    local TrigGroup = AimTab:CreateGroupbox("Triggerbot", "Right")
    TrigGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.T, Callback = function(v) state.trigger = v end })
    TrigGroup:AddDropdown("Hit part", { "Head", "Closest", "Hitbox", "Torso", "HumanoidRootPart" }, "Head", function(v) state.triggerPart = v end)
    local trigFovS = TrigGroup:AddSlider("FOV", 20, 800, 150, "px", function(v) state.triggerFov = v end)
    register("trigger.fov", trigFovS, 150)
    TrigGroup:AddToggle("Team Check", true, { Callback = function(v) state.triggerTeamCheck = v end })
    local tdS = TrigGroup:AddSlider("Delay", 10, 500, 80, "ms", function(v) state.triggerDelay = v / 1000 end)
    register("trigger.delay", tdS, 80)
end

--=====================================================================
-- SILENT TAB
--=====================================================================
do
    local SilentTab = Window:CreateTab("Silent")
    local SilentGroup = SilentTab:CreateGroupbox("Silent Aim", "Left")
    local silToggle = SilentGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.Q, Callback = function(v) state.silent = v end })
    register("silent.enabled", silToggle, false)
    SilentGroup:AddDropdown("Hit limb", { "Closest", "Hitbox", "HumanoidRootPart", "Head", "Torso", "Adaptive" }, "Hitbox", function(v) state.silentPart = v end)
    SilentGroup:AddToggle("Knock Check", true, { Callback = function(v) state.knockCheck = v end })
    SilentGroup:AddToggle("Spread Condenser (Pellet Lock)", true, { Callback = function(v) state.spreadCondenser = v end })
    local silFov = SilentGroup:AddSlider("FOV", 20, 800, 300, "px", function(v) state.silentFov = v end)
    register("silent.fov", silFov, 300)
    local silChance = SilentGroup:AddSlider("Hit Chance", 1, 100, 100, "%", function(v) state.silentChance = v end)
    register("silent.chance", silChance, 100)
    SilentGroup:AddToggle("Team Check", true, { Callback = function(v) state.silentTeamCheck = v end })
    SilentGroup:AddToggle("Visible Only", false, { Callback = function(v) state.silentVisibleOnly = v end })
    SilentGroup:AddSegmented("Wallbang", { "Off", "Remote", "Soft", "Hard", "Snap" }, "Remote", function(v) state.wallbangMode = v end)
    SilentGroup:AddToggle("Shift Handle", true, { Callback = function(v) state.shiftHandle = v end })
    local wbMax = SilentGroup:AddSlider("Wallbang Max Move", 4, 300, 28, "st", function(v) state.wallbangMax = v end)
    register("silent.wbmax", wbMax, 28)
    SilentGroup:AddToggle("Debug Shots", false, { Callback = function(v) state.debugShots = v end })
    SilentGroup:AddToggle("Prediction", true, { Callback = function(v) state.silentPrediction = v end })
    local silPredSlider = SilentGroup:AddSlider("Prediction Factor", 0, 200, 100, "%", function(v) state.silentPredictionFactor = v / 100 end)
    register("silent.predfactor", silPredSlider, 100)
    SilentGroup:AddToggle("Show FOV Circle", false, { Callback = function(v) state.silentCircle = v end })
    local silCY = SilentGroup:AddSlider("Circle Y Offset", -300, 300, 0, "px", function(v) state.silentCircleY = v end)
    register("silent.circley", silCY, 0)
    SilentGroup:AddColorPicker("Circle Colour", Color3.fromRGB(0, 200, 255), function(c) state.silentColor = c end)

    local SilVis = SilentTab:CreateGroupbox("Silent Snapline", "Right")
    SilVis:AddToggle("Show", false, { Callback = function(v) state.silentSnapline = v end })
    SilVis:AddDropdown("From", { "Gun", "Mouse", "Bottom" }, "Gun", function(v) state.silentSnaplineOrigin = v end)
    local ssw = SilVis:AddSlider("Width", 1, 6, 1, "px", function(v) state.silentSnaplineWidth = v end)
    register("silent.snapwidth", ssw, 1)
    SilVis:AddColorPicker("Colour", Color3.fromRGB(0, 200, 255), function(c) state.silentSnaplineColor = c end)

    local AaGroup = SilentTab:CreateGroupbox("Anti-Aim Viewer", "Right")
    AaGroup:AddToggle("Show", false, { Callback = function(v) state.antiAimViewer = v end })
    local aaLen = AaGroup:AddSlider("Length", 20, 200, 80, "px", function(v) state.antiAimLength = v end)
    register("aa.length", aaLen, 80)
    AaGroup:AddColorPicker("Colour", Color3.fromRGB(0, 200, 255), function(c) state.antiAimColor = c end)

    local GunGroup = SilentTab:CreateGroupbox("Gun Mods", "Right")
    GunGroup:AddToggle("Infinite Ammo", false, { Callback = function(v) state.infiniteAmmo = v; pushLocks(toolEquipped()) end })
    local maxAmmoSlider = GunGroup:AddSlider("Ammo Value", 30, 9999, 999, "", function(v) state.maxAmmo = v; pushLocks(toolEquipped()) end)
    register("gun.maxammo", maxAmmoSlider, 999)
    GunGroup:AddToggle("Rapid Fire (hold LMB)", false, { Callback = function(v) state.rapidFire = v; pushLocks(toolEquipped()) end })
    local cdSlider = GunGroup:AddSlider("Fire Cooldown", 10, 500, 30, "ms", function(v) state.fireCooldown = v / 1000; pushLocks(toolEquipped()) end)
    register("gun.cooldown", cdSlider, 30)
    GunGroup:AddToggle("Damage Override", false, { Callback = function(v) state.damageOverride = v; pushLocks(toolEquipped()) end })
    local dmgSlider = GunGroup:AddSlider("Damage", 1, 500, 100, "", function(v) state.damageValue = v; pushLocks(toolEquipped()) end)
    register("gun.damage", dmgSlider, 100)
    GunGroup:AddToggle("Range Override", false, { Callback = function(v) state.rangeOverride = v; pushLocks(toolEquipped()) end })
    local rangeSlider = GunGroup:AddSlider("Range", 50, 3000, 500, "", function(v) state.rangeValue = v; pushLocks(toolEquipped()) end)
    register("gun.range", rangeSlider, 500)
    GunGroup:AddToggle("Auto Reload", false, { Callback = function(v) state.autoReload = v end })
    GunGroup:AddToggle("Auto Attack", false, { Callback = function(v) state.autoAttack = v end })
end

--=====================================================================
-- ESP TAB
--=====================================================================
do
    local EspTab = Window:CreateTab("ESP")
    local EspGroup = EspTab:CreateGroupbox("Players", "Left")
    EspGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.F, Callback = function(v) state.esp = v end })
    EspGroup:AddToggle("Box", true, { Callback = function(v) state.espBox = v end })
    EspGroup:AddDropdown("Box Style", { "Full", "Corner" }, "Full", function(v) state.espBoxStyle = v end)
    EspGroup:AddToggle("Outline", true, { Callback = function(v) state.espOutline = v end })
    EspGroup:AddToggle("Skeleton", false, { Callback = function(v) state.espSkeleton = v end })
    EspGroup:AddToggle("Name", true, { Callback = function(v) state.espName = v end })
    EspGroup:AddToggle("Health Text", true, { Callback = function(v) state.espHealth = v end })
    EspGroup:AddToggle("Health Bar", true, { Callback = function(v) state.espHealthBar = v end })
    EspGroup:AddToggle("Distance", true, { Callback = function(v) state.espDist = v end })
    EspGroup:AddToggle("Equipped Tool", true, { Callback = function(v) state.espTool = v end })
    EspGroup:AddToggle("Tracer", false, { Callback = function(v) state.espTracer = v end })
    EspGroup:AddDropdown("Tracer Origin", { "Bottom", "Top", "Middle", "Mouse" }, "Bottom", function(v) state.espTracerOrigin = v end)
    EspGroup:AddToggle("Chams", false, { Callback = function(v) state.espChams = v end })
    local distS = EspGroup:AddSlider("Max Distance", 100, 5000, 1500, "m", function(v) state.espMaxDist = v end)
    register("esp.maxdist", distS, 1500)
    EspGroup:AddColorPicker("Enemy Colour", Color3.fromRGB(255, 60, 60), function(c) state.espEnemy = c end)
    EspGroup:AddColorPicker("Team Colour", Color3.fromRGB(60, 255, 120), function(c) state.espTeam = c end)
end

--=====================================================================
-- CHARACTER TAB
--=====================================================================
do
    local CharTab = Window:CreateTab("Character")
    local MoveGroup = CharTab:CreateGroupbox("Movement", "Left")
    MoveGroup:AddToggle("Speed", false, { Keybind = Enum.KeyCode.Z, Callback = function(v) state.speed = v end })
    MoveGroup:AddDropdown("Speed Mode", { "CFrame", "WalkSpeed" }, "CFrame", function(v) state.speedMode = v end)
    local spdS = MoveGroup:AddSlider("Speed Value", 16, 300, 24, "", function(v) state.speedValue = v end)
    register("char.speed", spdS, 24)
    MoveGroup:AddToggle("Jump Power", false, { Callback = function(v) state.jump = v end })
    local jmpS = MoveGroup:AddSlider("Jump Value", 50, 400, 55, "", function(v) state.jumpValue = v end)
    register("char.jump", jmpS, 55)
    MoveGroup:AddToggle("Hip Height", false, { Callback = function(v) state.hipHeight = v end })
    local hipS = MoveGroup:AddSlider("Hip Value", 0, 20, 2, "", function(v) state.hipValue = v end)
    register("char.hip", hipS, 2)
    MoveGroup:AddToggle("Fly", false, { Keybind = Enum.KeyCode.G, Callback = function(v)
        state.fly = v
        if not v then pcall(stopFly) end
    end })
    local flyS = MoveGroup:AddSlider("Fly Speed", 10, 300, 60, "", function(v) state.flySpeed = v end)
    register("char.flyspeed", flyS, 60)
    local flySm = MoveGroup:AddSlider("Fly Smoothing", 0, 100, 45, "%", function(v)
        state.flySmooth = 30 * (1 - v / 100) ^ 2 + 2
    end)
    register("char.flysmooth", flySm, 45)
    MoveGroup:AddToggle("Fly Vertical (camera pitch)", false, { Callback = function(v) state.flyVertical = v end })
    MoveGroup:AddToggle("Noclip", false, { Callback = function(v) state.noclip = v end })
    MoveGroup:AddToggle("Infinite Jump", false, { Callback = function(v) state.infJump = v end })

    local TracerGroup = CharTab:CreateGroupbox("Bullet Tracers", "Left")
    TracerGroup:AddToggle("Enabled", false, { Callback = function(v) state.tracer = v end })
    TracerGroup:AddDropdown("Style", { "Line", "Thick", "Glow" }, "Line", function(v) state.tracerStyle = v end)
    local trW = TracerGroup:AddSlider("Width", 1, 8, 2, "px", function(v) state.tracerWidth = v end)
    register("tracer.width", trW, 2)
    local trLife = TracerGroup:AddSlider("Lifetime", 5, 100, 35, "%", function(v) state.tracerLife = v / 100 end)
    register("tracer.life", trLife, 35)
    TracerGroup:AddColorPicker("Colour", Color3.fromRGB(255, 220, 90), function(c) state.tracerColor = c end)

    local GlowGroup = CharTab:CreateGroupbox("Forcefields", "Left")
    GlowGroup:AddToggle("Character Glow", false, { Callback = function(v) state.charGlow = v end })
    GlowGroup:AddToggle("Character Rainbow", false, { Callback = function(v) state.charGlowRainbow = v end })
    GlowGroup:AddColorPicker("Character Colour", Color3.fromRGB(0, 200, 255), function(c) state.charGlowColor = c end)
    GlowGroup:AddToggle("Gun Glow", false, { Callback = function(v) state.gunGlow = v end })
    GlowGroup:AddToggle("Gun Rainbow", false, { Callback = function(v) state.gunGlowRainbow = v end })
    GlowGroup:AddColorPicker("Gun Colour", Color3.fromRGB(0, 200, 255), function(c) state.gunGlowColor = c end)
    local rbS = GlowGroup:AddSlider("Rainbow Speed", 5, 100, 30, "%", function(v) state.rainbowSpeed = v end)
    register("glow.rainbowspeed", rbS, 30)

    local SpinGroup = CharTab:CreateGroupbox("Spinbot", "Right")
    SpinGroup:AddToggle("Enabled", false, { Callback = function(v)
        state.spinbot = v
        if not v then pcall(restoreAutoRotate) end
    end })
    SpinGroup:AddDropdown("Axis", { "Yaw", "Pitch", "Roll" }, "Yaw", function(v) state.spinAxis = v end)
    local spinS = SpinGroup:AddSlider("Speed", 30, 3600, 720, " deg/s", function(v) state.spinSpeed = v end)
    register("char.spinspeed", spinS, 720)

    local HatGroup = CharTab:CreateGroupbox("Chinese Hat", "Right")
    HatGroup:AddToggle("Enabled", false, { Callback = function(v)
        state.hat = v
        if not v then pcall(clearHat) end
    end })
    HatGroup:AddToggle("Rainbow", true, { Callback = function(v) state.hatRainbow = v end })
    HatGroup:AddColorPicker("Colour", Color3.fromRGB(255, 210, 90), function(c) state.hatColor = c end)
    local hatSizeS = HatGroup:AddSlider("Size", 30, 200, 100, "%", function(v) state.hatSize = v / 100 end)
    register("hat.size", hatSizeS, 100)
    local hatTrS = HatGroup:AddSlider("Transparency", 0, 90, 35, "%", function(v) state.hatTransparency = v / 100 end)
    register("hat.transparency", hatTrS, 35)
    local hatHS = HatGroup:AddSlider("Height", -30, 60, 0, "st", function(v) state.hatHeight = v / 10 end)
    register("hat.height", hatHS, 0)

    local MiscGroup = CharTab:CreateGroupbox("Utility", "Right")
    MiscGroup:AddToggle("Anti AFK", true, { Callback = function(v) state.antiAfk = v end })
    MiscGroup:AddButton("Rejoin Server", function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
    end)
    MiscGroup:AddButton("Server Hop", function()
        task.spawn(function()
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"))
            end)
            if ok and res and res.data then
                for _, s in ipairs(res.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP) end)
                        return
                    end
                end
            end
            pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
        end)
    end)

    local TpGroup = CharTab:CreateGroupbox("Teleport", "Right")

    local tpDrop
    local function refreshTpList()
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local c = plr.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r then table.insert(list, plr.Name) end
            end
        end
        table.sort(list)
        if #list == 0 then list = { "Nobody" } end
        if tpDrop then pcall(tpDrop.SetOptions, list, list[1]) end
    end

    tpDrop = TpGroup:AddDropdown("Player", { "Nobody" }, "Nobody")

    local tpOffS = TpGroup:AddSlider("Offset", 2, 12, 4, " studs", function(v) state.tpOffset = v end)
    register("char.tpoffset", tpOffS, 4)

    local function teleportTo(name)
        if not name or name == "Nobody" then return end
        local target
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == name then target = plr break end
        end
        if not target then return end

        local tChar = target.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tRoot then return end

        local myRoot, myHum = getRoot(), getHum()
        if not myRoot or not myHum then return end

        local back = tRoot.CFrame.LookVector * -(state.tpOffset or 4)
        local goal = tRoot.Position + back + Vector3.new(0, 3, 0)

        myRoot.CFrame = CFrame.new(goal) * (myRoot.CFrame - myRoot.CFrame.Position)

        if myHum.PlatformStand or myHum:GetState() == Enum.HumanoidStateType.Physics then
            pcall(function() myHum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end

    TpGroup:AddButton("Teleport", function()
        teleportTo(tpDrop:GetValue())
    end)

    TpGroup:AddButton("Refresh List", function()
        refreshTpList()
    end)

    task.spawn(function()
        task.wait(1)
        while not state.unloaded do
            pcall(refreshTpList)
            task.wait(2)
        end
    end)
end

--=====================================================================
-- WORLD TAB
--=====================================================================
do
    local WorldTab = Window:CreateTab("World")

    local LightGroup = WorldTab:CreateGroupbox("Lighting", "Left")
    LightGroup:AddToggle("Fullbright", false, { Callback = function(v) state.fullbright = v end })
    LightGroup:AddToggle("No Fog", false, { Callback = function(v) state.noFog = v end })

    local SkyGroup = WorldTab:CreateGroupbox("Skybox", "Left")
    SkyGroup:AddDropdown("Preset", { "Default", "Nebula", "Custom" }, "Default", function(v)
        state.skyPreset = v
        applySky()
    end)
    SkyGroup:AddTextbox("Custom IDs", "", "bk,dn,ft,lf,rt,up", function(v)
        state.skyCustom = v
        if state.skyPreset == "Custom" then applySky() end
    end)
    local skyStars = SkyGroup:AddSlider("Stars", 0, 5000, 3000, "", function(v)
        state.skyStars = v
        if sky.inst then sky.inst.StarCount = v end
    end)
    register("sky.stars", skyStars, 3000)
    SkyGroup:AddToggle("Sun & Moon", true, { Callback = function(v)
        state.skySun = v
        if sky.inst then sky.inst.CelestialBodiesShown = v end
    end })

    local SoundGroup = WorldTab:CreateGroupbox("Hit Sounds", "Right")
    SoundGroup:AddToggle("Enabled", false, { Callback = function(v) state.hitSound = v end })
    SoundGroup:AddDropdown("Sound", { "Sword Slash", "Sword Lunge", "Blade", "Click", "Bass", "Pop" }, "Sword Slash", function(v)
        state.hitSoundId = HIT_SOUNDS[v] or ""
    end)
    local hsVol = SoundGroup:AddSlider("Volume", 5, 100, 60, "%", function(v) state.hitSoundVolume = v / 100 end)
    register("sound.volume", hsVol, 60)
    local hsPitch = SoundGroup:AddSlider("Pitch", 50, 200, 100, "%", function(v) state.hitSoundPitch = v / 100 end)
    register("sound.pitch", hsPitch, 100)
    SoundGroup:AddButton("Preview", function()
        playHitSound()
    end)
end

--=====================================================================
-- SETTINGS TAB
--=====================================================================
do
    local SetTab = Window:CreateTab("Settings")
    local CfgGroup = SetTab:CreateGroupbox("Config", "Left")

    local function saveConfig()
        local data = {}
        for k, get in pairs(reg.getters) do
            local ok, val = pcall(get)
            if ok then data[k] = val end
        end
        pcall(function() writefile("snowcc_zeehood.json", HttpService:JSONEncode(data)) end)
        print("[snow] config saved")
    end

    local function loadConfig()
        local ok, raw = pcall(function() return readfile("snowcc_zeehood.json") end)
        if not ok or not raw then return end
        local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok2 or type(data) ~= "table" then return end
        for k, v in pairs(data) do
            local setter = reg.setters[k]
            if setter then pcall(setter, v) end
        end
        print("[snow] config loaded")
    end

    CfgGroup:AddButton("Save Config", saveConfig)
    CfgGroup:AddButton("Load Config", loadConfig)

    local AcGroup = SetTab:CreateGroupbox("Anti-Cheat", "Right")
    AcGroup:AddToggle("AC Bypass (Shield)", true, {
        Callback = function(v)
            Shield.on = v
            if v then
                task.spawn(armShield)
            else
                restoreShield()
                print("[snow] shield disabled")
            end
        end,
    })
    AcGroup:AddButton("Rescan Detectors", function()
        Shield.cands = {}
        Shield.lastFull = 0
        task.spawn(armShield)
    end)
    AcGroup:AddDropdown("Hook Mode", { "Off", "Namecall", "Auto" }, "Off", function(v)
        state.hookMode = v
        pcall(uninstallRemote)
        if v ~= "Off" then pcall(installRemote) end
    end)
    AcGroup:AddButton("Reinstall Hooks", function()
        pcall(uninstallRemote)
        pcall(installAll)
    end)
    AcGroup:AddButton("Dump GunHandler", function()
        if not GunHandler then print("[snow] GunHandler missing") return end
        local keys = {}
        for k, v in pairs(GunHandler) do table.insert(keys, tostring(k) .. "=" .. typeof(v)) end
        print("[snow] GunHandler: " .. table.concat(keys, ", "))
    end)

    local AboutGroup = SetTab:CreateGroupbox("About", "Right")
    AboutGroup:AddButton("snow.cc | Zee Hood build", function() end)
    AboutGroup:AddButton("Menu toggle: RightShift", function() end)
    AboutGroup:AddButton("Unload Script", function()
        if Unload then Unload() end
    end)
end

--=====================================================================
-- UNLOAD
--=====================================================================
function Unload()
    state.unloaded = true
    for _, c in ipairs(con.live) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(con.ui) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(Library.Conns) do pcall(function() c:Disconnect() end) end
    pcall(clearAll)
    pcall(uninstallRemote)
    pcall(restoreShield)
    pcall(restoreGrip)
    pcall(stopFly)
    pcall(restoreAutoRotate)
    pcall(clearGlows)
    pcall(clearHat)
    pcall(clearTracers)
    state.skyPreset = "Default"
    pcall(applySky)
    for t in pairs(locks.byTool) do detachLocks(t) end
    for _, t in pairs(esp.data) do destroyESP(t) end
    for _, h in pairs(esp.chams) do pcall(function() h:Destroy() end) end
    if draw.aimCircle then pcall(function() draw.aimCircle:Remove() end) end
    if draw.silentCircle then pcall(function() draw.silentCircle:Remove() end) end
    if draw.aimSnapline then pcall(function() draw.aimSnapline:Remove() end) end
    if draw.silentSnapline then pcall(function() draw.silentSnapline:Remove() end) end
    if draw.aaLine then pcall(function() draw.aaLine:Remove() end) end
    if draw.aaText then pcall(function() draw.aaText:Remove() end) end
    if savedLighting.ambient then
        Lighting.Ambient = savedLighting.ambient
        Lighting.OutdoorAmbient = savedLighting.outdoor
        Lighting.Brightness = savedLighting.brightness
        Lighting.ClockTime = savedLighting.clock
    end
    if savedLighting.fog then
        Lighting.FogStart = savedLighting.fog[1]
        Lighting.FogEnd = savedLighting.fog[2]
    end
    pcall(function() Window.ScreenGui:Destroy() end)
    if getgenv then getgenv().SnowHoodLoaded = nil end
    print("[snow] unloaded")
end

getgenv().SnowHoodLoaded = { Unload = Unload }

--=====================================================================
-- STARTUP
--=====================================================================
state.hitSoundId = HIT_SOUNDS["Sword Slash"]

task.spawn(function()
    local tries = 0
    while not GunHandler and tries < 40 do
        GunHandler = loadGunHandler()
        if not GunHandler then task.wait(1) end
        tries = tries + 1
    end
    if GunHandler then installAll() else warn("[snow] GunHandler never loaded") end
    pcall(loadConfig)
end)

-- The shield toggle starts checked but its callback never runs on build, so it
-- has to be armed here rather than waiting for a user interaction.
task.spawn(function()
    task.wait(3)
    if Shield.on and not state.unloaded then armShield() end
end)

print("[snow] loaded | GunHandler:", GunHandler and "hooked" or "missing", "| remote:", getRemoteEvent() and "found" or "missing")