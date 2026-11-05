--[[ snow.cc | 99 Nights in the Forest  (PlaceId 126509999114328) ]]

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
-- 99 NIGHTS IN THE FOREST: GAME LOGIC
-- =========================================================================
local Lighting = game:GetService("Lighting")
local checkcallerFn = getGlobal("checkcaller") or function() return false end
local getnamecall = getGlobal("getnamecallmethod")
local writefileFn = getGlobal("writefile")
local setclipboardFn = getGlobal("setclipboard")

local Running = true
local Connections = {}
local function connect(sig, fn)
    local c = sig:Connect(fn)
    Connections[#Connections + 1] = c
    return c
end

local F = {
    KillAura = false, AuraRange = 25, AuraMode = "Hostile Only", AuraDelay = 15, AuraDamage = 100, AuraArgs = "(target, damage)",
    TreeAura = false, TreeRange = 25,
    SilentAim = false, SilentFOV = 250, SilentPassive = false,
    DeerBanish = false, DeerRange = 150,
    AutoFeed = false, FeedRange = 60, FeedOrder = "fire, item",
    God = false,
    AutoEat = false, EatBelow = 70,
    AutoSawmill = false,
    SpeedOn = false, Speed = 40, SpeedMode = "CFrame",
    InfJump = false, Fly = false, FlySpeed = 60, NoClip = false,
    Fullbright = false, NoFog = false,
    Spy = false,
    ESP = false, EspDeer = true, EspHostile = true, EspPassive = false, EspKids = true, EspItems = true, EspCamp = true,
    EspRange = 600,
}

local RemoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
local function remote(name)
    return RemoteFolder and RemoteFolder:FindFirstChild(name)
end
local function fire(name, ...)
    local r = remote(name)
    if r then pcall(r.FireServer, r, ...) end
end
local function invoke(name, ...)
    local r = remote(name)
    if r then return pcall(r.InvokeServer, r, ...) end
    return false
end

local function getChar() return LocalPlayer.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local CharactersFolder = Workspace:FindFirstChild("Characters")
local ItemsFolder = Workspace:FindFirstChild("Items")
task.spawn(function()
    CharactersFolder = CharactersFolder or Workspace:WaitForChild("Characters", 15)
    ItemsFolder = ItemsFolder or Workspace:WaitForChild("Items", 15)
end)

local function modelRoot(m)
    if not m or not m.Parent then return nil end
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart", true)
end

local PASSIVE = { "bunny", "frog" }
local function lname(m) return string.lower(m.Name) end
local function isKid(m)
    local n = lname(m)
    return n:find("lost child", 1, true) ~= nil or n:find("kid", 1, true) ~= nil or n:find("salesman", 1, true) ~= nil
end
local function isDeer(m) return lname(m):find("deer", 1, true) ~= nil end
local function isPassive(m)
    local n = lname(m)
    for _, p in ipairs(PASSIVE) do
        if n:find(p, 1, true) then return true end
    end
    return false
end
local function isPlayerChar(m) return Players:GetPlayerFromCharacter(m) ~= nil end

local function eachMob(fn)
    if not CharactersFolder then return end
    for _, m in ipairs(CharactersFolder:GetChildren()) do
        if m:IsA("Model") and not isPlayerChar(m) then
            local r = modelRoot(m)
            if r then fn(m, r) end
        end
    end
end

local function distTo(part)
    local r = getRoot()
    if not (r and part) then return math.huge end
    return (part.Position - r.Position).Magnitude
end

-- Generic name search across the map (cached)
local nameCache = {}
local function findNamed(key, patterns, roots)
    local cached = nameCache[key]
    if cached and cached.Parent then return cached end
    for _, root in ipairs(roots) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("Model") then
                    local n = string.lower(d.Name)
                    for _, p in ipairs(patterns) do
                        if n:find(p, 1, true) then
                            nameCache[key] = d
                            return d
                        end
                    end
                end
            end
        end
    end
    return nil
end

local CollectionService = game:GetService("CollectionService")
local function findCampfire()
    local cached = nameCache.camp
    if cached and cached.Parent then return cached end
    for _, tag in ipairs({ "MainFire", "Campfire", "FireSource", "Fire" }) do
        local ok, list = pcall(CollectionService.GetTagged, CollectionService, tag)
        if ok and list[1] and list[1]:IsA("Model") then
            nameCache.camp = list[1]
            return list[1]
        end
    end
    local map = Workspace:FindFirstChild("Map")
    local camp = map and map:FindFirstChild("Campground")
    if camp then
        for _, d in ipairs(camp:GetDescendants()) do
            if d:IsA("Fire") or (d:IsA("ParticleEmitter") and string.lower(d.Name):find("fire", 1, true)) then
                local m = d:FindFirstAncestorOfClass("Model")
                if m and m ~= camp then
                    nameCache.camp = m
                    return m
                end
            end
        end
    end
    return nil
end

local function findSawmills()
    local ok, list = pcall(CollectionService.GetTagged, CollectionService, "LoggingCamp")
    return ok and list or {}
end

local function equippedToolName()
    local c = getChar()
    return c and c:GetAttribute("Equipped")
end

-- =========================================================================
-- NAMECALL HOOK: godmode, silent redirect, remote spy
-- =========================================================================
local DAMAGE_REMOTES = {
    DamagePlayer = true, CheckLightningDamage = true,
    JungleSpikeTrapDamage = true, NPCProjectileDamagePlayer = true,
}
local PROJECTILE_REMOTES = {
    ProjectileDamageEnemy = true, RegisterProjectile = true, ExplosiveProjectileDamageEnemy = true,
}

local function mobFromInstance(inst)
    if not (CharactersFolder and typeof(inst) == "Instance") then return nil end
    local cur = inst
    while cur and cur.Parent do
        if cur.Parent == CharactersFolder then return cur end
        cur = cur.Parent
    end
    return nil
end

local function bestSilentTarget()
    local best, bestD = nil, F.SilentFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    eachMob(function(m, r)
        if isKid(m) then return end
        if isPassive(m) and not F.SilentPassive then return end
        local sp, on = Camera:WorldToViewportPoint(r.Position)
        if not on then return end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < bestD then best, bestD = m, d end
    end)
    return best
end

local SpyLog, SpyCount = {}, {}
local function serArg(v)
    local t = typeof(v)
    if t == "Instance" then return "<" .. v.ClassName .. " " .. v:GetFullName() .. ">" end
    if t == "string" then return string.format("%q", v) end
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "{table n=" .. n .. "}"
    end
    return tostring(v)
end

if typeof(hookmeta) == "function" and typeof(getnamecall) == "function" then
    pcall(function()
        local old
        old = hookmeta(game, "__namecall", newccl(function(self, ...)
            local m = getnamecall()
            if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" and not checkcallerFn() then
                local n = self.Name
                if F.God and DAMAGE_REMOTES[n] then
                    return nil
                end
                if F.SilentAim and PROJECTILE_REMOTES[n] then
                    local target = bestSilentTarget()
                    if target then
                        local args = table.pack(...)
                        for i = 1, args.n do
                            local a = args[i]
                            if typeof(a) == "Instance" and mobFromInstance(a) then
                                args[i] = (a:IsA("BasePart") and modelRoot(target)) or target
                            elseif typeof(a) == "Vector3" and i > 1 then
                                local r = modelRoot(target)
                                if r then args[i] = r.Position end
                            end
                        end
                        return old(self, table.unpack(args, 1, args.n))
                    end
                end
                if F.Spy then
                    SpyCount[n] = (SpyCount[n] or 0) + 1
                    if SpyCount[n] <= 30 then
                        local args = table.pack(...)
                        local parts = {}
                        for i = 1, math.min(args.n, 8) do parts[#parts + 1] = serArg(args[i]) end
                        SpyLog[#SpyLog + 1] = string.format("[%.1f] %s %s(%s)", os.clock(), m, self:GetFullName(), table.concat(parts, ", "))
                    end
                end
            end
            return old(self, ...)
        end))
    end)
end

-- =========================================================================
-- COMBAT
-- =========================================================================
local function auraAllowed(m)
    if isKid(m) then return false end
    if F.AuraMode == "Deer Only" then return isDeer(m) end
    if F.AuraMode == "Hostile Only" then return not isPassive(m) end
    return true
end

local function findEquippedTool()
    local name = equippedToolName()
    local c = getChar()
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and (not name or t.Name == name) then return t end
        end
    end
    return nil
end

-- Real signature (from game scripts): ToolDamageObject:InvokeServer(target, toolModel, damage, hitCFrame)
local function hit(target)
    local tool = findEquippedTool()
    local r = modelRoot(target)
    if not (tool and r) then return end
    invoke("ToolDamageObject", target, tool, F.AuraDamage, r.CFrame)
end

task.spawn(function()
    while Running do
        task.wait(math.max(0.05, F.AuraDelay / 100))
        if F.KillAura then
            local count = 0
            eachMob(function(m, r)
                if count < 4 and auraAllowed(m) and distTo(r) <= F.AuraRange then
                    count = count + 1
                    task.spawn(hit, m)
                end
            end)
        end
        if F.TreeAura and Workspace:FindFirstChild("Map") then
            local foliage = Workspace.Map:FindFirstChild("Foliage")
            if foliage then
                local count = 0
                for _, t in ipairs(foliage:GetChildren()) do
                    if count >= 3 then break end
                    if t:IsA("Model") and string.lower(t.Name):find("tree", 1, true) then
                        local r = modelRoot(t)
                        if r and distTo(r) <= F.TreeRange then
                            count = count + 1
                            task.spawn(hit, t)
                        end
                    end
                end
            end
        end
    end
end)

-- Deer banisher
task.spawn(function()
    while Running do
        task.wait(0.2)
        if F.DeerBanish then
            eachMob(function(m, r)
                if isDeer(m) and distTo(r) <= F.DeerRange then
                    fire("HurtDeerTorch", m)
                    invoke("MonsterHitByTorch", m)
                end
            end)
        end
    end
end)

-- =========================================================================
-- SURVIVAL
-- =========================================================================
local FUEL = { "log", "coal", "biofuel", "fuel canister" }
local function isFuel(name)
    name = string.lower(name)
    for _, f in ipairs(FUEL) do
        if name:find(f, 1, true) then return true end
    end
    return false
end

task.spawn(function()
    while Running do
        task.wait(0.5)
        if F.AutoFeed and ItemsFolder then
            local fireModel = findCampfire()
            if fireModel then
                local sent = 0
                for _, it in ipairs(ItemsFolder:GetChildren()) do
                    if sent >= 4 then break end
                    if isFuel(it.Name) then
                        local r = it:IsA("BasePart") and it or modelRoot(it)
                        if r and distTo(r) <= F.FeedRange then
                            sent = sent + 1
                            if F.FeedOrder == "item, fire" then
                                fire("RequestBurnItem", it, fireModel)
                            elseif F.FeedOrder == "item only" then
                                fire("RequestBurnItem", it)
                            else
                                fire("RequestBurnItem", fireModel, it)
                            end
                        end
                    end
                end
            end
        end
    end
end)

local FOOD = { "carrot", "berry", "berries", "meat", "steak", "apple", "stew", "pumpkin", "cooked" }
task.spawn(function()
    while Running do
        task.wait(1.5)
        if F.AutoEat then
            local hunger = tonumber(LocalPlayer:GetAttribute("Hunger"))
            if hunger and hunger < F.EatBelow then
                local pool = { LocalPlayer:FindFirstChild("Backpack"), LocalPlayer:FindFirstChild("Inventory") }
                local done = false
                for _, p in ipairs(pool) do
                    if p and not done then
                        for _, it in ipairs(p:GetChildren()) do
                            local n = string.lower(it.Name)
                            for _, f in ipairs(FOOD) do
                                if n:find(f, 1, true) then
                                    invoke("RequestConsumeItem", it)
                                    done = true
                                    break
                                end
                            end
                            if done then break end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while Running do
        task.wait(1)
        if F.AutoSawmill then
            for _, camp in ipairs(findSawmills()) do fire("RequestPullSawmillLever", camp) end
        end
    end
end)

-- =========================================================================
-- MOVEMENT
-- =========================================================================
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
        root.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * F.FlySpeed or Vector3.zero
    elseif F.SpeedOn and not isMenuVisible then
        local move = hum.MoveDirection
        if F.SpeedMode == "CFrame" then
            if move.Magnitude > 0 then
                root.CFrame = root.CFrame + move * (F.Speed - 16) * dt
            end
        else
            hum.WalkSpeed = F.Speed
        end
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

-- Lighting
local origLighting = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}
connect(RunService.RenderStepped, function()
    if F.Fullbright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
    end
    if F.NoFog then
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a.Density = 0 end
        end
    end
end)
local function restoreLighting()
    for k, v in pairs(origLighting) do pcall(function() Lighting[k] = v end) end
end

-- =========================================================================
-- ESP
-- =========================================================================
local EspPool = {}
local EspFrame = 0
local C_DEER, C_HOSTILE, C_PASSIVE, C_KID, C_ITEM, C_CAMP =
    Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 150, 60), Color3.fromRGB(120, 230, 120),
    Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 230, 90), Color3.fromRGB(120, 190, 255)

local function getEsp(key)
    local e = EspPool[key]
    if not e then
        local box = newDrawing("Square")
        box.Thickness = 1.5
        box.Filled = false
        box.Visible = false
        local text = newDrawing("Text")
        text.Size = 13
        text.Center = true
        text.Outline = true
        text.Visible = false
        e = { Box = box, Text = text, Seen = 0 }
        EspPool[key] = e
    end
    e.Seen = EspFrame
    return e
end

local function drawEsp(key, root, size, label, color, withBox)
    local pos, on = Camera:WorldToViewportPoint(root.Position)
    local e = getEsp(key)
    if not on then
        e.Box.Visible = false
        e.Text.Visible = false
        return
    end
    local top = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, size / 2, 0))
    local bot = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, size / 2, 0))
    local h = math.max(math.abs(top.Y - bot.Y), 8)
    local w = h * 0.7
    if withBox then
        e.Box.Size = Vector2.new(w, h)
        e.Box.Position = Vector2.new(pos.X - w / 2, pos.Y - h / 2)
        e.Box.Color = color
        e.Box.Visible = true
    else
        e.Box.Visible = false
    end
    e.Text.Text = string.format("%s [%dm]", label, math.floor(distTo(root)))
    e.Text.Position = Vector2.new(pos.X, pos.Y - h / 2 - 15)
    e.Text.Color = color
    e.Text.Visible = true
end

local itemEspList, itemEspT = {}, 0
local ITEM_PATTERNS = { "key", "chest", "pelt", "diamond", "coin stack", "gem", "medkit", "ammo" }
local function refreshItemList()
    table.clear(itemEspList)
    if not ItemsFolder then return end
    for _, it in ipairs(ItemsFolder:GetChildren()) do
        local n = string.lower(it.Name)
        for _, p in ipairs(ITEM_PATTERNS) do
            if n:find(p, 1, true) then
                local r = it:IsA("BasePart") and it or modelRoot(it)
                if r then
                    itemEspList[#itemEspList + 1] = { Inst = it, Root = r, D = distTo(r) }
                end
                break
            end
        end
    end
    table.sort(itemEspList, function(a, b) return a.D < b.D end)
end

connect(RunService.RenderStepped, function()
    EspFrame = EspFrame + 1
    if F.ESP and not isMenuVisible then
        eachMob(function(m, r)
            if distTo(r) > F.EspRange then return end
            local size = 5
            if isDeer(m) then
                if F.EspDeer then drawEsp(m, r, 9, "THE DEER", C_DEER, true) end
            elseif isKid(m) then
                if F.EspKids then drawEsp(m, r, 4, "Lost Child", C_KID, true) end
            elseif isPassive(m) then
                if F.EspPassive then drawEsp(m, r, 2.5, m.Name, C_PASSIVE, true) end
            elseif F.EspHostile then
                drawEsp(m, r, size, m.Name, C_HOSTILE, true)
            end
        end)

        if F.EspCamp then
            local c = findCampfire()
            local r = c and modelRoot(c)
            if r then drawEsp("campfire", r, 6, "Campfire", C_CAMP, false) end
        end

        if F.EspItems then
            if os.clock() - itemEspT > 1.5 then
                itemEspT = os.clock()
                refreshItemList()
            end
            for i = 1, math.min(#itemEspList, 40) do
                local d = itemEspList[i]
                if d.Inst.Parent and d.D <= F.EspRange then
                    drawEsp(d.Inst, d.Root, 2, d.Inst.Name, C_ITEM, false)
                end
            end
        end
    end

    for key, e in pairs(EspPool) do
        local stale = e.Seen ~= EspFrame
        if stale then
            e.Box.Visible = false
            e.Text.Visible = false
            if typeof(key) == "Instance" and not key.Parent then
                pcall(function() e.Box:Remove() end)
                pcall(function() e.Text:Remove() end)
                EspPool[key] = nil
            end
        end
    end
end)

-- =========================================================================
-- TELEPORT / EVENT HELPERS
-- =========================================================================
local function teleportTo(cf)
    local r = getRoot()
    if r then
        r.AssemblyLinearVelocity = Vector3.zero
        r.CFrame = cf + Vector3.new(0, 5, 0)
    end
end

local function tpNamed(key, label, patterns, roots)
    local m = findNamed(key, patterns, roots)
    local r = m and modelRoot(m)
    if r then
        teleportTo(r.CFrame)
        Library.Notify("Teleported to " .. label)
    else
        Library.Notify(label .. " not found yet - explore the map first")
    end
end

local function nearestKid()
    local best, bd = nil, math.huge
    eachMob(function(m, r)
        if isKid(m) then
            local d = distTo(r)
            if d < bd then best, bd = r, d end
        end
    end)
    return best
end

-- =========================================================================
-- INTERFACE
-- =========================================================================
local Window = Library.CreateWindow({
    Title = "snow.cc",
    Game = "99 Nights in the Forest",
    Link = "discord.gg/snowcc",
    Size = Vector2.new(700, 600),
    ToggleKey = Enum.KeyCode.RightControl,
})
Library.CurrentWindow = Window

local function tog(group, label, key, bind)
    return group:AddToggle(label, F[key], { HasKeybind = bind, Callback = function(v) F[key] = v end })
end
local function sld(group, label, min, max, key, unit)
    return group:AddSlider(label, min, max, F[key], unit or "", function(v) F[key] = v end)
end

-- Combat
local combat = Window:CreateTab("Combat")
local subAura = combat:CreateSubtab("Kill Aura")
local subSilent = combat:CreateSubtab("Projectiles")
local gbAura = subAura:CreateGroupbox("Melee Aura", "Left")
tog(gbAura, "Mob Kill Aura", "KillAura", true)
sld(gbAura, "Range", 5, 60, "AuraRange", " studs")
sld(gbAura, "Damage", 1, 500, "AuraDamage")
sld(gbAura, "Delay (x10ms)", 5, 100, "AuraDelay")
gbAura:AddDropdown("Targets", { "Hostile Only", "All", "Deer Only" }, F.AuraMode, function(v) F.AuraMode = v end)
local gbTree = subAura:CreateGroupbox("Resources", "Right")
tog(gbTree, "Tree Chopper", "TreeAura", true)
sld(gbTree, "Tree Range", 5, 60, "TreeRange", " studs")
local gbDeer = subAura:CreateGroupbox("The Deer", "Right")
tog(gbDeer, "Deer Banisher", "DeerBanish", true)
sld(gbDeer, "Trigger Distance", 30, 300, "DeerRange", " studs")
local gbSilent = subSilent:CreateGroupbox("Silent Redirection", "Left")
tog(gbSilent, "Silent Projectile Aim", "SilentAim", true)
sld(gbSilent, "Aim FOV", 50, 600, "SilentFOV", "px")
tog(gbSilent, "Include Passive Animals", "SilentPassive")

-- Survival
local surv = Window:CreateTab("Survival")
local subBase = surv:CreateSubtab("Base")
local subSelf = surv:CreateSubtab("Player")
local gbFire = subBase:CreateGroupbox("Campfire", "Left")
tog(gbFire, "Auto-Feed Campfire", "AutoFeed", true)
sld(gbFire, "Item Range", 10, 200, "FeedRange", " studs")
gbFire:AddDropdown("Burn Arguments", { "fire, item", "item, fire", "item only" }, F.FeedOrder, function(v) F.FeedOrder = v end)
local gbMach = subBase:CreateGroupbox("Machines", "Right")
tog(gbMach, "Auto Sawmill Lever", "AutoSawmill")
gbMach:AddButton("Clear Weather", function()
    invoke("RequestClearWeather")
    Library.Notify("Clear weather requested")
end)
local gbPlayer = subSelf:CreateGroupbox("Protection", "Left")
tog(gbPlayer, "Godmode (block damage remotes)", "God", true)
tog(gbPlayer, "Auto-Eat", "AutoEat")
sld(gbPlayer, "Eat Below Hunger", 10, 150, "EatBelow")

-- Events
local events = Window:CreateTab("Events")
local subCarn = events:CreateSubtab("Carnival")
local subAlien = events:CreateSubtab("Alien & Kids")
local gbCarn = subCarn:CreateGroupbox("Carnival Games (experimental)", "Left")
for _, g in ipairs({ "CarnivalCompleteShootingGallery", "CarnivalCompleteBasketballGallery", "CarnivalCompleteRingToss" }) do
    gbCarn:AddButton(g:gsub("CarnivalComplete", "Complete "), function()
        fire(g)
        Library.Notify("Fired " .. g)
    end)
end
local gbAlien = subAlien:CreateGroupbox("Alien Ship", "Left")
gbAlien:AddButton("Repair Alien Ship", function() invoke("RequestRepairAlienShip") Library.Notify("Repair requested") end)
gbAlien:AddButton("Pull Airlock Lever", function() fire("RequestPullAlienAirlockLever") end)
gbAlien:AddButton("Pull Prison Lever", function() fire("RequestPullAlienPrisonLever") end)
local gbKids = subAlien:CreateGroupbox("Lost Children", "Right")
gbKids:AddButton("Teleport To Nearest Child", function()
    local r = nearestKid()
    if r then teleportTo(r.CFrame) else Library.Notify("No lost child loaded nearby") end
end)

-- Visuals
local vis = Window:CreateTab("Visuals")
local subEsp = vis:CreateSubtab("ESP")
local subWorld = vis:CreateSubtab("World")
local gbEsp = subEsp:CreateGroupbox("ESP", "Left")
tog(gbEsp, "Master ESP", "ESP", true)
sld(gbEsp, "Max Distance", 50, 2000, "EspRange", " studs")
local gbEspT = subEsp:CreateGroupbox("Targets", "Right")
tog(gbEspT, "The Deer", "EspDeer")
tog(gbEspT, "Hostile Mobs", "EspHostile")
tog(gbEspT, "Passive Animals", "EspPassive")
tog(gbEspT, "Lost Children", "EspKids")
tog(gbEspT, "Key Items & Chests", "EspItems")
tog(gbEspT, "Campfire", "EspCamp")
local gbWorld = subWorld:CreateGroupbox("Environment", "Left")
gbWorld:AddToggle("Fullbright", false, { Callback = function(v)
    F.Fullbright = v
    if not v then restoreLighting() end
end })
gbWorld:AddToggle("Remove Fog", false, { Callback = function(v)
    F.NoFog = v
    if not v then restoreLighting() end
end })

-- Movement
local move = Window:CreateTab("Movement")
local subMove = move:CreateSubtab("Movement")
local subTp = move:CreateSubtab("Teleports")
local gbSpeed = subMove:CreateGroupbox("Speed", "Left")
tog(gbSpeed, "Speed Hack", "SpeedOn", true)
sld(gbSpeed, "Speed", 16, 120, "Speed")
gbSpeed:AddDropdown("Mode", { "CFrame", "WalkSpeed" }, F.SpeedMode, function(v) F.SpeedMode = v end)
local gbFly = subMove:CreateGroupbox("Flight & Collision", "Right")
tog(gbFly, "Fly (WASD / Space / Shift)", "Fly", true)
sld(gbFly, "Fly Speed", 20, 200, "FlySpeed")
tog(gbFly, "Noclip", "NoClip", true)
tog(gbFly, "Infinite Jump", "InfJump", true)
local gbTp = subTp:CreateGroupbox("Locations", "Left")
gbTp:AddButton("Campfire", function() local f = findCampfire() local r = f and modelRoot(f) if r then teleportTo(r.CFrame) Library.Notify("Teleported to Campfire") else Library.Notify("Campfire not found") end end)
gbTp:AddButton("Trader (Sketchy Salesman)", function()
    local s = CharactersFolder and CharactersFolder:FindFirstChild("Sketchy Salesman")
    local r = s and modelRoot(s)
    if r then teleportTo(r.CFrame) else Library.Notify("Trader not loaded") end
end)
gbTp:AddButton("Sawmill", function()
    local camp = findSawmills()[1]
    local r = camp and modelRoot(camp)
    if r then teleportTo(r.CFrame) else Library.Notify("Sawmill not found") end
end)
gbTp:AddButton("Stronghold", function()
    local map = Workspace:FindFirstChild("Map")
    local s = map and map:FindFirstChild("Landmarks") and map.Landmarks:FindFirstChild("Stronghold")
    if s then teleportTo(s:GetPivot()) else Library.Notify("Stronghold not found") end
end)
gbTp:AddButton("Crafting Bench", function()
    local map = Workspace:FindFirstChild("Map")
    local b = map and map:FindFirstChild("Campground") and map.Campground:FindFirstChild("CraftingBench")
    if b then teleportTo(b:GetPivot()) else Library.Notify("Bench not found") end
end)
gbTp:AddButton("Nearest Lost Child", function()
    local r = nearestKid()
    if r then teleportTo(r.CFrame) else Library.Notify("No lost child loaded nearby") end
end)

-- Settings
local setTab = Window:CreateTab("Settings")
local subMenu = setTab:CreateSubtab("Menu")
local gbMenu = subMenu:CreateGroupbox("Interface", "Left")
gbMenu:AddKeybind("Menu Key", Enum.KeyCode.RightControl, function(key)
    Window:SetToggleKey(key or Enum.KeyCode.RightControl)
end)
gbMenu:AddToggle("Show Watermark", true, { Callback = function(v) Window.Watermark.Visible = v end })
gbMenu:AddToggle("Keybind List", true, { Callback = function(v)
    Library.BindHudEnabled = v
    Library.RefreshBinds()
end })
local gbDev = subMenu:CreateGroupbox("Diagnostics", "Right")
gbDev:AddToggle("Remote Spy (game calls)", false, { Callback = function(v) F.Spy = v end })
gbDev:AddButton("Save Spy Log", function()
    local text = table.concat(SpyLog, "\n")
    if writefileFn then
        pcall(writefileFn, "forest99_spy.txt", text)
        Library.Notify("Saved forest99_spy.txt (" .. #SpyLog .. " calls)")
    elseif setclipboardFn then
        setclipboardFn(text)
        Library.Notify("Spy log copied to clipboard")
    end
end)
gbDev:AddButton("Unload Script", function()
    Running = false
    for key, e in pairs(EspPool) do
        pcall(function() e.Box:Remove() end)
        pcall(function() e.Text:Remove() end)
    end
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    for k in pairs(F) do
        if type(F[k]) == "boolean" then F[k] = false end
    end
    restoreLighting()
    Window.ScreenGui:Destroy()
end)

Library.Notify("99 Nights loaded - RightControl toggles the menu", 4)
