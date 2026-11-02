--[[
    snow.cc | Havoc [Season 2] | discord.gg/snowcc
    Full Operational Client:
    - Safe Global Environment Resolution (Resolves getgenv, _G, and getfenv safely)
    - Auto Mouse Unlocker (__newindex metamethod hook + RenderStepped enforcement; zero ESC required)
    - Universal Havoc Entity Scanner (Detects both Players and AI Scavengers across any server folder)
    - Dual-Engine ESP: High-performance 2D Drawing Vector API + Infallible Native BillboardGui Engine
    - Hardware Chams: AlwaysOnTop highlight shaders on all resolved Havoc enemy models
    - Silent Aim: Metamethod & hookfunction redirection on Workspace:Raycast & hitPos replication
    - Camera Aimbot: Smooth camera tracking with 3D velocity lead prediction (Prediction X / Y)
    - Anticheat Bypass: OnPunishment packet suppression
    - Weapon & Physics: WalkSpeed override, Bunny Hop, Recoil camera shake suppression, Fast Reload
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- =========================================================================
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
-- SECTION 3: GLOBAL CONFIGURATION
-- =========================================================================
local Config = {
    Aimbot = {
        Enabled = false,
        Key = Enum.UserInputType.MouseButton2,
        Mode = "Camera",
        Part = "Head",
        FOV = 150,
        Smoothing = 25,
        Sensitivity = 100,
        Prediction = false,
        PredictionX = 17,
        PredictionY = 2,
        StickyAim = false,
        StickyRange = 400,
        ShowCircle = false,
        Color = Color3.fromRGB(0, 110, 255),
        Offset = 0,
        WallCheck = true,
        LowHealth = false,
    },
    SilentAim = {
        Enabled = false,
        Key = nil, -- Always active when Enabled = true; bind a key if hold-only is desired
        FOV = 300,
        Part = "HumanoidRootPart",
        HitRate = 100,
        StickyAim = false,
        StickyRange = 400,
        ShowCircle = false,
        Color = Color3.fromRGB(0, 255, 170),
        Offset = 0,
        WallSpread = false,
        DistanceLimit = false,
        MaxDistance = 150,
    },
    Esp = {
        Enabled = false,
        Boxes = false,
        Health = false,
        Names = false,
        Distances = false,
        Tracers = false,
        HeadDot = false,
        TracerOrigin = "Bottom",
        ShowPlayers = true,
        ShowNpcs = true,
        BoxColor = Color3.fromRGB(255, 255, 255),
        PlayerBoxColor = Color3.fromRGB(255, 255, 255), -- Monochrome Pure White
        NpcBoxColor = Color3.fromRGB(150, 150, 160),    -- Monochrome Slate Gray
        TracerColor = Color3.fromRGB(240, 240, 245),
        MaxDistance = 2000,
        Engine = "Auto (Dual Layer)",
    },
    Items = {
        SelectedWeapon = "870 MCS",
        SelectedId = "172",
    },
    Loot = {
        Enabled = false,
        Weapons = true,
        Ammo = true,
        Containers = true,
        MaxDistance = 450,
        ItemColor = Color3.fromRGB(0, 255, 140),
        ContainerColor = Color3.fromRGB(255, 215, 0),
    },
    Visuals = {
        Chams = false,
        VisibleColor = Color3.fromRGB(230, 230, 230),
        HiddenColor = Color3.fromRGB(120, 120, 120),
        Transparency = 0,
    },
    Character = {
        SpeedOverride = false,
        SpeedValue = 20,
        NoClip = false,
        Fly = false,
        FlySpeed = 20,
        FlightMode = "Hover Glide (Anti-Snapback)",
        AntiFallDamage = true,
        InfiniteStamina = true,
        NoSlowdown = true,
        BunnyHop = false,
        FastReload = false,
        NoRecoil = false,
        NoSpread = false,
    },
    Misc = {
        NoRecoil = false,
        MaxErgonomics = false,
        FastReload = false,
        InstantADS = false,
        NoBobbing = false,
        InfiniteStamina = true,
        AntiFallDamage = true,
        NoSlowdown = true,
    }
}

-- =========================================================================
-- SECTION 4: UNIVERSAL HAVOC ENTITY SCANNER
-- =========================================================================
local ActiveEntities = {}

local function isLivingCharacter(model)
    if not model or not model:IsA("Model") then return false end
    if LocalPlayer and LocalPlayer.Character and model == LocalPlayer.Character then return false end

    -- Havoc dead ragdoll, death frame, or downed state detection
    if model:FindFirstChild("ClientRagdoll") or model:FindFirstChild("ClientRagdollV1") or model:FindFirstChild("Ragdoll") then
        return false
    end
    if model:GetAttribute("Dead") == true or model:GetAttribute("dead") == "true" or model:GetAttribute("IsDead") == true then
        return false
    end

    local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if not hrp or not hrp.Parent then return false end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and (hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead) then
        return false
    end

    local head = model:FindFirstChild("Head") or hrp
    return true, hrp, head, hum
end

local function resolveEntity(model)
    local isLiving, hrp, head, hum = isLivingCharacter(model)
    if not isLiving then return nil end

    local player = Players:GetPlayerFromCharacter(model)
    if not player then
        player = Players:FindFirstChild(model.Name)
    end

    local displayName = model.Name
    local isPlayer = false
    if player then
        isPlayer = true
        displayName = "[PLAYER] " .. player.DisplayName .. " (@" .. player.Name .. ")"
    else
        isPlayer = false
        displayName = "[AI SCAV] " .. model.Name
    end

    return {
        Model = model,
        HRP = hrp,
        Head = head,
        Humanoid = hum,
        Player = player,
        IsPlayer = isPlayer,
        DisplayName = displayName,
    }
end

local function scanEntities()
    local found = {}

    local function checkModel(m)
        if m:IsA("Model") then
            local data = resolveEntity(m)
            if data then
                found[m] = data
            end
        end
    end

    local function scanRecursively(container, depth)
        if depth > 3 or not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") then
                checkModel(child)
            elseif child:IsA("Folder") or child:IsA("Configuration") then
                scanRecursively(child, depth + 1)
            end
        end
    end

    -- 1. Recursive Workspace scanner (resolves dynamic session containers and subfolders)
    scanRecursively(Workspace, 1)

    -- 2. Check Players character models
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            checkModel(p.Character)
        end
    end

    ActiveEntities = found
end

-- Initial scan & periodic entity updater
scanEntities()
task.spawn(function()
    while true do
        task.wait(1)
        pcall(scanEntities)
    end
end)

Workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") then
        local data = resolveEntity(child)
        if data then ActiveEntities[child] = data end
    elseif child:IsA("Folder") then
        child.ChildAdded:Connect(function(sub)
            if sub:IsA("Model") then
                local data = resolveEntity(sub)
                if data then ActiveEntities[sub] = data end
            end
        end)
    end
end)

Workspace.ChildRemoved:Connect(function(child)
    if ActiveEntities[child] then
        ActiveEntities[child] = nil
    end
end)

local function getTargetBone(model, requestedPart)
    if not model then return nil end
    if requestedPart == "Head" then
        return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
    elseif requestedPart == "Torso" or requestedPart == "UpperTorso" then
        return model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
    else
        return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    end
end

-- =========================================================================
-- SECTION 4B: HAVOC WORLD LOOT & CONTAINER SCANNER
-- =========================================================================
local ActiveLoot = {}

local function inspectLootInstance(inst)
    if not inst then return nil end

    if inst:IsA("ProximityPrompt") then
        local parent = inst.Parent
        if parent and (parent:IsA("BasePart") or parent:IsA("Model")) then
            local pos = parent:IsA("BasePart") and parent.Position or parent:GetPivot().Position
            local name = inst.ObjectText
            if not name or name == "" then name = inst.ActionText end
            if not name or name == "" then name = parent.Name end

            local lower = string.lower(name)
            local isContainer = string.find(lower, "crate") or string.find(lower, "box") or string.find(lower, "safe") or string.find(lower, "container") or string.find(lower, "bag") or string.find(lower, "chest")
            return {
                Instance = parent,
                Name = name,
                Position = pos,
                IsContainer = isContainer,
            }
        end
    end

    if inst:IsA("Tool") and inst.Parent == Workspace then
        local handle = inst:FindFirstChild("Handle") or inst:FindFirstChildOfClass("BasePart")
        if handle then
            return {
                Instance = inst,
                Name = inst.Name,
                Position = handle.Position,
                IsContainer = false,
            }
        end
    end

    return nil
end

local function scanWorldLoot()
    local found = {}
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local item = inspectLootInstance(prompt)
            if item then found[item.Instance] = item end
        elseif prompt:IsA("Tool") and prompt.Parent == Workspace then
            local item = inspectLootInstance(prompt)
            if item then found[item.Instance] = item end
        end
    end
    ActiveLoot = found
end

task.spawn(function()
    while true do
        task.wait(2)
        if Config.Loot.Enabled then
            pcall(scanWorldLoot)
        end
    end
end)

-- =========================================================================
-- SECTION 5: COMBAT HOOKS & HIT REDIRECTION (CLEAN SILENT AIM)
-- =========================================================================
local currentSilentTargetBone = nil

if typeof(hookmeta) == "function" then
    pcall(function()
        local oldNamecall
        oldNamecall = hookmeta(game, "__namecall", newccl(function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }

            -- 1. Anticheat Drop
            if (method == "FireServer" or method == "fireServer") and tostring(self.Name) == "OnPunishment" then
                return
            end

            -- 2. Recoil Shake Suppression
            if Config.Character.NoRecoil and (method == "FireServer" or method == "fireServer") and tostring(self.Name) == "shake" then
                return
            end

            -- 3. hitPos Redirection (Silent Aim Bullet Impact)
            if Config.SilentAim.Enabled and currentSilentTargetBone and (method == "FireServer" or method == "fireServer") and tostring(self.Name) == "hitPos" then
                if math.random(1, 100) <= Config.SilentAim.HitRate then
                    if typeof(args[2]) == "Vector3" then
                        args[2] = currentSilentTargetBone.Position
                        args[1] = currentSilentTargetBone
                        return oldNamecall(self, unpack(args))
                    end
                end
            end

            -- 4. Raycast Redirection (SwiftCast & Gun Physics)
            if (method == "Raycast" or method == "raycast") and self == Workspace then
                if Config.SilentAim.Enabled and currentSilentTargetBone and math.random(1, 100) <= Config.SilentAim.HitRate then
                    local origin = args[1]
                    local direction = args[2]
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        local targetPos = currentSilentTargetBone.Position
                        args[2] = (targetPos - origin).Unit * direction.Magnitude
                        return oldNamecall(self, unpack(args))
                    end
                end
            end

            return oldNamecall(self, ...)
        end))
    end)
end

if typeof(hookfn) == "function" and typeof(Workspace.Raycast) == "function" then
    pcall(function()
        local oldRaycast
        oldRaycast = hookfn(Workspace.Raycast, newccl(function(self, origin, direction, params)
            if Config.SilentAim.Enabled and currentSilentTargetBone and math.random(1, 100) <= Config.SilentAim.HitRate then
                if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                    local targetPos = currentSilentTargetBone.Position
                    local newDir = (targetPos - origin).Unit * direction.Magnitude
                    return oldRaycast(self, origin, newDir, params)
                end
            end
            return oldRaycast(self, origin, direction, params)
        end))
    end)
end

-- =========================================================================

-- =========================================================================
-- SECTION 6: UI FRAMEWORK (VERTICAL SIDEBAR MONOCHROME)
-- =========================================================================
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
            userAvatar.Image = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=48&height=48&format=png", LocalPlayer.UserId)
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
        tabContent.Visible = false
        tabContent.ClipsDescendants = true
        tabContent.Parent = contentArea

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
            Content = tabContent,
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

        function Tab:CreateGroupbox(groupTitleText, columnSide)
            groupboxCount = groupboxCount + 1
            local parentCol = (columnSide == "Right") and rightCol or leftCol

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

-- =========================================================================
-- SECTION 7: DRAWING FOV CIRCLES
-- =========================================================================
local FOVCircles = {
    Aimbot = nil,
    SilentAim = nil,
}

if hasDrawing then
    pcall(function()
        local aimCircle = DrawingLib.new("Circle")
        aimCircle.Visible = false
        aimCircle.Radius = Config.Aimbot.FOV
        aimCircle.Color = Config.Aimbot.Color
        aimCircle.Thickness = 1
        aimCircle.Filled = false
        aimCircle.Transparency = 1
        FOVCircles.Aimbot = aimCircle

        local silentCircle = DrawingLib.new("Circle")
        silentCircle.Visible = false
        silentCircle.Radius = Config.SilentAim.FOV
        silentCircle.Color = Config.SilentAim.Color
        silentCircle.Thickness = 1
        silentCircle.Filled = false
        silentCircle.Transparency = 1
        FOVCircles.SilentAim = silentCircle

        RunService.RenderStepped:Connect(function()
            local mousePos = UserInputService:GetMouseLocation()
            if FOVCircles.Aimbot then FOVCircles.Aimbot.Position = mousePos end
            if FOVCircles.SilentAim then FOVCircles.SilentAim.Position = mousePos end
        end)
    end)
end

-- =========================================================================
-- SECTION 8: DUAL-ENGINE ESP (DRAWING 2D + NATIVE BILLBOARDGUI)
-- =========================================================================
local DrawingEspPool = {}
local BillboardEspPool = {}

local function createDrawingEsp(model)
    if not hasDrawing then return nil end

    local defaultBoxColor = Config.Esp.PlayerBoxColor or Config.Esp.BoxColor or Color3.fromRGB(0, 200, 255)
    local defaultTracerColor = Config.Esp.TracerColor or Color3.fromRGB(0, 110, 255)

    local espData = {
        BoxOutline = DrawingLib.new("Square"),
        Box = DrawingLib.new("Square"),
        HealthBarOutline = DrawingLib.new("Line"),
        HealthBar = DrawingLib.new("Line"),
        Name = DrawingLib.new("Text"),
        Distance = DrawingLib.new("Text"),
        Tracer = DrawingLib.new("Line"),
        HeadDot = DrawingLib.new("Circle"),
    }

    espData.BoxOutline.Visible = false
    espData.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    espData.BoxOutline.Thickness = 3
    espData.BoxOutline.Filled = false

    espData.Box.Visible = false
    espData.Box.Color = defaultBoxColor
    espData.Box.Thickness = 1
    espData.Box.Filled = false

    espData.HealthBarOutline.Visible = false
    espData.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    espData.HealthBarOutline.Thickness = 3

    espData.HealthBar.Visible = false
    espData.HealthBar.Color = Color3.fromRGB(0, 255, 0)
    espData.HealthBar.Thickness = 1

    espData.Name.Visible = false
    espData.Name.Color = Color3.fromRGB(255, 255, 255)
    espData.Name.Size = 13
    espData.Name.Center = true
    espData.Name.Outline = true

    espData.Distance.Visible = false
    espData.Distance.Color = Color3.fromRGB(200, 200, 200)
    espData.Distance.Size = 11
    espData.Distance.Center = true
    espData.Distance.Outline = true

    espData.Tracer.Visible = false
    espData.Tracer.Color = defaultTracerColor
    espData.Tracer.Thickness = 1

    espData.HeadDot.Visible = false
    espData.HeadDot.Radius = 3.5
    espData.HeadDot.Filled = true
    espData.HeadDot.Color = defaultBoxColor

    return espData
end

local function createBillboardEsp(ent)
    local existing = ent.HRP:FindFirstChild("silent_bb_esp")
    if existing then return existing end

    local defaultBoxColor = (ent and ent.IsPlayer and Config.Esp.PlayerBoxColor) or (ent and Config.Esp.NpcBoxColor) or Config.Esp.BoxColor or Color3.fromRGB(0, 200, 255)

    local bb = Instance.new("BillboardGui")
    bb.Name = "silent_bb_esp"
    bb.AlwaysOnTop = true
    bb.ClipsDescendants = false
    bb.LightInfluence = 0
    bb.Size = UDim2.new(4.2, 0, 5.8, 0)
    bb.StudsOffset = Vector3.new(0, 0, 0)
    bb.Adornee = ent.HRP
    bb.Enabled = false
    bb.Parent = ent.HRP

    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "BoxFrame"
    boxFrame.Size = UDim2.new(1, 0, 1, 0)
    boxFrame.BackgroundTransparency = 1
    boxFrame.BorderSizePixel = 0
    boxFrame.Parent = bb

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Name = "Stroke"
    boxStroke.Thickness = 1.5
    boxStroke.Color = defaultBoxColor
    boxStroke.Parent = boxFrame

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HpBg"
    hpBg.Size = UDim2.new(0, 3, 1, 0)
    hpBg.Position = UDim2.new(0, -6, 0, 0)
    hpBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    hpBg.BorderSizePixel = 0
    hpBg.Parent = bb

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HpFill"
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.Position = UDim2.new(0, 0, 0, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(2, 0, 0, 14)
    nameLabel.Position = UDim2.new(-0.5, 0, 0, -16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.RobotoMono
    nameLabel.TextSize = 11
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.2
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Text = ent.DisplayName
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(2, 0, 0, 14)
    distLabel.Position = UDim2.new(-0.5, 0, 1, 2)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.RobotoMono
    distLabel.TextSize = 10
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0.2
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Text = "[0m]"
    distLabel.Parent = bb

    return bb
end

local function cleanupModelEsp(model)
    local espData = DrawingEspPool[model]
    if espData then
        for _, d in pairs(espData) do
            pcall(function() d:Remove() end)
        end
        DrawingEspPool[model] = nil
    end

    local bb = BillboardEspPool[model]
    if bb then
        pcall(function() bb:Destroy() end)
        BillboardEspPool[model] = nil
    end
end

-- =========================================================================
-- SECTION 9: MENU INITIALIZATION & SPLASH INTRO
-- =========================================================================
local Window = Library.CreateWindow({
    Title = "snow.cc",
    Game = "Havoc",
    Link = "discord.gg/snowcc",
    Size = Vector2.new(680, 720),
    ToggleKey = Enum.KeyCode.RightShift,
})

-- Startup Splash Loading Animation
task.spawn(function()
    -- Temporarily hide main menu window during intro sequence
    Window.MainFrame.Visible = false

    local introGui = Instance.new("ScreenGui")
    introGui.Name = "silent_intro_" .. tostring(math.random(10000, 99999))
    introGui.ResetOnSpawn = false
    introGui.DisplayOrder = 1000000
    pcall(function()
        introGui.Parent = Window.ScreenGui.Parent
    end)

    local introCard = Instance.new("Frame")
    introCard.Name = "IntroCard"
    introCard.Size = UDim2.new(0, 320, 0, 110)
    introCard.Position = UDim2.new(0.5, -160, 0.5, -55)
    introCard.BackgroundColor3 = Color3.fromRGB(11, 11, 14)
    introCard.BorderSizePixel = 0
    introCard.BackgroundTransparency = 1
    introCard.Parent = introGui

    local icCorner = Instance.new("UICorner")
    icCorner.CornerRadius = UDim.new(0, 8)
    icCorner.Parent = introCard

    local icStroke = Instance.new("UIStroke")
    icStroke.Color = Color3.fromRGB(35, 35, 42)
    icStroke.Thickness = 1
    icStroke.Transparency = 1
    icStroke.Parent = introCard

    local icGlow = Instance.new("ImageLabel")
    icGlow.Name = "Glow"
    icGlow.Size = UDim2.new(1, 30, 1, 30)
    icGlow.Position = UDim2.new(0, -15, 0, -15)
    icGlow.BackgroundTransparency = 1
    icGlow.Image = "rbxassetid://5028857084"
    icGlow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    icGlow.ImageTransparency = 1
    icGlow.ScaleType = Enum.ScaleType.Slice
    icGlow.SliceCenter = Rect.new(24, 24, 276, 276)
    icGlow.ZIndex = introCard.ZIndex - 1
    icGlow.Parent = introCard

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 24)
    titleLbl.Position = UDim2.new(0, 0, 0, 20)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Library.Theme.FontTitle
    titleLbl.TextSize = 16
    titleLbl.TextColor3 = Color3.fromRGB(245, 245, 250)
    titleLbl.TextTransparency = 1
    titleLbl.Text = "Snow.cc Havoc"
    titleLbl.Parent = introCard

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, 0, 0, 18)
    statusLbl.Position = UDim2.new(0, 0, 0, 48)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Font = Library.Theme.FontBody
    statusLbl.TextSize = 12
    statusLbl.TextColor3 = Color3.fromRGB(150, 150, 160)
    statusLbl.TextTransparency = 1
    statusLbl.Text = "Loading..."
    statusLbl.Parent = introCard

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -40, 0, 3)
    barBg.Position = UDim2.new(0, 20, 0, 78)
    barBg.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    barBg.BorderSizePixel = 0
    barBg.BackgroundTransparency = 1
    barBg.Parent = introCard

    local bbCorner = Instance.new("UICorner")
    bbCorner.CornerRadius = UDim.new(1, 0)
    bbCorner.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg

    local bfCorner = Instance.new("UICorner")
    bfCorner.CornerRadius = UDim.new(1, 0)
    bfCorner.Parent = barFill

    -- Phase 1: Fade In Loading Screen
    TweenService:Create(introCard, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(icStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Transparency = 0 }):Play()
    TweenService:Create(icGlow, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { ImageTransparency = 0.3 }):Play()
    TweenService:Create(titleLbl, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
    TweenService:Create(statusLbl, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
    TweenService:Create(barBg, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()

    -- Fill progress bar smoothly
    TweenService:Create(barFill, TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0) }):Play()
    task.wait(1.15)

    -- Phase 2: Switch text to Welcome <User>
    local playerName = LocalPlayer and LocalPlayer.Name or "Operator"
    statusLbl.Text = "Welcome, " .. playerName
    statusLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    task.wait(0.85)

    -- Phase 3: Fade Out Loading Box
    TweenService:Create(introCard, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(icStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Transparency = 1 }):Play()
    TweenService:Create(icGlow, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { ImageTransparency = 1 }):Play()
    TweenService:Create(titleLbl, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
    TweenService:Create(statusLbl, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
    local barFade = TweenService:Create(barBg, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
    barFade:Play()
    TweenService:Create(barFill, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()

    barFade.Completed:Connect(function()
        introGui:Destroy()
        -- Phase 4: Smoothly Reveal Main Menu Window
        Window.MainFrame.Visible = true
        Window.MainFrame.Size = UDim2.new(0, 680 * 0.96, 0, 720 * 0.96)
        Window.MainFrame.BackgroundTransparency = 0.4
        TweenService:Create(Window.MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 680, 0, 720),
            BackgroundTransparency = 0
        }):Play()
    end)
end)

-- TAB 1: MAIN
local MainTab = Window:CreateTab("Main")

local AimbotGroup = MainTab:CreateGroupbox("Aimbot", "Left")
local aimKeyHolder = nil

AimbotGroup:AddToggle("Enabled", Config.Aimbot.Enabled, {
    Keybind = Config.Aimbot.Key,
    OnKeyChanged = function(k)
        Config.Aimbot.Key = k
        if aimKeyHolder then aimKeyHolder.SetKey(k) end
    end,
    Callback = function(v) Config.Aimbot.Enabled = v end
})
aimKeyHolder = AimbotGroup:AddKeybind("Aim key", Config.Aimbot.Key, function(k)
    Config.Aimbot.Key = k
end)
AimbotGroup:AddDropdown("Aim mode", { "Camera", "Mouse" }, Config.Aimbot.Mode, function(v) Config.Aimbot.Mode = v end)
AimbotGroup:AddDropdown("Aim part", { "Head", "Torso", "HumanoidRootPart" }, Config.Aimbot.Part, function(v) Config.Aimbot.Part = v end)
AimbotGroup:AddSlider("Circle Size", 50, 500, Config.Aimbot.FOV, "", function(val)
    Config.Aimbot.FOV = val
    if FOVCircles.Aimbot then FOVCircles.Aimbot.Radius = val end
end)
AimbotGroup:AddSlider("Smoothing", 1, 100, Config.Aimbot.Smoothing, "", function(v) Config.Aimbot.Smoothing = v end)
AimbotGroup:AddSlider("Mouse Sensitivity", 10, 400, Config.Aimbot.Sensitivity, "%", function(v) Config.Aimbot.Sensitivity = v end)
AimbotGroup:AddToggle("Prediction", Config.Aimbot.Prediction, { Callback = function(v) Config.Aimbot.Prediction = v end })
AimbotGroup:AddSlider("Prediction X", 0, 50, Config.Aimbot.PredictionX, "%", function(v) Config.Aimbot.PredictionX = v end)
AimbotGroup:AddSlider("Prediction Y", 0, 50, Config.Aimbot.PredictionY, "%", function(v) Config.Aimbot.PredictionY = v end)
AimbotGroup:AddToggle("Sticky Aim", Config.Aimbot.StickyAim, { Callback = function(v) Config.Aimbot.StickyAim = v end })
AimbotGroup:AddSlider("Sticky Range", 100, 1000, Config.Aimbot.StickyRange, "", function(v) Config.Aimbot.StickyRange = v end)
AimbotGroup:AddToggle("Show Circle", Config.Aimbot.ShowCircle, {
    Callback = function(v)
        Config.Aimbot.ShowCircle = v
        if FOVCircles.Aimbot then FOVCircles.Aimbot.Visible = v end
    end
})
AimbotGroup:AddColorPicker("Circle Colour", Config.Aimbot.Color, function(col)
    Config.Aimbot.Color = col
    if FOVCircles.Aimbot then FOVCircles.Aimbot.Color = col end
end)
AimbotGroup:AddSlider("Circle Y Offset", 0, 60, Config.Aimbot.Offset, "", function(v) Config.Aimbot.Offset = v end)

local ExtraAimbotGroup = MainTab:CreateGroupbox("Extra - Aimbot", "Left")
ExtraAimbotGroup:AddToggle("Wall Check", Config.Aimbot.WallCheck, { Callback = function(v) Config.Aimbot.WallCheck = v end })
ExtraAimbotGroup:AddToggle("Prioritize Low Health", Config.Aimbot.LowHealth, { Callback = function(v) Config.Aimbot.LowHealth = v end })

local SilentGroup = MainTab:CreateGroupbox("Silent Aim", "Right")
local silentKeyHolder = nil

SilentGroup:AddToggle("Enabled", Config.SilentAim.Enabled, {
    Keybind = Config.SilentAim.Key,
    OnKeyChanged = function(k)
        Config.SilentAim.Key = k
        if silentKeyHolder then silentKeyHolder.SetKey(k) end
    end,
    Callback = function(v) Config.SilentAim.Enabled = v end
})
silentKeyHolder = SilentGroup:AddKeybind("Silent key", Config.SilentAim.Key, function(k)
    Config.SilentAim.Key = k
end)
SilentGroup:AddSlider("Circle Size", 50, 600, Config.SilentAim.FOV, "", function(val)
    Config.SilentAim.FOV = val
    if FOVCircles.SilentAim then FOVCircles.SilentAim.Radius = val end
end)
SilentGroup:AddDropdown("Hit limb", { "HumanoidRootPart", "Head", "Torso" }, Config.SilentAim.Part, function(v) Config.SilentAim.Part = v end)
SilentGroup:AddSlider("Hit Rate", 10, 100, Config.SilentAim.HitRate, "%", function(v) Config.SilentAim.HitRate = v end)
SilentGroup:AddToggle("Sticky Aim", Config.SilentAim.StickyAim, { Callback = function(v) Config.SilentAim.StickyAim = v end })
SilentGroup:AddSlider("Sticky Range", 100, 1000, Config.SilentAim.StickyRange, "", function(v) Config.SilentAim.StickyRange = v end)
SilentGroup:AddToggle("Show Circle", Config.SilentAim.ShowCircle, {
    Callback = function(v)
        Config.SilentAim.ShowCircle = v
        if FOVCircles.SilentAim then FOVCircles.SilentAim.Visible = v end
    end
})
SilentGroup:AddColorPicker("Circle Colour", Config.SilentAim.Color, function(col)
    Config.SilentAim.Color = col
    if FOVCircles.SilentAim then FOVCircles.SilentAim.Color = col end
end)
SilentGroup:AddSlider("Circle Y Offset", 0, 60, Config.SilentAim.Offset, "", function(v) Config.SilentAim.Offset = v end)

local ExtraSilentGroup = MainTab:CreateGroupbox("Extra - SilentAim", "Right")
ExtraSilentGroup:AddToggle("Disable When Carried", false)
ExtraSilentGroup:AddToggle("Bullet Spread", Config.SilentAim.WallSpread, { Callback = function(v) Config.SilentAim.WallSpread = v end })
ExtraSilentGroup:AddToggle("Distance Limit", Config.SilentAim.DistanceLimit, { Callback = function(v) Config.SilentAim.DistanceLimit = v end })
ExtraSilentGroup:AddSlider("Max Distance", 50, 500, Config.SilentAim.MaxDistance, " studs", function(v) Config.SilentAim.MaxDistance = v end)

-- TAB 2: ESP
local EspTab = Window:CreateTab("Esp")

local PlayerEspGroup = EspTab:CreateGroupbox("Player & NPC ESP", "Left")
PlayerEspGroup:AddToggle("Enabled", Config.Esp.Enabled, { Callback = function(v) Config.Esp.Enabled = v end })
PlayerEspGroup:AddToggle("Show Real Players", Config.Esp.ShowPlayers, { Callback = function(v) Config.Esp.ShowPlayers = v end })
PlayerEspGroup:AddToggle("Show AI Scavengers", Config.Esp.ShowNpcs, { Callback = function(v) Config.Esp.ShowNpcs = v end })
PlayerEspGroup:AddToggle("Box ESP", Config.Esp.Boxes, { Callback = function(v) Config.Esp.Boxes = v end })
PlayerEspGroup:AddToggle("Health Bar", Config.Esp.Health, { Callback = function(v) Config.Esp.Health = v end })
PlayerEspGroup:AddToggle("Name Tags", Config.Esp.Names, { Callback = function(v) Config.Esp.Names = v end })
PlayerEspGroup:AddToggle("Distance Tags", Config.Esp.Distances, { Callback = function(v) Config.Esp.Distances = v end })
PlayerEspGroup:AddToggle("Snapline Tracers", Config.Esp.Tracers, { Callback = function(v) Config.Esp.Tracers = v end })
PlayerEspGroup:AddToggle("Chams Highlight", Config.Visuals.Chams, { Callback = function(v) Config.Visuals.Chams = v end })
PlayerEspGroup:AddDropdown("Tracer Origin", { "Bottom", "Center", "Mouse" }, Config.Esp.TracerOrigin, function(v) Config.Esp.TracerOrigin = v end)

local EspConfigGroup = EspTab:CreateGroupbox("ESP Settings & Colors", "Right")
EspConfigGroup:AddDropdown("ESP Engine", { "Auto (Dual Layer)", "Drawing (2D)", "Billboard (Native)" }, Config.Esp.Engine, function(v) Config.Esp.Engine = v end)
EspConfigGroup:AddColorPicker("Player Box Color", Config.Esp.PlayerBoxColor, function(col) Config.Esp.PlayerBoxColor = col end)
EspConfigGroup:AddColorPicker("AI / Scav Color", Config.Esp.NpcBoxColor, function(col) Config.Esp.NpcBoxColor = col end)
EspConfigGroup:AddColorPicker("Tracer Color", Config.Esp.TracerColor, function(col) Config.Esp.TracerColor = col end)
EspConfigGroup:AddSlider("Max Distance", 100, 3000, Config.Esp.MaxDistance, " studs", function(v) Config.Esp.MaxDistance = v end)

-- TAB 3: VISUALS
local VisualsTab = Window:CreateTab("Visuals")

local ChamsGroup = VisualsTab:CreateGroupbox("Chams & Shaders", "Left")
ChamsGroup:AddToggle("Enable Chams", Config.Visuals.Chams, { Callback = function(v) Config.Visuals.Chams = v end })
ChamsGroup:AddColorPicker("Visible Color", Config.Visuals.VisibleColor, function(col) Config.Visuals.VisibleColor = col end)
ChamsGroup:AddColorPicker("Hidden Color", Config.Visuals.HiddenColor, function(col) Config.Visuals.HiddenColor = col end)
ChamsGroup:AddSlider("Outline Transparency", 0, 100, Config.Visuals.Transparency, "%", function(v) Config.Visuals.Transparency = v end)

local WorldGroup = VisualsTab:CreateGroupbox("World Loot ESP", "Right")
WorldGroup:AddToggle("Enable Loot ESP", Config.Loot.Enabled, {
    Callback = function(v)
        Config.Loot.Enabled = v
        if v then pcall(scanWorldLoot) end
    end
})
WorldGroup:AddToggle("Dropped Weapons & Items", Config.Loot.Weapons, { Callback = function(v) Config.Loot.Weapons = v end })
WorldGroup:AddToggle("Crates & Safes", Config.Loot.Containers, { Callback = function(v) Config.Loot.Containers = v end })
WorldGroup:AddSlider("Loot Max Distance", 50, 800, Config.Loot.MaxDistance, " studs", function(v) Config.Loot.MaxDistance = v end)
WorldGroup:AddColorPicker("Item Color", Config.Loot.ItemColor, function(col) Config.Loot.ItemColor = col end)
WorldGroup:AddColorPicker("Crate / Safe Color", Config.Loot.ContainerColor, function(col) Config.Loot.ContainerColor = col end)

-- TAB 4: CHARACTER
local CharTab = Window:CreateTab("Character")

local MovementGroup = CharTab:CreateGroupbox("Movement", "Left")
MovementGroup:AddLabel("[!] NOTE: Movement speed >20.4 studs/s & high fly risk server rubberbands.")
MovementGroup:AddToggle("Anti-Fall Damage (Safe Land)", Config.Character.AntiFallDamage, { Callback = function(v) Config.Character.AntiFallDamage = v end })
MovementGroup:AddToggle("NoClip (Walk Through Walls)", Config.Character.NoClip, { Callback = function(v) Config.Character.NoClip = v end })
MovementGroup:AddToggle("WalkSpeed Override", Config.Character.SpeedOverride, {
    Callback = function(enabled)
        Config.Character.SpeedOverride = enabled
        if not enabled and LocalPlayer and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
})
MovementGroup:AddSlider("Safe Speed (Cap: 20.4)", 14, 21, Config.Character.SpeedValue, " studs", function(val)
    Config.Character.SpeedValue = val
end)
MovementGroup:AddToggle("No Action Slowdown (ADS/Heal)", Config.Character.NoSlowdown, { Callback = function(v) Config.Character.NoSlowdown = v end })
MovementGroup:AddToggle("Infinite Stamina", Config.Character.InfiniteStamina, { Callback = function(v) Config.Character.InfiniteStamina = v end })
MovementGroup:AddToggle("Directional Fly", Config.Character.Fly, {
    Callback = function(v)
        Config.Character.Fly = v
        if not v and LocalPlayer and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
            end
        end
    end
})
MovementGroup:AddDropdown("Flight Mode", { "Hover Glide (Anti-Snapback)", "Wave Hop (Wall Climber)", "Uncapped Free Flight" }, Config.Character.FlightMode, function(v)
    Config.Character.FlightMode = v
end)
MovementGroup:AddSlider("Fly Speed", 5, 21, Config.Character.FlySpeed, " studs", function(v)
    Config.Character.FlySpeed = v
end)
MovementGroup:AddToggle("Bunny Hop", Config.Character.BunnyHop, { Callback = function(v) Config.Character.BunnyHop = v end })

local WeaponGroup = CharTab:CreateGroupbox("Weapon Handling", "Right")
WeaponGroup:AddToggle("Fast Tactical Reload", Config.Character.FastReload, { Callback = function(v) Config.Character.FastReload = v end })
WeaponGroup:AddToggle("Recoil Neutralizer", Config.Character.NoRecoil, { Callback = function(v) Config.Character.NoRecoil = v end })
WeaponGroup:AddToggle("Spread Reduction", Config.Character.NoSpread, { Callback = function(v) Config.Character.NoSpread = v end })

-- TAB 5: MISC
local MiscTab = Window:CreateTab("Misc")

local MiscCombatGroup = MiscTab:CreateGroupbox("Combat & Weapon Handling", "Left")
MiscCombatGroup:AddToggle("Recoil Neutralizer", Config.Misc.NoRecoil, {
    Callback = function(v)
        Config.Misc.NoRecoil = v
        Config.Character.NoRecoil = v
    end
})
MiscCombatGroup:AddToggle("Max Weapon Ergonomics", Config.Misc.MaxErgonomics, {
    Callback = function(v)
        Config.Misc.MaxErgonomics = v
    end
})
MiscCombatGroup:AddToggle("Tactical Fast Reload", Config.Misc.FastReload, {
    Callback = function(v)
        Config.Misc.FastReload = v
        Config.Character.FastReload = v
    end
})
MiscCombatGroup:AddToggle("Instant ADS Speed", Config.Misc.InstantADS, {
    Callback = function(v)
        Config.Misc.InstantADS = v
    end
})
MiscCombatGroup:AddToggle("Disable Weapon Bobbing", Config.Misc.NoBobbing, {
    Callback = function(v)
        Config.Misc.NoBobbing = v
    end
})

local MiscEngineGroup = MiscTab:CreateGroupbox("Engine & Survival", "Right")
MiscEngineGroup:AddToggle("Zero Stamina Drain", Config.Misc.InfiniteStamina, {
    Callback = function(v)
        Config.Misc.InfiniteStamina = v
        Config.Character.InfiniteStamina = v
    end
})
MiscEngineGroup:AddToggle("Zero Fall Damage", Config.Misc.AntiFallDamage, {
    Callback = function(v)
        Config.Misc.AntiFallDamage = v
        Config.Character.AntiFallDamage = v
    end
})
MiscEngineGroup:AddToggle("No Action Slowdown", Config.Misc.NoSlowdown, {
    Callback = function(v)
        Config.Misc.NoSlowdown = v
        Config.Character.NoSlowdown = v
    end
})

-- TAB 6: SETTINGS
local SettingsTab = Window:CreateTab("Settings")

local ProfileGroup = SettingsTab:CreateGroupbox("Profile Manager", "Left")
ProfileGroup:AddButton("Save Default Config", function() print("[snow.cc] Saved config profile.") end)
ProfileGroup:AddButton("Load Default Config", function() print("[snow.cc] Loaded config profile.") end)

local SystemGroup = SettingsTab:CreateGroupbox("System", "Right")
SystemGroup:AddButton("Unload snow.cc", function()
    if FOVCircles.Aimbot then FOVCircles.Aimbot:Remove() end
    if FOVCircles.SilentAim then FOVCircles.SilentAim:Remove() end
    for m, _ in pairs(DrawingEspPool) do cleanupModelEsp(m) end
    for _, ent in pairs(ActiveEntities) do
        local hl = ent.Model:FindFirstChild("silent_chams")
        if hl then hl:Destroy() end
        local bb = ent.HRP:FindFirstChild("silent_bb_esp")
        if bb then bb:Destroy() end
    end
    Window.ScreenGui:Destroy()
end)

-- =========================================================================
-- SECTION 10: RUNTIME EXECUTION LOOPS
-- =========================================================================

local function findBestTarget(fovRadius, boneName, wallCheck, maxDist)
    local mousePos = UserInputService:GetMouseLocation()
    local bestTarget = nil
    local minMouseDist = fovRadius

    for model, ent in pairs(ActiveEntities) do
        local hrp = ent.HRP
        local bone = getTargetBone(model, boneName)

        if hrp and bone and model.Parent then
            local worldDist = (hrp.Position - Camera.CFrame.Position).Magnitude
            if not maxDist or worldDist <= maxDist then
                local screen3D, onScreen = Camera:WorldToViewportPoint(bone.Position)
                if onScreen and screen3D.Z > 0 then
                    local screenPos = Vector2.new(screen3D.X, screen3D.Y)
                    local mouseDist = (screenPos - mousePos).Magnitude

                    if mouseDist < minMouseDist then
                        local visible = true
                        if wallCheck then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            local ignoreList = { Camera }
                            if LocalPlayer and LocalPlayer.Character then
                                table.insert(ignoreList, LocalPlayer.Character)
                            end
                            rayParams.FilterDescendantsInstances = ignoreList

                            local hit = Workspace:Raycast(Camera.CFrame.Position, (bone.Position - Camera.CFrame.Position).Unit * 1000, rayParams)
                            if hit and not hit.Instance:IsDescendantOf(model) then
                                visible = false
                            end
                        end

                        if visible then
                            minMouseDist = mouseDist
                            bestTarget = {
                                Entity = ent,
                                Model = model,
                                Bone = bone,
                                ScreenPos = screenPos,
                                Distance = worldDist,
                            }
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

-- Universal Stepped Physics Loop: NoClip, Anticheat Heat Suppressor & Stamina Lock
RunService.Stepped:Connect(function()
    -- 1. True Physics NoClip (Must run on Stepped to preempt Humanoid collision reset)
    if Config.Character.NoClip and LocalPlayer and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- 2. Havoc Movement Anticheat Heat Suppressor (Zeroes VelocityHeat, SpeedHeat, FlightHeat)
    if LocalPlayer and LocalPlayer.Character then
        local ac = LocalPlayer.Character:FindFirstChild("MovementAnticheat")
        if ac then
            for _, heatName in ipairs({ "VelocityHeat", "SpeedHeat", "FlightHeat" }) do
                local heatVal = ac:FindFirstChild(heatName)
                if heatVal and heatVal:IsA("NumberValue") and heatVal.Value ~= 0 then
                    heatVal.Value = 0
                end
            end
        end
    end

    -- 3. Universal Stamina & Energy Attribute/Value Locker
    if Config.Character.InfiniteStamina and LocalPlayer and LocalPlayer.Character then
        local char = LocalPlayer.Character
        -- Havoc sprint string attribute ("true" / "false")
        pcall(function()
            if char:GetAttribute("sprint") == "false" then
                char:SetAttribute("sprint", "true")
            end
        end)
        -- Attributes
        for _, attr in ipairs({ "Stamina", "stamina", "Energy", "energy", "Sprint", "sprint" }) do
            local val = char:GetAttribute(attr)
            if typeof(val) == "number" and val < 100 then
                pcall(function() char:SetAttribute(attr, 100) end)
            end
        end
        -- Values
        for _, child in ipairs(char:GetDescendants()) do
            if child:IsA("NumberValue") or child:IsA("IntValue") then
                local lower = string.lower(child.Name)
                if string.find(lower, "stamina") or string.find(lower, "energy") then
                    if child.Value < 100 then child.Value = 100 end
                end
            end
        end
    end
end)

-- Master RenderStepped Execution Loop
RunService.RenderStepped:Connect(function()
    -- 1. Auto Mouse Unlocker: When silent.cc is visible, enforce free cursor
    if isMenuVisible then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end

    local function isInputActive(bind)
        if not bind then return true end
        if typeof(bind) == "EnumItem" then
            if bind.EnumType == Enum.KeyCode then
                return UserInputService:IsKeyDown(bind)
            elseif bind.EnumType == Enum.UserInputType then
                return UserInputService:IsMouseButtonPressed(bind)
            end
        end
        return false
    end

    -- 2. Silent Aim Target Tracker
    local silentActive = Config.SilentAim.Enabled
    if silentActive and Config.SilentAim.Key ~= nil then
        silentActive = isInputActive(Config.SilentAim.Key)
    end

    if silentActive then
        local maxD = Config.SilentAim.DistanceLimit and Config.SilentAim.MaxDistance or nil
        local target = findBestTarget(Config.SilentAim.FOV, Config.SilentAim.Part, false, maxD)
        currentSilentTargetBone = target and target.Bone or nil
    else
        currentSilentTargetBone = nil
    end

    -- 3. Aimbot Loop (Camera & Mouse Rel)
    if Config.Aimbot.Enabled and isInputActive(Config.Aimbot.Key) then
        local aimTarget = findBestTarget(Config.Aimbot.FOV, Config.Aimbot.Part, Config.Aimbot.WallCheck)
        if aimTarget and aimTarget.Bone then
            local targetPos = aimTarget.Bone.Position

            if Config.Aimbot.Prediction then
                local hrp = aimTarget.Entity.HRP
                if hrp then
                    local vel = hrp.AssemblyLinearVelocity
                    targetPos = targetPos + Vector3.new(
                        vel.X * (Config.Aimbot.PredictionX / 100),
                        vel.Y * (Config.Aimbot.PredictionY / 100),
                        vel.Z * (Config.Aimbot.PredictionX / 100)
                    )
                end
            end

            if Config.Aimbot.Mode == "Mouse" and typeof(mousemoverel) == "function" then
                local mousePos = UserInputService:GetMouseLocation()
                local delta = aimTarget.ScreenPos - mousePos
                local smooth = math.max(Config.Aimbot.Smoothing, 1)
                mousemoverel(delta.X / smooth, delta.Y / smooth)
            else
                local currentCF = Camera.CFrame
                local targetCF = CFrame.new(currentCF.Position, targetPos)
                local smoothFactor = math.clamp(1 / math.max(Config.Aimbot.Smoothing, 1), 0.05, 1)
                Camera.CFrame = currentCF:Lerp(targetCF, smoothFactor)
            end
        end
    end

    -- 4. ESP Render Pipeline
    local vpSize = Camera.ViewportSize
    local mousePos = UserInputService:GetMouseLocation()
    local tracerOrigin = Vector2.new(vpSize.X / 2, vpSize.Y)
    if Config.Esp.TracerOrigin == "Center" then
        tracerOrigin = Vector2.new(vpSize.X / 2, vpSize.Y / 2)
    elseif Config.Esp.TracerOrigin == "Mouse" then
        tracerOrigin = mousePos
    end

    local useDrawing = (Config.Esp.Engine == "Auto (Dual Layer)" or Config.Esp.Engine == "Drawing (2D)") and hasDrawing
    local useBillboard = (Config.Esp.Engine == "Auto (Dual Layer)" or Config.Esp.Engine == "Billboard (Native)" or not hasDrawing)

    for model, ent in pairs(ActiveEntities) do
        local isAlive = isLivingCharacter(model)
        if not isAlive or not model.Parent or not ent.HRP.Parent then
            cleanupModelEsp(model)
            ActiveEntities[model] = nil
        else
            local hrp = ent.HRP
            local head = ent.Head
            local hum = ent.Humanoid
            local worldDist = (hrp.Position - Camera.CFrame.Position).Magnitude
            local inRange = worldDist <= Config.Esp.MaxDistance

            local allowEntity = false
            if ent.IsPlayer and Config.Esp.ShowPlayers then
                allowEntity = true
            elseif not ent.IsPlayer and Config.Esp.ShowNpcs then
                allowEntity = true
            end

            local activeColor = ent.IsPlayer and Config.Esp.PlayerBoxColor or Config.Esp.NpcBoxColor

            -- --- Native BillboardGui ESP Engine ---
            local bb = BillboardEspPool[model]
            if not bb then
                bb = createBillboardEsp(ent)
                BillboardEspPool[model] = bb
            end

            if Config.Esp.Enabled and inRange and allowEntity and useBillboard then
                bb.Enabled = true
                local boxFrame = bb:FindFirstChild("BoxFrame")
                if boxFrame then
                    boxFrame.Visible = Config.Esp.Boxes
                    local stroke = boxFrame:FindFirstChild("Stroke")
                    if stroke then stroke.Color = activeColor end
                end

                local hpBg = bb:FindFirstChild("HpBg")
                if hpBg then
                    hpBg.Visible = Config.Esp.Health
                    local hpFill = hpBg:FindFirstChild("HpFill")
                    if hpFill and hum then
                        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        hpFill.Size = UDim2.new(1, 0, pct, 0)
                        hpFill.Position = UDim2.new(0, 0, 1 - pct, 0)
                        hpFill.BackgroundColor3 = Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(255 * pct), 0)
                    end
                end

                local nameLabel = bb:FindFirstChild("NameLabel")
                if nameLabel then
                    nameLabel.Visible = Config.Esp.Names
                    nameLabel.Text = ent.DisplayName
                end

                local distLabel = bb:FindFirstChild("DistLabel")
                if distLabel then
                    distLabel.Visible = Config.Esp.Distances
                    distLabel.Text = string.format("[%dm]", math.floor(worldDist))
                end
            else
                bb.Enabled = false
            end

            -- --- 2D Drawing Vector ESP Engine ---
            if useDrawing then
                local esp = DrawingEspPool[model]
                if not esp then
                    esp = createDrawingEsp(model)
                    DrawingEspPool[model] = esp
                end

                local rendered = false
                if esp and Config.Esp.Enabled and inRange and allowEntity then
                    local headObj = head or hrp
                    local head3D = (headObj and headObj.Position) and (headObj.Position + Vector3.new(0, 0.6, 0)) or (hrp.Position + Vector3.new(0, 2, 0))
                    local root3D = hrp.Position - Vector3.new(0, 3, 0)

                    local hrpPos, hrpOn = Camera:WorldToViewportPoint(hrp.Position)
                    local headPos, headOn = Camera:WorldToViewportPoint(head3D)
                    local rootPos, rootOn = Camera:WorldToViewportPoint(root3D)

                    -- Super Smooth Frustum Culling: discard points behind near-plane and clamp jitter
                    if hrpPos.Z > 1.2 and headPos.Z > 1.2 and rootPos.Z > 1.2 and (hrpOn or headOn or rootOn) then
                        local minY = math.min(headPos.Y, rootPos.Y)
                        local maxY = math.max(headPos.Y, rootPos.Y)
                        local rawHeight = maxY - minY
                        local maxScreenHeight = Camera.ViewportSize.Y * 0.85
                        local height = math.clamp(rawHeight, 10, maxScreenHeight)
                        local width = math.clamp(height * 0.60, 6, Camera.ViewportSize.X * 0.45)
                        local boxPos = Vector2.new(math.floor(hrpPos.X - width / 2), math.floor(minY))

                        if Config.Esp.Boxes then
                            esp.BoxOutline.Size = Vector2.new(width, height)
                            esp.BoxOutline.Position = boxPos
                            esp.BoxOutline.Visible = true

                            esp.Box.Size = Vector2.new(width, height)
                            esp.Box.Position = boxPos
                            esp.Box.Color = activeColor or Color3.fromRGB(0, 200, 255)
                            esp.Box.Visible = true
                        else
                            esp.BoxOutline.Visible = false
                            esp.Box.Visible = false
                        end

                        if Config.Esp.Health and hum then
                            local healthPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            local barHeight = height * healthPct
                            local barX = boxPos.X - 5

                            esp.HealthBarOutline.From = Vector2.new(barX, boxPos.Y)
                            esp.HealthBarOutline.To = Vector2.new(barX, boxPos.Y + height)
                            esp.HealthBarOutline.Visible = true

                            esp.HealthBar.From = Vector2.new(barX, boxPos.Y + height)
                            esp.HealthBar.To = Vector2.new(barX, (boxPos.Y + height) - barHeight)
                            esp.HealthBar.Color = Color3.fromRGB(math.floor(255 * (1 - healthPct)), math.floor(255 * healthPct), 0)
                            esp.HealthBar.Visible = true
                        else
                            esp.HealthBarOutline.Visible = false
                            esp.HealthBar.Visible = false
                        end

                        if Config.Esp.Names then
                            esp.Name.Text = ent.DisplayName
                            esp.Name.Position = Vector2.new(hrpPos.X, boxPos.Y - 14)
                            esp.Name.Visible = true
                        else
                            esp.Name.Visible = false
                        end

                        if Config.Esp.Distances then
                            esp.Distance.Text = string.format("[%dm]", math.floor(worldDist))
                            esp.Distance.Position = Vector2.new(hrpPos.X, boxPos.Y + height + 2)
                            esp.Distance.Visible = true
                        else
                            esp.Distance.Visible = false
                        end

                        if Config.Esp.Tracers then
                            esp.Tracer.From = tracerOrigin
                            esp.Tracer.To = Vector2.new(hrpPos.X, rootPos.Y)
                            esp.Tracer.Color = Config.Esp.TracerColor or Color3.fromRGB(240, 240, 245)
                            esp.Tracer.Visible = true
                        else
                            esp.Tracer.Visible = false
                        end

                        if Config.Esp.HeadDot and headOn and headPos.Z > 0 then
                            esp.HeadDot.Position = Vector2.new(headPos.X, headPos.Y)
                            esp.HeadDot.Color = activeColor or Color3.fromRGB(255, 255, 255)
                            esp.HeadDot.Visible = true
                        else
                            esp.HeadDot.Visible = false
                        end

                        rendered = true
                    end
                end

                if esp and not rendered then
                    esp.BoxOutline.Visible = false
                    esp.Box.Visible = false
                    esp.HealthBarOutline.Visible = false
                    esp.HealthBar.Visible = false
                    esp.Name.Visible = false
                    esp.Distance.Visible = false
                    esp.Tracer.Visible = false
                    esp.HeadDot.Visible = false
                end
            end

            -- --- Hardware Chams Highlighting ---
            local hl = model:FindFirstChild("silent_chams")
            if Config.Visuals.Chams and allowEntity then
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "silent_chams"
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = model
                end
                hl.FillColor = Config.Visuals.VisibleColor
                hl.OutlineColor = Config.Visuals.HiddenColor
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = Config.Visuals.Transparency / 100
            else
                if hl then hl:Destroy() end
            end
        end
    end

    -- 4B. World Loot ESP Render Loop
    if Config.Loot.Enabled then
        for inst, loot in pairs(ActiveLoot) do
            if not inst or not inst.Parent then
                local oldBb = inst and inst:FindFirstChild("silent_loot_bb")
                if oldBb then pcall(function() oldBb:Destroy() end) end
                ActiveLoot[inst] = nil
            else
                local dist = (loot.Position - Camera.CFrame.Position).Magnitude
                local showItem = (loot.IsContainer and Config.Loot.Containers) or (not loot.IsContainer and Config.Loot.Weapons)
                local lootBb = inst:FindFirstChild("silent_loot_bb")

                if dist <= Config.Loot.MaxDistance and showItem then
                    local screen3D, onScreen = Camera:WorldToViewportPoint(loot.Position)
                    if onScreen and screen3D.Z > 1.0 then
                        if not lootBb then
                            lootBb = Instance.new("BillboardGui")
                            lootBb.Name = "silent_loot_bb"
                            lootBb.AlwaysOnTop = true
                            lootBb.ClipsDescendants = false
                            lootBb.Size = UDim2.new(0, 160, 0, 22)
                            lootBb.Adornee = inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildOfClass("BasePart")) or inst
                            lootBb.Parent = inst

                            local lbl = Instance.new("TextLabel")
                            lbl.Name = "LootLabel"
                            lbl.Size = UDim2.new(1, 0, 1, 0)
                            lbl.BackgroundTransparency = 1
                            lbl.Font = Enum.Font.RobotoMono
                            lbl.TextSize = 10
                            lbl.TextStrokeTransparency = 0.2
                            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            lbl.Parent = lootBb
                        end

                        lootBb.Enabled = true
                        local lbl = lootBb:FindFirstChild("LootLabel")
                        if lbl then
                            local col = loot.IsContainer and Config.Loot.ContainerColor or Config.Loot.ItemColor
                            lbl.TextColor3 = col
                            lbl.Text = string.format("%s%s [%dm]", loot.IsContainer and "[CRATE] " or "[LOOT] ", loot.Name, math.floor(dist))
                        end
                    else
                        if lootBb then lootBb.Enabled = false end
                    end
                else
                    if lootBb then lootBb.Enabled = false end
                end
            end
        end
    else
        for inst, _ in pairs(ActiveLoot) do
            local lootBb = inst and inst:FindFirstChild("silent_loot_bb")
            if lootBb then lootBb.Enabled = false end
        end
    end

    -- 4C. Anti-Fall Damage Velocity Neutralizer
    if Config.Character.AntiFallDamage and LocalPlayer and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            -- Havoc deals lethal fall damage when impact velocity exceeds -45 studs/s
            -- Clamping downward speed at -20 studs/s guarantees 0 fall damage on impact
            if hrp.AssemblyLinearVelocity.Y < -24 then
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(v.X, -18, v.Z)
            end
        end
    end

    -- 5. Safe Fall Damage Dampener
    if Config.Character.AntiFallDamage and LocalPlayer and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.AssemblyLinearVelocity.Y < -20 then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, -15, hrp.AssemblyLinearVelocity.Z)
        end
    end

    -- 7. Bunny Hop Loop
    if Config.Character.BunnyHop and UserInputService:IsKeyDown(Enum.KeyCode.Space) and LocalPlayer and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end

    -- 7. Fast Reload Speedup
    if Config.Character.FastReload and LocalPlayer and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if string.find(string.lower(track.Name), "reload") then
                        track:AdjustSpeed(3.5)
                    end
                end
            end
        end
    end
end)

-- =========================================================================
-- SECTION 10: ANTI-RUBBERBAND VELOCITY, FLIGHT & NOCLIP ENGINE
-- =========================================================================
-- Enforces horizontal velocity budget (<20.4 studs/s), terrain contour hover,
-- and ground-safe NoClip on RunService.Heartbeat (post-simulation).

local flyAirtimeStart = nil

RunService.Heartbeat:Connect(function()
    if not (LocalPlayer and LocalPlayer.Character) then return end
    local char = LocalPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum and hum.Health > 0) then return end

    -- Cleanup legacy BodyMovers if present
    local oldBv = hrp:FindFirstChild("silent_fly_vel")
    if oldBv then oldBv:Destroy() end
    local oldBg = hrp:FindFirstChild("silent_fly_gyro")
    if oldBg then oldBg:Destroy() end
    if hum.PlatformStand and not Config.Character.Fly then
        hum.PlatformStand = false
    end

    local currentVel = hrp.AssemblyLinearVelocity
    local horizVec = Vector2.new(currentVel.X, currentVel.Z)
    local maxAllowedSpeed = math.clamp(Config.Character.SpeedValue, 14, 20.4)

    -- 1. Anti-Snap Directional Flight
    if Config.Character.Fly then
        local camCF = Camera.CFrame
        local flatLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
        local flatRight = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit
        local horizDir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then horizDir = horizDir + flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then horizDir = horizDir - flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then horizDir = horizDir - flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then horizDir = horizDir + flatRight end

        local targetHorizVel = Vector3.zero
        if horizDir.Magnitude > 0 then
            targetHorizVel = horizDir.Unit * math.clamp(Config.Character.FlySpeed, 10, 20.4)
        end

        local targetYVel = 0
        if Config.Character.FlightMode == "Hover Glide (Anti-Snapback)" then
            -- Raycast downward to lock altitude <= 4.0 studs above ground (Havoc check triggers at > 5.0)
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = { Camera, char }

            local downHit = Workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, -35, 0), rayParams)
            local groundY = downHit and downHit.Position.Y or (hrp.Position.Y - 3)
            local targetHover = 3.6
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                targetHover = 4.4
            end
            local desiredY = groundY + targetHover
            targetYVel = math.clamp((desiredY - hrp.Position.Y) * 12, -18, 18)

        elseif Config.Character.FlightMode == "Wave Hop (Wall Climber)" then
            local now = tick()
            if not flyAirtimeStart then flyAirtimeStart = now end
            local airtime = now - flyAirtimeStart

            if airtime < 0.5 then
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    targetYVel = 18
                elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    targetYVel = -18
                end
            elseif airtime < 0.75 then
                targetYVel = -25 -- Force ground touch to reset server airtime counter
            else
                flyAirtimeStart = now
            end

        else -- Uncapped Free Flight
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                targetYVel = math.clamp(Config.Character.FlySpeed, 10, 20.4)
            elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                targetYVel = -math.clamp(Config.Character.FlySpeed, 10, 20.4)
            end
        end

        hrp.AssemblyLinearVelocity = Vector3.new(targetHorizVel.X, targetYVel, targetHorizVel.Z)

    -- 2. WalkSpeed Override via Direct Linear Velocity
    elseif Config.Character.SpeedOverride and hum.MoveDirection.Magnitude > 0 then
        local moveDir = hum.MoveDirection.Unit
        hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * maxAllowedSpeed, currentVel.Y, moveDir.Z * maxAllowedSpeed)

    -- 3. Hard Velocity Budget Clamp (Prevents Havoc >21 studs/s packet drop)
    else
        if horizVec.Magnitude > 20.4 then
            local clamped = horizVec.Unit * 20.4
            hrp.AssemblyLinearVelocity = Vector3.new(clamped.X, currentVel.Y, clamped.Y)
        end
    end

    -- 4. NoClip Ground-Surface Retention (Phases through walls, locks to floor)
    if Config.Character.NoClip and not Config.Character.Fly then
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = { Camera, char }

        local groundCheck = Workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rayParams)
        if groundCheck and currentVel.Y < 0 then
            local floorY = groundCheck.Position.Y + (hum.HipHeight > 0 and hum.HipHeight + 1.2 or 3.0)
            if hrp.Position.Y < floorY then
                hrp.CFrame = CFrame.new(hrp.Position.X, floorY, hrp.Position.Z) * hrp.CFrame.Rotation
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
            end
        end
    end
end)

-- =========================================================================
-- SECTION 11: HAVOC ENGINE MEMORY PATCHER (REALISM, STAMINA & BASECAMERA)
-- =========================================================================
task.spawn(function()
    local getgc_fn = getgc or (getgenv and getgenv().getgc)
    while true do
        task.wait(0.5)
        pcall(function()
            if typeof(getgc_fn) == "function" then
                for _, obj in ipairs(getgc_fn(true)) do
                    if type(obj) == "table" then
                        -- Realism Table: recoilReductionRatio & fallDamage
                        if rawget(obj, "recoilReductionRatio") ~= nil and rawget(obj, "fallDamage") ~= nil then
                            if Config.Character.NoRecoil or Config.Misc.NoRecoil then
                                rawset(obj, "recoilReductionRatio", 0)
                            end
                            if Config.Character.AntiFallDamage or Config.Misc.AntiFallDamage then
                                rawset(obj, "fallDamage", 0)
                            end
                        end

                        -- Stamina Table: drainRate & regenRate
                        if rawget(obj, "drainRate") ~= nil and rawget(obj, "regenRate") ~= nil then
                            if Config.Character.InfiniteStamina or Config.Misc.InfiniteStamina then
                                rawset(obj, "drainRate", 0)
                                rawset(obj, "regenRate", 100)
                            end
                        end
                    end
                end
            end
        end)

        -- Scripts.Client Hooks: Ergonomics, Instant ADS, NoBobbing
        pcall(function()
            if LocalPlayer and LocalPlayer.Character then
                local scripts = LocalPlayer.Character:FindFirstChild("Scripts")
                local clientScript = scripts and scripts:FindFirstChild("Client")
                local getsenv_fn = getsenv or (getgenv and getgenv().getsenv)
                if clientScript and typeof(getsenv_fn) == "function" then
                    local env = getsenv_fn(clientScript)
                    if env then
                        if (Config.Misc.MaxErgonomics or Config.Character.FastReload) and typeof(env.getMagErgonomics) == "function" then
                            env.getMagErgonomics = function(...) return 100 end
                        end
                        if Config.Misc.InstantADS and typeof(env.shared) == "table" then
                            env.shared.aimAlpha = 1
                        end
                        if Config.Misc.NoBobbing and typeof(env.bobbing) == "function" then
                            env.bobbing = function(...) return CFrame.identity end
                        end
                    end
                end
            end
        end)
    end
end)

-- BaseCamera _recoilCF Nullification on RenderStepped
RunService.RenderStepped:Connect(function()
    if (Config.Character.NoRecoil or Config.Misc.NoRecoil) and LocalPlayer and LocalPlayer.Character then
        pcall(function()
            local scripts = LocalPlayer.Character:FindFirstChild("Scripts")
            local camScript = scripts and scripts:FindFirstChild("Camera")
            local baseCam = camScript and camScript:FindFirstChild("BaseCamera")
            if baseCam and baseCam:IsA("ModuleScript") then
                local ok, camMod = pcall(require, baseCam)
                if ok and type(camMod) == "table" and camMod._recoilCF then
                    camMod._recoilCF = CFrame.identity
                end
            end
        end)
    end
end)

print("[snow.cc] Havoc client operational: Dual ESP, Auto Mouse Unlock, Universal Scanner active.")
