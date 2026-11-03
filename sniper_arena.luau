--[[
    snow.cc | Sniper Arena Dedicated Suite
    Full snow.cc UI Framework & Combat Engine
    - 360 Degree Targeting Mode (Bypasses FOV, hits any enemy)
    - Hardware Mouse & Camera Lock-on (Smooth / Snappy)
    - Wallbang Engine (Pierces any geometry)
    - Auto Shoot (Direct Weapon Fire via Combat Controller)
    - Headshot Override
    - Deep Universal Entity Scanner (Single-Instance per character, zero double boxes)
    - Safe AirJump
    - Z-Indexed Dual-Layer ESP (Won't overlap the menu window)
    - Dead Player / Bot ESP Auto-Purge
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local mousemoverel = (getfenv and getfenv().mousemoverel) or (mousemoverel)

-- SECTION 1: EXECUTOR ENVIRONMENT RESOLUTION
-- =========================================================================
local function getGlobal(name)
    local direct = nil
    pcall(function()
        direct = getfenv()[name]
    end)
    if direct ~= nil then return direct end

    if typeof(getgenv) == "function" then
        local ok, genv = pcall(getgenv)
        if ok and typeof(genv) == "table" and genv[name] ~= nil then
            return genv[name]
        end
    end

    if typeof(_G) == "table" and _G[name] ~= nil then
        return _G[name]
    end

    return nil
end

local DrawingLib = getGlobal("Drawing")
local hasDrawing = typeof(DrawingLib) == "table" and typeof(DrawingLib.new) == "function"
local hookmeta = getGlobal("hookmetamethod")
local hookfn = getGlobal("hookfunction")
local newccl = getGlobal("newcclosure") or function(f) return f end
local gethui = getGlobal("gethui")
local mousemoverel = getGlobal("mousemoverel")

local isMenuVisible = true

local function newDrawing(kind)
    if hasDrawing then
        local ok, obj = pcall(DrawingLib.new, kind)
        if ok and obj then return obj end
    end
    return setmetatable({}, { __newindex = function() end, __index = function() return function() end end })
end

-- =========================================================================
-- SECTION 2: AUTO MOUSE UNLOCK (NO ESC REQUIRED)
-- =========================================================================
if typeof(hookmeta) == "function" then
    pcall(function()
        local oldNewIndex
        oldNewIndex = hookmeta(game, "__newindex", newccl(function(self, key, value)
            if isMenuVisible and self == UserInputService and key == "MouseBehavior" then
                return oldNewIndex(self, key, Enum.MouseBehavior.Default)
            end
            return oldNewIndex(self, key, value)
        end))
    end)
end

-- =========================================================================


-- =========================================================================

-- =========================================================================

-- =========================================================================
-- SECTION 3: GLOBAL CONFIGURATION
-- =========================================================================
local Config = {
    -- Legit Mode Settings
    Legit = {
        AimbotEnabled = false,
        Key = Enum.UserInputType.MouseButton2,
        Part = "Head",
        FOV = 90,
        Smoothing = 14,
        Prediction = true,
        PredictionLead = 0.035,
        ShowCircle = true,
        CircleColor = Color3.fromRGB(0, 170, 255),
        Triggerbot = false,
        TriggerDelay = 0.08,
        Humanize = true,
    },
    -- Rage Mode Settings
    Rage = {
        Enabled = false,
        SilentAim = true,
        Ragebot = false,
        AutoShoot = true,
        AutoShootDelay = 0.01,
        Mode360 = true,
        FOV = 800,
        Part = "Head",
        HeadshotAlways = true,
        Wallbang = true,
        TargetBots = true,
        RapidFire = false,
        ShowCircle = false,
        CircleColor = Color3.fromRGB(255, 45, 85),
    },
    -- Visuals & ESP
    Esp = {
        Enabled = true,
        Boxes = true,
        Health = true,
        Names = true,
        Distances = true,
        Tracers = false,
        HeadDots = true,
        Skeletons = true,
        Chams = false,
        TargetBots = true,
        BoxColor = Color3.fromRGB(255, 255, 255),
        TracerColor = Color3.fromRGB(0, 255, 170),
        TextColor = Color3.fromRGB(255, 255, 255),
        HeadDotColor = Color3.fromRGB(255, 50, 50),
        SkeletonColor = Color3.fromRGB(255, 255, 255),
        ChamsColor = Color3.fromRGB(0, 255, 170),
    },
    -- Character & Locomotion
    Character = {
        SpeedHack = false,
        SpeedMultiplier = 2.5,
        AirJump = true,
        JumpPower = 48,
        NoClip = false,
        Fly = false,
        FlySpeed = 25,
        AntiFallDamage = true,
        BunnyHop = false,
    },
    -- Camera & View
    Camera = {
        ThirdPerson = false,
        ThirdPersonDistance = 12,
        ThirdPersonOffset = Vector3.new(2, 2, 0),
        FOVChanger = false,
        CustomFOV = 90,
        NoRecoil = false,
    },
    -- Misc & Environment
    Misc = {
        InstantReload = false,
        NoBobbing = false,
        PreventKill = true,
        HitSound = false,
        Hitmarker = false,
    }
}
-- SECTION 6: UI FRAMEWORK (VERTICAL SIDEBAR MONOCHROME)
-- =========================================================================
local Library = {}
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
    bindHud.AutomaticSize = Enum.AutomaticSize.Y
    bindHud.Size = UDim2.new(0, 170, 0, 0)
    bindHud.Position = UDim2.new(1, -182, 0, 12)
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
                row.Size = UDim2.new(1, 0, 0, 14)
                row.LayoutOrder = i
                row.BackgroundTransparency = 1
                row.Font = Library.Theme.FontBody
                row.TextSize = 11
                row.TextColor3 = Library.Theme.LabelText
                row.TextXAlignment = Enum.TextXAlignment.Left
                row.RichText = true
                local name = typeof(key) == "EnumItem" and key.Name or tostring(key)
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
    RunService.RenderStepped:Connect(function()
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
        subBaseline.AnchorPoint = Vector2.new(0, 1)
        subBaseline.Position = UDim2.new(0, 0, 1, 0)
        subBaseline.Size = UDim2.new(1, 0, 0, 1)
        subBaseline.BackgroundColor3 = Library.Theme.GroupboxBorder
        subBaseline.BorderSizePixel = 0
        subBaseline.ZIndex = 49
        subBaseline.Parent = subtabBar

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

                    UserInputService.InputBegan:Connect(function(input, gpe)
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

                UserInputService.InputBegan:Connect(function(input, gpe)
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

                UserInputService.InputBegan:Connect(function(input, gpe)
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

-- =========================================================================


-- =========================================================================

-- =========================================================================

-- =========================================================================
-- SECTION 4: SNIPER ARENA UNIVERSAL ENTITY SCANNER & COMBAT HOOKS
-- =========================================================================
local WorldManager = nil
pcall(function()
    WorldManager = require(ReplicatedStorage.Remote.EntityService.WorldManager)
end)

-- Unified Root Finder: Deduplicates nested models to ensure EXACTLY 1 entry per character
local targetCache = { [true] = { t = 0, list = {} }, [false] = { t = 0, list = {} } }

local function getPotentialTargets(includeBots)
    includeBots = includeBots and true or false
    local cached = targetCache[includeBots]
    local nowClock = os.clock()
    if nowClock - cached.t < 0.1 then
        return cached.list
    end

    local list = {}
    local seen = {}
    
    local function addCandidate(model, name, playerObj)
        if not model or not model:IsA("Model") then return end
        if model == LocalPlayer.Character then return end
        if not model.Parent then return end
        
        -- Ascend to top-level character model if inside a sub-model
        local top = model
        while top.Parent and top.Parent:IsA("Model") and top.Parent ~= Workspace do
            top = top.Parent
        end
        
        if seen[top] then return end
        
        local parentName = top.Parent.Name:lower()
        if parentName:find("dead") or parentName:find("corpse") or parentName:find("ragdoll") or parentName:find("cache") then
            return
        end
        
        local hum = top:FindFirstChildOfClass("Humanoid")
        local root = top:FindFirstChild("HumanoidRootPart") or top:FindFirstChild("Head") or top:FindFirstChild("Torso") or top:FindFirstChild("UpperTorso")
        
        if hum and root and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
            seen[top] = true
            table.insert(list, {
                Model = top,
                Name = name or top.Name,
                Player = playerObj,
                Humanoid = hum,
                Root = root
            })
        end
    end
    
    -- 1. Real Players
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local isTeammate = (p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team)
            if not isTeammate then
                addCandidate(p.Character, p.DisplayName or p.Name, p)
            end
        end
    end
    
    -- 2. Bots via WorldManager Focused Entities
    if includeBots then
        if WorldManager and WorldManager.GetFocusedEntities then
            pcall(function()
                local entities = WorldManager:GetFocusedEntities()
                if entities then
                    for _, entity in pairs(entities) do
                        local inst = entity.Instance or entity.Character or entity.Model
                        if inst and inst:IsA("Model") then
                            addCandidate(inst, inst.Name, nil)
                        end
                    end
                end
            end)
        end
        
        -- 3. Workspace Search
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Model") and not Players:GetPlayerFromCharacter(child) then
                if child:FindFirstChildOfClass("Humanoid") then
                    addCandidate(child, child.Name, nil)
                end
            end
        end
        
        local worldFolder = Workspace:FindFirstChild("World") or Workspace:FindFirstChild("Room")
        if worldFolder then
            for _, child in ipairs(worldFolder:GetChildren()) do
                if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
                    addCandidate(child, child.Name, nil)
                end
            end
        end
    end
    
    cached.t = nowClock
    cached.list = list
    return list
end

local function getClosestTarget(mode360, maxFov, targetPart)
    local best = nil
    local bestDist = mode360 and math.huge or maxFov
    local mousePos = UserInputService:GetMouseLocation()
    
    for _, t in ipairs(getPotentialTargets(Config.Rage.TargetBots)) do
        local model = t.Model
        local hum = t.Humanoid
        local bone = model:FindFirstChild(targetPart) or model:FindFirstChild("Head") or t.Root
        
        if hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead and bone then
            local sp, onScreen = Camera:WorldToViewportPoint(bone.Position)
            if mode360 or onScreen then
                local dist = 0
                if mode360 then
                    dist = (bone.Position - Camera.CFrame.Position).Magnitude
                else
                    dist = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                end
                
                if dist < bestDist then
                    bestDist = dist
                    best = {
                        Model = model,
                        Bone = bone,
                        WorldPos = bone.Position,
                        ScreenPos = Vector2.new(sp.X, sp.Y),
                        Name = t.Name,
                        Humanoid = hum,
                        Root = t.Root,
                        Player = t.Player,
                        Distance = (bone.Position - Camera.CFrame.Position).Magnitude
                    }
                end
            end
        end
    end
    return best
end

-- Hook Combat Service for Silent Aim & Wallbang (Dual Path for Players + Bots)
local CombatServiceRef = nil
pcall(function()
    CombatServiceRef = require(ReplicatedStorage.Remote.CombatService)
    
    local oldInvoke = CombatServiceRef.InvokeAction
    if oldInvoke then
        CombatServiceRef.InvokeAction = function(...)
            local args = {...}
            local weaponHolder = args[1]
            local action = args[2]
            local shotData = args[3]
            
            local isSilentActive = (Config.Rage.Enabled and Config.Rage.SilentAim) or (not Config.Rage.Enabled and false)
            if isSilentActive and action == "Shoot" and type(shotData) == "table" then
                local mode360 = Config.Rage.Enabled and Config.Rage.Mode360
                local maxFov = Config.Rage.Enabled and Config.Rage.FOV or 200
                local part = Config.Rage.Enabled and Config.Rage.Part or "Head"

                local target = getClosestTarget(mode360, maxFov, part)
                if target then
                    local startPos = shotData.Start or Camera.CFrame.Position
                    shotData.Direction = (target.WorldPos - startPos).Unit
                    shotData.Spread = 0
                    
                    -- Submit Player if real player, or Model if bot
                    shotData.Target = target.Player or target.Model
                    
                    -- Calculate local offset in target's root coordinate space
                    local rootPart = target.Model:FindFirstChild("HumanoidRootPart") or target.Bone
                    shotData.TargetPos = rootPart.CFrame:PointToObjectSpace(target.Bone.Position)
                    
                    if Config.Rage.HeadshotAlways then
                        shotData.TargetHeadshot = true
                    end
                    
                    -- Sync Holder._Shootable LastTarget if present so native validation passes
                    if type(weaponHolder) == "table" and type(weaponHolder.Holder) == "table" and type(weaponHolder.Holder._Shootable) == "table" then
                        weaponHolder.Holder._Shootable.LastTargetPos = shotData.TargetPos
                        weaponHolder.Holder._Shootable.LastTarget = target.Model
                    end
                end
            end
            return oldInvoke(table.unpack(args))
        end
    end
    
    local oldSend = CombatServiceRef.SendLocalMessage
    if oldSend then
        CombatServiceRef.SendLocalMessage = function(...)
            local args = {...}
            local msg = args[2]
            local shotData = args[3]
            
            local isSilentActive = (Config.Rage.Enabled and Config.Rage.SilentAim)
            if isSilentActive and msg == "Shooted" and type(shotData) == "table" then
                local mode360 = Config.Rage.Enabled and Config.Rage.Mode360
                local maxFov = Config.Rage.Enabled and Config.Rage.FOV or 200
                local part = Config.Rage.Enabled and Config.Rage.Part or "Head"

                local target = getClosestTarget(mode360, maxFov, part)
                if target then
                    local startPos = shotData.Start or Camera.CFrame.Position
                    shotData.Direction = (target.WorldPos - startPos).Unit
                end
            end
            return oldSend(table.unpack(args))
        end
    end
end)

-- Safe AirJump
UserInputService.JumpRequest:Connect(function()
    if Config.Character.AirJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hum and hrp then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, Config.Character.JumpPower, hrp.AssemblyLinearVelocity.Z)
        end
    end
end)

-- Prevent Height / Suicide Kill (namecall hook; remote methods cannot be overwritten directly)
if typeof(hookmeta) == "function" then
    pcall(function()
        local oldNamecall
        oldNamecall = hookmeta(game, "__namecall", newccl(function(self, ...)
            if Config.Misc.PreventKill and getnamecallmethod() == "FireServer" and typeof(self) == "Instance" and (self.Name == "TouchDead" or self.Name == "Suicide") then
                return
            end
            return oldNamecall(self, ...)
        end))
    end)
end

-- Robust Camera & Mouse Lock-on (Right-Click Hold)
local isAiming = false
local function matchesAimKey(input)
    local key = Config.Legit.Key
    return input.UserInputType == key or input.KeyCode == key
end
UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and matchesAimKey(input) then
        isAiming = true
    end
end)
UserInputService.InputEnded:Connect(function(input, gp)
    if matchesAimKey(input) then
        isAiming = false
    end
end)

-- Native Controller & Hardware Triggerbot Execution
local function executeNativeShot(target)
    local fired = false
    pcall(function()
        if CombatServiceRef and CombatServiceRef.InvokeAction and target then
            CombatServiceRef.InvokeAction(CombatServiceRef, "Shoot", {
                Start = Camera.CFrame.Position,
                Direction = (target.WorldPos - Camera.CFrame.Position).Unit,
                Spread = 0,
                Target = target.Player or target.Model,
                TargetPos = (target.Model:FindFirstChild("HumanoidRootPart") or target.Bone).CFrame:PointToObjectSpace(target.Bone.Position),
                TargetHeadshot = Config.Rage.Enabled and Config.Rage.HeadshotAlways
            })
            fired = true
        end
    end)
    if not fired then
        if mouse1click then
            mouse1click()
        elseif mouse1press and mouse1release then
            mouse1press()
            task.delay(0.016, mouse1release)
        end
    end
end

-- 3rd Person Camera Engine (runs right after the default camera so it is not overwritten)
RunService:BindToRenderStep("snowcc_thirdperson", Enum.RenderPriority.Camera.Value + 1, function()
    if Config.Camera.FOVChanger then
        Camera.FieldOfView = Config.Camera.CustomFOV
    end

    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if not (Config.Camera.ThirdPerson and head) then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.LocalTransparencyModifier > 0 then
            part.LocalTransparencyModifier = 0
        end
    end

    local cf = Camera.CFrame
    local offset = Config.Camera.ThirdPersonOffset
    local origin = head.Position
    local desired = origin - cf.LookVector * Config.Camera.ThirdPersonDistance + cf.RightVector * offset.X + cf.UpVector * offset.Y

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    local hit = Workspace:Raycast(origin, desired - origin, params)
    if hit then
        desired = hit.Position + (origin - desired).Unit * 0.5
    end

    Camera.CFrame = CFrame.new(desired) * cf.Rotation
end)

-- Main RenderStepped Execution Loop (Legit Aimbot, Ragebot, AutoShoot, Locomotion)
local lastAutoShootTick = 0
RunService.RenderStepped:Connect(function()
    local now = tick()

    -- 1. LEGIT AIMBOT
    if not Config.Rage.Enabled and Config.Legit.AimbotEnabled and isAiming and not isMenuVisible then
        local target = getClosestTarget(false, Config.Legit.FOV, Config.Legit.Part)
        if target then
            local aimPos = target.WorldPos
            if Config.Legit.Prediction and target.Model:FindFirstChild("HumanoidRootPart") then
                local vel = target.Model.HumanoidRootPart.AssemblyLinearVelocity
                aimPos = aimPos + (vel * Config.Legit.PredictionLead)
            end
            
            local smooth = math.clamp(Config.Legit.Smoothing, 1, 40)
            local sp, onScreen = Camera:WorldToViewportPoint(aimPos)
            if typeof(mousemoverel) == "function" and onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                mousemoverel((sp.X - mousePos.X) / smooth, (sp.Y - mousePos.Y) / smooth)
            else
                local currentCF = Camera.CFrame
                Camera.CFrame = currentCF:Lerp(CFrame.new(currentCF.Position, aimPos), 1 / smooth)
            end
        end
    end

    -- 2. LEGIT TRIGGERBOT
    if not Config.Rage.Enabled and Config.Legit.Triggerbot and not isMenuVisible then
        if now - lastAutoShootTick >= Config.Legit.TriggerDelay then
            local target = getClosestTarget(false, 35, Config.Legit.Part)
            if target then
                lastAutoShootTick = now
                executeNativeShot(target)
            end
        end
    end

    -- 3. RAGEBOT & RAGE AUTOSHOOT
    if Config.Rage.Enabled and (Config.Rage.Ragebot or Config.Rage.AutoShoot) and not isMenuVisible then
        local delay = math.max(0.005, Config.Rage.AutoShootDelay)
        if now - lastAutoShootTick >= delay then
            local target = getClosestTarget(Config.Rage.Mode360, Config.Rage.FOV, Config.Rage.Part)
            if target then
                lastAutoShootTick = now
                if Config.Rage.Ragebot then
                    -- Snap Camera instantly to target
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.WorldPos)
                end
                executeNativeShot(target)
            end
        end
    end

    -- 4. CHARACTER LOCOMOTION (SPEED & BHOP)
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if hum and hrp then
            if Config.Character.AntiFallDamage then
                local v = hrp.AssemblyLinearVelocity
                if v.Y < -55 then
                    hrp.AssemblyLinearVelocity = Vector3.new(v.X, -40, v.Z)
                end
            end

            -- Speed Hack
            if Config.Character.SpeedHack and hum.MoveDirection.Magnitude > 0.05 then
                local targetVel = hum.MoveDirection * (16 * Config.Character.SpeedMultiplier)
                hrp.AssemblyLinearVelocity = Vector3.new(targetVel.X, hrp.AssemblyLinearVelocity.Y, targetVel.Z)
            end
            
            -- Bunny Hop
            if Config.Character.BunnyHop and hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0.1 then
                hum.Jump = true
            end
        end
    end
end)

-- Drawing FOV Circles
local LegitCircle = newDrawing("Circle")
LegitCircle.Thickness = 1.5
LegitCircle.NumSides = 64
LegitCircle.Radius = Config.Legit.FOV
LegitCircle.Filled = false
LegitCircle.Transparency = 0.7
LegitCircle.Color = Config.Legit.CircleColor
LegitCircle.Visible = false

local RageCircle = newDrawing("Circle")
RageCircle.Thickness = 1.5
RageCircle.NumSides = 64
RageCircle.Radius = Config.Rage.FOV
RageCircle.Filled = false
RageCircle.Transparency = 0.7
RageCircle.Color = Config.Rage.CircleColor
RageCircle.Visible = false

RunService.RenderStepped:Connect(function()
    local mousePos = UserInputService:GetMouseLocation()
    
    if Config.Rage.Enabled then
        LegitCircle.Visible = false
        RageCircle.Position = mousePos
        RageCircle.Radius = Config.Rage.FOV
        RageCircle.Color = Config.Rage.CircleColor
        RageCircle.Visible = Config.Rage.ShowCircle and not Config.Rage.Mode360
    else
        RageCircle.Visible = false
        LegitCircle.Position = mousePos
        LegitCircle.Radius = Config.Legit.FOV
        LegitCircle.Color = Config.Legit.CircleColor
        LegitCircle.Visible = Config.Legit.AimbotEnabled and Config.Legit.ShowCircle
    end
end)

-- Comprehensive Dual-Layer Drawing ESP with Skeleton ESP, HeadDots & Health Bars
local R15_BONES = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"LowerTorso", "HumanoidRootPart"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local R6_BONES = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local ESPMap = {}
RunService.RenderStepped:Connect(function()
    if not Config.Esp.Enabled then
        for _, esp in pairs(ESPMap) do
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Tracer.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            esp.HeadDot.Visible = false
            for _, line in ipairs(esp.Skeleton) do
                line.Visible = false
            end
        end
        return
    end

    local targets = getPotentialTargets(Config.Esp.TargetBots)
    local active = {}

    local menuMinX, menuMinY, menuMaxX, menuMaxY = -1, -1, -1, -1
    if isMenuVisible and Library and Library.CurrentWindow and Library.CurrentWindow.MainFrame then
        local mf = Library.CurrentWindow.MainFrame
        local p = mf.AbsolutePosition
        local s = mf.AbsoluteSize
        menuMinX = p.X
        menuMinY = p.Y
        menuMaxX = p.X + s.X
        menuMaxY = p.Y + s.Y
    end

    for _, t in ipairs(targets) do
        local model = t.Model
        local hum = t.Humanoid
        
        if hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead and model.Parent then
            active[model] = true
            
            local esp = ESPMap[model]
            if not esp then
                local box = newDrawing("Square")
                box.Thickness = 1.5
                box.Filled = false
                box.Color = Config.Esp.BoxColor
                box.Visible = false

                local name = newDrawing("Text")
                name.Size = 13
                name.Center = true
                name.Outline = true
                name.Color = Config.Esp.TextColor
                name.Visible = false

                local tracer = newDrawing("Line")
                tracer.Thickness = 1
                tracer.Color = Config.Esp.TracerColor
                tracer.Transparency = 0.7
                tracer.Visible = false

                local healthOutline = newDrawing("Square")
                healthOutline.Thickness = 1
                healthOutline.Filled = true
                healthOutline.Color = Color3.fromRGB(15, 15, 15)
                healthOutline.Visible = false

                local healthBar = newDrawing("Square")
                healthBar.Thickness = 1
                healthBar.Filled = true
                healthBar.Color = Color3.fromRGB(0, 255, 100)
                healthBar.Visible = false

                local headDot = newDrawing("Circle")
                headDot.Radius = 3.5
                headDot.Filled = true
                headDot.Thickness = 1
                headDot.Color = Config.Esp.HeadDotColor
                headDot.Visible = false

                -- Allocate 15 bone lines for skeleton
                local skeletonLines = {}
                for i = 1, 15 do
                    local l = newDrawing("Line")
                    l.Thickness = 1.5
                    l.Color = Config.Esp.SkeletonColor
                    l.Transparency = 0.85
                    l.Visible = false
                    table.insert(skeletonLines, l)
                end

                esp = { 
                    Box = box, 
                    Name = name, 
                    Tracer = tracer, 
                    HealthBar = healthBar, 
                    HealthBarOutline = healthOutline,
                    HeadDot = headDot,
                    Skeleton = skeletonLines
                }
                ESPMap[model] = esp
            end

            -- Sync live colors
            esp.Box.Color = Config.Esp.BoxColor
            esp.Name.Color = Config.Esp.TextColor
            esp.Tracer.Color = Config.Esp.TracerColor
            esp.HeadDot.Color = Config.Esp.HeadDotColor

            local root = t.Root
            local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            local head = model:FindFirstChild("Head")
            local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or { Y = rootPos.Y - 25 }
            local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

            local isInsideMenu = false
            if isMenuVisible and rootPos.X >= menuMinX and rootPos.X <= menuMaxX and rootPos.Y >= menuMinY and rootPos.Y <= menuMaxY then
                isInsideMenu = true
            end

            if onScreen and not isInsideMenu then
                local height = math.abs(headPos.Y - legPos.Y)
                local width = height * 0.65

                if Config.Esp.Boxes then
                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = Vector2.new(rootPos.X - width / 2, rootPos.Y - height / 2)
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
                end

                if Config.Esp.Names then
                    local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
                    esp.Name.Text = string.format("%s [%dm]", t.Name, dist)
                    esp.Name.Position = Vector2.new(rootPos.X, (rootPos.Y - height / 2) - 16)
                    esp.Name.Visible = true
                else
                    esp.Name.Visible = false
                end

                if Config.Esp.Health then
                    local hpPercent = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
                    local barWidth = 3
                    local barHeight = height * hpPercent
                    local barX = (rootPos.X - width / 2) - 6
                    local barY = (rootPos.Y + height / 2) - barHeight

                    esp.HealthBarOutline.Size = Vector2.new(barWidth + 2, height + 2)
                    esp.HealthBarOutline.Position = Vector2.new(barX - 1, (rootPos.Y - height / 2) - 1)
                    esp.HealthBarOutline.Visible = true

                    esp.HealthBar.Size = Vector2.new(barWidth, barHeight)
                    esp.HealthBar.Position = Vector2.new(barX, barY)
                    esp.HealthBar.Color = Color3.fromHSV(hpPercent * 0.33, 1, 1)
                    esp.HealthBar.Visible = true
                else
                    esp.HealthBar.Visible = false
                    esp.HealthBarOutline.Visible = false
                end

                if Config.Esp.HeadDots and head then
                    local hsp, hOnScreen = Camera:WorldToViewportPoint(head.Position)
                    if hOnScreen then
                        esp.HeadDot.Position = Vector2.new(hsp.X, hsp.Y)
                        esp.HeadDot.Visible = true
                    else
                        esp.HeadDot.Visible = false
                    end
                else
                    esp.HeadDot.Visible = false
                end

                -- Render Skeleton Bones
                if Config.Esp.Skeletons then
                    local isR15 = (model:FindFirstChild("UpperTorso") ~= nil)
                    local bonePairs = isR15 and R15_BONES or R6_BONES
                    for i, line in ipairs(esp.Skeleton) do
                        if i <= #bonePairs then
                            local pair = bonePairs[i]
                            local pA = model:FindFirstChild(pair[1])
                            local pB = model:FindFirstChild(pair[2])
                            if pA and pB then
                                local spA, vA = Camera:WorldToViewportPoint(pA.Position)
                                local spB, vB = Camera:WorldToViewportPoint(pB.Position)
                                if vA and vB then
                                    line.From = Vector2.new(spA.X, spA.Y)
                                    line.To = Vector2.new(spB.X, spB.Y)
                                    line.Color = Config.Esp.SkeletonColor
                                    line.Visible = true
                                else
                                    line.Visible = false
                                end
                            else
                                line.Visible = false
                            end
                        else
                            line.Visible = false
                        end
                    end
                else
                    for _, line in ipairs(esp.Skeleton) do
                        line.Visible = false
                    end
                end

                if Config.Esp.Tracers then
                    esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    esp.Tracer.To = Vector2.new(rootPos.X, rootPos.Y + height / 2)
                    esp.Tracer.Visible = true
                else
                    esp.Tracer.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Tracer.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthBarOutline.Visible = false
                esp.HeadDot.Visible = false
                for _, line in ipairs(esp.Skeleton) do
                    line.Visible = false
                end
            end
        end
    end

    -- Instant Purge
    for model, esp in pairs(ESPMap) do
        if not active[model] then
            esp.Box.Visible = false
            esp.Name.Visible = false
            esp.Tracer.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthBarOutline.Visible = false
            esp.HeadDot.Visible = false
            for _, line in ipairs(esp.Skeleton) do
                line.Visible = false
                pcall(function() line:Remove() end)
            end
            pcall(function()
                esp.Box:Remove()
                esp.Name:Remove()
                esp.Tracer:Remove()
                esp.HealthBar:Remove()
                esp.HealthBarOutline:Remove()
                esp.HeadDot:Remove()
            end)
            ESPMap[model] = nil
        end
    end
end)

-- =========================================================================
-- SECTION 5: snow.cc INTERFACE INITIALIZATION
-- =========================================================================
local Window = Library.CreateWindow({
    Title = "snow.cc",
    Game = "Sniper Arena",
    Link = "discord.gg/snowcc",
    Size = Vector2.new(700, 600),
    ToggleKey = Enum.KeyCode.RightShift,
})
Library.CurrentWindow = Window

-- ==========================================
-- TAB 1: LEGIT
-- ==========================================
local legitTab = Window:CreateTab("Legit")
local subLegitAim = legitTab:CreateSubtab("Aimbot")
local subTrigger = legitTab:CreateSubtab("Triggerbot")

-- Legit Aimbot Groupbox
local gbLegitAim = subLegitAim:CreateGroupbox("Legit Targeting", "Left")
gbLegitAim:AddToggle("Enable Legit Aimbot", Config.Legit.AimbotEnabled, {
    Callback = function(val) Config.Legit.AimbotEnabled = val end,
})
gbLegitAim:AddKeybind("Aim Key", Config.Legit.Key, function(key)
    Config.Legit.Key = key or Enum.UserInputType.MouseButton2
end)
gbLegitAim:AddDropdown("Target Bone", {"Head", "UpperTorso", "HumanoidRootPart"}, "Head", function(val)
    Config.Legit.Part = val
end)
gbLegitAim:AddToggle("Movement Prediction", Config.Legit.Prediction, {
    Callback = function(val) Config.Legit.Prediction = val end,
})
gbLegitAim:AddToggle("Show FOV Circle", Config.Legit.ShowCircle, {
    Callback = function(val) Config.Legit.ShowCircle = val end,
})
gbLegitAim:AddColorPicker("FOV Circle Color", Config.Legit.CircleColor, function(col)
    Config.Legit.CircleColor = col
end)

local gbLegitTuning = subLegitAim:CreateGroupbox("Smoothing & Dynamics", "Right")
gbLegitTuning:AddSlider("Field of View", 20, 350, Config.Legit.FOV, "px", function(val)
    Config.Legit.FOV = val
end)
gbLegitTuning:AddSlider("Smoothing Factor", 3, 40, Config.Legit.Smoothing, "", function(val)
    Config.Legit.Smoothing = val
end)
gbLegitTuning:AddSlider("Prediction Lead", 1, 10, 4, "0ms", function(val)
    Config.Legit.PredictionLead = val / 100
end)

-- Triggerbot Subtab
local gbTrigger = subTrigger:CreateGroupbox("Triggerbot Core", "Left")
gbTrigger:AddToggle("Enable Triggerbot", Config.Legit.Triggerbot, {
    Callback = function(val) Config.Legit.Triggerbot = val end,
})
gbTrigger:AddSlider("Reaction Delay", 1, 30, 8, "0ms", function(val)
    Config.Legit.TriggerDelay = val / 100
end)

-- ==========================================
-- TAB 2: RAGE
-- ==========================================
local rageTab = Window:CreateTab("Rage")
local subRageCore = rageTab:CreateSubtab("Ragebot")
local subRageSilent = rageTab:CreateSubtab("Silent Aim")

-- Ragebot Groupbox
local gbRageCore = subRageCore:CreateGroupbox("Ragebot Master", "Left")
gbRageCore:AddToggle("Master Rage Switch", Config.Rage.Enabled, {
    Callback = function(val) Config.Rage.Enabled = val end,
})
gbRageCore:AddToggle("Camera Snapping (Ragebot)", Config.Rage.Ragebot, {
    Callback = function(val) Config.Rage.Ragebot = val end,
})
gbRageCore:AddToggle("Auto Shoot (Instant Trigger)", Config.Rage.AutoShoot, {
    Callback = function(val) Config.Rage.AutoShoot = val end,
})
gbRageCore:AddToggle("360 Degree Targeting", Config.Rage.Mode360, {
    Callback = function(val) Config.Rage.Mode360 = val end,
})
gbRageCore:AddToggle("Target Bots & NPCs", Config.Rage.TargetBots, {
    Callback = function(val) Config.Rage.TargetBots = val end,
})

local gbRageTuning = subRageCore:CreateGroupbox("Rage Parameters", "Right")
gbRageTuning:AddSlider("Rage FOV", 50, 800, Config.Rage.FOV, "px", function(val)
    Config.Rage.FOV = val
end)
gbRageTuning:AddSlider("Fire Interval Delay", 1, 20, 1, "0ms", function(val)
    Config.Rage.AutoShootDelay = val / 100
end)
gbRageTuning:AddColorPicker("Rage Circle Color", Config.Rage.CircleColor, function(col)
    Config.Rage.CircleColor = col
end)

-- Silent Aim Subtab
local gbRageSilent = subRageSilent:CreateGroupbox("Silent Redirection", "Left")
gbRageSilent:AddToggle("Enable Silent Aim", Config.Rage.SilentAim, {
    Callback = function(val) Config.Rage.SilentAim = val end,
})
gbRageSilent:AddToggle("Always Headshot", Config.Rage.HeadshotAlways, {
    Callback = function(val) Config.Rage.HeadshotAlways = val end,
})
gbRageSilent:AddToggle("Wallbang (Piercing)", Config.Rage.Wallbang, {
    Callback = function(val) Config.Rage.Wallbang = val end,
})
gbRageSilent:AddDropdown("Bone Priority", {"Head", "UpperTorso", "HumanoidRootPart"}, "Head", function(val)
    Config.Rage.Part = val
end)

-- ==========================================
-- TAB 3: VISUALS
-- ==========================================
local visualTab = Window:CreateTab("Visuals")
local subEsp = visualTab:CreateSubtab("ESP")
local subChams = visualTab:CreateSubtab("Chams & Dots")

local gbEsp = subEsp:CreateGroupbox("ESP Overlays", "Left")
gbEsp:AddToggle("Master ESP", Config.Esp.Enabled, {
    Callback = function(val) Config.Esp.Enabled = val end,
})
gbEsp:AddToggle("Boxes", Config.Esp.Boxes, {
    Callback = function(val) Config.Esp.Boxes = val end,
})
gbEsp:AddToggle("Health Bars", Config.Esp.Health, {
    Callback = function(val) Config.Esp.Health = val end,
})
gbEsp:AddToggle("Names & Distance", Config.Esp.Names, {
    Callback = function(val) Config.Esp.Names = val end,
})
gbEsp:AddToggle("Tracers", Config.Esp.Tracers, {
    Callback = function(val) Config.Esp.Tracers = val end,
})
gbEsp:AddToggle("Target Bots & NPCs", Config.Esp.TargetBots, {
    Callback = function(val) Config.Esp.TargetBots = val end,
})

local gbEspColors = subEsp:CreateGroupbox("Color Customization", "Right")
gbEspColors:AddColorPicker("Box Color", Config.Esp.BoxColor, function(col)
    Config.Esp.BoxColor = col
end)
gbEspColors:AddColorPicker("Text Color", Config.Esp.TextColor, function(col)
    Config.Esp.TextColor = col
end)
gbEspColors:AddColorPicker("Tracer Color", Config.Esp.TracerColor, function(col)
    Config.Esp.TracerColor = col
end)

local gbChams = subChams:CreateGroupbox("Indicators & Skeleton", "Left")
gbChams:AddToggle("Skeleton ESP (Bone Rig)", Config.Esp.Skeletons, {
    Callback = function(val) Config.Esp.Skeletons = val end,
})
gbChams:AddColorPicker("Skeleton Color", Config.Esp.SkeletonColor, function(col)
    Config.Esp.SkeletonColor = col
end)
gbChams:AddToggle("Head Target Dot", Config.Esp.HeadDots, {
    Callback = function(val) Config.Esp.HeadDots = val end,
})
gbChams:AddColorPicker("Head Dot Color", Config.Esp.HeadDotColor, function(col)
    Config.Esp.HeadDotColor = col
end)

-- ==========================================
-- TAB 4: CHARACTER
-- ==========================================
local charTab = Window:CreateTab("Character")
local subLocomotion = charTab:CreateSubtab("Locomotion")
local subSurvival = charTab:CreateSubtab("Survival")

local gbLoco = subLocomotion:CreateGroupbox("Movement Physics", "Left")
gbLoco:AddToggle("Speed Hack", Config.Character.SpeedHack, {
    Callback = function(val) Config.Character.SpeedHack = val end,
})
gbLoco:AddSlider("Speed Multiplier", 1, 10, 2.5, "x", function(val)
    Config.Character.SpeedMultiplier = val
end)
gbLoco:AddToggle("Bunny Hop (Auto Jump)", Config.Character.BunnyHop, {
    Callback = function(val) Config.Character.BunnyHop = val end,
})

local gbSurv = subSurvival:CreateGroupbox("Air & Integrity", "Right")
gbSurv:AddToggle("AirJump (Infinite)", Config.Character.AirJump, {
    Callback = function(val) Config.Character.AirJump = val end,
})
gbSurv:AddSlider("AirJump Velocity", 20, 100, Config.Character.JumpPower, " studs", function(val)
    Config.Character.JumpPower = val
end)
gbSurv:AddToggle("Anti Fall Damage", Config.Character.AntiFallDamage, {
    Callback = function(val) Config.Character.AntiFallDamage = val end,
})
gbSurv:AddToggle("Anti-Kill / Suicide Block", Config.Misc.PreventKill, {
    Callback = function(val) Config.Misc.PreventKill = val end,
})

-- ==========================================
-- TAB 5: MISC
-- ==========================================
local miscTab = Window:CreateTab("Misc")
local subCamera = miscTab:CreateSubtab("Camera")
local subEngine = miscTab:CreateSubtab("Presets")

local gbCam = subCamera:CreateGroupbox("3rd Person Camera", "Left")
gbCam:AddToggle("Enable 3rd Person View", Config.Camera.ThirdPerson, {
    Callback = function(val) Config.Camera.ThirdPerson = val end,
})
gbCam:AddSlider("Camera Distance", 5, 30, Config.Camera.ThirdPersonDistance, " studs", function(val)
    Config.Camera.ThirdPersonDistance = val
end)
gbCam:AddToggle("Custom Field of View", Config.Camera.FOVChanger, {
    Callback = function(val) Config.Camera.FOVChanger = val end,
})
gbCam:AddSlider("Field of View", 60, 120, Config.Camera.CustomFOV, " deg", function(val)
    Config.Camera.CustomFOV = val
end)

local gbPresets = subEngine:CreateGroupbox("Quick Config Profiles", "Right")
gbCam:AddToggle("Show Watermark", true, {
    Callback = function(val) Window.Watermark.Visible = val end,
})

gbPresets:AddButton("Load Legit Profile", function()
    Config.Rage.Enabled = false
    Config.Legit.AimbotEnabled = true
    Config.Legit.FOV = 85
    Config.Legit.Smoothing = 18
    Config.Legit.Triggerbot = true
    Config.Legit.ShowCircle = true
    Config.Esp.Boxes = true
    Config.Esp.Health = true
    Config.Esp.Names = true
    Config.Esp.Tracers = false
    Config.Character.SpeedHack = false
    Library.Notify("Legit profile applied")
end)

gbPresets:AddButton("Load Rage Profile", function()
    Config.Rage.Enabled = true
    Config.Rage.Ragebot = true
    Config.Rage.SilentAim = true
    Config.Rage.AutoShoot = true
    Config.Rage.Mode360 = true
    Config.Rage.HeadshotAlways = true
    Config.Rage.Wallbang = true
    Config.Legit.AimbotEnabled = false
    Config.Esp.Boxes = true
    Config.Esp.Health = true
    Config.Esp.Names = true
    Config.Esp.Tracers = true
    Config.Character.SpeedHack = true
    Config.Character.SpeedMultiplier = 3.5
    Library.Notify("Rage profile applied")
end)

Library.Notify("Sniper Arena loaded - RightShift toggles the menu", 4)
print("[snow.cc] Sniper Arena Suite v4.0 (Legit, Rage, 3rd Person, Character & Misc) initialized!")
