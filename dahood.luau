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

local function screenCentre()
    local vp = cam().ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
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
    silent = false, silentFov = 300, silentPart = "HumanoidRootPart", silentChance = 100,
    silentTeamCheck = true, wallbangMode = "Off", silentPrediction = true, silentPredictionFactor = 1,
    knockCheck = true, adaptiveHitbox = false, spreadCondenser = true,
    silentCircle = false, silentColor = Color3.fromRGB(0, 200, 255), silentCircleY = 0,
    silentSnapline = false, silentSnaplineOrigin = "Gun", silentSnaplineWidth = 1,
    silentSnaplineColor = Color3.fromRGB(0, 200, 255),
    autoReload = false, infiniteAmmo = false, maxAmmo = 999, autoAttack = false, attackRange = 14,
    rapidFire = false, fireCooldown = 0.03,
    damageOverride = false, damageValue = 100,
    rangeOverride = false, rangeValue = 500,
    esp = false, espBox = true, espName = true, espHealth = true, espHealthBar = true, espDist = true,
    espTracer = false, espTracerOrigin = "Bottom", espTool = true, espMaxDist = 1500, espChams = false,
    espEnemy = Color3.fromRGB(255, 60, 60), espTeam = Color3.fromRGB(60, 255, 120),
    speed = false, speedValue = 24, speedMode = "CFrame", jump = false, jumpValue = 55,
    hipHeight = false, hipValue = 2, fly = false, flySpeed = 60,
    noclip = false, infJump = false, antiAfk = true,
    fullbright = false, noFog = false,
    unloaded = false,
}

local flags, setters = {}, {}
local function register(key, setter, initial)
    flags[key] = initial
    setters[key] = setter
end

local conns = {}
local function track(c) table.insert(conns, c) return c end

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
    if state.knockCheck and isKnocked(c) then return false end
    return true
end
local function getPart(plr, name)
    local c = plr and plr.Character
    if not c then return nil end
    if (state.adaptiveHitbox or name == "Adaptive") then
        local candidates = { "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso" }
        for _, n in ipairs(candidates) do
            local p = c:FindFirstChild(n)
            if p and p:IsA("BasePart") and visible(p) then return p end
        end
    end
    local p = c:FindFirstChild(name)
    if p and p:IsA("BasePart") then return p end
    p = c:FindFirstChild("Head")
    if p and p:IsA("BasePart") then return p end
    return c:FindFirstChild("HumanoidRootPart")
end
local function mouseFree()
    return UserInputService:GetFocusedTextBox() == nil
end
local function ping()
    return smoothPing()
end
local cachedPing, cachedPingAt = 60, 0
local function smoothPing()
    if os.clock() - cachedPingAt > 0.2 then
        cachedPingAt = os.clock()
        local ok, v = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        cachedPing = ok and v or cachedPing
    end
    return cachedPing
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
local InVisRay = false
local function visible(part)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = { LP.Character }
    if part.Parent then table.insert(ignore, part.Parent) end
    params.FilterDescendantsInstances = ignore
    InVisRay = true
    local res = workspace:Raycast(cam().CFrame.Position, part.Position - cam().CFrame.Position, params)
    InVisRay = false
    return res == nil
end
local function ignoreVis()
    return state.wallbangMode == "Off"
end

local function findTarget(partName, fov, teamCheck, visCheck, fromPoint)
    local best, bestDist = nil, math.huge
    local mpos = fromPoint or cursorPoint()
    local myChar = getChar()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.UserId ~= LP.UserId and plr.Name ~= LP.Name and alive(plr) then
            local char = plr.Character
            if char and char ~= myChar and not (myChar and char:IsDescendantOf(myChar)) then
                local skip = teamCheck and plr.Team ~= nil and LP.Team ~= nil and plr.Team == LP.Team
                if not skip then
                    local part = getPart(plr, partName)
                    if part and part.Parent ~= myChar then
                        local sp, on = cam():WorldToViewportPoint(part.Position)
                        if on and sp.Z > 0 then
                            local d = (mpos - Vector2.new(sp.X, sp.Y)).Magnitude
                            if d <= fov and d < bestDist and (not visCheck or visible(part)) then
                                best, bestDist = plr, d
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function toolEquipped()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Tool")
end

--=====================================================================
-- ADONIS SHIELD
--=====================================================================
-- Adonis verifies hooked metamethods by calling its own detector functions.
-- We find those tables in the GC and zombify the detectors so they always
-- report "clean". Game metamethods stay protected so the engine keeps working.
local Shield = { zombied = {}, cands = {}, lastFull = 0, count = 0, armed = false, on = true }

local DETECT = {
    namecallInstance = true, indexInstance = true, newindexInstance = true,
    namecallEnum = true, indexEnum = true, newindexEnum = true,
    eqEnum = true, checkStack = true, isMethamethodValid = true,
    getgcInstance = true, fireServerInstance = true, invokeServerInstance = true,
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
            if type(k) == "string" and DETECT[k] then table.insert(names, k) end
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
            if type(k) == "string" and DETECT[k] then
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
Library.Theme = {
    WindowBg = Color3.fromRGB(10, 10, 12),
    WindowBorder = Color3.fromRGB(0, 0, 0),
    WindowStroke = Color3.fromRGB(32, 32, 38),
    WindowGlow = Color3.fromRGB(255, 255, 255),

    SidebarBg = Color3.fromRGB(8, 8, 10),
    SidebarBorder = Color3.fromRGB(22, 22, 26),

    TitlebarBg = Color3.fromRGB(8, 8, 10),
    TitlebarText = Color3.fromRGB(245, 245, 250),

    NavbarBg = Color3.fromRGB(8, 8, 10),
    TabActiveBg = Color3.fromRGB(20, 20, 24),
    TabActiveBorder = Color3.fromRGB(48, 48, 56),
    TabInactiveText = Color3.fromRGB(130, 130, 142),
    TabActiveText = Color3.fromRGB(255, 255, 255),
    TabHoverBg = Color3.fromRGB(14, 14, 18),

    Accent = Color3.fromRGB(235, 235, 240),
    AccentGlow = Color3.fromRGB(255, 255, 255),
    AccentDim = Color3.fromRGB(165, 165, 175),
    AccentSecondary = Color3.fromRGB(185, 185, 195),

    GroupboxBg = Color3.fromRGB(13, 13, 16),
    GroupboxBorder = Color3.fromRGB(26, 26, 32),
    GroupboxTitle = Color3.fromRGB(235, 235, 240),

    LabelText = Color3.fromRGB(200, 200, 208),
    MutedText = Color3.fromRGB(120, 120, 132),
    WarnText = Color3.fromRGB(255, 95, 95),

    InputBg = Color3.fromRGB(8, 8, 10),
    InputBorder = Color3.fromRGB(30, 30, 36),

    SliderTrack = Color3.fromRGB(16, 16, 20),
    SliderFill = Color3.fromRGB(235, 235, 240),
    SliderText = Color3.fromRGB(250, 250, 255),

    FontTitle = Enum.Font.GothamMedium,
    FontTab = Enum.Font.GothamMedium,
    FontBody = Enum.Font.RobotoMono,
}

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

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
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
    titleLabel.Size = UDim2.new(1, -36, 1, 0)
    titleLabel.Position = UDim2.new(0, 28, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Library.Theme.FontTitle
    titleLabel.TextSize = 15
    titleLabel.TextColor3 = Library.Theme.TitlebarText
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = "snow.cc"
    titleLabel.Parent = titleBar

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
    userAvatar.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    pcall(function()
        if LocalPlayer then
            local thumb, ready = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if thumb and ready then
                userAvatar.Image = ready
            else
                userAvatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", LocalPlayer.UserId)
            end
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
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
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

    UserInputService.InputBegan:Connect(function(input, gpe)
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

    local Window = {
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
                -- Offset the scrolling pane below the fixed top navbar
                tabContent.Position = UDim2.new(0, 0, 0, 36)
                tabContent.Size = UDim2.new(1, 0, 1, -36)
            end

            local subIdx = #subtabs + 1

            local subBtn = Instance.new("TextButton")
            subBtn.Name = string.format("SubTab_%02d_%s", subIdx, subName)
            subBtn.Size = UDim2.new(0, 0, 1, 0)
            subBtn.AutomaticSize = Enum.AutomaticSize.X
            subBtn.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
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

            local sCorner = Instance.new("UICorner")
            sCorner.CornerRadius = UDim.new(0, 4)
            sCorner.Parent = subBtn

            local sStroke = Instance.new("UIStroke")
            sStroke.Color = Color3.fromRGB(32, 32, 38)
            sStroke.Thickness = 1
            sStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            sStroke.Parent = subBtn

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

            local function setSubActive(active)
                if active then
                    subCols.Visible = true
                    TweenService:Create(subBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(24, 24, 30),
                        TextColor3 = Color3.fromRGB(255, 255, 255)
                    }):Play()
                    TweenService:Create(sStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Color = Library.Theme.Accent
                    }):Play()
                else
                    subCols.Visible = false
                    TweenService:Create(subBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        BackgroundColor3 = Color3.fromRGB(13, 13, 16),
                        TextColor3 = Library.Theme.TabInactiveText
                    }):Play()
                    TweenService:Create(sStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                        Color = Color3.fromRGB(30, 30, 36)
                    }):Play()
                end
            end

            subBtn.MouseButton1Click:Connect(function()
                for _, s in ipairs(subtabs) do
                    s.SetActive(s == subObj)
                end
                currentSubtab = subObj
            end)

            subBtn.MouseEnter:Connect(function()
                if currentSubtab ~= subObj then
                    TweenService:Create(sStroke, TweenInfo.new(0.12), { Color = Color3.fromRGB(56, 56, 68) }):Play()
                    TweenService:Create(subBtn, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(210, 210, 220) }):Play()
                end
            end)

            subBtn.MouseLeave:Connect(function()
                if currentSubtab ~= subObj then
                    TweenService:Create(sStroke, TweenInfo.new(0.12), { Color = Color3.fromRGB(30, 30, 36) }):Play()
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
            groupTitle.Font = Enum.Font.RobotoMono
            groupTitle.TextSize = 12
            groupTitle.TextColor3 = Library.Theme.GroupboxTitle
            groupTitle.TextXAlignment = Enum.TextXAlignment.Left
            groupTitle.Text = groupTitleText
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
                boxStroke.Color = Library.Theme.InputBorder
                boxStroke.Thickness = 1
                boxStroke.Parent = box

                local textBtn = Instance.new("TextButton")
                textBtn.Name = "LabelBtn"
                textBtn.Size = UDim2.new(1, -55, 1, 0)
                textBtn.Position = UDim2.new(0, 22, 0, 0)
                textBtn.BackgroundTransparency = 1
                textBtn.Font = Enum.Font.RobotoMono
                textBtn.TextSize = 11
                textBtn.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                textBtn.TextXAlignment = Enum.TextXAlignment.Left
                textBtn.Text = label
                textBtn.Parent = row

                if keybind ~= nil or onKeyChanged ~= nil then
                    local currentKey = keybind
                    local listening = false
                    local listenStartTime = 0

                    local keybindBtn = Instance.new("TextButton")
                    keybindBtn.Name = "Keybind"
                    keybindBtn.Size = UDim2.new(0, 42, 0, 16)
                    keybindBtn.Position = UDim2.new(1, -42, 0.5, -8)
                    keybindBtn.BackgroundColor3 = Library.Theme.InputBg
                    keybindBtn.BorderSizePixel = 0
                    keybindBtn.Font = Enum.Font.RobotoMono
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

                    UserInputService.InputBegan:Connect(function(input, gpe)
                        if listening then
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
                            end
                            return
                        end

                        -- Trigger toggle when keybind is pressed in-game
                        if not gpe and currentKey ~= nil and UserInputService:GetFocusedTextBox() == nil then
                            local matched = false
                            if typeof(currentKey) == "EnumItem" then
                                if currentKey.EnumType == Enum.KeyCode and input.KeyCode == currentKey then
                                    matched = true
                                elseif currentKey.EnumType == Enum.UserInputType and input.UserInputType == currentKey then
                                    matched = true
                                end
                            end
                            if matched then
                                toggleState()
                            end
                        end
                    end)
                end

                local function toggleState()
                    state = not state
                    box.BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.InputBg
                    textBtn.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                    if callback then pcall(callback, state) end
                end

                box.MouseButton1Click:Connect(toggleState)
                textBtn.MouseButton1Click:Connect(toggleState)

                return {
                    SetValue = function(newVal)
                        state = newVal
                        box.BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.InputBg
                        textBtn.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                        if callback then pcall(callback, state) end
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
                labelText.Font = Enum.Font.RobotoMono
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
                keyBtn.Font = Enum.Font.RobotoMono
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

                UserInputService.InputBegan:Connect(function(input, gpe)
                    if listening then
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
                        return
                    end

                    if not gpe and currentKey ~= nil and UserInputService:GetFocusedTextBox() == nil then
                        local matched = false
                        if typeof(currentKey) == "EnumItem" then
                            if currentKey.EnumType == Enum.KeyCode and input.KeyCode == currentKey then
                                matched = true
                            elseif currentKey.EnumType == Enum.UserInputType and input.UserInputType == currentKey then
                                matched = true
                            end
                        end
                        if matched and callback then
                            pcall(callback, currentKey)
                        end
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
                fill.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
                fill.BorderSizePixel = 0
                fill.ClipsDescendants = false
                fill.Parent = track

                local fCorner = Instance.new("UICorner")
                fCorner.CornerRadius = UDim.new(1, 0)
                fCorner.Parent = fill

                local fGrad = Instance.new("UIGradient")
                fGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 180, 195)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
                })
                fGrad.Parent = fill

                -- Right-edge vertical accent bar for subtle high-contrast terminus
                local fillCap = Instance.new("Frame")
                fillCap.Name = "Cap"
                fillCap.Size = UDim2.new(0, 2, 1, 2)
                fillCap.AnchorPoint = Vector2.new(1, 0.5)
                fillCap.Position = UDim2.new(1, 0, 0.5, 0)
                fillCap.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
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

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if sliding then
                            sliding = false
                            TweenService:Create(trackStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(32, 32, 38) }):Play()
                            TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(18, 18, 22) }):Play()
                            TweenService:Create(valueBox, TweenInfo.new(0.15), { TextColor3 = Library.Theme.Accent }):Play()
                        end
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
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
                UserInputService.InputBegan:Connect(function(input)
                    if isOpen and input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mPos = UserInputService:GetMouseLocation()
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

                UserInputService.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                        if draggingSV then
                            updateSV(input)
                        elseif draggingHue then
                            updateHue(input)
                        end
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
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

                UserInputService.InputBegan:Connect(function(input)
                    if isOpen and not draggingSV and not draggingHue and input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mPos = UserInputService:GetMouseLocation()
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
                lbl.Font = Enum.Font.RobotoMono
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
                btn.Font = Enum.Font.RobotoMono
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
-- FOV CIRCLES
--=====================================================================
local aimCircle = Drawing.new("Circle")
aimCircle.Thickness = 1
aimCircle.NumSides = 48
aimCircle.Transparency = 1
aimCircle.Visible = false

local silentCircle = Drawing.new("Circle")
silentCircle.Thickness = 1
silentCircle.NumSides = 48
silentCircle.Transparency = 1
silentCircle.Visible = false

local aimSnapline = Drawing.new("Line")
aimSnapline.Thickness = 1
aimSnapline.Visible = false

local silentSnapline = Drawing.new("Line")
silentSnapline.Thickness = 1
silentSnapline.Visible = false

--=====================================================================
-- GUN LOCKS
--=====================================================================
local LOCK_KEYS = { "Ammo", "MaxAmmo", "ShootingCooldown", "Damage", "Range" }
local gunLocks = {}

local origMax = setmetatable({}, { __mode = "k" })

-- Ammo is only ever refilled up to the gun's REAL MaxAmmo; values above it desync from the server and make it drop shots
local function desiredValues(tool)
    local ammo
    if state.infiniteAmmo and tool then
        if not origMax[tool] then
            local m = tool:FindFirstChild("MaxAmmo")
            origMax[tool] = m and m.Value or nil
        end
        ammo = origMax[tool]
    end
    return {
        Ammo = ammo,
        ShootingCooldown = state.rapidFire and state.fireCooldown or nil,
        Damage = state.damageOverride and state.damageValue or nil,
        Range = state.rangeOverride and state.rangeValue or nil,
    }
end

local function pushLocks(tool)
    if not tool or state.unloaded then return end
    local want = desiredValues(tool)
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
    if not tool or gunLocks[tool] then return end
    local list = {}
    for _, name in ipairs(LOCK_KEYS) do
        local v = tool:FindFirstChild(name)
        if v and v:IsA("ValueBase") then
            local c = v:GetPropertyChangedSignal("Value"):Connect(function()
                local want = desiredValues(tool)[name]
                if want and v.Value ~= want then
                    pcall(function() v.Value = want end)
                end
            end)
            table.insert(list, c)
        end
    end
    gunLocks[tool] = list
    pushLocks(tool)
end

local function detachLocks(tool)
    local list = gunLocks[tool]
    if list then
        for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
        gunLocks[tool] = nil
    end
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

local originals = {}
local shotCount = 0
local lastReport = 0

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
    if typeof(origin) ~= "Vector3" then
        if tool then
            local p = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
            if p then origin = p.Position end
        end
    end
    if typeof(origin) ~= "Vector3" then origin = cam().CFrame.Position end

    local dir = pos - origin
    local dist = dir.Magnitude
    if dist < 0.01 then
        dir = Vector3.new(0, 0, -1)
        dist = 1
    else
        dir = dir.Unit
    end

    params.AimPosition = pos
    params.Normal = -dir
    params.HitPosition = pos
    params.HitNormal = -dir
    params.HitInstance = part
    params.Hit = part
    params.Target = part

    -- Keep original weapon origin clean so Zee Hood server distance check passes
    if state.wallbangMode == "Hard" then
        local back = origin - pos
        if back.Magnitude > 0.01 then
            params.ForcedOrigin = pos + back.Unit * 1.5
        end
    elseif params.Origin ~= nil then
        params.ForcedOrigin = params.Origin
    end

    local pre = params.Precomputed
    if typeof(pre) == "CFrame" then
        params.Precomputed = CFrame.lookAt(origin, pos)
    elseif typeof(pre) == "Vector3" then
        params.Precomputed = pos
    elseif type(pre) == "table" then
        patchDeep(pre, part, dir, pos, 0)
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
        shotCount, table.concat(keys, ","), res.n, table.concat(rets, ",")))
end

local function split(a, b)
    if a == GunHandler then return GunHandler, b end
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

local function forcedTrace(part, origin)
    origin = typeof(origin) == "Vector3" and origin or cam().CFrame.Position
    local dir = part.Position - origin
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { part.Parent }
    local hit = workspace:Raycast(origin, dir, rp)
    if hit then return hit.Position, hit.Instance, hit.Normal end
    return part.Position, part, -dir.Unit
end

local silPart, silPos, silAt = nil, nil, 0

local function liveSilentPart()
    if not state.silent then return nil end
    if silPart and silPos and os.clock() - silAt < 0.04 then
        if silPart.Parent and silPart.Parent.Parent then
            return silPart, silPos
        end
        silPart, silPos = nil, nil
    end
    local originPoint = cursorPoint()
    if state.silentCircleY and state.silentCircleY ~= 0 then
        originPoint = Vector2.new(originPoint.X, originPoint.Y + state.silentCircleY)
    end
    local target = findTarget(state.silentPart, state.silentFov, state.silentTeamCheck, ignoreVis(), originPoint)
    if not target then silPart, silPos = nil, nil; return nil end
    if math.random(1, 100) > state.silentChance then silPart, silPos = nil, nil; return nil end
    local part = getPart(target, state.silentPart)
    if not part then silPart, silPos = nil, nil; return nil end
    local pos = predict(part, 1, "silent")
    silPart, silPos, silAt = part, pos, os.clock()
    return part, pos
end

local function install(name, wrapper)
    local fn = GunHandler[name]
    if type(fn) ~= "function" then return false end
    if SAFE then
        originals[name] = fn
        GunHandler[name] = function(...) return wrapper(fn, ...) end
        return true
    end
    local orig = nil
    local hookOk = pcall(function()
        local res = hookfunction(fn, function(...)
            local targetFn = orig or originals[name] or fn
            return wrapper(targetFn, ...)
        end)
        if type(res) == "function" then
            orig = res
        end
    end)
    if not hookOk or type(orig) ~= "function" then
        originals[name] = fn
        GunHandler[name] = function(...) return wrapper(fn, ...) end
        return true
    end
    originals[name] = orig
    return true
end

local shootWrapper = function(orig, a, b, ...)
    local self, params = split(a, b)
    local part, pos = nil, nil
    local cachedPos, cachedDir

    if not state.unloaded and state.silent then part, pos = liveSilentPart() end
    if part and type(params) == "table" then
        local ok, p, d = pcall(fillParams, params, part, pos)
        if ok then cachedPos, cachedDir = p, d end
    end
    if not state.unloaded and state.infiniteAmmo then pushLocks(toolEquipped()) end

    local res = table.pack(callOrig(orig, self, params, ...))

    if part and cachedPos and cachedDir then
        for i = 1, res.n do
            local v = res[i]
            local tv = typeof(v)
            if tv == "Vector3" then
                res[i] = cachedPos
            elseif tv == "Instance" then
                res[i] = part
            elseif type(v) == "table" then
                pcall(patchDeep, v, part, cachedDir, cachedPos, 0)
            end
        end
        if res.n >= 2 and typeof(res[2]) ~= "Instance" then
            res[2] = part
        end
    end

    shotCount = shotCount + 1
    if shotCount <= 10 or os.clock() - lastReport > 3 then
        lastReport = os.clock()
        pcall(report, params, res)
    end

    if not state.unloaded and state.infiniteAmmo then pushLocks(toolEquipped()) end
    return table.unpack(res, 1, res.n)
end

local getAimWrapper = function(orig, a, b, ...)
    local self, first = split(a, b)
    local res = callOrig(orig, self, first, ...)

    if not state.unloaded and state.silent then
        local part, pos = liveSilentPart()
        if part then
            local rt = typeof(res)
            if rt == "CFrame" then return CFrame.lookAt(cam().CFrame.Position, pos) end
            if rt == "Vector3" then
                    -- GetAim returns a unit DIRECTION from the muzzle (game does muzzle + dir * range)
                    local o = typeof(first) == "Vector3" and first or cam().CFrame.Position
                    local d = pos - o
                    if d.Magnitude > 0.01 then return d.Unit end
                    return res
                end
            if rt == "table" then
                pcall(function()
                    res.Position = pos
                    res.AimPosition = pos
                    res.Hit = part
                end)
                return res
            end
        end
    end
    return res
end

local traceWrapper = function(orig, a, b, ...)
    local self, first = split(a, b)
    if not state.unloaded and state.wallbangMode == "Hard" then
        local part = liveSilentPart()
        if part then
            local o = typeof(first) == "table" and first.ForcedOrigin or nil
            return forcedTrace(part, o)
        end
    end
    return callOrig(orig, self, first, ...)
end

local canShootWrapper = function(orig, ...)
    if not state.unloaded and state.rapidFire then return true end
    return orig(...)
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
    print("[snow] hooks | Shoot:", okShoot and "yes" or "no", "| method:", SAFE and "table" or "hookfunction")
    return okShoot
end

local function clearAll()
    if GunHandler then
        for name, orig in pairs(originals) do
            if type(orig) == "function" then
                pcall(function()
                    if restorefunction and not SAFE then restorefunction(orig) end
                end)
                pcall(function() GunHandler[name] = orig end)
            end
        end
    end
    originals = {}
end

--=====================================================================
-- NAMECALL RAY REDIRECT
--=====================================================================
local mt = getrawmetatable and getrawmetatable(game)
local origNamecall = mt and mt.__namecall
local namecallOn = false

local RAY_METHODS = {
    Raycast = true,
    FindPartOnRay = true,
    FindPartOnRayWithIgnoreList = true,
    FindPartOnRayWithIgnoreLists = true,
    FindPartOnRayWithWhitelist = true,
}

local function redirectRay(a)
    local origin, dir
    if typeof(a[1]) == "Ray" then
        origin, dir = a[1].Origin, a[1].Direction
    elseif typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3" then
        origin, dir = a[1], a[2]
    else
        return nil
    end
    if not origin or not dir then return nil end
    if InVisRay then return nil end

    local camPos = cam().CFrame.Position
    local hrp = getRoot()
    local nearCam = (origin - camPos).Magnitude < 24
    local nearBody = hrp and (hrp.Position - origin).Magnitude < 24
    if not (nearCam or nearBody) then return nil end

    local part, pos = liveSilentPart()
    if not part or not pos then return nil end

    local nd = pos - origin
    if nd.Magnitude < 0.001 then return nil end

    local mag = math.max(dir.Magnitude, nd.Magnitude + 50)
    if state.wallbangMode == "Hard" then
        mag = math.max(mag, nd.Magnitude + 2000)
    end
    return nd.Unit * mag
end

local function installNamecall()
    if namecallOn or not hookmetamethod or type(origNamecall) ~= "function" then return end
    local ok = pcall(hookmetamethod, game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if RAY_METHODS[m] then
            local a = table.pack(...)
            local dir = redirectRay(a)
            if dir then
                local out = {}
                for i = 1, a.n do out[i] = a[i] end
                if typeof(a[1]) == "Ray" then
                    out[1] = Ray.new(a[1].Origin, dir)
                else
                    out[2] = dir
                end
                local ok2, res = pcall(origNamecall, self, table.unpack(out, 1, a.n))
                if ok2 then return res end
            end
        end
        return origNamecall(self, ...)
    end))
    namecallOn = ok
    print("[snow] namecall hook:", ok and "ok" or "failed")
end

local function uninstallNamecall()
    if namecallOn and origNamecall then
        pcall(hookmetamethod, game, "__namecall", origNamecall)
        namecallOn = false
    end
end

--=====================================================================
-- ESP
--=====================================================================
local espData = {}
local chams = {}
local hasDrawing = Drawing ~= nil

local function colorFor(plr)
    local team = plr.Team ~= nil and LP.Team ~= nil and plr.Team == LP.Team
    return team and state.espTeam or state.espEnemy
end

local function hideESP(t)
    for _, o in pairs(t) do pcall(function() o.Visible = false end) end
end

local function destroyESP(t)
    for _, o in pairs(t) do pcall(function() o:Remove() end) end
end

track(Players.PlayerRemoving:Connect(function(plr)
    local t = espData[plr]
    if t then destroyESP(t); espData[plr] = nil end
    local h = chams[plr]
    if h then pcall(function() h:Destroy() end); chams[plr] = nil end
end))

local function buildESP()
    if not hasDrawing then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not espData[plr] then
            local t = {}
            t.box = Drawing.new("Square"); t.box.Thickness = 1; t.box.Filled = false
            t.name = Drawing.new("Text"); t.name.Size = 13; t.name.Center = true; t.name.Outline = true
            t.hp = Drawing.new("Text"); t.hp.Size = 12; t.hp.Outline = true
            t.hpBg = Drawing.new("Square"); t.hpBg.Filled = true
            t.hpFill = Drawing.new("Square"); t.hpFill.Filled = true
            t.dist = Drawing.new("Text"); t.dist.Size = 12; t.dist.Center = true; t.dist.Outline = true
            t.tool = Drawing.new("Text"); t.tool.Size = 11; t.tool.Center = true; t.tool.Outline = true
            t.tracer = Drawing.new("Line"); t.tracer.Thickness = 1
            espData[plr] = t
        end
    end
end

local function renderESP()
    if not state.esp or state.unloaded then
        for _, t in pairs(espData) do hideESP(t) end
        for plr, h in pairs(chams) do pcall(function() h:Destroy() end); chams[plr] = nil end
        return
    end
    buildESP()

    local camPos = cam().CFrame.Position
    local vp = cam().ViewportSize
    local tracerOrigin = Vector2.new(vp.X / 2, vp.Y)
    if state.espTracerOrigin == "Top" then
        tracerOrigin = Vector2.new(vp.X / 2, 0)
    elseif state.espTracerOrigin == "Middle" then
        tracerOrigin = Vector2.new(vp.X / 2, vp.Y / 2)
    elseif state.espTracerOrigin == "Mouse" then
        tracerOrigin = cursorPoint()
    end

    for plr, t in pairs(espData) do
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
                local h = math.abs(bottom.Y - top.Y)
                local w = h * 0.55
                local x = top.X - w / 2
                local y = top.Y

                t.box.Visible = state.espBox
                t.box.Color = col
                t.box.Position = Vector2.new(x, y)
                t.box.Size = Vector2.new(w, h)

                t.name.Visible = state.espName
                t.name.Text = plr.Name
                t.name.Color = col
                t.name.Position = Vector2.new(top.X, y - 15)

                local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
                local frac = math.clamp(hum.Health / maxHp, 0, 1)
                local barCol = frac > 0.6 and Color3.fromRGB(70, 235, 130)
                    or (frac > 0.3 and Color3.fromRGB(245, 215, 90) or Color3.fromRGB(245, 80, 80))

                t.hpBg.Visible = state.espHealthBar
                t.hpBg.Color = Color3.fromRGB(18, 18, 22)
                t.hpBg.Position = Vector2.new(x - 6, y)
                t.hpBg.Size = Vector2.new(4, h)

                t.hpFill.Visible = state.espHealthBar
                t.hpFill.Color = barCol
                t.hpFill.Position = Vector2.new(x - 6, y + h * (1 - frac))
                t.hpFill.Size = Vector2.new(4, h * frac)

                t.hp.Visible = state.espHealth
                t.hp.Text = tostring(math.floor(hum.Health))
                t.hp.Color = barCol
                t.hp.Position = Vector2.new(x - 26, y + h / 2 - 6)

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
                t.tracer.From = tracerOrigin
                t.tracer.To = Vector2.new(x + w / 2, y + h)
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
                local h = chams[plr]
                if h and h.Parent ~= plr.Character then
                    h:Destroy(); chams[plr] = nil
                end
                if not chams[plr] then
                    local hl = Instance.new("Highlight")
                    hl.Name = "SnowChams"
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.FillColor = colorFor(plr)
                    hl.OutlineColor = colorFor(plr)
                    hl.FillTransparency = 0.5
                    hl.Parent = plr.Character
                    chams[plr] = hl
                else
                    h.FillColor = colorFor(plr)
                    h.OutlineColor = colorFor(plr)
                end
            end
        end
    else
        for plr, h in pairs(chams) do pcall(function() h:Destroy() end); chams[plr] = nil end
    end
end

--=====================================================================
-- CHARACTER / WORLD
--=====================================================================
local flyBV
local savedLighting = {}

local function applyCharacter()
    local char = getChar()
    local hum = getHum()
    local root = getRoot()
    if not char or not hum or not root then return end

    -- Speed
    if state.speed then
        if state.speedMode == "CFrame" then
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                root.CFrame = root.CFrame + moveDir.Unit * (state.speedValue / 50)
            end
        else
            hum.WalkSpeed = state.speedValue
        end
    end

    -- Jump Power / Jump Height
    if state.jump then
        hum.UseJumpPower = true
        hum.JumpPower = state.jumpValue
        pcall(function() hum.JumpHeight = state.jumpValue / 7 end)
    end

    -- Hip Height
    if state.hipHeight then
        pcall(function() hum.HipHeight = state.hipValue end)
    end

    -- Noclip (Sets CanCollide false across entire character)
    if state.noclip then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end

    -- Fly
    if state.fly and not flyBV then
        flyBV = Instance.new("BodyVelocity")
        flyBV.Name = "SnowFly"
        flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = root
    elseif not state.fly and flyBV then
        flyBV:Destroy()
        flyBV = nil
    end

    if flyBV then
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam().CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam().CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam().CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam().CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0, 1, 0) end
        flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * state.flySpeed or Vector3.zero
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
        savedLighting = {}
    end

    if state.noFog then
        if Lighting.FogEnd ~= 1e6 then
            Lighting.FogStart = 0
            Lighting.FogEnd = 1e6
        end
    end
end

--=====================================================================
-- MAIN LOOP
--=====================================================================
local lastAttack = 0
local lastTrigger = 0

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

track(RunService.RenderStepped:Connect(function()
    if state.unloaded then return end

    local mpos = cursorPoint()
    aimCircle.Position = Vector2.new(mpos.X, mpos.Y + state.aimCircleY)
    aimCircle.Radius = state.aimFov
    aimCircle.Color = state.aimColor
    aimCircle.Visible = state.aimCircle and state.aimbot

    silentCircle.Position = Vector2.new(mpos.X, mpos.Y + state.silentCircleY)
    silentCircle.Radius = state.silentFov
    silentCircle.Color = state.silentColor
    silentCircle.Visible = state.silentCircle and state.silent

    -- aimbot
    local aimTarget = nil
    if state.aimbot and mouseFree() then
        aimTarget = findTarget(state.aimPart, state.aimFov, state.aimTeamCheck, state.aimVisible, mpos)
        if aimTarget then
            local part = getPart(aimTarget, state.aimPart)
            if part then
                local pos = predict(part, 1, "aim")
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
    end

    -- aim snapline
    if state.aimSnapline and state.aimbot and aimTarget then
        local part = getPart(aimTarget, state.aimPart)
        if part then
            local sp, on = cam():WorldToViewportPoint(part.Position)
            if on and sp.Z > 0 then
                aimSnapline.Visible = true
                aimSnapline.Color = state.aimSnaplineColor
                aimSnapline.Thickness = state.aimSnaplineWidth
                aimSnapline.From = snaplineFrom(state.aimSnaplineOrigin)
                aimSnapline.To = Vector2.new(sp.X, sp.Y)
            else
                aimSnapline.Visible = false
            end
        else
            aimSnapline.Visible = false
        end
    else
        aimSnapline.Visible = false
    end

    -- silent snapline
    if state.silentSnapline and state.silent then
        local part, pos = liveSilentPart()
        if part and pos then
            local sp, on = cam():WorldToViewportPoint(pos)
            if on and sp.Z > 0 then
                silentSnapline.Visible = true
                silentSnapline.Color = state.silentSnaplineColor
                silentSnapline.Thickness = state.silentSnaplineWidth
                silentSnapline.From = snaplineFrom(state.silentSnaplineOrigin)
                silentSnapline.To = Vector2.new(sp.X, sp.Y)
            else
                silentSnapline.Visible = false
            end
        else
            silentSnapline.Visible = false
        end
    else
        silentSnapline.Visible = false
    end

    -- triggerbot
    if state.trigger and mouseFree() and os.clock() - lastTrigger > state.triggerDelay then
        local t = findTarget(state.triggerPart, state.triggerFov, state.triggerTeamCheck, true, mpos)
        if t then
            lastTrigger = os.clock()
            pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
            task.wait(0.02)
            pcall(function() VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
        end
    end

    -- auto attack
    if state.autoAttack then
        local tool = toolEquipped()
        if tool and os.clock() - lastAttack >= 0.15 then
            lastAttack = os.clock()
            pcall(function() tool:Activate() end)
        end
    end
end))

track(RunService.Heartbeat:Connect(function()
    if state.unloaded then return end
    applyCharacter()
    applyLighting()
    renderESP()

    local tool = toolEquipped()
    if tool then
        attachLocks(tool)
        if state.infiniteAmmo then pushLocks(tool) end
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
    if state.infJump and not state.unloaded then
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
local Window = Library.CreateWindow({
    Title = "snow.cc",
    Game = "Zee Hood",
    Link = "discord.gg/snowcc",
    Size = Vector2.new(700, 600),
    ToggleKey = Enum.KeyCode.RightShift,
})
Library.CurrentWindow = Window

--=====================================================================
-- AIMBOT TAB
--=====================================================================
local AimTab = Window:CreateTab("Aimbot")
local AimGroup = AimTab:CreateGroupbox("Aimbot", "Left")
local aimToggle = AimGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.E, Callback = function(v) state.aimbot = v end })
register("aim.enabled", aimToggle.SetValue, false)
AimGroup:AddDropdown("Aim mode", { "Camera", "Mouse" }, "Camera", function(v) state.aimMode = v end)
AimGroup:AddDropdown("Aim part", { "Head", "Torso", "HumanoidRootPart" }, "Head", function(v) state.aimPart = v end)
local fovS = AimGroup:AddSlider("FOV", 20, 800, 150, "px", function(v) state.aimFov = v end)
register("aim.fov", fovS.SetValue, 150)
local smoothS = AimGroup:AddSlider("Smoothing", 1, 100, 25, "%", function(v) state.aimSmooth = v end)
register("aim.smooth", smoothS.SetValue, 25)
AimGroup:AddToggle("Prediction", true, { Callback = function(v) state.aimPrediction = v end })
AimGroup:AddToggle("Team Check", true, { Callback = function(v) state.aimTeamCheck = v end })
AimGroup:AddToggle("Visible Only", false, { Callback = function(v) state.aimVisible = v end })
AimGroup:AddToggle("FOV Circle", true, { Callback = function(v) state.aimCircle = v end })
AimGroup:AddColorPicker("Circle Colour", Color3.fromRGB(0, 175, 255), function(c) state.aimColor = c end)

local AimVis = AimTab:CreateGroupbox("Aim Snapline", "Right")
AimVis:AddToggle("Show", false, { Callback = function(v) state.aimSnapline = v end })
AimVis:AddDropdown("From", { "Gun", "Mouse", "Bottom" }, "Gun", function(v) state.aimSnaplineOrigin = v end)
local asw = AimVis:AddSlider("Width", 1, 6, 1, "px", function(v) state.aimSnaplineWidth = v end)
register("aim.snapwidth", asw.SetValue, 1)
AimVis:AddColorPicker("Colour", Color3.fromRGB(0, 175, 255), function(c) state.aimSnaplineColor = c end)

local TrigGroup = AimTab:CreateGroupbox("Triggerbot", "Right")
TrigGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.T, Callback = function(v) state.trigger = v end })
TrigGroup:AddDropdown("Hit part", { "Head", "Torso", "HumanoidRootPart" }, "Head", function(v) state.triggerPart = v end)
local trigFovS = TrigGroup:AddSlider("FOV", 20, 800, 150, "px", function(v) state.triggerFov = v end)
register("trigger.fov", trigFovS.SetValue, 150)
TrigGroup:AddToggle("Team Check", true, { Callback = function(v) state.triggerTeamCheck = v end })
local tdS = TrigGroup:AddSlider("Delay", 10, 500, 80, "ms", function(v) state.triggerDelay = v / 1000 end)
register("trigger.delay", tdS.SetValue, 80)

--=====================================================================
-- SILENT TAB
--=====================================================================
local SilentTab = Window:CreateTab("Silent")
local SilentGroup = SilentTab:CreateGroupbox("Silent Aim", "Left")
local silToggle = SilentGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.Q, Callback = function(v) state.silent = v end })
register("silent.enabled", silToggle.SetValue, false)
SilentGroup:AddDropdown("Hit limb", { "HumanoidRootPart", "Head", "Torso", "Adaptive" }, "HumanoidRootPart", function(v) state.silentPart = v end)
SilentGroup:AddToggle("Knock Check", true, { Callback = function(v) state.knockCheck = v end })
SilentGroup:AddToggle("Spread Condenser (Pellet Lock)", true, { Callback = function(v) state.spreadCondenser = v end })
local silFov = SilentGroup:AddSlider("FOV", 20, 800, 300, "px", function(v) state.silentFov = v end)
register("silent.fov", silFov.SetValue, 300)
local silChance = SilentGroup:AddSlider("Hit Chance", 1, 100, 100, "%", function(v) state.silentChance = v end)
register("silent.chance", silChance.SetValue, 100)
SilentGroup:AddToggle("Team Check", true, { Callback = function(v) state.silentTeamCheck = v end })
SilentGroup:AddDropdown("Wallbang", { "Off", "Soft", "Hard" }, "Off", function(v) state.wallbangMode = v end)
SilentGroup:AddToggle("Prediction", true, { Callback = function(v) state.silentPrediction = v end })
local silPredSlider = SilentGroup:AddSlider("Prediction Factor", 0, 200, 100, "%", function(v) state.silentPredictionFactor = v / 100 end)
register("silent.predfactor", silPredSlider.SetValue, 100)
SilentGroup:AddToggle("Show FOV Circle", false, { Callback = function(v) state.silentCircle = v end })
SilentGroup:AddColorPicker("Circle Colour", Color3.fromRGB(0, 200, 255), function(c) state.silentColor = c end)

local SilVis = SilentTab:CreateGroupbox("Silent Snapline", "Right")
SilVis:AddToggle("Show", false, { Callback = function(v) state.silentSnapline = v end })
SilVis:AddDropdown("From", { "Gun", "Mouse", "Bottom" }, "Gun", function(v) state.silentSnaplineOrigin = v end)
local ssw = SilVis:AddSlider("Width", 1, 6, 1, "px", function(v) state.silentSnaplineWidth = v end)
register("silent.snapwidth", ssw.SetValue, 1)
SilVis:AddColorPicker("Colour", Color3.fromRGB(0, 200, 255), function(c) state.silentSnaplineColor = c end)

local GunGroup = SilentTab:CreateGroupbox("Gun Mods", "Right")
GunGroup:AddToggle("Infinite Ammo", false, { Callback = function(v) state.infiniteAmmo = v; pushLocks(toolEquipped()) end })
local maxAmmoSlider = GunGroup:AddSlider("Ammo Value", 30, 9999, 999, "", function(v) state.maxAmmo = v; pushLocks(toolEquipped()) end)
register("gun.maxammo", maxAmmoSlider.SetValue, 999)
GunGroup:AddToggle("Rapid Fire (hold LMB)", false, { Callback = function(v) state.rapidFire = v; pushLocks(toolEquipped()) end })
local cdSlider = GunGroup:AddSlider("Fire Cooldown", 10, 500, 30, "ms", function(v) state.fireCooldown = v / 1000; pushLocks(toolEquipped()) end)
register("gun.cooldown", cdSlider.SetValue, 30)
GunGroup:AddToggle("Damage Override", false, { Callback = function(v) state.damageOverride = v; pushLocks(toolEquipped()) end })
local dmgSlider = GunGroup:AddSlider("Damage", 1, 500, 100, "", function(v) state.damageValue = v; pushLocks(toolEquipped()) end)
register("gun.damage", dmgSlider.SetValue, 100)
GunGroup:AddToggle("Range Override", false, { Callback = function(v) state.rangeOverride = v; pushLocks(toolEquipped()) end })
local rangeSlider = GunGroup:AddSlider("Range", 50, 3000, 500, "", function(v) state.rangeValue = v; pushLocks(toolEquipped()) end)
register("gun.range", rangeSlider.SetValue, 500)
GunGroup:AddToggle("Auto Reload", false, { Callback = function(v) state.autoReload = v end })
GunGroup:AddToggle("Auto Attack", false, { Callback = function(v) state.autoAttack = v end })

--=====================================================================
-- ESP TAB
--=====================================================================
local EspTab = Window:CreateTab("ESP")
local EspGroup = EspTab:CreateGroupbox("Players", "Left")
EspGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.F, Callback = function(v) state.esp = v end })
EspGroup:AddToggle("Box", true, { Callback = function(v) state.espBox = v end })
EspGroup:AddToggle("Name", true, { Callback = function(v) state.espName = v end })
EspGroup:AddToggle("Health Text", true, { Callback = function(v) state.espHealth = v end })
EspGroup:AddToggle("Health Bar", true, { Callback = function(v) state.espHealthBar = v end })
EspGroup:AddToggle("Distance", true, { Callback = function(v) state.espDist = v end })
EspGroup:AddToggle("Equipped Tool", true, { Callback = function(v) state.espTool = v end })
EspGroup:AddToggle("Tracer", false, { Callback = function(v) state.espTracer = v end })
EspGroup:AddDropdown("Tracer Origin", { "Bottom", "Top", "Middle", "Mouse" }, "Bottom", function(v) state.espTracerOrigin = v end)
EspGroup:AddToggle("Chams", false, { Callback = function(v) state.espChams = v end })
local distS = EspGroup:AddSlider("Max Distance", 100, 5000, 1500, "m", function(v) state.espMaxDist = v end)
register("esp.maxdist", distS.SetValue, 1500)
EspGroup:AddColorPicker("Enemy Colour", Color3.fromRGB(255, 60, 60), function(c) state.espEnemy = c end)
EspGroup:AddColorPicker("Team Colour", Color3.fromRGB(60, 255, 120), function(c) state.espTeam = c end)

--=====================================================================
-- CHARACTER TAB
--=====================================================================
local CharTab = Window:CreateTab("Character")
local MoveGroup = CharTab:CreateGroupbox("Movement", "Left")
MoveGroup:AddToggle("Speed", false, { Keybind = Enum.KeyCode.Z, Callback = function(v) state.speed = v end })
MoveGroup:AddDropdown("Speed Mode", { "CFrame", "WalkSpeed" }, "CFrame", function(v) state.speedMode = v end)
local spdS = MoveGroup:AddSlider("Speed Value", 16, 300, 24, "", function(v) state.speedValue = v end)
register("char.speed", spdS.SetValue, 24)
MoveGroup:AddToggle("Jump Power", false, { Callback = function(v) state.jump = v end })
local jmpS = MoveGroup:AddSlider("Jump Value", 50, 400, 55, "", function(v) state.jumpValue = v end)
register("char.jump", jmpS.SetValue, 55)
MoveGroup:AddToggle("Hip Height", false, { Callback = function(v) state.hipHeight = v end })
local hipS = MoveGroup:AddSlider("Hip Value", 0, 20, 2, "", function(v) state.hipValue = v end)
register("char.hip", hipS.SetValue, 2)
MoveGroup:AddToggle("Fly", false, { Keybind = Enum.KeyCode.G, Callback = function(v) state.fly = v end })
local flyS = MoveGroup:AddSlider("Fly Speed", 10, 300, 60, "", function(v) state.flySpeed = v end)
register("char.flyspeed", flyS.SetValue, 60)
MoveGroup:AddToggle("Noclip", false, { Callback = function(v) state.noclip = v end })
MoveGroup:AddToggle("Infinite Jump", false, { Callback = function(v) state.infJump = v end })

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

--=====================================================================
-- WORLD TAB
--=====================================================================
local WorldTab = Window:CreateTab("World")
local WorldGroup = WorldTab:CreateGroupbox("Lighting", "Left")
WorldGroup:AddToggle("Fullbright", false, { Callback = function(v) state.fullbright = v end })
WorldGroup:AddToggle("No Fog", false, { Callback = function(v) state.noFog = v end })

--=====================================================================
-- SETTINGS TAB
--=====================================================================
local SetTab = Window:CreateTab("Settings")
local CfgGroup = SetTab:CreateGroupbox("Config", "Left")

local function saveConfig()
    local data = {}
    for k, v in pairs(flags) do
        local val = setters[k]
        if val then data[k] = flags[k] end
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
        local setter = setters[k]
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
AcGroup:AddButton("Dump GunHandler", function()
    if not GunHandler then print("[snow] GunHandler missing") return end
    local keys = {}
    for k, v in pairs(GunHandler) do table.insert(keys, tostring(k) .. "=" .. typeof(v)) end
    print("[snow] GunHandler: " .. table.concat(keys, ", "))
end)

local AboutGroup = SetTab:CreateGroupbox("About", "Right")
AboutGroup:AddButton("snow.cc | Zee Hood build", function() end)
AboutGroup:AddButton("Menu toggle: RightShift", function() end)

--=====================================================================
-- UNLOAD
--=====================================================================
local function Unload()
    state.unloaded = true
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(clearAll)
    pcall(uninstallNamecall)
    pcall(restoreShield)
    for _, t in pairs(espData) do destroyESP(t) end
    for _, h in pairs(chams) do pcall(function() h:Destroy() end) end
    pcall(function() aimCircle:Remove() end)
    pcall(function() silentCircle:Remove() end)
    pcall(function() aimSnapline:Remove() end)
    pcall(function() silentSnapline:Remove() end)
    if flyBV then pcall(function() flyBV:Destroy() end) end
    if savedLighting.ambient then
        Lighting.Ambient = savedLighting.ambient
        Lighting.OutdoorAmbient = savedLighting.outdoor
        Lighting.Brightness = savedLighting.brightness
        Lighting.ClockTime = savedLighting.clock
    end
    pcall(function() Window.ScreenGui:Destroy() end)
    if getgenv then getgenv().SnowHoodLoaded = nil end
    print("[snow] unloaded")
end

AboutGroup:AddButton("Unload Script", Unload)
getgenv().SnowHoodLoaded = { Unload = Unload }

--=====================================================================
-- STARTUP
--=====================================================================
task.spawn(function()
    local tries = 0
    while not GunHandler and tries < 40 do
        GunHandler = loadGunHandler()
        if not GunHandler then task.wait(1) end
        tries = tries + 1
    end
    if GunHandler then installAll() else warn("[snow] GunHandler never loaded") end

    -- Zee Hood utilizes ReplicatedStorage.Modules.GunHandler directly.
    -- Namecall Ray hooks are disabled to guarantee complete client stability and prevent crash/desync.
    -- All silent aim, bullet redirect, and pellet condensation are executed inside GunHandler.Shoot.
    pcall(loadConfig)
end)

print("[snow] loaded | GunHandler:", GunHandler and "hooked" or "missing")