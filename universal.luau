--[[ snow.cc | Universal ]]

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
-- UNIVERSAL LOGIC
-- =========================================================================
local Lighting = game:GetService("Lighting")
local Running = true
local Connections = {}
local function connect(sig, fn)
    local c = sig:Connect(fn)
    Connections[#Connections + 1] = c
    return c
end

local F = {
    ESP = false, EspBox = true, EspName = true, EspHealth = true, EspTracer = false, EspTeam = false, EspRange = 1500,
    Fullbright = false, NoFog = false, FOV = 70, FovOn = false,
    SpeedOn = false, Speed = 50, SpeedMode = "CFrame", Jump = false, JumpPower = 50, JumpOn = false,
    InfJump = false, Fly = false, FlySpeed = 70, NoClip = false, Bhop = false,
    Spin = false, SpinSpeed = 30, Fling = false, Orbit = false, OrbitSpeed = 3, OrbitDist = 8,
    Spectate = false, ClickTP = false, AntiAFK = true,
    Skeleton = false, HeadDot = false, Chams = false, ChamFill = 5, WireChams = false, Rainbow = false,
    Hump = false, HumpSpeed = 12, HumpReach = 1.5, Headsit = false, Piggy = false, FollowT = false, FlingT = false,
    Shake = false, LoopTP = false, Crosshair = false, CrossSize = 10, Xray = false, Gravity = 196, GravOn = false,
}
local TargetPlayer = nil

local function getChar() return LocalPlayer.Character end
local function getRoot() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function otherPlayers()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then t[#t + 1] = p end
    end
    return t
end

local function teleportTo(cf)
    local r = getRoot()
    if r then
        r.AssemblyLinearVelocity = Vector3.zero
        r.CFrame = cf
    end
end

-- Lighting
local orig = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}
local function restoreLighting()
    for k, v in pairs(orig) do pcall(function() Lighting[k] = v end) end
end

-- ESP
local EspPool, EspFrame = {}, 0
local function getEsp(p)
    local e = EspPool[p]
    if not e then
        local box = newDrawing("Square") box.Thickness = 1.5 box.Filled = false box.Visible = false
        local text = newDrawing("Text") text.Size = 13 text.Center = true text.Outline = true text.Visible = false
        local bar = newDrawing("Line") bar.Thickness = 2 bar.Visible = false
        local tr = newDrawing("Line") tr.Thickness = 1 tr.Visible = false
        e = { Box = box, Text = text, Bar = bar, Tracer = tr, Seen = 0 }
        EspPool[p] = e
    end
    e.Seen = EspFrame
    return e
end
local function hideEsp(e)
    e.Box.Visible = false e.Text.Visible = false e.Bar.Visible = false e.Tracer.Visible = false
end
local function removeEsp(e)
    for _, k in ipairs({ "Box", "Text", "Bar", "Tracer" }) do pcall(function() e[k]:Remove() end) end
end

local BONES = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" }, { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local BONES6 = {
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}
local SkelLines, HeadDots, Chams = {}, {}, {}
local chamFolder = Instance.new("Folder")
chamFolder.Name = "snowcham"
chamFolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local function hideSkel(p)
    local t = SkelLines[p]
    if t then for _, l in ipairs(t) do l.Visible = false end end
    if HeadDots[p] then HeadDots[p].Visible = false end
end
local function clearPlayerVisuals(p)
    if SkelLines[p] then for _, l in ipairs(SkelLines[p]) do pcall(function() l:Remove() end) end SkelLines[p] = nil end
    if HeadDots[p] then pcall(function() HeadDots[p]:Remove() end) HeadDots[p] = nil end
    if Chams[p] then Chams[p]:Destroy() Chams[p] = nil end
end

local function drawSkeleton(p, ch, col)
    local bones = ch:FindFirstChild("UpperTorso") and BONES or BONES6
    local lines = SkelLines[p]
    if not lines then
        lines = {}
        for i = 1, #BONES do
            local l = newDrawing("Line") l.Thickness = 1.5 l.Visible = false
            lines[i] = l
        end
        SkelLines[p] = lines
    end
    for i, l in ipairs(lines) do
        local b = bones[i]
        local a, c = b and ch:FindFirstChild(b[1]), b and ch:FindFirstChild(b[2])
        if a and c then
            local pa, oa = Camera:WorldToViewportPoint(a.Position)
            local pc, oc = Camera:WorldToViewportPoint(c.Position)
            if oa and oc then
                l.From = Vector2.new(pa.X, pa.Y) l.To = Vector2.new(pc.X, pc.Y) l.Color = col l.Visible = true
            else l.Visible = false end
        else l.Visible = false end
    end
end

local function updateChams(p, ch, col, on)
    local h = Chams[p]
    if not on then
        if h then h.Enabled = false end
        return
    end
    if not h or h.Adornee ~= ch then
        if h then h:Destroy() end
        h = Instance.new("Highlight")
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee = ch
        h.Parent = chamFolder
        Chams[p] = h
    end
    h.Enabled = true
    h.FillColor = col
    h.OutlineColor = F.WireChams and col or Color3.new(1, 1, 1)
    h.FillTransparency = F.WireChams and 1 or (1 - F.ChamFill / 10)
    h.OutlineTransparency = 0
end

local rainbowHue = 0
local crossH, crossV = newDrawing("Line"), newDrawing("Line")
crossH.Thickness = 1.5 crossV.Thickness = 1.5

connect(RunService.RenderStepped, function()
    EspFrame = EspFrame + 1
    rainbowHue = (rainbowHue + 0.004) % 1
    local rb = Color3.fromHSV(rainbowHue, 0.8, 1)
    local vc = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    crossH.Visible = F.Crosshair and not isMenuVisible
    crossV.Visible = crossH.Visible
    if crossH.Visible then
        crossH.From = vc - Vector2.new(F.CrossSize, 0) crossH.To = vc + Vector2.new(F.CrossSize, 0) crossH.Color = rb
        crossV.From = vc - Vector2.new(0, F.CrossSize) crossV.To = vc + Vector2.new(0, F.CrossSize) crossV.Color = rb
    end
    for _, p in ipairs(otherPlayers()) do
        local ch = p.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local ok = ch and hum and hum.Health > 0 and (F.EspTeam or p.Team ~= LocalPlayer.Team or p.Team == nil)
        local col = F.Rainbow and rb or (p.TeamColor and p.TeamColor.Color or Color3.fromRGB(120, 190, 255))
        if ok then
            updateChams(p, ch, col, F.Chams or F.WireChams)
            local head = ch:FindFirstChild("Head")
            if F.Skeleton then drawSkeleton(p, ch, col) else hideSkel(p) end
            if F.HeadDot and head then
                local d = HeadDots[p]
                if not d then d = newDrawing("Circle") d.Thickness = 1.5 d.NumSides = 20 d.Filled = false HeadDots[p] = d end
                local pos, on = Camera:WorldToViewportPoint(head.Position)
                d.Visible = on and not isMenuVisible
                d.Position = Vector2.new(pos.X, pos.Y)
                d.Radius = math.clamp(250 / math.max(pos.Z, 1), 3, 20)
                d.Color = col
            elseif HeadDots[p] then HeadDots[p].Visible = false end
            if isMenuVisible then hideSkel(p) end
        else
            hideSkel(p)
            if Chams[p] then Chams[p].Enabled = false end
        end
    end
    for p in pairs(SkelLines) do if not p.Parent then clearPlayerVisuals(p) end end
    for p in pairs(Chams) do if not p.Parent then clearPlayerVisuals(p) end end
    if F.GravOn then Workspace.Gravity = F.Gravity end
    local myRoot = getRoot()
    if F.ESP and not isMenuVisible then
        for _, p in ipairs(otherPlayers()) do
            local ch = p.Character
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 and (F.EspTeam or p.Team ~= LocalPlayer.Team or p.Team == nil) then
                local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                local e = getEsp(p)
                local pos, on = Camera:WorldToViewportPoint(root.Position)
                if on and dist <= F.EspRange then
                    local top = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
                    local bot = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                    local h = math.max(math.abs(top.Y - bot.Y), 10)
                    local w = h * 0.6
                    local col = p.TeamColor and p.TeamColor.Color or Color3.fromRGB(120, 190, 255)
                    e.Box.Visible = F.EspBox
                    e.Box.Size = Vector2.new(w, h)
                    e.Box.Position = Vector2.new(pos.X - w / 2, pos.Y - h / 2)
                    e.Box.Color = col
                    e.Text.Visible = F.EspName
                    e.Text.Text = string.format("%s [%dm]", p.DisplayName, dist)
                    e.Text.Position = Vector2.new(pos.X, pos.Y - h / 2 - 15)
                    e.Text.Color = Color3.new(1, 1, 1)
                    local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    e.Bar.Visible = F.EspHealth
                    e.Bar.From = Vector2.new(pos.X - w / 2 - 4, pos.Y + h / 2)
                    e.Bar.To = Vector2.new(pos.X - w / 2 - 4, pos.Y + h / 2 - h * frac)
                    e.Bar.Color = Color3.fromRGB(255 * (1 - frac), 255 * frac, 60)
                    e.Tracer.Visible = F.EspTracer
                    e.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    e.Tracer.To = Vector2.new(pos.X, pos.Y + h / 2)
                    e.Tracer.Color = col
                else
                    hideEsp(e)
                end
            end
        end
    end
    for p, e in pairs(EspPool) do
        if e.Seen ~= EspFrame then
            hideEsp(e)
            if not p.Parent then removeEsp(e) EspPool[p] = nil end
        end
    end

    if F.Fullbright then
        Lighting.Brightness = 2 Lighting.ClockTime = 14 Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    end
    if F.NoFog then
        Lighting.FogEnd = 1e6 Lighting.FogStart = 1e6
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a.Density = 0 end
        end
    end
    if F.FovOn then Camera.FieldOfView = F.FOV end
    if F.Spectate and TargetPlayer and TargetPlayer.Character then
        local h = TargetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then Camera.CameraSubject = h end
    end
end)

-- Movement / trolling
local spinAngle, orbitAngle = 0, 0
connect(RunService.Heartbeat, function(dt)
    local root, hum = getRoot(), getHum()
    if not (root and hum) then return end

    if F.Fly then
        local cf = Camera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        root.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * F.FlySpeed or Vector3.new(0, 0.5, 0)
        root.CFrame = root.CFrame + dir * (F.FlySpeed * dt * 0.5)
    elseif F.SpeedOn and not isMenuVisible then
        local move = hum.MoveDirection
        if F.SpeedMode == "CFrame" then
            if move.Magnitude > 0 then root.CFrame = root.CFrame + move * (F.Speed - 16) * dt end
        else
            hum.WalkSpeed = F.Speed
        end
    end
    if F.JumpOn then hum.UseJumpPower = true hum.JumpPower = F.JumpPower end
    if F.Bhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and hum.FloorMaterial ~= Enum.Material.Air then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    if F.Spin then
        spinAngle = spinAngle + F.SpinSpeed * dt
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, spinAngle, 0)
    end
    if F.Fling then
        root.AssemblyAngularVelocity = Vector3.new(0, 9e4, 0)
        root.AssemblyLinearVelocity = Vector3.new(9e4, 9e4, 9e4)
    end
    if F.Orbit and TargetPlayer and TargetPlayer.Character then
        local tr = TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tr then
            orbitAngle = orbitAngle + F.OrbitSpeed * dt
            local off = Vector3.new(math.cos(orbitAngle), 0, math.sin(orbitAngle)) * F.OrbitDist
            root.CFrame = CFrame.lookAt(tr.Position + off, tr.Position)
        end
    end
end)

local humpT, flingT = 0, 0
connect(RunService.Heartbeat, function(dt)
    local root, hum = getRoot(), getHum()
    local tch = TargetPlayer and TargetPlayer.Character
    local tr = tch and tch:FindFirstChild("HumanoidRootPart")
    if not (root and hum and tr) then return end
    if F.Hump then
        humpT = humpT + dt * F.HumpSpeed
        local thrust = (math.sin(humpT) + 1) / 2 * F.HumpReach
        root.CFrame = tr.CFrame * CFrame.new(0, 0, 1.2 + thrust)
        root.AssemblyLinearVelocity = Vector3.zero
    elseif F.Headsit then
        local head = tch:FindFirstChild("Head")
        if head then
            hum.Sit = true
            root.CFrame = head.CFrame * CFrame.new(0, 1.6, 0)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    elseif F.Piggy then
        hum.Sit = true
        root.CFrame = tr.CFrame * CFrame.new(0, 1.2, 1.1) * CFrame.Angles(math.rad(90), 0, 0)
        root.AssemblyLinearVelocity = Vector3.zero
    elseif F.FollowT then
        root.CFrame = tr.CFrame * CFrame.new(0, 0, 3)
    elseif F.LoopTP then
        root.CFrame = tr.CFrame
    elseif F.Shake then
        humpT = humpT + dt * 60
        root.CFrame = tr.CFrame * CFrame.new(math.sin(humpT) * 2, 0, math.cos(humpT * 0.7) * 2)
    end
    if F.FlingT then
        flingT = flingT + dt
        root.CFrame = tr.CFrame * CFrame.new(0, 0, (flingT % 0.2 < 0.1) and 1 or -1)
        root.AssemblyAngularVelocity = Vector3.new(0, 9e4, 0)
        root.AssemblyLinearVelocity = Vector3.new(9e5, 9e5, 9e5)
    end
end)

connect(RunService.Stepped, function()
    if F.NoClip then
        local c = getChar()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end
end)

connect(UserInputService.JumpRequest, function()
    if F.InfJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local mouse = LocalPlayer:GetMouse()
connect(UserInputService.InputBegan, function(input, gp)
    if gp or isMenuVisible then return end
    if F.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and mouse.Hit then
        teleportTo(mouse.Hit + Vector3.new(0, 4, 0))
    end
end)

connect(LocalPlayer.Idled, function()
    if F.AntiAFK then
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end
end)

local targetDrop
local playerMap = {}
local function labelFor(p) return string.format("%s (@%s)", p.DisplayName, p.Name) end
local function setTarget(p, silent)
    TargetPlayer = p
    if p and targetDrop and targetDrop.SetValue and not silent then
        pcall(targetDrop.SetValue, labelFor(p))
    end
    if p then Library.Notify("Target: " .. p.DisplayName) end
end
local function refreshPlayers()
    table.clear(playerMap)
    local names = {}
    for _, p in ipairs(otherPlayers()) do
        local l = labelFor(p)
        playerMap[l] = p
        names[#names + 1] = l
    end
    table.sort(names)
    if #names == 0 then names[1] = "No other players" end
    if targetDrop and targetDrop.SetOptions then
        local keep = TargetPlayer and TargetPlayer.Parent and labelFor(TargetPlayer) or names[1]
        pcall(targetDrop.SetOptions, names, keep)
    end
    return names
end
local function cycleTarget(step)
    local names = refreshPlayers()
    if not playerMap[names[1]] then Library.Notify("No other players") return end
    local idx = 0
    for i, n in ipairs(names) do if playerMap[n] == TargetPlayer then idx = i end end
    idx = ((idx - 1 + step) % #names) + 1
    setTarget(playerMap[names[idx]])
end
local function aimedPlayer()
    local best, bd = nil, math.huge
    local c = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, p in ipairs(otherPlayers()) do
        local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if r then
            local sp, on = Camera:WorldToViewportPoint(r.Position)
            local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude
            if on and d < bd then best, bd = p, d end
        end
    end
    return best
end

local warnT = 0
connect(RunService.Heartbeat, function()
    if TargetPlayer and not TargetPlayer.Parent then
        TargetPlayer = nil
        Library.Notify("Target left the game")
    end
    if not TargetPlayer and (F.Hump or F.Headsit or F.Piggy or F.FollowT or F.LoopTP or F.Shake or F.FlingT or F.Orbit) then
        if os.clock() - warnT > 4 then
            warnT = os.clock()
            Library.Notify("Pick a target in the Lobby tab first")
        end
    end
end)
connect(Players.PlayerAdded, function() if Running then refreshPlayers() end end)
connect(Players.PlayerRemoving, function() task.defer(refreshPlayers) end)
-- =========================================================================
-- INTERFACE
-- =========================================================================
local Window = Library.CreateWindow({
    Title = "snow.cc", Game = "Universal", Link = "discord.gg/snowcc",
    Size = Vector2.new(700, 600), ToggleKey = Enum.KeyCode.RightControl,
})
Library.CurrentWindow = Window

local PanicKey = Enum.KeyCode.End
local H = {}
local DEFAULTS = {}
for k, v in pairs(F) do DEFAULTS[k] = v end
local function tog(g, label, key, bind)
    local h = g:AddToggle(label, F[key], { HasKeybind = bind, Callback = function(v) F[key] = v end })
    H[key] = h
    return h
end
local function sld(g, label, min, max, key, unit)
    local h = g:AddSlider(label, min, max, F[key], unit or "", function(v) F[key] = v end)
    H[key] = h
    return h
end
local HttpService = game:GetService("HttpService")
local CFG_FILE = "snowcc_universal.json"
local function setF(k, v)
    F[k] = v
    if H[k] and H[k].SetValue then pcall(H[k].SetValue, H[k], v) end
end
local function saveConfig()
    if not writefile then Library.Notify("Executor has no writefile") return end
    local t = {}
    for k, v in pairs(F) do
        if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then t[k] = v end
    end
    pcall(writefile, CFG_FILE, HttpService:JSONEncode(t))
    Library.Notify("Config saved")
end
local function loadConfig()
    if not (isfile and readfile and isfile(CFG_FILE)) then Library.Notify("No saved config") return end
    local ok, t = pcall(function() return HttpService:JSONDecode(readfile(CFG_FILE)) end)
    if not ok then Library.Notify("Config corrupt") return end
    for k, v in pairs(t) do
        if F[k] ~= nil and type(F[k]) == type(v) then setF(k, v) end
    end
    Library.Notify("Config loaded")
end
local function resetAll()
    for k, v in pairs(DEFAULTS) do
        if type(v) == "boolean" or type(v) == "number" then setF(k, v) end
    end
    restoreLighting()
    Workspace.Gravity = 196.2
    Library.Notify("Everything reset")
end
local function unloadAll()
    Running = false
    for _, e in pairs(EspPool) do removeEsp(e) end
    for p in pairs(SkelLines) do clearPlayerVisuals(p) end
    for p in pairs(Chams) do clearPlayerVisuals(p) end
    pcall(function() crossH:Remove() crossV:Remove() end)
    pcall(function() chamFolder:Destroy() end)
    Workspace.Gravity = 196.2
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for k, v in pairs(F) do if type(v) == "boolean" then F[k] = false end end
    restoreLighting()
    local h = getHum()
    if h then Camera.CameraSubject = h end
    Window.ScreenGui:Destroy()
end

local vis = Window:CreateTab("Visuals")
local sEsp = vis:CreateSubtab("ESP")
local sWorld = vis:CreateSubtab("World")
local g1 = sEsp:CreateGroupbox("Player ESP", "Left")
tog(g1, "Master ESP", "ESP", true)
tog(g1, "Boxes", "EspBox")
tog(g1, "Names", "EspName")
tog(g1, "Health Bars", "EspHealth")
tog(g1, "Tracers", "EspTracer")
tog(g1, "Skeleton", "Skeleton", true)
tog(g1, "Head Dot", "HeadDot")
tog(g1, "Rainbow Colors", "Rainbow")
local gC = sEsp:CreateGroupbox("Chams", "Right")
tog(gC, "Chams (through walls)", "Chams", true)
tog(gC, "Wireframe Chams (outline only)", "WireChams", true)
sld(gC, "Fill Opacity (x10%)", 0, 10, "ChamFill")
tog(g1, "Show Teammates", "EspTeam")
sld(g1, "Max Distance", 100, 5000, "EspRange", " studs")
local g2 = sWorld:CreateGroupbox("Environment", "Left")
g2:AddToggle("Fullbright", false, { HasKeybind = true, Callback = function(v) F.Fullbright = v if not v then restoreLighting() end end })
g2:AddToggle("X-Ray (see through walls)", false, { Callback = function(v)
    F.Xray = v
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and not d:IsDescendantOf(Players) then
            local isChar = false
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Character and d:IsDescendantOf(pl.Character) then isChar = true break end
            end
            if not isChar then
                if v then d:SetAttribute("snowT", d.LocalTransparencyModifier) d.LocalTransparencyModifier = 0.6
                else d.LocalTransparencyModifier = 0 end
            end
        end
    end
end })
g2:AddToggle("Crosshair", false, { Callback = function(v) F.Crosshair = v end })
sld(g2, "Crosshair Size", 4, 30, "CrossSize")
g2:AddToggle("Remove Fog", false, { Callback = function(v) F.NoFog = v if not v then restoreLighting() end end })
tog(g2, "Custom FOV", "FovOn")
sld(g2, "FOV", 30, 120, "FOV")

local mv = Window:CreateTab("Movement")
local sMove = mv:CreateSubtab("Movement")
local g3 = sMove:CreateGroupbox("Speed & Jump", "Left")
tog(g3, "Speed Hack", "SpeedOn", true)
sld(g3, "Speed", 16, 200, "Speed")
g3:AddDropdown("Mode", { "CFrame", "WalkSpeed" }, F.SpeedMode, function(v) F.SpeedMode = v end)
tog(g3, "Jump Power", "JumpOn")
sld(g3, "Power", 50, 300, "JumpPower")
tog(g3, "Bunny Hop (hold Space)", "Bhop")
tog(g3, "Custom Gravity", "GravOn")
sld(g3, "Gravity", 0, 300, "Gravity")
local g4 = sMove:CreateGroupbox("Flight & Collision", "Right")
tog(g4, "Fly (WASD / Space / Shift)", "Fly", true)
sld(g4, "Fly Speed", 20, 300, "FlySpeed")
tog(g4, "Noclip", "NoClip", true)
tog(g4, "Infinite Jump", "InfJump", true)

local lobby = Window:CreateTab("Lobby")
local sLob = lobby:CreateSubtab("Players")
local gSel = sLob:CreateGroupbox("Target Selector", "Left")
do
    local names = {}
    for _, p in ipairs(otherPlayers()) do
        local l = labelFor(p)
        playerMap[l] = p
        names[#names + 1] = l
    end
    table.sort(names)
    if #names == 0 then names[1] = "No other players" end
    targetDrop = gSel:AddDropdown("Selected Player", names, names[1], function(v)
        local p = playerMap[v]
        if p and p ~= TargetPlayer then setTarget(p, true) end
    end)
end
gSel:AddButton("Refresh Player List", function() refreshPlayers() Library.Notify("Player list refreshed") end)
gSel:AddButton("Next Player", function() cycleTarget(1) end)
gSel:AddButton("Previous Player", function() cycleTarget(-1) end)
gSel:AddButton("Select Player Under Crosshair", function()
    local p = aimedPlayer()
    if p then setTarget(p) else Library.Notify("Nobody on screen") end
end)
gSel:AddButton("Clear Target", function() TargetPlayer = nil Library.Notify("Target cleared") end)
local gAct = sLob:CreateGroupbox("Quick Actions", "Right")
gAct:AddButton("Teleport To Target", function()
    local r = TargetPlayer and TargetPlayer.Character and TargetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if r then teleportTo(r.CFrame * CFrame.new(0, 0, 4)) else Library.Notify("Pick a target first") end
end)
gAct:AddToggle("Spectate Target", false, { Callback = function(v)
    F.Spectate = v
    if not v then local h = getHum() if h then Camera.CameraSubject = h end end
end })
gAct:AddButton("Copy Target Username", function()
    if TargetPlayer and setclipboard then setclipboard(TargetPlayer.Name) Library.Notify("Copied") end
end)
local gLob = sLob:CreateGroupbox("Lobby Info", "Left")
gLob:AddLabel("Players in server: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers)
gLob:AddLabel("Server: " .. string.sub(tostring(game.JobId), 1, 8))
gLob:AddLabel("Use Refresh after people join or leave")

local tp = Window:CreateTab("Teleport")
local sTp = tp:CreateSubtab("Teleports")
local g5 = sTp:CreateGroupbox("Players", "Left")
g5:AddLabel("Pick targets in the Lobby tab")
g5:AddButton("Teleport To Nearest", function()
    local mine, best, bd = getRoot(), nil, math.huge
    for _, p in ipairs(otherPlayers()) do
        local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if r and mine and (r.Position - mine.Position).Magnitude < bd then best, bd = r, (r.Position - mine.Position).Magnitude end
    end
    if best then teleportTo(best.CFrame * CFrame.new(0, 0, 4)) end
end)
local g6 = sTp:CreateGroupbox("Utility", "Right")
tog(g6, "Ctrl + Click Teleport", "ClickTP", true)
local saved
g6:AddButton("Save Position", function() local r = getRoot() if r then saved = r.CFrame Library.Notify("Position saved") end end)
g6:AddButton("Return To Saved", function() if saved then teleportTo(saved) else Library.Notify("Nothing saved") end end)

local tr = Window:CreateTab("Trolling")
local sTr = tr:CreateSubtab("Trolling")
local g7 = sTr:CreateGroupbox("Self", "Left")
tog(g7, "Spinbot", "Spin", true)
sld(g7, "Spin Speed", 5, 100, "SpinSpeed")
tog(g7, "Fling (touch players)", "Fling", true)
local g8 = sTr:CreateGroupbox("Target (pick in Lobby tab)", "Right")
tog(g8, "Orbit Target", "Orbit")
sld(g8, "Orbit Distance", 3, 40, "OrbitDist", " studs")
sld(g8, "Orbit Speed", 1, 20, "OrbitSpeed")
local g10 = sTr:CreateGroupbox("Annoy Target", "Left")
tog(g10, "Humper (behind target)", "Hump", true)
sld(g10, "Hump Speed", 4, 40, "HumpSpeed")
sld(g10, "Hump Reach", 1, 5, "HumpReach")
tog(g10, "Head Sit", "Headsit")
tog(g10, "Piggyback", "Piggy")
tog(g10, "Follow Behind", "FollowT")
tog(g10, "Loop Teleport (on top)", "LoopTP")
tog(g10, "Shake Around Target", "Shake")
tog(g10, "Fling Target", "FlingT", true)

local st = Window:CreateTab("Settings")
local sSt = st:CreateSubtab("Menu")
local sCfg = st:CreateSubtab("Config")
local sMisc = st:CreateSubtab("Server")

local g9 = sSt:CreateGroupbox("Interface", "Left")
g9:AddKeybind("Menu Key", Enum.KeyCode.RightControl, function(key) Window:SetToggleKey(key or Enum.KeyCode.RightControl) end)
g9:AddToggle("Show Watermark", true, { Callback = function(v) Window.Watermark.Visible = v end })
g9:AddToggle("Keybind List", true, { Callback = function(v) Library.BindHudEnabled = v Library.RefreshBinds() end })
g9:AddLabel("Binds appear in the list when toggled on")
local gU = sSt:CreateGroupbox("Unload", "Right")
gU:AddKeybind("Panic / Unload Key", Enum.KeyCode.End, function(key) PanicKey = key end)
gU:AddButton("Unload Script", unloadAll)
gU:AddButton("Reset All Features", resetAll)

local gCfg = sCfg:CreateGroupbox("Config", "Left")
gCfg:AddButton("Save Config", saveConfig)
gCfg:AddButton("Load Config", loadConfig)
gCfg:AddButton("Reset To Defaults", resetAll)
local gPre = sCfg:CreateGroupbox("Presets", "Right")
gPre:AddButton("Visuals Only", function()
    resetAll()
    for _, k in ipairs({ "ESP", "Skeleton", "Chams", "Fullbright", "Crosshair" }) do setF(k, true) end
end)
gPre:AddButton("Movement Pack", function()
    resetAll()
    for _, k in ipairs({ "SpeedOn", "InfJump", "NoClip" }) do setF(k, true) end
end)
gPre:AddButton("Disable Everything", resetAll)

local gSrv = sMisc:CreateGroupbox("Server", "Left")
tog(gSrv, "Anti-AFK", "AntiAFK")
gSrv:AddButton("Rejoin Server", function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)
gSrv:AddButton("Server Hop", function()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and data and data.data then
        for _, sv in ipairs(data.data) do
            if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, sv.id, LocalPlayer)
                return
            end
        end
    end
    Library.Notify("No server found")
end)
gSrv:AddButton("Copy Join Script", function()
    if setclipboard then
        setclipboard(string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")', game.PlaceId, game.JobId))
        Library.Notify("Copied")
    end
end)
local gInfo = sMisc:CreateGroupbox("Info", "Right")
gInfo:AddLabel("Game: " .. game.PlaceId)
gInfo:AddLabel("Players: " .. #Players:GetPlayers())
gInfo:AddLabel("User: " .. LocalPlayer.Name)

connect(UserInputService.InputBegan, function(input, gp)
    if not gp and PanicKey and input.KeyCode == PanicKey then unloadAll() end
end)
Library.Notify("Universal loaded - RightControl toggles the menu", 4)
