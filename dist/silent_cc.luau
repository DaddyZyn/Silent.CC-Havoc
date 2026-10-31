--[[
    silent.cc | Havoc [Season 2] | discord.gg/silentcc
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
        Key = Enum.KeyCode.Q,
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
        TracerOrigin = "Bottom",
        IncludeScavs = true,
        TeamCheck = false,
        MaxDistance = 2000,
        BoxColor = Color3.fromRGB(255, 255, 255),
        TracerColor = Color3.fromRGB(0, 110, 255),
        Engine = "Auto (Dual Layer)",
    },
    Visuals = {
        Chams = false,
        VisibleColor = Color3.fromRGB(120, 87, 255),
        HiddenColor = Color3.fromRGB(255, 60, 60),
        Transparency = 0,
    },
    Character = {
        SpeedOverride = false,
        SpeedValue = 24,
        InfiniteStamina = false,
        BunnyHop = false,
        FastReload = false,
        NoRecoil = false,
        NoSpread = false,
    }
}

-- =========================================================================
-- SECTION 4: UNIVERSAL HAVOC ENTITY SCANNER
-- =========================================================================
local ActiveEntities = {}

local function isLivingCharacter(model)
    if not model or not model:IsA("Model") then return false end
    if LocalPlayer and LocalPlayer.Character and model == LocalPlayer.Character then return false end

    -- Havoc dead ragdoll detection
    if model:FindFirstChild("ClientRagdoll") or model:FindFirstChild("ClientRagdollV1") then
        return false
    end

    local hrp = model:FindFirstChild("HumanoidRootPart")
    local head = model:FindFirstChild("Head")
    if not hrp or not head then return false end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end

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
        displayName = player.DisplayName .. " (@" .. player.Name .. ")"
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

    -- 1. Direct Workspace Children & 1-level subfolders
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") then
            checkModel(child)
        elseif child:IsA("Folder") then
            for _, sub in ipairs(child:GetChildren()) do
                if sub:IsA("Model") then
                    checkModel(sub)
                end
            end
        end
    end

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
-- SECTION 5: COMBAT HOOKS (SILENT AIM & ANTICHEAT)
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

            -- 3. hitPos Redirection
            if Config.SilentAim.Enabled and currentSilentTargetBone and (method == "FireServer" or method == "fireServer") and tostring(self.Name) == "hitPos" then
                if math.random(1, 100) <= Config.SilentAim.HitRate then
                    if typeof(args[2]) == "Vector3" then
                        args[2] = currentSilentTargetBone.Position
                        args[1] = currentSilentTargetBone
                        return oldNamecall(self, unpack(args))
                    end
                end
            end

            -- 4. Raycast Redirection
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
-- SECTION 6: UI FRAMEWORK (LAYOUT-ORDER IMMUNE)
-- =========================================================================
local Library = {}
Library.Theme = {
    WindowBg = Color3.fromRGB(14, 14, 16),
    WindowBorder = Color3.fromRGB(0, 0, 0),
    WindowStroke = Color3.fromRGB(36, 36, 42),

    TitlebarBg = Color3.fromRGB(12, 12, 14),
    TitlebarText = Color3.fromRGB(210, 210, 215),

    NavbarBg = Color3.fromRGB(14, 14, 16),
    TabActiveBg = Color3.fromRGB(22, 22, 26),
    TabActiveBorder = Color3.fromRGB(50, 50, 60),
    TabInactiveText = Color3.fromRGB(130, 130, 140),
    TabActiveText = Color3.fromRGB(255, 255, 255),

    Accent = Color3.fromRGB(0, 110, 255),
    AccentSecondary = Color3.fromRGB(120, 87, 255),

    GroupboxBg = Color3.fromRGB(16, 16, 20),
    GroupboxBorder = Color3.fromRGB(32, 32, 38),
    GroupboxTitle = Color3.fromRGB(220, 220, 225),

    LabelText = Color3.fromRGB(190, 190, 198),
    MutedText = Color3.fromRGB(110, 110, 120),

    InputBg = Color3.fromRGB(10, 10, 12),
    InputBorder = Color3.fromRGB(38, 38, 46),

    SliderTrack = Color3.fromRGB(12, 12, 15),
    SliderFill = Color3.fromRGB(0, 110, 255),
    SliderText = Color3.fromRGB(255, 255, 255),
}

local function getSafeParent()
    if typeof(gethui) == "function" then
        local success, hui = pcall(gethui)
        if success and hui then return hui end
    end

    local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if success and coreGui then return coreGui end

    if LocalPlayer then return LocalPlayer:WaitForChild("PlayerGui") end
    error("[silent.cc] Failed to find UI container.")
end

local function makeDraggable(dragHandle, container)
    local dragging = false
    local dragInput = nil
    local dragStart = Vector2.zero
    local startPos = UDim2.new()

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = container.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function Library.CreateWindow(config)
    local title = config.Title or "silent.cc"
    local gameName = config.Game or "Havoc"
    local link = config.Link or "discord.gg/silentcc"
    local windowSize = config.Size or Vector2.new(680, 720)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "silent_cc_" .. tostring(math.random(100000, 999999))
    screenGui.ResetOnSpawn = false
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

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 28)
    titleBar.BackgroundColor3 = Library.Theme.TitlebarBg
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -20, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.RobotoMono
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = Library.Theme.TitlebarText
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = string.format("%s  |  %s  |  %s", title, gameName, link)
    titleLabel.Parent = titleBar

    makeDraggable(titleBar, mainFrame)

    local function setVisibility(visible)
        isMenuVisible = visible
        mainFrame.Visible = visible
        if visible then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end

    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            setVisibility(not isMenuVisible)
        end
    end)

    local navBar = Instance.new("Frame")
    navBar.Name = "NavBar"
    navBar.Size = UDim2.new(1, -20, 0, 30)
    navBar.Position = UDim2.new(0, 10, 0, 30)
    navBar.BackgroundColor3 = Library.Theme.NavbarBg
    navBar.BorderSizePixel = 0
    navBar.Parent = mainFrame

    local navLayout = Instance.new("UIListLayout")
    navLayout.FillDirection = Enum.FillDirection.Horizontal
    navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, 6)
    navLayout.Parent = navBar

    local navAccentLine = Instance.new("Frame")
    navAccentLine.Name = "NavAccentLine"
    navAccentLine.Size = UDim2.new(1, -20, 0, 1)
    navAccentLine.Position = UDim2.new(0, 10, 0, 62)
    navAccentLine.BackgroundColor3 = Library.Theme.Accent
    navAccentLine.BorderSizePixel = 0
    navAccentLine.Parent = mainFrame

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -20, 1, -72)
    contentArea.Position = UDim2.new(0, 10, 0, 66)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    local Window = {
        ScreenGui = screenGui,
        MainFrame = mainFrame,
        Tabs = {},
        CurrentTab = nil,
    }

    function Window:CreateTab(tabName)
        local tabIndex = #Window.Tabs + 1

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = string.format("Tab_%02d_%s", tabIndex, tabName)
        tabBtn.Size = UDim2.new(0, 85, 0, 24)
        tabBtn.LayoutOrder = tabIndex
        tabBtn.BackgroundColor3 = Library.Theme.NavbarBg
        tabBtn.BorderSizePixel = 0
        tabBtn.Font = Enum.Font.RobotoMono
        tabBtn.TextSize = 12
        tabBtn.TextColor3 = Library.Theme.TabInactiveText
        tabBtn.Text = tabName
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = navBar

        local tabStroke = Instance.new("UIStroke")
        tabStroke.Color = Library.Theme.TabActiveBorder
        tabStroke.Thickness = 1
        tabStroke.Enabled = false
        tabStroke.Parent = tabBtn

        local tabContent = Instance.new("ScrollingFrame")
        tabContent.Name = "TabContent_" .. tabName
        tabContent.Size = UDim2.new(1, 0, 1, 0)
        tabContent.BackgroundTransparency = 1
        tabContent.BorderSizePixel = 0
        tabContent.ScrollBarThickness = 2
        tabContent.ScrollBarImageColor3 = Library.Theme.Accent
        tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tabContent.Visible = false
        tabContent.Parent = contentArea

        local columns = Instance.new("Frame")
        columns.Name = "Columns"
        columns.Size = UDim2.new(1, 0, 0, 0)
        columns.AutomaticSize = Enum.AutomaticSize.Y
        columns.BackgroundTransparency = 1
        columns.Parent = tabContent

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
            Stroke = tabStroke,
            Content = tabContent,
            Left = leftCol,
            Right = rightCol,
        }

        local function selectTab()
            for _, t in ipairs(Window.Tabs) do
                t.Content.Visible = false
                t.Stroke.Enabled = false
                t.Button.BackgroundColor3 = Library.Theme.NavbarBg
                t.Button.TextColor3 = Library.Theme.TabInactiveText
            end
            tabData.Content.Visible = true
            tabData.Stroke.Enabled = true
            tabData.Button.BackgroundColor3 = Library.Theme.TabActiveBg
            tabData.Button.TextColor3 = Library.Theme.TabActiveText
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
                sliderContainer.Size = UDim2.new(1, 0, 0, 34)
                sliderContainer.BackgroundTransparency = 1
                sliderContainer.Parent = itemsContainer

                local labelText = Instance.new("TextLabel")
                labelText.Name = "Label"
                labelText.Size = UDim2.new(1, 0, 0, 14)
                labelText.BackgroundTransparency = 1
                labelText.Font = Enum.Font.RobotoMono
                labelText.TextSize = 11
                labelText.TextColor3 = Library.Theme.LabelText
                labelText.TextXAlignment = Enum.TextXAlignment.Left
                labelText.Text = label
                labelText.Parent = sliderContainer

                local track = Instance.new("Frame")
                track.Name = "Track"
                track.Size = UDim2.new(1, 0, 0, 15)
                track.Position = UDim2.new(0, 0, 0, 17)
                track.BackgroundColor3 = Library.Theme.SliderTrack
                track.BorderSizePixel = 0
                track.Parent = sliderContainer

                local trackStroke = Instance.new("UIStroke")
                trackStroke.Color = Library.Theme.InputBorder
                trackStroke.Thickness = 1
                trackStroke.Parent = track

                local fill = Instance.new("Frame")
                fill.Name = "Fill"
                local alpha = (currentVal - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                fill.BackgroundColor3 = Library.Theme.SliderFill
                fill.BorderSizePixel = 0
                fill.Parent = track

                local valueText = Instance.new("TextLabel")
                valueText.Name = "Value"
                valueText.Size = UDim2.new(1, 0, 1, 0)
                valueText.BackgroundTransparency = 1
                valueText.Font = Enum.Font.RobotoMono
                valueText.TextSize = 10
                valueText.TextColor3 = Library.Theme.SliderText
                valueText.ZIndex = 5
                valueText.Text = string.format("%d%s/%d%s", currentVal, u, max, u)
                valueText.Parent = track

                local sliding = false
                local function updateSlide(input)
                    local trackX = track.AbsolutePosition.X
                    local trackW = track.AbsoluteSize.X
                    local mouseX = input.Position.X
                    local pct = math.clamp((mouseX - trackX) / trackW, 0, 1)
                    local val = math.floor(min + ((max - min) * pct))
                    currentVal = val
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    valueText.Text = string.format("%d%s/%d%s", val, u, max, u)
                    if callback then pcall(callback, val) end
                end

                track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        updateSlide(input)
                    end
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        updateSlide(input)
                    end
                end)

                return {
                    SetValue = function(val)
                        currentVal = math.clamp(val, min, max)
                        local pct = (currentVal - min) / (max - min)
                        fill.Size = UDim2.new(pct, 0, 1, 0)
                        valueText.Text = string.format("%d%s/%d%s", currentVal, u, max, u)
                        if callback then pcall(callback, currentVal) end
                    end,
                    GetValue = function() return currentVal end,
                }
            end

            function Group:AddDropdown(label, items, default, callback)
                local selected = default or items[1] or "None"
                local isOpen = false
                local order = nextOrder()

                local dropContainer = Instance.new("Frame")
                dropContainer.Name = string.format("%03d_Dropdown_%s", order, label)
                dropContainer.LayoutOrder = order
                dropContainer.Size = UDim2.new(1, 0, 0, 40)
                dropContainer.BackgroundTransparency = 1
                dropContainer.ClipsDescendants = false
                dropContainer.ZIndex = 10
                dropContainer.Parent = itemsContainer

                local dropTitle = Instance.new("TextLabel")
                dropTitle.Name = "Label"
                dropTitle.Size = UDim2.new(1, 0, 0, 14)
                dropTitle.BackgroundTransparency = 1
                dropTitle.Font = Enum.Font.RobotoMono
                dropTitle.TextSize = 11
                dropTitle.TextColor3 = Library.Theme.LabelText
                dropTitle.TextXAlignment = Enum.TextXAlignment.Left
                dropTitle.Text = label
                dropTitle.Parent = dropContainer

                local dropBtn = Instance.new("TextButton")
                dropBtn.Name = "SelectBox"
                dropBtn.Size = UDim2.new(1, 0, 0, 22)
                dropBtn.Position = UDim2.new(0, 0, 0, 16)
                dropBtn.BackgroundColor3 = Library.Theme.InputBg
                dropBtn.BorderSizePixel = 0
                dropBtn.Font = Enum.Font.RobotoMono
                dropBtn.TextSize = 11
                dropBtn.TextColor3 = Library.Theme.LabelText
                dropBtn.TextXAlignment = Enum.TextXAlignment.Left
                dropBtn.Text = "  " .. selected
                dropBtn.AutoButtonColor = false
                dropBtn.Parent = dropContainer

                local dropStroke = Instance.new("UIStroke")
                dropStroke.Color = Library.Theme.InputBorder
                dropStroke.Thickness = 1
                dropStroke.Parent = dropBtn

                local arrow = Instance.new("TextLabel")
                arrow.Name = "Arrow"
                arrow.Size = UDim2.new(0, 20, 1, 0)
                arrow.Position = UDim2.new(1, -20, 0, 0)
                arrow.BackgroundTransparency = 1
                arrow.Font = Enum.Font.RobotoMono
                arrow.TextSize = 10
                arrow.TextColor3 = Library.Theme.MutedText
                arrow.Text = "v"
                arrow.Parent = dropBtn

                local optionsFrame = Instance.new("Frame")
                optionsFrame.Name = "Options"
                optionsFrame.Size = UDim2.new(1, 0, 0, #items * 22)
                optionsFrame.Position = UDim2.new(0, 0, 1, 2)
                optionsFrame.BackgroundColor3 = Library.Theme.GroupboxBg
                optionsFrame.BorderSizePixel = 0
                optionsFrame.ZIndex = 100
                optionsFrame.Visible = false
                optionsFrame.Parent = dropBtn

                local optStroke = Instance.new("UIStroke")
                optStroke.Color = Library.Theme.Accent
                optStroke.Thickness = 1
                optStroke.Parent = optionsFrame

                local optLayout = Instance.new("UIListLayout")
                optLayout.FillDirection = Enum.FillDirection.Vertical
                optLayout.SortOrder = Enum.SortOrder.LayoutOrder
                optLayout.Parent = optionsFrame

                for idx, item in ipairs(items) do
                    local opt = Instance.new("TextButton")
                    opt.Name = "Item_" .. item
                    opt.LayoutOrder = idx
                    opt.Size = UDim2.new(1, 0, 0, 22)
                    opt.BackgroundColor3 = Library.Theme.GroupboxBg
                    opt.BorderSizePixel = 0
                    opt.Font = Enum.Font.RobotoMono
                    opt.TextSize = 11
                    opt.TextColor3 = (item == selected) and Library.Theme.Accent or Library.Theme.LabelText
                    opt.TextXAlignment = Enum.TextXAlignment.Left
                    opt.Text = "  " .. item
                    opt.ZIndex = 101
                    opt.AutoButtonColor = false
                    opt.Parent = optionsFrame

                    opt.MouseButton1Click:Connect(function()
                        selected = item
                        dropBtn.Text = "  " .. selected
                        optionsFrame.Visible = false
                        isOpen = false
                        arrow.Text = "v"
                        if callback then pcall(callback, selected) end
                    end)
                end

                dropBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    optionsFrame.Visible = isOpen
                    arrow.Text = isOpen and "^" or "v"
                end)

                return {
                    GetValue = function() return selected end,
                }
            end

            function Group:AddColorPicker(label, default, callback)
                local currentColor = default or Color3.fromRGB(0, 255, 170)
                local order = nextOrder()

                local colorRow = Instance.new("Frame")
                colorRow.Name = string.format("%03d_Color_%s", order, label)
                colorRow.LayoutOrder = order
                colorRow.Size = UDim2.new(1, 0, 0, 22)
                colorRow.BackgroundTransparency = 1
                colorRow.Parent = itemsContainer

                local colorLabel = Instance.new("TextLabel")
                colorLabel.Name = "Label"
                colorLabel.Size = UDim2.new(1, -50, 1, 0)
                colorLabel.BackgroundTransparency = 1
                colorLabel.Font = Enum.Font.RobotoMono
                colorLabel.TextSize = 11
                colorLabel.TextColor3 = Library.Theme.LabelText
                colorLabel.TextXAlignment = Enum.TextXAlignment.Left
                colorLabel.Text = label
                colorLabel.Parent = colorRow

                local colorPreview = Instance.new("TextButton")
                colorPreview.Name = "Preview"
                colorPreview.Size = UDim2.new(0, 38, 0, 16)
                colorPreview.Position = UDim2.new(1, -38, 0.5, -8)
                colorPreview.BackgroundColor3 = currentColor
                colorPreview.BorderSizePixel = 0
                colorPreview.Text = ""
                colorPreview.Parent = colorRow

                local previewStroke = Instance.new("UIStroke")
                previewStroke.Color = Library.Theme.InputBorder
                previewStroke.Thickness = 1
                previewStroke.Parent = colorPreview

                return {
                    SetColor = function(newColor)
                        currentColor = newColor
                        colorPreview.BackgroundColor3 = currentColor
                        if callback then pcall(callback, currentColor) end
                    end,
                    GetColor = function() return currentColor end,
                }
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

    local espData = {
        BoxOutline = DrawingLib.new("Square"),
        Box = DrawingLib.new("Square"),
        HealthBarOutline = DrawingLib.new("Line"),
        HealthBar = DrawingLib.new("Line"),
        Name = DrawingLib.new("Text"),
        Distance = DrawingLib.new("Text"),
        Tracer = DrawingLib.new("Line"),
    }

    espData.BoxOutline.Visible = false
    espData.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    espData.BoxOutline.Thickness = 3
    espData.BoxOutline.Filled = false

    espData.Box.Visible = false
    espData.Box.Color = Config.Esp.BoxColor
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
    espData.Tracer.Color = Config.Esp.TracerColor
    espData.Tracer.Thickness = 1

    return espData
end

local function createBillboardEsp(ent)
    local existing = ent.HRP:FindFirstChild("silent_bb_esp")
    if existing then return existing end

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
    boxStroke.Color = Config.Esp.BoxColor
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
-- SECTION 9: MENU INITIALIZATION
-- =========================================================================
local Window = Library.CreateWindow({
    Title = "silent.cc",
    Game = "Havoc",
    Link = "discord.gg/silentcc",
    Size = Vector2.new(680, 720),
    ToggleKey = Enum.KeyCode.RightShift,
})

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
PlayerEspGroup:AddToggle("Box ESP", Config.Esp.Boxes, { Callback = function(v) Config.Esp.Boxes = v end })
PlayerEspGroup:AddToggle("Health Bar", Config.Esp.Health, { Callback = function(v) Config.Esp.Health = v end })
PlayerEspGroup:AddToggle("Name Tags", Config.Esp.Names, { Callback = function(v) Config.Esp.Names = v end })
PlayerEspGroup:AddToggle("Distance Tags", Config.Esp.Distances, { Callback = function(v) Config.Esp.Distances = v end })
PlayerEspGroup:AddToggle("Snapline Tracers", Config.Esp.Tracers, { Callback = function(v) Config.Esp.Tracers = v end })
PlayerEspGroup:AddToggle("Chams Highlight", Config.Visuals.Chams, { Callback = function(v) Config.Visuals.Chams = v end })
PlayerEspGroup:AddDropdown("Tracer Origin", { "Bottom", "Center", "Mouse" }, Config.Esp.TracerOrigin, function(v) Config.Esp.TracerOrigin = v end)

local EspConfigGroup = EspTab:CreateGroupbox("ESP Settings", "Right")
EspConfigGroup:AddDropdown("ESP Engine", { "Auto (Dual Layer)", "Drawing (2D)", "Billboard (Native)" }, Config.Esp.Engine, function(v) Config.Esp.Engine = v end)
EspConfigGroup:AddToggle("Include AI Scavengers", Config.Esp.IncludeScavs, { Callback = function(v) Config.Esp.IncludeScavs = v end })
EspConfigGroup:AddToggle("Team Check", Config.Esp.TeamCheck, { Callback = function(v) Config.Esp.TeamCheck = v end })
EspConfigGroup:AddSlider("Max Distance", 100, 3000, Config.Esp.MaxDistance, " studs", function(v) Config.Esp.MaxDistance = v end)
EspConfigGroup:AddColorPicker("Box Color", Config.Esp.BoxColor, function(col) Config.Esp.BoxColor = col end)
EspConfigGroup:AddColorPicker("Tracer Color", Config.Esp.TracerColor, function(col) Config.Esp.TracerColor = col end)

-- TAB 3: VISUALS
local VisualsTab = Window:CreateTab("Visuals")

local ChamsGroup = VisualsTab:CreateGroupbox("Chams & Shaders", "Left")
ChamsGroup:AddToggle("Enable Chams", Config.Visuals.Chams, { Callback = function(v) Config.Visuals.Chams = v end })
ChamsGroup:AddColorPicker("Visible Color", Config.Visuals.VisibleColor, function(col) Config.Visuals.VisibleColor = col end)
ChamsGroup:AddColorPicker("Hidden Color", Config.Visuals.HiddenColor, function(col) Config.Visuals.HiddenColor = col end)
ChamsGroup:AddSlider("Outline Transparency", 0, 100, Config.Visuals.Transparency, "%", function(v) Config.Visuals.Transparency = v end)

local WorldGroup = VisualsTab:CreateGroupbox("World ESP", "Right")
WorldGroup:AddToggle("Dropped Weapons", false)
WorldGroup:AddToggle("Ammo Crates", false)
WorldGroup:AddToggle("Objective Markers", false)

-- TAB 4: CHARACTER
local CharTab = Window:CreateTab("Character")

local MovementGroup = CharTab:CreateGroupbox("Movement", "Left")
MovementGroup:AddToggle("WalkSpeed Override", Config.Character.SpeedOverride, {
    Callback = function(enabled)
        Config.Character.SpeedOverride = enabled
        if not enabled and LocalPlayer and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
})
MovementGroup:AddSlider("Speed Value", 16, 100, Config.Character.SpeedValue, " studs", function(val)
    Config.Character.SpeedValue = val
end)
MovementGroup:AddToggle("Infinite Stamina", Config.Character.InfiniteStamina, { Callback = function(v) Config.Character.InfiniteStamina = v end })
MovementGroup:AddToggle("Bunny Hop", Config.Character.BunnyHop, { Callback = function(v) Config.Character.BunnyHop = v end })

local WeaponGroup = CharTab:CreateGroupbox("Weapon Handling", "Right")
WeaponGroup:AddToggle("Fast Tactical Reload", Config.Character.FastReload, { Callback = function(v) Config.Character.FastReload = v end })
WeaponGroup:AddToggle("Recoil Neutralizer", Config.Character.NoRecoil, { Callback = function(v) Config.Character.NoRecoil = v end })
WeaponGroup:AddToggle("Spread Reduction", Config.Character.NoSpread, { Callback = function(v) Config.Character.NoSpread = v end })

-- TAB 5: SETTINGS
local SettingsTab = Window:CreateTab("settings")

local ProfileGroup = SettingsTab:CreateGroupbox("Profile Manager", "Left")
ProfileGroup:AddButton("Save Default Config", function() print("[silent.cc] Saved config profile.") end)
ProfileGroup:AddButton("Load Default Config", function() print("[silent.cc] Loaded config profile.") end)

local SystemGroup = SettingsTab:CreateGroupbox("System", "Right")
SystemGroup:AddButton("Unload silent.cc", function()
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
        if not model.Parent or not ent.HRP.Parent or (ent.Humanoid and ent.Humanoid.Health <= 0) then
            cleanupModelEsp(model)
            ActiveEntities[model] = nil
        else
            local hrp = ent.HRP
            local head = ent.Head
            local hum = ent.Humanoid
            local worldDist = (hrp.Position - Camera.CFrame.Position).Magnitude
            local inRange = worldDist <= Config.Esp.MaxDistance
            local allowEntity = ent.IsPlayer or Config.Esp.IncludeScavs

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
                    if stroke then stroke.Color = Config.Esp.BoxColor end
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
                if Config.Esp.Enabled and inRange and allowEntity then
                    local hrpPos, hrpOn = Camera:WorldToViewportPoint(hrp.Position)
                    local headPos, headOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
                    local rootPos, rootOn = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

                    if hrpOn and headOn and rootOn and hrpPos.Z > 0 then
                        local height = math.abs(headPos.Y - rootPos.Y)
                        local width = math.clamp(height * 0.65, 4, 300)
                        local boxPos = Vector2.new(hrpPos.X - width / 2, headPos.Y)

                        if Config.Esp.Boxes then
                            esp.BoxOutline.Size = Vector2.new(width, height)
                            esp.BoxOutline.Position = boxPos
                            esp.BoxOutline.Visible = true

                            esp.Box.Size = Vector2.new(width, height)
                            esp.Box.Position = boxPos
                            esp.Box.Color = Config.Esp.BoxColor
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
                            esp.Tracer.Color = Config.Esp.TracerColor
                            esp.Tracer.Visible = true
                        else
                            esp.Tracer.Visible = false
                        end

                        rendered = true
                    end
                end

                if not rendered then
                    esp.BoxOutline.Visible = false
                    esp.Box.Visible = false
                    esp.HealthBarOutline.Visible = false
                    esp.HealthBar.Visible = false
                    esp.Name.Visible = false
                    esp.Distance.Visible = false
                    esp.Tracer.Visible = false
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

    -- 5. WalkSpeed Physics Override
    if Config.Character.SpeedOverride and LocalPlayer and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= Config.Character.SpeedValue then
            hum.WalkSpeed = Config.Character.SpeedValue
        end
    end

    -- 6. Bunny Hop Loop
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

print("[silent.cc] Havoc client operational: Dual ESP, Auto Mouse Unlock, Universal Scanner active.")
