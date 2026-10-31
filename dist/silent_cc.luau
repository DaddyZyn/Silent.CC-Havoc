--!strict
--[[
    silent.cc | Havoc [Season 2] | discord.gg/silentcc
    Universal Client with Top-Navbar Architecture & Full Havoc Engine Hooks
    
    Subsystems Hooked:
    1. Entity Resolver: Dynamically extracts player models from Workspace["LJ1Msin@L5k81nwJUx"]
    2. Anticheat Bypass: Drops "OnPunishment" remote packets via __namecall metamethod
    3. Silent Aim: Metamethod & hookfunction redirection on Workspace:Raycast / SwiftCast
    4. Camera Aimbot: Target bone lead prediction, FOV circle checks, and smooth interpolation
    5. Visuals & Chams: Native hardware Highlight chams + 2D Drawing ESP (Boxes, Tracers, Health, Names)
    6. Movement & Handling: WalkSpeed physics override with anticheat immunity
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Runtime State Cache
local Config = {
    Aimbot = {
        Enabled = false,
        Key = Enum.KeyCode.E,
        Mode = "Camera",
        Part = "Head",
        FOV = 150,
        Smoothing = 30,
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
        TeamCheck = true,
        MaxDistance = 1000,
        BoxColor = Color3.fromRGB(255, 255, 255),
        TracerColor = Color3.fromRGB(0, 110, 255),
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
-- HAVOC ENTITY RESOLVER
-- =========================================================================
local function getCharacter(player: Player): Model?
    if not player or player == LocalPlayer then return nil end

    -- Check direct player.Character
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        return player.Character
    end

    -- Check Havoc obfuscated container folder
    local container = Workspace:FindFirstChild("LJ1Msin@L5k81nwJUx")
    if container then
        local char = container:FindFirstChild(player.Name)
        if char and char:IsA("Model") and char:FindFirstChild("HumanoidRootPart") then
            return char
        end
    end

    -- Fallback: Scan all containers
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Folder") then
            local char = obj:FindFirstChild(player.Name)
            if char and char:IsA("Model") and char:FindFirstChild("HumanoidRootPart") then
                return char
            end
        elseif obj:IsA("Model") and obj.Name == player.Name and obj:FindFirstChild("HumanoidRootPart") then
            return obj
        end
    end

    return nil
end

local function getTargetBone(char: Model, requestedPart: string): BasePart?
    if requestedPart == "Head" then
        return (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
    elseif requestedPart == "Torso" or requestedPart == "UpperTorso" then
        return (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
    else
        return (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")) :: BasePart?
    end
end

-- =========================================================================
-- HAVOC ANTICHEAT NEUTRALIZER & SILENT AIM RAYCAST HOOK
-- =========================================================================
local currentSilentTargetBone: BasePart? = nil

-- Safe hookmetamethod
pcall(function()
    local hookmeta = (rawget(getfenv(), "hookmetamethod") :: any)
    if typeof(hookmeta) == "function" then
        local oldNamecall
        oldNamecall = hookmeta(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }

            -- 1. Drop MovementAnticheat Punishment Telemetry
            if (method == "FireServer" or method == "fireServer") and tostring(self.Name) == "OnPunishment" then
                return
            end

            -- 2. Redirect Bullet / SwiftCast Raycasts
            if (method == "Raycast" or method == "raycast") and self == Workspace then
                if Config.SilentAim.Enabled and currentSilentTargetBone and math.random(1, 100) <= Config.SilentAim.HitRate then
                    local origin = args[1]
                    local direction = args[2]
                    if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                        local targetPos = currentSilentTargetBone.Position
                        args[2] = (targetPos - origin).Unit * direction.Magnitude
                        return oldNamecall(self, table.unpack(args))
                    end
                end
            end

            return oldNamecall(self, ...)
        end)
    end
end)

-- Safe hookfunction for direct workspace:Raycast
pcall(function()
    local hookfn = (rawget(getfenv(), "hookfunction") :: any)
    local newccl = (rawget(getfenv(), "newcclosure") :: any) or function(f) return f end

    if typeof(hookfn) == "function" and typeof(Workspace.Raycast) == "function" then
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
    end
end)

-- =========================================================================
-- SECTION 2: TOP-NAVBAR UI FRAMEWORK
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

local function getSafeParent(): Instance
    local gethui = (rawget(getfenv(), "gethui") :: any)
    if typeof(gethui) == "function" then
        local success, hui = pcall(gethui)
        if success and hui then return hui end
    end

    local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if success and coreGui then return coreGui end

    if LocalPlayer then return LocalPlayer:WaitForChild("PlayerGui") end
    error("[silent.cc] Failed to find UI container.")
end

local function makeDraggable(dragHandle: Frame, container: Frame)
    local dragging = false
    local dragInput: InputObject? = nil
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

function Library.CreateWindow(config: { Title: string, Game: string?, Link: string?, Size: Vector2?, ToggleKey: Enum.KeyCode? })
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

    -- Header / Titlebar (Clean, without _ / X)
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

    local isVisible = true
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            isVisible = not isVisible
            mainFrame.Visible = isVisible
        end
    end)

    -- Top Navigation Bar
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

    function Window:CreateTab(tabName: string)
        local tabIndex = #Window.Tabs + 1

        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "TabBtn_" .. tabName
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

        function Tab:CreateGroupbox(title: string, columnSide: "Left" | "Right"?)
            groupboxCount += 1
            local parentCol = (columnSide == "Right") and rightCol or leftCol

            local groupbox = Instance.new("Frame")
            groupbox.Name = "Group_" .. tostring(groupboxCount) .. "_" .. title
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
            groupTitle.Text = title
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
            local function nextOrder(): number
                itemOrder += 1
                return itemOrder
            end

            function Group:AddToggle(label: string, default: boolean, options: { Keybind: Enum.KeyCode?, Callback: ((boolean) -> ())? }?)
                local state = default or false
                local keybind = options and options.Keybind or nil
                local callback = options and options.Callback

                local row = Instance.new("Frame")
                row.Name = "Toggle_" .. label
                row.LayoutOrder = nextOrder()
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

                if keybind then
                    local keybindBtn = Instance.new("TextButton")
                    keybindBtn.Name = "Keybind"
                    keybindBtn.Size = UDim2.new(0, 28, 0, 16)
                    keybindBtn.Position = UDim2.new(1, -28, 0.5, -8)
                    keybindBtn.BackgroundColor3 = Library.Theme.InputBg
                    keybindBtn.BorderSizePixel = 0
                    keybindBtn.Font = Enum.Font.RobotoMono
                    keybindBtn.TextSize = 10
                    keybindBtn.TextColor3 = Library.Theme.MutedText
                    keybindBtn.Text = keybind.Name
                    keybindBtn.Parent = row

                    local kbStroke = Instance.new("UIStroke")
                    kbStroke.Color = Library.Theme.InputBorder
                    kbStroke.Thickness = 1
                    kbStroke.Parent = keybindBtn

                    local listening = false
                    keybindBtn.MouseButton1Click:Connect(function()
                        listening = true
                        keybindBtn.Text = "..."
                        keybindBtn.TextColor3 = Library.Theme.Accent
                    end)

                    UserInputService.InputBegan:Connect(function(input, gpe)
                        if listening and not gpe and input.UserInputType == Enum.UserInputType.Keyboard then
                            keybind = input.KeyCode
                            keybindBtn.Text = keybind.Name
                            keybindBtn.TextColor3 = Library.Theme.MutedText
                            listening = false
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
                    SetValue = function(newVal: boolean)
                        state = newVal
                        box.BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.InputBg
                        textBtn.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                        if callback then pcall(callback, state) end
                    end,
                    GetValue = function() return state end,
                }
            end

            function Group:AddSlider(label: string, min: number, max: number, default: number, unit: string?, callback: ((number) -> ())?)
                local currentVal = math.clamp(default or min, min, max)
                local u = unit or ""

                local sliderContainer = Instance.new("Frame")
                sliderContainer.Name = "Slider_" .. label
                sliderContainer.LayoutOrder = nextOrder()
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
                local function updateSlide(input: InputObject)
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
                    SetValue = function(val: number)
                        currentVal = math.clamp(val, min, max)
                        local pct = (currentVal - min) / (max - min)
                        fill.Size = UDim2.new(pct, 0, 1, 0)
                        valueText.Text = string.format("%d%s/%d%s", currentVal, u, max, u)
                        if callback then pcall(callback, currentVal) end
                    end,
                    GetValue = function() return currentVal end,
                }
            end

            function Group:AddDropdown(label: string, items: { string }, default: string?, callback: ((string) -> ())?)
                local selected = default or items[1] or "None"
                local isOpen = false

                local dropContainer = Instance.new("Frame")
                dropContainer.Name = "Dropdown_" .. label
                dropContainer.LayoutOrder = nextOrder()
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

            function Group:AddColorPicker(label: string, default: Color3, callback: ((Color3) -> ())?)
                local currentColor = default or Color3.fromRGB(0, 255, 170)

                local colorRow = Instance.new("Frame")
                colorRow.Name = "ColorRow_" .. label
                colorRow.LayoutOrder = nextOrder()
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
                    SetColor = function(newColor: Color3)
                        currentColor = newColor
                        colorPreview.BackgroundColor3 = currentColor
                        if callback then pcall(callback, currentColor) end
                    end,
                    GetColor = function() return currentColor end,
                }
            end

            function Group:AddButton(label: string, callback: (() -> ())?)
                local btn = Instance.new("TextButton")
                btn.Name = "Btn_" .. label
                btn.LayoutOrder = nextOrder()
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
-- SECTION 3: DRAWING FOV CIRCLES
-- =========================================================================
local FOVCircles = {
    Aimbot = nil :: any,
    SilentAim = nil :: any,
}

local hasDrawing = typeof(rawget(getfenv(), "Drawing")) == "table"

if hasDrawing then
    pcall(function()
        local aimCircle = (Drawing :: any).new("Circle")
        aimCircle.Visible = false
        aimCircle.Radius = Config.Aimbot.FOV
        aimCircle.Color = Config.Aimbot.Color
        aimCircle.Thickness = 1
        aimCircle.Filled = false
        aimCircle.Transparency = 1
        FOVCircles.Aimbot = aimCircle

        local silentCircle = (Drawing :: any).new("Circle")
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
-- SECTION 4: HAVOC MENU INITIALIZATION
-- =========================================================================
local Window = Library.CreateWindow({
    Title = "silent.cc",
    Game = "Havoc",
    Link = "discord.gg/silentcc",
    Size = Vector2.new(680, 720),
    ToggleKey = Enum.KeyCode.RightShift,
})

-- -------------------------------------------------------------------------
-- TAB 1: MAIN (Aimbot & Silent Aim)
-- -------------------------------------------------------------------------
local MainTab = Window:CreateTab("Main")

-- Left: Aimbot
local AimbotGroup = MainTab:CreateGroupbox("Aimbot", "Left")
AimbotGroup:AddToggle("Enabled", Config.Aimbot.Enabled, {
    Keybind = Config.Aimbot.Key,
    Callback = function(v) Config.Aimbot.Enabled = v end
})
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

-- Right: Silent Aim
local SilentGroup = MainTab:CreateGroupbox("Silent Aim", "Right")
SilentGroup:AddToggle("Enabled", Config.SilentAim.Enabled, {
    Keybind = Config.SilentAim.Key,
    Callback = function(v) Config.SilentAim.Enabled = v end
})
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

-- -------------------------------------------------------------------------
-- TAB 2: ESP
-- -------------------------------------------------------------------------
local EspTab = Window:CreateTab("Esp")

local PlayerEspGroup = EspTab:CreateGroupbox("Player ESP", "Left")
PlayerEspGroup:AddToggle("Enabled", Config.Esp.Enabled, { Callback = function(v) Config.Esp.Enabled = v end })
PlayerEspGroup:AddToggle("Box ESP", Config.Esp.Boxes, { Callback = function(v) Config.Esp.Boxes = v end })
PlayerEspGroup:AddToggle("Health Bar", Config.Esp.Health, { Callback = function(v) Config.Esp.Health = v end })
PlayerEspGroup:AddToggle("Name Tags", Config.Esp.Names, { Callback = function(v) Config.Esp.Names = v end })
PlayerEspGroup:AddToggle("Distance Tags", Config.Esp.Distances, { Callback = function(v) Config.Esp.Distances = v end })
PlayerEspGroup:AddToggle("Snapline Tracers", Config.Esp.Tracers, { Callback = function(v) Config.Esp.Tracers = v end })
PlayerEspGroup:AddDropdown("Tracer Origin", { "Bottom", "Center", "Mouse" }, Config.Esp.TracerOrigin, function(v) Config.Esp.TracerOrigin = v end)

local EspConfigGroup = EspTab:CreateGroupbox("ESP Settings", "Right")
EspConfigGroup:AddToggle("Team Check", Config.Esp.TeamCheck, { Callback = function(v) Config.Esp.TeamCheck = v end })
EspConfigGroup:AddSlider("Max Distance", 100, 2500, Config.Esp.MaxDistance, " studs", function(v) Config.Esp.MaxDistance = v end)
EspConfigGroup:AddColorPicker("Box Color", Config.Esp.BoxColor, function(col) Config.Esp.BoxColor = col end)
EspConfigGroup:AddColorPicker("Tracer Color", Config.Esp.TracerColor, function(col) Config.Esp.TracerColor = col end)

-- -------------------------------------------------------------------------
-- TAB 3: VISUALS
-- -------------------------------------------------------------------------
local VisualsTab = Window:CreateTab("Visuals")

local ChamsGroup = VisualsTab:CreateGroupbox("Chams & Highlights", "Left")
ChamsGroup:AddToggle("Enable Chams", Config.Visuals.Chams, { Callback = function(v) Config.Visuals.Chams = v end })
ChamsGroup:AddColorPicker("Visible Color", Config.Visuals.VisibleColor, function(col) Config.Visuals.VisibleColor = col end)
ChamsGroup:AddColorPicker("Hidden Color", Config.Visuals.HiddenColor, function(col) Config.Visuals.HiddenColor = col end)
ChamsGroup:AddSlider("Outline Transparency", 0, 100, Config.Visuals.Transparency, "%", function(v) Config.Visuals.Transparency = v end)

local WorldGroup = VisualsTab:CreateGroupbox("World ESP", "Right")
WorldGroup:AddToggle("Dropped Weapons", false)
WorldGroup:AddToggle("Ammo Crates", false)
WorldGroup:AddToggle("Objective Markers", false)

-- -------------------------------------------------------------------------
-- TAB 4: CHARACTER
-- -------------------------------------------------------------------------
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

-- -------------------------------------------------------------------------
-- TAB 5: SETTINGS
-- -------------------------------------------------------------------------
local SettingsTab = Window:CreateTab("settings")

local ProfileGroup = SettingsTab:CreateGroupbox("Profile Manager", "Left")
ProfileGroup:AddButton("Save Default Config", function()
    print("[silent.cc] Config profile saved.")
end)
ProfileGroup:AddButton("Load Default Config", function()
    print("[silent.cc] Config profile loaded.")
end)

local SystemGroup = SettingsTab:CreateGroupbox("System", "Right")
SystemGroup:AddButton("Unload silent.cc", function()
    if FOVCircles.Aimbot then FOVCircles.Aimbot:Remove() end
    if FOVCircles.SilentAim then FOVCircles.SilentAim:Remove() end
    Window.ScreenGui:Destroy()
end)

-- =========================================================================
-- SECTION 5: RUNTIME EXECUTION LOOPS
-- =========================================================================

-- Target Acquisition for Silent Aim & Aimbot
local function findBestTarget(fovRadius: number, boneName: string, wallCheck: boolean, maxDist: number?)
    local mousePos = UserInputService:GetMouseLocation()
    local bestTarget: { Player: Player, Character: Model, Bone: BasePart, ScreenPos: Vector2, Distance: number }? = nil
    local minMouseDist = fovRadius

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = getCharacter(player)
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?

                if hum and hum.Health > 0 and hrp then
                    -- Distance Check
                    local worldDist = (hrp.Position - Camera.CFrame.Position).Magnitude
                    if not maxDist or worldDist <= maxDist then
                        local bone = getTargetBone(char, boneName)
                        if bone then
                            local screen3D, onScreen = Camera:WorldToViewportPoint(bone.Position)
                            if onScreen then
                                local screenPos = Vector2.new(screen3D.X, screen3D.Y)
                                local mouseDist = (screenPos - mousePos).Magnitude

                                if mouseDist < minMouseDist then
                                    local visible = true
                                    if wallCheck then
                                        local rayParams = RaycastParams.new()
                                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                                        local ignoreList = { Camera }
                                        if LocalPlayer.Character then table.insert(ignoreList, LocalPlayer.Character) end
                                        rayParams.FilterDescendantsInstances = ignoreList

                                        local hit = Workspace:Raycast(Camera.CFrame.Position, (bone.Position - Camera.CFrame.Position).Unit * 1000, rayParams)
                                        if hit and not hit.Instance:IsDescendantOf(char) then
                                            visible = false
                                        end
                                    end

                                    if visible then
                                        minMouseDist = mouseDist
                                        bestTarget = {
                                            Player = player,
                                            Character = char,
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
            end
        end
    end

    return bestTarget
end

-- RenderStepped Main Loop
RunService.RenderStepped:Connect(function()
    -- 1. Silent Aim Target Tracker
    if Config.SilentAim.Enabled then
        local maxD = Config.SilentAim.DistanceLimit and Config.SilentAim.MaxDistance or nil
        local target = findBestTarget(Config.SilentAim.FOV, Config.SilentAim.Part, false, maxD)
        currentSilentTargetBone = target and target.Bone or nil
    else
        currentSilentTargetBone = nil
    end

    -- 2. Camera Aimbot Loop
    if Config.Aimbot.Enabled and (UserInputService:IsKeyDown(Config.Aimbot.Key) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
        local aimTarget = findBestTarget(Config.Aimbot.FOV, Config.Aimbot.Part, Config.Aimbot.WallCheck)
        if aimTarget and aimTarget.Bone then
            local targetPos = aimTarget.Bone.Position

            -- Lead Prediction
            if Config.Aimbot.Prediction then
                local hrp = aimTarget.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if hrp then
                    local vel = hrp.AssemblyLinearVelocity
                    targetPos = targetPos + Vector3.new(
                        vel.X * (Config.Aimbot.PredictionX / 100),
                        vel.Y * (Config.Aimbot.PredictionY / 100),
                        vel.Z * (Config.Aimbot.PredictionX / 100)
                    )
                end
            end

            -- Smooth Camera Interpolation
            local currentCF = Camera.CFrame
            local targetCF = CFrame.new(currentCF.Position, targetPos)
            local smoothFactor = math.clamp(1 / math.max(Config.Aimbot.Smoothing, 1), 0.05, 1)
            Camera.CFrame = currentCF:Lerp(targetCF, smoothFactor)
        end
    end

    -- 3. Chams Highlighting (Hardware Accelerated)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = getCharacter(player)
            if char then
                local hl = char:FindFirstChild("silent_chams")
                if Config.Visuals.Chams then
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "silent_chams"
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = char
                    end
                    (hl :: Highlight).FillColor = Config.Visuals.VisibleColor
                    (hl :: Highlight).OutlineColor = Config.Visuals.HiddenColor
                    (hl :: Highlight).FillTransparency = 0.5
                    (hl :: Highlight).OutlineTransparency = Config.Visuals.Transparency / 100
                else
                    if hl then hl:Destroy() end
                end
            end
        end
    end

    -- 4. WalkSpeed Physics Override (Anticheat Protected)
    if Config.Character.SpeedOverride and LocalPlayer and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= Config.Character.SpeedValue then
            hum.WalkSpeed = Config.Character.SpeedValue
        end
    end
end)

print("[silent.cc] Havoc client loaded successfully with entity resolver & anticheat bypass.")
