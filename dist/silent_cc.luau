--!strict
--[[
    silent.cc | Havoc [Season 2] | discord.gg/silentcc
    Pure Luau Client with Integrated Top-Navbar Engine
    Engineered for precision targeting, ballistics telemetry, and ESP rendering.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- =========================================================================
-- SECTION 1: TOP-NAVBAR UI FRAMEWORK
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

    Accent = Color3.fromRGB(0, 110, 255),       -- Classic electric blue accent (or violet)
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
        if success and hui then
            return hui
        end
    end

    local success, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if success and coreGui then
        return coreGui
    end

    if LocalPlayer then
        return LocalPlayer:WaitForChild("PlayerGui")
    end

    error("[silent.cc] Failed to find UI parent container.")
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
            container.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

function Library.CreateWindow(config: { Title: string, Game: string?, Link: string?, Size: Vector2?, ToggleKey: Enum.KeyCode? })
    local title = config.Title or "silent.cc"
    local gameName = config.Game or "Havoc"
    local link = config.Link or "discord.gg/silentcc"
    local windowSize = config.Size or Vector2.new(580, 620)
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

    -- Header / Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 26)
    titleBar.BackgroundColor3 = Library.Theme.TitlebarBg
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.RobotoMono
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = Library.Theme.TitlebarText
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = string.format("%s  |  %s  |  %s", title, gameName, link)
    titleLabel.Parent = titleBar

    local minBtn = Instance.new("TextButton")
    minBtn.Name = "MinBtn"
    minBtn.Size = UDim2.new(0, 20, 0, 18)
    minBtn.Position = UDim2.new(1, -46, 0, 4)
    minBtn.BackgroundColor3 = Library.Theme.InputBg
    minBtn.BorderSizePixel = 0
    minBtn.Font = Enum.Font.RobotoMono
    minBtn.TextSize = 12
    minBtn.TextColor3 = Library.Theme.MutedText
    minBtn.Text = "_"
    minBtn.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 20, 0, 18)
    closeBtn.Position = UDim2.new(1, -24, 0, 4)
    closeBtn.BackgroundColor3 = Library.Theme.InputBg
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.RobotoMono
    closeBtn.TextSize = 11
    closeBtn.TextColor3 = Library.Theme.MutedText
    closeBtn.Text = "X"
    closeBtn.Parent = titleBar

    makeDraggable(titleBar, mainFrame)

    local isVisible = true
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            isVisible = not isVisible
            mainFrame.Visible = isVisible
        end
    end)

    minBtn.MouseButton1Click:Connect(function()
        isVisible = false
        mainFrame.Visible = false
    end)

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Top Navigation Bar
    local navBar = Instance.new("Frame")
    navBar.Name = "NavBar"
    navBar.Size = UDim2.new(1, -16, 0, 28)
    navBar.Position = UDim2.new(0, 8, 0, 28)
    navBar.BackgroundColor3 = Library.Theme.NavbarBg
    navBar.BorderSizePixel = 0
    navBar.Parent = mainFrame

    local navLayout = Instance.new("UIListLayout")
    navLayout.FillDirection = Enum.FillDirection.Horizontal
    navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    navLayout.Padding = UDim.new(0, 6)
    navLayout.Parent = navBar

    local navAccentLine = Instance.new("Frame")
    navAccentLine.Name = "NavAccentLine"
    navAccentLine.Size = UDim2.new(1, -16, 0, 1)
    navAccentLine.Position = UDim2.new(0, 8, 0, 58)
    navAccentLine.BackgroundColor3 = Library.Theme.Accent
    navAccentLine.BorderSizePixel = 0
    navAccentLine.Parent = mainFrame

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -16, 1, -66)
    contentArea.Position = UDim2.new(0, 8, 0, 62)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    local Window = {
        ScreenGui = screenGui,
        MainFrame = mainFrame,
        Tabs = {},
        CurrentTab = nil,
    }

    function Window:CreateTab(tabName: string)
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "TabBtn_" .. tabName
        tabBtn.Size = UDim2.new(0, 75, 0, 22)
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
        leftCol.Size = UDim2.new(0.5, -4, 0, 0)
        leftCol.Position = UDim2.new(0, 0, 0, 0)
        leftCol.AutomaticSize = Enum.AutomaticSize.Y
        leftCol.BackgroundTransparency = 1
        leftCol.Parent = columns

        local leftLayout = Instance.new("UIListLayout")
        leftLayout.FillDirection = Enum.FillDirection.Vertical
        leftLayout.Padding = UDim.new(0, 8)
        leftLayout.Parent = leftCol

        local rightCol = Instance.new("Frame")
        rightCol.Name = "RightCol"
        rightCol.Size = UDim2.new(0.5, -4, 0, 0)
        rightCol.Position = UDim2.new(0.5, 4, 0, 0)
        rightCol.AutomaticSize = Enum.AutomaticSize.Y
        rightCol.BackgroundTransparency = 1
        rightCol.Parent = columns

        local rightLayout = Instance.new("UIListLayout")
        rightLayout.FillDirection = Enum.FillDirection.Vertical
        rightLayout.Padding = UDim.new(0, 8)
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

        if #Window.Tabs == 0 then
            selectTab()
        end

        table.insert(Window.Tabs, tabData)

        local Tab = {}

        function Tab:CreateGroupbox(title: string, columnSide: "Left" | "Right"?)
            local parentCol = (columnSide == "Right") and rightCol or leftCol

            local groupbox = Instance.new("Frame")
            groupbox.Name = "Group_" .. title
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
            groupTitle.Size = UDim2.new(1, -16, 0, 20)
            groupTitle.Position = UDim2.new(0, 8, 0, 4)
            groupTitle.BackgroundTransparency = 1
            groupTitle.Font = Enum.Font.RobotoMono
            groupTitle.TextSize = 12
            groupTitle.TextColor3 = Library.Theme.GroupboxTitle
            groupTitle.TextXAlignment = Enum.TextXAlignment.Left
            groupTitle.Text = title
            groupTitle.Parent = groupbox

            local itemsContainer = Instance.new("Frame")
            itemsContainer.Name = "Items"
            itemsContainer.Size = UDim2.new(1, -16, 0, 0)
            itemsContainer.Position = UDim2.new(0, 8, 0, 26)
            itemsContainer.AutomaticSize = Enum.AutomaticSize.Y
            itemsContainer.BackgroundTransparency = 1
            itemsContainer.Parent = groupbox

            local itemsLayout = Instance.new("UIListLayout")
            itemsLayout.FillDirection = Enum.FillDirection.Vertical
            itemsLayout.Padding = UDim.new(0, 6)
            itemsLayout.Parent = itemsContainer

            local bottomPad = Instance.new("UIPadding")
            bottomPad.PaddingBottom = UDim.new(0, 8)
            bottomPad.Parent = itemsContainer

            local Group = {}

            function Group:AddToggle(label: string, default: boolean, options: { Keybind: Enum.KeyCode?, Callback: ((boolean) -> ())? }?)
                local state = default or false
                local keybind = options and options.Keybind or nil
                local callback = options and options.Callback

                local row = Instance.new("Frame")
                row.Name = "ToggleRow_" .. label
                row.Size = UDim2.new(1, 0, 0, 18)
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
                textBtn.Size = UDim2.new(1, -50, 1, 0)
                textBtn.Position = UDim2.new(0, 20, 0, 0)
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
                    keybindBtn.Size = UDim2.new(0, 26, 0, 16)
                    keybindBtn.Position = UDim2.new(1, -26, 0.5, -8)
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
                    if callback then
                        pcall(callback, state)
                    end
                end

                box.MouseButton1Click:Connect(toggleState)
                textBtn.MouseButton1Click:Connect(toggleState)

                return {
                    SetValue = function(newVal: boolean)
                        state = newVal
                        box.BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.InputBg
                        textBtn.TextColor3 = state and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                        if callback then
                            pcall(callback, state)
                        end
                    end,
                    GetValue = function() return state end,
                }
            end

            function Group:AddSlider(label: string, min: number, max: number, default: number, unit: string?, callback: ((number) -> ())?)
                local currentVal = math.clamp(default or min, min, max)
                local u = unit or ""

                local sliderContainer = Instance.new("Frame")
                sliderContainer.Name = "Slider_" .. label
                sliderContainer.Size = UDim2.new(1, 0, 0, 32)
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
                track.Size = UDim2.new(1, 0, 0, 14)
                track.Position = UDim2.new(0, 0, 0, 16)
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
                    if callback then
                        pcall(callback, val)
                    end
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
                        if callback then
                            pcall(callback, currentVal)
                        end
                    end,
                    GetValue = function() return currentVal end,
                }
            end

            function Group:AddDropdown(label: string, items: { string }, default: string?, callback: ((string) -> ())?)
                local selected = default or items[1] or "None"
                local isOpen = false

                local dropContainer = Instance.new("Frame")
                dropContainer.Name = "Dropdown_" .. label
                dropContainer.Size = UDim2.new(1, 0, 0, 38)
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
                dropBtn.Size = UDim2.new(1, 0, 0, 20)
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
                optionsFrame.Size = UDim2.new(1, 0, 0, #items * 20)
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
                optLayout.Parent = optionsFrame

                for _, item in ipairs(items) do
                    local opt = Instance.new("TextButton")
                    opt.Name = "Item_" .. item
                    opt.Size = UDim2.new(1, 0, 0, 20)
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
                        if callback then
                            pcall(callback, selected)
                        end
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
                colorRow.Size = UDim2.new(1, 0, 0, 20)
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
                colorPreview.Size = UDim2.new(0, 36, 0, 14)
                colorPreview.Position = UDim2.new(1, -36, 0.5, -7)
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
                        if callback then
                            pcall(callback, currentColor)
                        end
                    end,
                    GetColor = function() return currentColor end,
                }
            end

            function Group:AddButton(label: string, callback: (() -> ())?)
                local btn = Instance.new("TextButton")
                btn.Name = "Btn_" .. label
                btn.Size = UDim2.new(1, 0, 0, 22)
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
                    if callback then
                        pcall(callback)
                    end
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
-- SECTION 2: FOV DRAWING OVERLAY
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
        aimCircle.Radius = 150
        aimCircle.Color = Color3.fromRGB(0, 110, 255)
        aimCircle.Thickness = 1
        aimCircle.Filled = false
        aimCircle.Transparency = 1
        FOVCircles.Aimbot = aimCircle

        local silentCircle = (Drawing :: any).new("Circle")
        silentCircle.Visible = false
        silentCircle.Radius = 300
        silentCircle.Color = Color3.fromRGB(0, 255, 170)
        silentCircle.Thickness = 1
        silentCircle.Filled = false
        silentCircle.Transparency = 1
        FOVCircles.SilentAim = silentCircle

        RunService.RenderStepped:Connect(function()
            local mousePos = UserInputService:GetMouseLocation()
            if FOVCircles.Aimbot then
                FOVCircles.Aimbot.Position = mousePos
            end
            if FOVCircles.SilentAim then
                FOVCircles.SilentAim.Position = mousePos
            end
        end)
    end)
end

-- =========================================================================
-- SECTION 3: HAVOC MENU CONFIGURATION & CONTROLS
-- =========================================================================

local Window = Library.CreateWindow({
    Title = "silent.cc",
    Game = "Havoc",
    Link = "discord.gg/silentcc",
    Size = Vector2.new(580, 620),
    ToggleKey = Enum.KeyCode.RightShift,
})

-- -------------------------------------------------------------------------
-- TAB 1: MAIN (Aimbot & Silent Aim)
-- -------------------------------------------------------------------------
local MainTab = Window:CreateTab("Main")

-- Left: Aimbot
local AimbotGroup = MainTab:CreateGroupbox("Aimbot", "Left")
AimbotGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.E })
AimbotGroup:AddDropdown("Aim mode", { "Camera", "Mouse" }, "Camera")
AimbotGroup:AddDropdown("Aim part", { "Head", "UpperTorso", "HumanoidRootPart" }, "Head")
AimbotGroup:AddSlider("Circle Size", 50, 500, 150, "", function(val)
    if FOVCircles.Aimbot then FOVCircles.Aimbot.Radius = val end
end)
AimbotGroup:AddSlider("Smoothing", 1, 100, 30)
AimbotGroup:AddSlider("Mouse Sensitivity", 10, 400, 100, "%")
AimbotGroup:AddToggle("Prediction", false)
AimbotGroup:AddSlider("Prediction X", 0, 50, 17, "%")
AimbotGroup:AddSlider("Prediction Y", 0, 50, 2, "%")
AimbotGroup:AddToggle("Sticky Aim", false)
AimbotGroup:AddSlider("Sticky Range", 100, 1000, 400)
AimbotGroup:AddToggle("Show Circle", false, {
    Callback = function(v)
        if FOVCircles.Aimbot then FOVCircles.Aimbot.Visible = v end
    end
})
AimbotGroup:AddColorPicker("Circle Colour", Color3.fromRGB(0, 110, 255), function(col)
    if FOVCircles.Aimbot then FOVCircles.Aimbot.Color = col end
end)
AimbotGroup:AddSlider("Circle Y Offset", 0, 60, 0)

local ExtraAimbotGroup = MainTab:CreateGroupbox("Extra - Aimbot", "Left")
ExtraAimbotGroup:AddToggle("Wall Check", true)
ExtraAimbotGroup:AddToggle("Prioritize Low Health", false)

-- Right: Silent Aim
local SilentGroup = MainTab:CreateGroupbox("Silent Aim", "Right")
SilentGroup:AddToggle("Enabled", false, { Keybind = Enum.KeyCode.Q })
SilentGroup:AddSlider("Circle Size", 50, 600, 300, "", function(val)
    if FOVCircles.SilentAim then FOVCircles.SilentAim.Radius = val end
end)
SilentGroup:AddDropdown("Hit limb", { "HumanoidRootPart", "Head", "UpperTorso" }, "HumanoidRootPart")
SilentGroup:AddSlider("Hit Rate", 10, 100, 100, "%")
SilentGroup:AddToggle("Sticky Aim", false)
SilentGroup:AddSlider("Sticky Range", 100, 1000, 400)
SilentGroup:AddToggle("Show Circle", false, {
    Callback = function(v)
        if FOVCircles.SilentAim then FOVCircles.SilentAim.Visible = v end
    end
})
SilentGroup:AddColorPicker("Circle Colour", Color3.fromRGB(0, 255, 170), function(col)
    if FOVCircles.SilentAim then FOVCircles.SilentAim.Color = col end
end)
SilentGroup:AddSlider("Circle Y Offset", 0, 60, 0)

local ExtraSilentGroup = MainTab:CreateGroupbox("Extra - SilentAim", "Right")
ExtraSilentGroup:AddToggle("Disable When Carried", false)
ExtraSilentGroup:AddToggle("Bullet Spread", false)
ExtraSilentGroup:AddToggle("Distance Limit", false)
ExtraSilentGroup:AddSlider("Max Distance", 50, 500, 150, " studs")

-- -------------------------------------------------------------------------
-- TAB 2: ESP
-- -------------------------------------------------------------------------
local EspTab = Window:CreateTab("Esp")

local PlayerEspGroup = EspTab:CreateGroupbox("Player ESP", "Left")
PlayerEspGroup:AddToggle("Enabled", false)
PlayerEspGroup:AddToggle("Box ESP", false)
PlayerEspGroup:AddToggle("Skeleton", false)
PlayerEspGroup:AddToggle("Health Bar", false)
PlayerEspGroup:AddToggle("Name Tags", false)
PlayerEspGroup:AddToggle("Distance Tags", false)
PlayerEspGroup:AddToggle("Snapline Tracers", false)
PlayerEspGroup:AddDropdown("Tracer Origin", { "Bottom", "Center", "Mouse" }, "Bottom")

local EspConfigGroup = EspTab:CreateGroupbox("ESP Settings", "Right")
EspConfigGroup:AddToggle("Team Check", true)
EspConfigGroup:AddSlider("Max Distance", 100, 2500, 1000, " studs")
EspConfigGroup:AddColorPicker("Box Color", Color3.fromRGB(255, 255, 255))
EspConfigGroup:AddColorPicker("Tracer Color", Color3.fromRGB(0, 110, 255))

-- -------------------------------------------------------------------------
-- TAB 3: VISUALS
-- -------------------------------------------------------------------------
local VisualsTab = Window:CreateTab("Visuals")

local ChamsGroup = VisualsTab:CreateGroupbox("Chams & Highlights", "Left")
ChamsGroup:AddToggle("Enable Chams", false)
ChamsGroup:AddColorPicker("Visible Color", Color3.fromRGB(120, 87, 255))
ChamsGroup:AddColorPicker("Hidden Color", Color3.fromRGB(255, 60, 60))
ChamsGroup:AddSlider("Outline Transparency", 0, 100, 0, "%")

local WorldGroup = VisualsTab:CreateGroupbox("World ESP", "Right")
WorldGroup:AddToggle("Dropped Weapons", false)
WorldGroup:AddToggle("Ammo Crates", false)
WorldGroup:AddToggle("Objective Markers", false)

-- -------------------------------------------------------------------------
-- TAB 4: CHARACTER
-- -------------------------------------------------------------------------
local CharTab = Window:CreateTab("Character")

local MovementGroup = CharTab:CreateGroupbox("Movement", "Left")
MovementGroup:AddToggle("WalkSpeed Override", false, {
    Callback = function(enabled)
        if LocalPlayer and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = enabled and 24 or 16 end
        end
    end
})
MovementGroup:AddSlider("Speed Value", 16, 100, 24, " studs", function(val)
    if LocalPlayer and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = val end
    end
end)
MovementGroup:AddToggle("Infinite Stamina", false)
MovementGroup:AddToggle("Bunny Hop", false)

local WeaponGroup = CharTab:CreateGroupbox("Weapon Handling", "Right")
WeaponGroup:AddToggle("Fast Tactical Reload", false)
WeaponGroup:AddToggle("Recoil Neutralizer", false)
WeaponGroup:AddToggle("Spread Reduction", false)
WeaponGroup:AddToggle("Unlock Firemodes", false)

-- -------------------------------------------------------------------------
-- TAB 5: SETTINGS
-- -------------------------------------------------------------------------
local SettingsTab = Window:CreateTab("settings")

local ProfileGroup = SettingsTab:CreateGroupbox("Profile Manager", "Left")
ProfileGroup:AddButton("Save Default Config", function()
    print("[silent.cc] Saved configuration profile.")
end)
ProfileGroup:AddButton("Load Default Config", function()
    print("[silent.cc] Loaded configuration profile.")
end)

local SystemGroup = SettingsTab:CreateGroupbox("System", "Right")
SystemGroup:AddButton("Unload silent.cc", function()
    if FOVCircles.Aimbot then FOVCircles.Aimbot:Remove() end
    if FOVCircles.SilentAim then FOVCircles.SilentAim:Remove() end
    Window.ScreenGui:Destroy()
end)

print("[silent.cc] Havoc client loaded successfully.")
