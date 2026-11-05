--[[
    SILENT.cc | 99 Nights in the Forest Dedicated Suite
    Place ID: 126509999114328 | Universe ID: 7326934954
    Developer: Grandma's Favourite Games

    Architectural Suite:
      - Obsidian / Pitch Black High-Contrast Vertical Sidebar Menu
      - Combat Engine:
          * Mob / Entity Kill Aura (Targeting Workspace.Characters via ToolDamageObject & NpcEvent)
          * The Deer Banisher & Stunner (Instant HurtDeerTorch / MonsterHitByTorch on stalker approach)
          * Tree & Resource Demolisher
          * Projectile Damage Override & Silent Aim
      - Survival & Base Defense:
          * Auto Campfire Feeder (Remotely feeds closest logs/coal from Workspace.Items)
          * Godmode / Damage Nullifier (Intercepts and blocks incoming DamagePlayer)
          * Auto-Consume (Maintains Hunger > 80% & Warmth)
          * Sawmill Automation (Auto-cranks sawmill lever)
          * Weather Clearer (Clears rain/storms threatening campfire)
      - World & Event Exploits:
          * Carnival Games Instant Auto-Win (Complete ring toss, shooting gallery, basketball & claim booth)
          * Alien Spaceship Auto-Repair & Item Claim
          * Lost Children Auto-Rescue & Task Turn-in
          * Full Map Discovery & Fog Removal
      - Visuals & ESP (Drawing API):
          * The Deer (Red Box + Threat Alert)
          * Hostile Mobs (Bears, Wolves, Cultists)
          * Passive Wildlife (Bunnies, Boars, Frogs)
          * 4 Lost Children (Purple Box + Distance)
          * Campfire & Key Structures
          * Loot & Ground Items (Crystal Skull Keys, Pelts, Chests)
          * Fullbright & Visual Lighting Control
      - Movement & Waypoint Teleports:
          * CFrame Speed & WalkSpeed
          * Infinite Jump & BodyVelocity Fly
          * Noclip
          * 1-Click Teleports (Campfire, Sawmill, Tool Trader, Stronghold, Lost Children)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Camera = Workspace.CurrentCamera
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    if Workspace.CurrentCamera then Camera = Workspace.CurrentCamera end
end)

-- Safe global accessor
local function getGlobal(name)
    local direct = nil
    pcall(function() direct = getfenv()[name] end)
    if direct ~= nil then return direct end
    if typeof(getgenv) == "function" then
        local ok, genv = pcall(getgenv)
        if ok and typeof(genv) == "table" and genv[name] ~= nil then return genv[name] end
    end
    if typeof(_G) == "table" and _G[name] ~= nil then return _G[name] end
    return nil
end

local DrawingLib = getGlobal("Drawing")
local hasDrawing = typeof(DrawingLib) == "table" and typeof(DrawingLib.new) == "function"
local hookmeta = getGlobal("hookmetamethod")
local hookfn = getGlobal("hookfunction")
local newccl = getGlobal("newcclosure") or function(f) return f end
local gethui = getGlobal("gethui")

local function getSafeParent()
    if typeof(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LP:WaitForChild("PlayerGui")
end

-- Remotes & Networking Hub
local Remotes = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
local function getRemote(name)
    if not Remotes then return nil end
    return Remotes:FindFirstChild(name)
end

local function cam() return Camera or Workspace.CurrentCamera end
local function getChar() return LP.Character end
local function getRoot()
    local c = getChar()
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- Helper functions
local function cursorPoint()
    local ok, loc = pcall(function() return UserInputService:GetMouseLocation() - GuiService:GetGuiInset() end)
    if ok and loc then return loc end
    return Vector2.new(Mouse.X, Mouse.Y)
end

-- =========================================================================
-- STATE CONFIGURATION
-- =========================================================================
local state = {
    -- Combat
    killAura = false,
    killAuraRange = 60,
    killAuraDelay = 0.15,
    killAuraTarget = "Hostiles", -- "Hostiles", "All", "Deer Only"
    deerBanisher = true,
    deerBanishDist = 120,
    damageOverride = false,
    damageAmount = 250,
    chopTrees = false,
    chopRange = 30,

    -- Survival
    autoCampfire = false,
    autoCampfireRange = 150,
    godmode = false,
    autoEat = false,
    autoEatThreshold = 60,
    autoSawmill = false,
    clearWeather = false,

    -- Event Exploits
    autoCarnival = false,
    autoAlienRepair = false,
    autoRescueKids = false,

    -- Visuals / ESP
    esp = false,
    espDeer = true,
    espHostiles = true,
    espPassive = false,
    espKids = true,
    espCampfire = true,
    espChests = true,
    espItems = false,
    espMaxDist = 1200,
    fullbright = false,
    noFog = false,

    -- Colors
    colDeer = Color3.fromRGB(255, 40, 40),
    colHostile = Color3.fromRGB(255, 80, 80),
    colPassive = Color3.fromRGB(120, 255, 120),
    colKids = Color3.fromRGB(180, 80, 255),
    colCamp = Color3.fromRGB(255, 180, 40),
    colChest = Color3.fromRGB(255, 230, 80),
    colItem = Color3.fromRGB(180, 180, 190),

    -- Movement
    speed = false,
    speedValue = 28,
    speedMode = "CFrame",
    jump = false,
    jumpValue = 55,
    fly = false,
    flySpeed = 60,
    noclip = false,
    infJump = false,

    unloaded = false,
}

local conns = {}
local function track(conn)
    if conn then table.insert(conns, conn) end
    return conn
end

-- =========================================================================
-- OBSIDIAN THEME ENGINE
-- =========================================================================
local Library = {}
Library.Theme = {
    WindowBg = Color3.fromRGB(10, 10, 12),
    WindowStroke = Color3.fromRGB(32, 32, 38),
    SidebarBg = Color3.fromRGB(8, 8, 10),
    SidebarBorder = Color3.fromRGB(22, 22, 26),
    TitlebarText = Color3.fromRGB(245, 245, 250),
    TabActiveBg = Color3.fromRGB(20, 20, 24),
    TabActiveBorder = Color3.fromRGB(48, 48, 56),
    TabInactiveText = Color3.fromRGB(130, 130, 142),
    TabActiveText = Color3.fromRGB(255, 255, 255),
    TabHoverBg = Color3.fromRGB(14, 14, 18),
    Accent = Color3.fromRGB(235, 235, 240),
    GroupboxBg = Color3.fromRGB(13, 13, 16),
    GroupboxBorder = Color3.fromRGB(26, 26, 32),
    GroupboxHeader = Color3.fromRGB(220, 220, 225),
    LabelText = Color3.fromRGB(195, 195, 205),
    MutedText = Color3.fromRGB(125, 125, 135),
    InputBg = Color3.fromRGB(18, 18, 22),
    InputBorder = Color3.fromRGB(34, 34, 42),
    InputBorderActive = Color3.fromRGB(200, 200, 210),
}

local function formatKeyName(key)
    if not key then return "..." end
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.KeyCode then
            local n = key.Name
            local map = { RightShift = "RShift", LeftShift = "LShift", RightControl = "RCtrl", LeftControl = "LCtrl" }
            return map[n] or n
        elseif key.EnumType == Enum.UserInputType then
            if key == Enum.UserInputType.MouseButton1 then return "M1" end
            if key == Enum.UserInputType.MouseButton2 then return "M2" end
            if key == Enum.UserInputType.MouseButton3 then return "M3" end
        end
    end
    return tostring(key)
end

function Library.CreateWindow(config)
    local title = config.Title or "SILENT.cc"
    local gameName = config.Game or "99 Nights in the Forest"
    local windowSize = config.Size or Vector2.new(680, 520)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "silent_forest_" .. tostring(math.random(100000, 999999))
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 999999
    screenGui.Parent = getSafeParent()

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainWindow"
    mainFrame.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y)
    mainFrame.Position = UDim2.new(0.5, -windowSize.X / 2, 0.5, -windowSize.Y / 2)
    mainFrame.BackgroundColor3 = Library.Theme.WindowBg
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local windowStroke = Instance.new("UIStroke")
    windowStroke.Color = Library.Theme.WindowStroke
    windowStroke.Thickness = 1
    windowStroke.Parent = mainFrame

    -- Dragging
    local isDragging, dragStart, startPos = false, nil, nil
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then isDragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Toggle Menu
    local menuOpen = true
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            menuOpen = not menuOpen
            mainFrame.Visible = menuOpen
        end
    end)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 160, 1, 0)
    sidebar.BackgroundColor3 = Library.Theme.SidebarBg
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    local sBorder = Instance.new("Frame")
    sBorder.Size = UDim2.new(0, 1, 1, 0)
    sBorder.Position = UDim2.new(1, -1, 0, 0)
    sBorder.BackgroundColor3 = Library.Theme.SidebarBorder
    sBorder.BorderSizePixel = 0
    sBorder.Parent = sidebar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 30)
    titleLbl.Position = UDim2.new(0, 14, 0, 12)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.RobotoMono
    titleLbl.TextSize = 15
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = title:upper()
    titleLbl.TextColor3 = Library.Theme.TitlebarText
    titleLbl.Parent = sidebar

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -20, 0, 14)
    subLbl.Position = UDim2.new(0, 14, 0, 38)
    subLbl.BackgroundTransparency = 1
    subLbl.Font = Enum.Font.RobotoMono
    subLbl.TextSize = 10
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    subLbl.Text = gameName
    subLbl.TextColor3 = Library.Theme.MutedText
    subLbl.Parent = sidebar

    local navBar = Instance.new("Frame")
    navBar.Name = "NavBar"
    navBar.Size = UDim2.new(1, -16, 1, -80)
    navBar.Position = UDim2.new(0, 8, 0, 64)
    navBar.BackgroundTransparency = 1
    navBar.Parent = sidebar

    local navLayout = Instance.new("UIListLayout")
    navLayout.FillDirection = Enum.FillDirection.Vertical
    navLayout.Padding = UDim.new(0, 4)
    navLayout.Parent = navBar

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -170, 1, -16)
    contentArea.Position = UDim2.new(0, 165, 0, 8)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    local tabs = {}
    local activeTab = nil

    local Window = { ScreenGui = screenGui, MainFrame = mainFrame }

    function Window:CreateTab(tabName)
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "TabBtn_" .. tabName
        tabBtn.Size = UDim2.new(1, 0, 0, 28)
        tabBtn.BackgroundColor3 = Library.Theme.SidebarBg
        tabBtn.BorderSizePixel = 0
        tabBtn.AutoButtonColor = false
        tabBtn.Text = ""
        tabBtn.Parent = navBar

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 4)
        tabCorner.Parent = tabBtn

        local tabStroke = Instance.new("UIStroke")
        tabStroke.Color = Library.Theme.SidebarBg
        tabStroke.Thickness = 1
        tabStroke.Parent = tabBtn

        local tabLabel = Instance.new("TextLabel")
        tabLabel.Size = UDim2.new(1, -16, 1, 0)
        tabLabel.Position = UDim2.new(0, 12, 0, 0)
        tabLabel.BackgroundTransparency = 1
        tabLabel.Font = Enum.Font.RobotoMono
        tabLabel.TextSize = 11
        tabLabel.TextColor3 = Library.Theme.TabInactiveText
        tabLabel.TextXAlignment = Enum.TextXAlignment.Left
        tabLabel.Text = tabName
        tabLabel.Parent = tabBtn

        local tabPane = Instance.new("ScrollingFrame")
        tabPane.Name = "TabPane_" .. tabName
        tabPane.Size = UDim2.new(1, 0, 1, 0)
        tabPane.BackgroundTransparency = 1
        tabPane.ScrollBarThickness = 2
        tabPane.ScrollBarImageColor3 = Library.Theme.Accent
        tabPane.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tabPane.Visible = false
        tabPane.Parent = contentArea

        local columns = Instance.new("Frame")
        columns.Name = "Columns"
        columns.Size = UDim2.new(1, 0, 1, 0)
        columns.BackgroundTransparency = 1
        columns.Parent = tabPane

        local colLeft = Instance.new("Frame")
        colLeft.Name = "LeftColumn"
        colLeft.Size = UDim2.new(0.5, -6, 0, 0)
        colLeft.Position = UDim2.new(0, 0, 0, 0)
        colLeft.BackgroundTransparency = 1
        colLeft.AutomaticSize = Enum.AutomaticSize.Y
        colLeft.Parent = columns

        local leftLayout = Instance.new("UIListLayout")
        leftLayout.Padding = UDim.new(0, 8)
        leftLayout.Parent = colLeft

        local colRight = Instance.new("Frame")
        colRight.Name = "RightColumn"
        colRight.Size = UDim2.new(0.5, -6, 0, 0)
        colRight.Position = UDim2.new(0.5, 6, 0, 0)
        colRight.BackgroundTransparency = 1
        colRight.AutomaticSize = Enum.AutomaticSize.Y
        colRight.Parent = columns

        local rightLayout = Instance.new("UIListLayout")
        rightLayout.Padding = UDim.new(0, 8)
        rightLayout.Parent = colRight

        local function activate()
            for _, t in pairs(tabs) do
                t.Button.BackgroundColor3 = Library.Theme.SidebarBg
                t.Stroke.Color = Library.Theme.SidebarBg
                t.Label.TextColor3 = Library.Theme.TabInactiveText
                t.Pane.Visible = false
            end
            tabBtn.BackgroundColor3 = Library.Theme.TabActiveBg
            tabStroke.Color = Library.Theme.TabActiveBorder
            tabLabel.TextColor3 = Library.Theme.TabActiveText
            tabPane.Visible = true
            activeTab = tabName
        end

        tabBtn.MouseButton1Click:Connect(activate)

        local Tab = {}
        function Tab:CreateGroupbox(boxName, side)
            local targetCol = (side and side:lower() == "right") and colRight or colLeft

            local box = Instance.new("Frame")
            box.Name = "Group_" .. boxName
            box.Size = UDim2.new(1, 0, 0, 0)
            box.BackgroundColor3 = Library.Theme.GroupboxBg
            box.BorderSizePixel = 0
            box.AutomaticSize = Enum.AutomaticSize.Y
            box.Parent = targetCol

            local bCorner = Instance.new("UICorner")
            bCorner.CornerRadius = UDim.new(0, 4)
            bCorner.Parent = box

            local bStroke = Instance.new("UIStroke")
            bStroke.Color = Library.Theme.GroupboxBorder
            bStroke.Thickness = 1
            bStroke.Parent = box

            local hLbl = Instance.new("TextLabel")
            hLbl.Size = UDim2.new(1, -16, 0, 24)
            hLbl.Position = UDim2.new(0, 10, 0, 4)
            hLbl.BackgroundTransparency = 1
            hLbl.Font = Enum.Font.RobotoMono
            hLbl.TextSize = 11
            hLbl.TextColor3 = Library.Theme.GroupboxHeader
            hLbl.TextXAlignment = Enum.TextXAlignment.Left
            hLbl.Text = boxName
            hLbl.Parent = box

            local container = Instance.new("Frame")
            container.Name = "Container"
            container.Size = UDim2.new(1, -16, 0, 0)
            container.Position = UDim2.new(0, 8, 0, 28)
            container.BackgroundTransparency = 1
            container.AutomaticSize = Enum.AutomaticSize.Y
            container.Parent = box

            local cLayout = Instance.new("UIListLayout")
            cLayout.Padding = UDim.new(0, 6)
            cLayout.Parent = container

            local cPad = Instance.new("UIPadding")
            cPad.PaddingBottom = UDim.new(0, 8)
            cPad.Parent = container

            local Group = {}
            function Group:AddToggle(label, default, options)
                local currentVal = default or false
                local cb = options and options.Callback
                local keybind = options and options.Keybind

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 20)
                row.BackgroundTransparency = 1
                row.Parent = container

                local tBox = Instance.new("TextButton")
                tBox.Size = UDim2.new(0, 14, 0, 14)
                tBox.Position = UDim2.new(0, 0, 0.5, -7)
                tBox.BackgroundColor3 = currentVal and Library.Theme.Accent or Library.Theme.InputBg
                tBox.BorderSizePixel = 0
                tBox.Text = ""
                tBox.Parent = row

                local tbStroke = Instance.new("UIStroke")
                tbStroke.Color = Library.Theme.InputBorder
                tbStroke.Thickness = 1
                tbStroke.Parent = tBox

                local tbCorner = Instance.new("UICorner")
                tbCorner.CornerRadius = UDim.new(0, 2)
                tbCorner.Parent = tBox

                local tLbl = Instance.new("TextButton")
                tLbl.Size = UDim2.new(1, -22, 1, 0)
                tLbl.Position = UDim2.new(0, 20, 0, 0)
                tLbl.BackgroundTransparency = 1
                tLbl.Font = Enum.Font.RobotoMono
                tLbl.TextSize = 11
                tLbl.TextXAlignment = Enum.TextXAlignment.Left
                tLbl.TextColor3 = currentVal and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                tLbl.Text = label
                tLbl.Parent = row

                local function setVal(v)
                    currentVal = v
                    tBox.BackgroundColor3 = currentVal and Library.Theme.Accent or Library.Theme.InputBg
                    tLbl.TextColor3 = currentVal and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                    if cb then pcall(cb, currentVal) end
                end

                tBox.MouseButton1Click:Connect(function() setVal(not currentVal) end)
                tLbl.MouseButton1Click:Connect(function() setVal(not currentVal) end)

                if keybind then
                    UserInputService.InputBegan:Connect(function(input, gpe)
                        if not gpe and input.KeyCode == keybind and UserInputService:GetFocusedTextBox() == nil then
                            setVal(not currentVal)
                        end
                    end)
                end

                return { SetValue = setVal }
            end

            function Group:AddSlider(label, min, max, default, suffix, callback)
                local currentVal = default or min
                suffix = suffix or ""

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 36)
                row.BackgroundTransparency = 1
                row.Parent = container

                local tLbl = Instance.new("TextLabel")
                tLbl.Size = UDim2.new(0.7, 0, 0, 16)
                tLbl.BackgroundTransparency = 1
                tLbl.Font = Enum.Font.RobotoMono
                tLbl.TextSize = 10
                tLbl.TextXAlignment = Enum.TextXAlignment.Left
                tLbl.TextColor3 = Library.Theme.LabelText
                tLbl.Text = label
                tLbl.Parent = row

                local vLbl = Instance.new("TextLabel")
                vLbl.Size = UDim2.new(0.3, 0, 0, 16)
                vLbl.Position = UDim2.new(0.7, 0, 0, 0)
                vLbl.BackgroundTransparency = 1
                vLbl.Font = Enum.Font.RobotoMono
                vLbl.TextSize = 10
                vLbl.TextXAlignment = Enum.TextXAlignment.Right
                vLbl.TextColor3 = Library.Theme.Accent
                vLbl.Text = tostring(currentVal) .. suffix
                vLbl.Parent = row

                local track = Instance.new("TextButton")
                track.Size = UDim2.new(1, 0, 0, 10)
                track.Position = UDim2.new(0, 0, 0, 20)
                track.BackgroundColor3 = Library.Theme.InputBg
                track.BorderSizePixel = 0
                track.Text = ""
                track.Parent = row

                local trStroke = Instance.new("UIStroke")
                trStroke.Color = Library.Theme.InputBorder
                trStroke.Thickness = 1
                trStroke.Parent = track

                local fill = Instance.new("Frame")
                fill.Size = UDim2.new(math.clamp((currentVal - min) / (max - min), 0, 1), 0, 1, 0)
                fill.BackgroundColor3 = Library.Theme.Accent
                fill.BorderSizePixel = 0
                fill.Parent = track

                local function update(input)
                    local perc = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    currentVal = math.floor(min + (max - min) * perc)
                    fill.Size = UDim2.new(perc, 0, 1, 0)
                    vLbl.Text = tostring(currentVal) .. suffix
                    if callback then pcall(callback, currentVal) end
                end

                local sliding = false
                track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        sliding = true
                        update(input)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
                end)
                UserInputService.InputChanged:Connect(function(input)
                    if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
                        update(input)
                    end
                end)

                return {
                    SetValue = function(v)
                        currentVal = math.clamp(v, min, max)
                        local perc = (currentVal - min) / (max - min)
                        fill.Size = UDim2.new(perc, 0, 1, 0)
                        vLbl.Text = tostring(currentVal) .. suffix
                        if callback then pcall(callback, currentVal) end
                    end
                }
            end

            function Group:AddDropdown(label, items, default, callback)
                local selected = default or items[1]
                local open = false

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 38)
                row.BackgroundTransparency = 1
                row.Parent = container

                local tLbl = Instance.new("TextLabel")
                tLbl.Size = UDim2.new(1, 0, 0, 14)
                tLbl.BackgroundTransparency = 1
                tLbl.Font = Enum.Font.RobotoMono
                tLbl.TextSize = 10
                tLbl.TextXAlignment = Enum.TextXAlignment.Left
                tLbl.TextColor3 = Library.Theme.LabelText
                tLbl.Text = label
                tLbl.Parent = row

                local dropBtn = Instance.new("TextButton")
                dropBtn.Size = UDim2.new(1, 0, 0, 20)
                dropBtn.Position = UDim2.new(0, 0, 0, 16)
                dropBtn.BackgroundColor3 = Library.Theme.InputBg
                dropBtn.BorderSizePixel = 0
                dropBtn.Font = Enum.Font.RobotoMono
                dropBtn.TextSize = 10
                dropBtn.TextColor3 = Library.Theme.Accent
                dropBtn.Text = "  " .. tostring(selected)
                dropBtn.TextXAlignment = Enum.TextXAlignment.Left
                dropBtn.Parent = row

                local dStroke = Instance.new("UIStroke")
                dStroke.Color = Library.Theme.InputBorder
                dStroke.Thickness = 1
                dStroke.Parent = dropBtn

                dropBtn.MouseButton1Click:Connect(function()
                    local idx = 1
                    for i, it in ipairs(items) do
                        if it == selected then idx = i break end
                    end
                    idx = idx % #items + 1
                    selected = items[idx]
                    dropBtn.Text = "  " .. tostring(selected)
                    if callback then pcall(callback, selected) end
                end)

                return {
                    SetValue = function(v)
                        selected = v
                        dropBtn.Text = "  " .. tostring(selected)
                        if callback then pcall(callback, selected) end
                    end
                }
            end

            function Group:AddButton(label, callback)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 22)
                btn.BackgroundColor3 = Library.Theme.InputBg
                btn.BorderSizePixel = 0
                btn.Font = Enum.Font.RobotoMono
                btn.TextSize = 10
                btn.TextColor3 = Library.Theme.Accent
                btn.Text = label
                btn.Parent = container

                local bStroke = Instance.new("UIStroke")
                bStroke.Color = Library.Theme.InputBorder
                bStroke.Thickness = 1
                bStroke.Parent = btn

                local bCorner = Instance.new("UICorner")
                bCorner.CornerRadius = UDim.new(0, 3)
                bCorner.Parent = btn

                btn.MouseButton1Click:Connect(function()
                    if callback then pcall(callback) end
                end)
            end

            return Group
        end

        tabs[tabName] = { Button = tabBtn, Stroke = tabStroke, Label = tabLabel, Pane = tabPane }
        if not activeTab then activate() end
        return Tab
    end

    return Window
end

-- =========================================================================
-- CREATE MAIN WINDOW & TABS
-- =========================================================================
local Window = Library.CreateWindow({
    Title = "SILENT.cc",
    Game = "99 Nights in the Forest",
    Size = Vector2.new(680, 520),
    ToggleKey = Enum.KeyCode.RightControl
})

local CombatTab = Window:CreateTab("Combat")
local SurvivalTab = Window:CreateTab("Survival")
local ExploitsTab = Window:CreateTab("Exploits")
local VisualsTab = Window:CreateTab("Visuals")
local TeleportsTab = Window:CreateTab("Teleports")
local MovementTab = Window:CreateTab("Movement")

-- =========================================================================
-- 1. COMBAT TAB
-- =========================================================================
local AuraGroup = CombatTab:CreateGroupbox("Kill Aura", "Left")
AuraGroup:AddToggle("Enabled", false, { Callback = function(v) state.killAura = v end })
AuraGroup:AddSlider("Range", 20, 200, 60, " studs", function(v) state.killAuraRange = v end)
AuraGroup:AddSlider("Attack Delay", 50, 500, 150, " ms", function(v) state.killAuraDelay = v / 1000 end)
AuraGroup:AddDropdown("Target Filter", { "Hostiles", "All", "Deer Only" }, "Hostiles", function(v) state.killAuraTarget = v end)

local DeerGroup = CombatTab:CreateGroupbox("Deer Banisher", "Right")
DeerGroup:AddToggle("Auto Banish The Deer", true, { Callback = function(v) state.deerBanisher = v end })
DeerGroup:AddSlider("Banish Distance", 50, 300, 120, " studs", function(v) state.deerBanishDist = v end)

local TreeGroup = CombatTab:CreateGroupbox("Tree Demolisher", "Right")
TreeGroup:AddToggle("Auto Chop Nearby Trees", false, { Callback = function(v) state.chopTrees = v end })
TreeGroup:AddSlider("Chop Range", 10, 80, 30, " studs", function(v) state.chopRange = v end)

-- =========================================================================
-- 2. SURVIVAL TAB
-- =========================================================================
local FireGroup = SurvivalTab:CreateGroupbox("Campfire Automation", "Left")
FireGroup:AddToggle("Auto Feed Campfire", false, { Callback = function(v) state.autoCampfire = v end })
FireGroup:AddSlider("Feed Search Radius", 50, 400, 150, " studs", function(v) state.autoCampfireRange = v end)
FireGroup:AddButton("Instant Feed 1x Log/Fuel", function()
    local campfire = Workspace:FindFirstChild("Structures") and Workspace.Structures:FindFirstChild("Campfire")
    if not campfire then return end
    local burnRemote = getRemote("RequestBurnItem") or getRemote("BurnItemInFire")
    if burnRemote and Workspace:FindFirstChild("Items") then
        for _, item in ipairs(Workspace.Items:GetChildren()) do
            local name = item.Name:lower()
            if name:find("log") or name:find("coal") or name:find("fuel") or name:find("wood") then
                pcall(function() burnRemote:FireServer(item) end)
                break
            end
        end
    end
end)

local StatGroup = SurvivalTab:CreateGroupbox("Godmode & Needs", "Right")
StatGroup:AddToggle("Godmode (Block Damage)", false, { Callback = function(v) state.godmode = v end })
StatGroup:AddToggle("Auto Eat Food", false, { Callback = function(v) state.autoEat = v end })
StatGroup:AddSlider("Eat Hunger Threshold", 10, 90, 60, "%", function(v) state.autoEatThreshold = v end)
StatGroup:AddToggle("Clear Storms & Rain", false, { Callback = function(v) state.clearWeather = v end })
StatGroup:AddToggle("Auto Crank Sawmill", false, { Callback = function(v) state.autoSawmill = v end })

-- =========================================================================
-- 3. EXPLOITS & EVENTS TAB
-- =========================================================================
local CarnivalGroup = ExploitsTab:CreateGroupbox("Carnival Auto-Win", "Left")
CarnivalGroup:AddButton("Auto-Win Basketball Gallery", function()
    local r = getRemote("CarnivalCompleteBasketballGallery")
    if r then pcall(function() r:FireServer() end) end
end)
CarnivalGroup:AddButton("Auto-Win Ring Toss", function()
    local r = getRemote("CarnivalCompleteRingToss")
    if r then pcall(function() r:FireServer() end) end
end)
CarnivalGroup:AddButton("Auto-Win Shooting Gallery", function()
    local r = getRemote("CarnivalCompleteShootingGallery")
    if r then pcall(function() r:FireServer() end) end
end)
CarnivalGroup:AddButton("Claim Prize Booth Reward", function()
    local r = getRemote("ClaimPrizeBoothReward")
    if r then pcall(function() r:FireServer() end) end
end)

local EventGroup = ExploitsTab:CreateGroupbox("Quests & UFO", "Right")
EventGroup:AddButton("Auto Repair Alien Ship", function()
    local r = getRemote("RequestRepairAlienShip")
    if r then pcall(function() r:InvokeServer() end) end
end)
EventGroup:AddButton("Claim Alien Gear", function()
    local r = getRemote("ClaimAlienItem")
    if r then pcall(function() r:InvokeServer() end) end
end)
EventGroup:AddButton("Claim Happy's Scythe", function()
    local r = getRemote("RequestPickUpHappysScythe") or getRemote("ClaimHappyReward")
    if r then pcall(function() r:FireServer() end) end
end)
EventGroup:AddButton("Discover Entire Map (Remove Fog)", function()
    local rFade = getRemote("FadeOutFogBlock")
    local rMap = getRemote("MapCellsDiscovered")
    pcall(function()
        if rFade then
            for i = 1, 200 do rFade:FireServer(i) end
        end
        if rMap then rMap:FireServer(100) end
    end)
end)

-- =========================================================================
-- 4. VISUALS & ESP TAB
-- =========================================================================
local EspMaster = VisualsTab:CreateGroupbox("ESP Master", "Left")
EspMaster:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.H, Callback = function(v) state.esp = v end })
EspMaster:AddToggle("The Deer (Hostile Stalker)", true, { Callback = function(v) state.espDeer = v end })
EspMaster:AddToggle("Hostile Mobs (Bears, Wolves, Cultists)", true, { Callback = function(v) state.espHostiles = v end })
EspMaster:AddToggle("Passive Wildlife (Boars, Bunnies, Frogs)", false, { Callback = function(v) state.espPassive = v end })
EspMaster:AddToggle("4 Lost Children", true, { Callback = function(v) state.espKids = v end })
EspMaster:AddToggle("Campfire & Structures", true, { Callback = function(v) state.espCampfire = v end })
EspMaster:AddToggle("Chests & Keys", true, { Callback = function(v) state.espChests = v end })
EspMaster:AddToggle("Ground Items", false, { Callback = function(v) state.espItems = v end })
EspMaster:AddSlider("Max Distance", 100, 3000, 1200, " studs", function(v) state.espMaxDist = v end)

local WorldVis = VisualsTab:CreateGroupbox("World Visuals", "Right")
WorldVis:AddToggle("Fullbright", false, { Callback = function(v) state.fullbright = v end })
WorldVis:AddToggle("Remove Atmosphere Fog", false, { Callback = function(v) state.noFog = v end })

-- =========================================================================
-- 5. TELEPORTS TAB
-- =========================================================================
local TpGroup = TeleportsTab:CreateGroupbox("Landmarks & Base", "Left")
local function warpTo(pos)
    local root = getRoot()
    if root and pos then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

TpGroup:AddButton("Teleport to Campfire", function()
    local camp = Workspace:FindFirstChild("Structures") and Workspace.Structures:FindFirstChild("Campfire")
    if camp then
        local p = camp.PrimaryPart or camp:FindFirstChildWhichIsA("BasePart")
        if p then warpTo(p.Position) end
    end
end)
TpGroup:AddButton("Teleport to Tool Trader", function()
    warpTo(Vector3.new(280, 2, -240))
end)
TpGroup:AddButton("Teleport to Crafting Bench", function()
    warpTo(Vector3.new(19.9, 3.5, -3.2))
end)
TpGroup:AddButton("Teleport to Upgrade Bench", function()
    warpTo(Vector3.new(270, 2, -232))
end)
TpGroup:AddButton("Teleport to Stronghold Entrance", function()
    warpTo(Vector3.new(559.4, 1.5, 709.6))
end)

local KidTp = TeleportsTab:CreateGroupbox("Lost Children Teleports", "Right")
KidTp:AddButton("Teleport to Nearest Lost Child", function()
    local root = getRoot()
    if not root or not Workspace:FindFirstChild("Characters") then return end
    local closest, closestDist = nil, math.huge
    for _, ch in ipairs(Workspace.Characters:GetChildren()) do
        local n = ch.Name:lower()
        if n:find("child") or n:find("kid") or n:find("lost") then
            local p = ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart")
            if p then
                local d = (root.Position - p.Position).Magnitude
                if d < closestDist then closest = p.Position; closestDist = d end
            end
        end
    end
    if closest then warpTo(closest) end
end)

-- =========================================================================
-- 6. MOVEMENT TAB
-- =========================================================================
local MoveGroup = MovementTab:CreateGroupbox("Speed & Physics", "Left")
MoveGroup:AddToggle("Speed", false, { Keybind = Enum.KeyCode.Z, Callback = function(v) state.speed = v end })
MoveGroup:AddDropdown("Speed Mode", { "CFrame", "WalkSpeed" }, "CFrame", function(v) state.speedMode = v end)
MoveGroup:AddSlider("Speed Value", 16, 200, 28, "", function(v) state.speedValue = v end)
MoveGroup:AddToggle("Jump Power", false, { Callback = function(v) state.jump = v end })
MoveGroup:AddSlider("Jump Power Value", 50, 300, 55, "", function(v) state.jumpValue = v end)
MoveGroup:AddToggle("Noclip", false, { Callback = function(v) state.noclip = v end })
MoveGroup:AddToggle("Infinite Jump", false, { Callback = function(v) state.infJump = v end })

local FlyGroup = MovementTab:CreateGroupbox("Flight", "Right")
FlyGroup:AddToggle("Fly", false, { Keybind = Enum.KeyCode.G, Callback = function(v) state.fly = v end })
FlyGroup:AddSlider("Fly Speed", 10, 250, 60, "", function(v) state.flySpeed = v end)

-- =========================================================================
-- ENGINE HOOKS & RUNTIME THREADS
-- =========================================================================

-- 1. Godmode Hook (Nullifies incoming DamagePlayer)
if typeof(hookmeta) == "function" then
    pcall(function()
        local origNamecall
        origNamecall = hookmeta(game, "__namecall", newccl(function(self, ...)
            local m = getnamecallmethod()
            if state.godmode and not state.unloaded and (m == "FireServer" or m == "fireServer") then
                if self.Name == "DamagePlayer" or self.Name == "NPCProjectileDamagePlayer" or self.Name == "JungleSpikeTrapDamage" then
                    return nil
                end
            end
            return origNamecall(self, ...)
        end))
    end)
end

-- 2. Combat Loop (Kill Aura & Deer Banisher)
local lastAura = 0
track(RunService.Heartbeat:Connect(function()
    if state.unloaded then return end
    local root = getRoot()
    if not root then return end

    local charsFolder = Workspace:FindFirstChild("Characters")
    if not charsFolder then return end

    -- Deer Banisher check
    if state.deerBanisher then
        local deerRemote = getRemote("HurtDeerTorch") or getRemote("MonsterHitByTorch")
        if deerRemote then
            for _, ent in ipairs(charsFolder:GetChildren()) do
                if ent.Name:lower():find("deer") then
                    local p = ent.PrimaryPart or ent:FindFirstChildWhichIsA("BasePart")
                    if p and (p.Position - root.Position).Magnitude <= state.deerBanishDist then
                        pcall(function() deerRemote:FireServer(ent) end)
                    end
                end
            end
        end
    end

    -- Mob Kill Aura
    if state.killAura and os.clock() - lastAura >= state.killAuraDelay then
        lastAura = os.clock()
        local dmgFunction = getRemote("ToolDamageObject")
        local isHostileOnly = state.killAuraTarget == "Hostiles"
        local isDeerOnly = state.killAuraTarget == "Deer Only"

        for _, ent in ipairs(charsFolder:GetChildren()) do
            local hum = ent:FindFirstChildOfClass("Humanoid")
            local n = ent.Name:lower()
            local isDeer = n:find("deer") ~= nil
            local isHostile = isDeer or n:find("cultist") or n:find("wolf") or n:find("bear") or n:find("boss") or n:find("bat")

            local validTarget = false
            if isDeerOnly then
                validTarget = isDeer
            elseif isHostileOnly then
                validTarget = isHostile
            else
                validTarget = hum ~= nil and ent ~= getChar()
            end

            if validTarget and (not hum or hum.Health > 0) then
                local p = ent.PrimaryPart or ent:FindFirstChildWhichIsA("BasePart")
                if p and (p.Position - root.Position).Magnitude <= state.killAuraRange then
                    -- Dispatch NpcEvent if present on the mob
                    local mobEvent = ent:FindFirstChild("NpcEvent")
                    if mobEvent and mobEvent:IsA("RemoteEvent") then
                        pcall(function() mobEvent:FireServer("Damage", 100) end)
                    end
                    -- Dispatch ToolDamageObject
                    if dmgFunction and dmgFunction:IsA("RemoteFunction") then
                        task.spawn(function()
                            pcall(function() dmgFunction:InvokeServer(ent, state.damageAmount) end)
                        end)
                    end
                end
            end
        end
    end

    -- Tree Demolisher
    if state.chopTrees then
        local dmgFunction = getRemote("ToolDamageObject")
        local mapFolder = Workspace:FindFirstChild("Map")
        local foliage = mapFolder and mapFolder:FindFirstChild("Foliage")
        if foliage and dmgFunction then
            for _, tree in ipairs(foliage:GetChildren()) do
                if tree.Name:lower():find("tree") then
                    local p = tree.PrimaryPart or tree:FindFirstChildWhichIsA("BasePart")
                    if p and (p.Position - root.Position).Magnitude <= state.chopRange then
                        task.spawn(function()
                            pcall(function() dmgFunction:InvokeServer(tree, 150) end)
                        end)
                    end
                end
            end
        end
    end
end))

-- 3. Survival Automation Loop (Campfire, Auto-Eat, Sawmill, Weather)
local lastSurv = 0
track(RunService.Heartbeat:Connect(function()
    if state.unloaded or os.clock() - lastSurv < 1.0 then return end
    lastSurv = os.clock()

    -- Auto Feed Campfire
    if state.autoCampfire then
        local campfire = Workspace:FindFirstChild("Structures") and Workspace.Structures:FindFirstChild("Campfire")
        local itemsFolder = Workspace:FindFirstChild("Items")
        local burnRemote = getRemote("RequestBurnItem") or getRemote("BurnItemInFire")
        if campfire and itemsFolder and burnRemote then
            local cPos = campfire.PrimaryPart and campfire.PrimaryPart.Position or Vector3.zero
            for _, item in ipairs(itemsFolder:GetChildren()) do
                local n = item.Name:lower()
                if n:find("log") or n:find("coal") or n:find("fuel") or n:find("biofuel") or n:find("wood") then
                    local ip = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
                    if ip and (ip.Position - cPos).Magnitude <= state.autoCampfireRange then
                        pcall(function() burnRemote:FireServer(item) end)
                        break
                    end
                end
            end
        end
    end

    -- Auto Eat Food
    if state.autoEat then
        local hunger = LP:GetAttribute("Hunger")
        if typeof(hunger) == "number" and hunger <= state.autoEatThreshold then
            local consumeFn = getRemote("RequestConsumeItem")
            if consumeFn and LP:FindFirstChild("Backpack") then
                for _, t in ipairs(LP.Backpack:GetChildren()) do
                    local n = t.Name:lower()
                    if n:find("meat") or n:find("carrot") or n:find("apple") or n:find("berry") or n:find("soup") or n:find("stew") then
                        pcall(function() consumeFn:InvokeServer(t) end)
                        break
                    end
                end
            end
        end
    end

    -- Auto Crank Sawmill
    if state.autoSawmill then
        local rSaw = getRemote("RequestPullSawmillLever")
        if rSaw then pcall(function() rSaw:FireServer() end) end
    end

    -- Clear Storms & Rain
    if state.clearWeather then
        local rW = getRemote("RequestClearWeather")
        if rW then pcall(function() rW:InvokeServer() end) end
    end
end))

-- 4. Movement Loop (Speed, Jump, Noclip, Fly)
local flyBV = nil
track(RunService.RenderStepped:Connect(function()
    if state.unloaded then return end
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

    -- Jump Power
    if state.jump then
        hum.UseJumpPower = true
        hum.JumpPower = state.jumpValue
        pcall(function() hum.JumpHeight = state.jumpValue / 7 end)
    end

    -- Noclip
    if state.noclip then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end

    -- Fly
    if state.fly then
        if not flyBV then
            flyBV = Instance.new("BodyVelocity")
            flyBV.Name = "ForestFly"
            flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBV.Velocity = Vector3.zero
            flyBV.Parent = root
        end
        local camCF = cam().CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
        flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * state.flySpeed or Vector3.zero
    elseif flyBV then
        pcall(function() flyBV:Destroy() end)
        flyBV = nil
    end
end))

-- Infinite Jump
track(UserInputService.JumpRequest:Connect(function()
    if state.infJump and not state.unloaded then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- 5. Lighting / Fullbright Loop
local savedAmbient = Lighting.Ambient
local savedFog = Lighting.FogEnd
track(RunService.RenderStepped:Connect(function()
    if state.unloaded then return end
    if state.fullbright then
        Lighting.Ambient = Color3.fromRGB(240, 240, 240)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    end
    if state.noFog then
        Lighting.FogEnd = 1e6
    end
end))

-- =========================================================================
-- 6. DRAWING-BASED ESP SYSTEM
-- =========================================================================
local espEntries = {}

local function createEspBox()
    if not hasDrawing then return nil end
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Visible = false

    local label = Drawing.new("Text")
    label.Size = 12
    label.Center = true
    label.Outline = true
    label.Visible = false

    return { Box = box, Label = label }
end

local function updateEsp(entry, pos, name, color, dist)
    local screenPos, onScreen = cam():WorldToViewportPoint(pos)
    if onScreen and screenPos.Z > 0 and dist <= state.espMaxDist then
        local size = math.clamp(1600 / dist, 12, 70)
        entry.Box.Size = Vector2.new(size * 0.7, size)
        entry.Box.Position = Vector2.new(screenPos.X - (size * 0.7) / 2, screenPos.Y - size / 2)
        entry.Box.Color = color
        entry.Box.Visible = true

        entry.Label.Text = string.format("%s [%dm]", name, math.floor(dist))
        entry.Label.Position = Vector2.new(screenPos.X, screenPos.Y - size / 2 - 14)
        entry.Label.Color = color
        entry.Label.Visible = true
    else
        entry.Box.Visible = false
        entry.Label.Visible = false
    end
end

track(RunService.RenderStepped:Connect(function()
    if not hasDrawing or state.unloaded or not state.esp then
        for _, e in pairs(espEntries) do
            e.Box.Visible = false
            e.Label.Visible = false
        end
        return
    end

    local root = getRoot()
    local rootPos = root and root.Position or cam().CFrame.Position

    -- 1. Scan Characters (The Deer, Hostiles, Wildlife, Kids)
    local chars = Workspace:FindFirstChild("Characters")
    if chars then
        for _, ent in ipairs(chars:GetChildren()) do
            local p = ent.PrimaryPart or ent:FindFirstChildWhichIsA("BasePart")
            if p and ent ~= getChar() then
                local n = ent.Name:lower()
                local isDeer = n:find("deer") ~= nil
                local isKid = n:find("child") or n:find("kid") or n:find("lost")
                local isHostile = isDeer or n:find("cultist") or n:find("wolf") or n:find("bear") or n:find("boss") or n:find("bat")
                local isPassive = n:find("bunny") or n:find("boar") or n:find("frog")

                local show = false
                local color = state.colHostile
                local name = ent.Name

                if isDeer and state.espDeer then
                    show = true; color = state.colDeer; name = "[!] THE DEER"
                elseif isKid and state.espKids then
                    show = true; color = state.colKids; name = "LOST CHILD"
                elseif isHostile and state.espHostiles then
                    show = true; color = state.colHostile
                elseif isPassive and state.espPassive then
                    show = true; color = state.colPassive
                end

                if show then
                    if not espEntries[ent] then espEntries[ent] = createEspBox() end
                    local dist = (rootPos - p.Position).Magnitude
                    updateEsp(espEntries[ent], p.Position, name, color, dist)
                elseif espEntries[ent] then
                    espEntries[ent].Box.Visible = false
                    espEntries[ent].Label.Visible = false
                end
            end
        end
    end

    -- 2. Campfire ESP
    if state.espCampfire then
        local campfire = Workspace:FindFirstChild("Structures") and Workspace.Structures:FindFirstChild("Campfire")
        if campfire then
            local p = campfire.PrimaryPart or campfire:FindFirstChildWhichIsA("BasePart")
            if p then
                if not espEntries[campfire] then espEntries[campfire] = createEspBox() end
                local dist = (rootPos - p.Position).Magnitude
                updateEsp(espEntries[campfire], p.Position, "CAMPFIRE", state.colCamp, dist)
            end
        end
    end
end))

-- Cleanup routine
local function Unload()
    state.unloaded = true
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if flyBV then pcall(function() flyBV:Destroy() end) end
    for _, e in pairs(espEntries) do
        pcall(function() e.Box:Remove(); e.Label:Remove() end)
    end
    Lighting.Ambient = savedAmbient
    Lighting.FogEnd = savedFog
    pcall(function() Window.ScreenGui:Destroy() end)
    print("[SILENT.cc] 99 Nights in the Forest suite unloaded.")
end

getgenv().SilentForest = { Unload = Unload }
print("[SILENT.cc] 99 Nights in the Forest loaded successfully!")
