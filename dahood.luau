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
    silentTeamCheck = true, wallbangMode = "Off", silentPrediction = true,
    silentCircle = false, silentColor = Color3.fromRGB(0, 200, 255), silentCircleY = 0,
    silentSnapline = false, silentSnaplineOrigin = "Gun", silentSnaplineWidth = 1,
    silentSnaplineColor = Color3.fromRGB(0, 200, 255),
    autoReload = false, infiniteAmmo = false, maxAmmo = 999, autoAttack = false, attackRange = 14,
    rapidFire = false, fireCooldown = 0.03,
    damageOverride = false, damageValue = 100,
    rangeOverride = false, rangeValue = 500,
    esp = false, espBox = true, espName = true, espHealth = true, espHealthBar = true, espDist = true,
    espTracer = false, espMaxDist = 1500, espChams = false,
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
local function alive(plr)
    local c = plr and plr.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end
local function getPart(plr, name)
    local c = plr and plr.Character
    if not c then return nil end
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
    return part.Position + (part.AssemblyLinearVelocity * ((smoothPing() / 1000) * (factor or 1)))
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
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and alive(plr) then
            local skip = teamCheck and plr.Team ~= nil and LP.Team ~= nil and plr.Team == LP.Team
            if not skip then
                local part = getPart(plr, partName)
                if part then
                    local sp, on = cam():WorldToViewportPoint(part.Position)
                    if on then
                        local d = (mpos - Vector2.new(sp.X, sp.Y)).Magnitude
                        if d <= fov and d < bestDist and (not visCheck or visible(part)) then
                            best, bestDist = plr, d
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
local Library = (function()
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Library = {}
Library.__index = Library

Library.Theme = {
    WindowBg = Color3.fromRGB(14, 14, 16),
    WindowBorder = Color3.fromRGB(0, 0, 0),
    WindowStroke = Color3.fromRGB(42, 72, 104),

    TitlebarBg = Color3.fromRGB(12, 12, 14),
    TitlebarText = Color3.fromRGB(215, 235, 255),

    NavbarBg = Color3.fromRGB(14, 14, 16),
    TabActiveBg = Color3.fromRGB(20, 26, 34),
    TabActiveBorder = Color3.fromRGB(70, 130, 200),
    TabInactiveText = Color3.fromRGB(130, 140, 155),
    TabActiveText = Color3.fromRGB(255, 255, 255),

    Accent = Color3.fromRGB(0, 175, 255),
    AccentSecondary = Color3.fromRGB(90, 205, 255),

    GroupboxBg = Color3.fromRGB(16, 16, 20),
    GroupboxBorder = Color3.fromRGB(32, 38, 46),
    GroupboxTitle = Color3.fromRGB(225, 240, 255),

    LabelText = Color3.fromRGB(190, 200, 212),
    MutedText = Color3.fromRGB(110, 120, 132),

    InputBg = Color3.fromRGB(10, 10, 12),
    InputBorder = Color3.fromRGB(38, 46, 58),
    InputActive = Color3.fromRGB(0, 175, 255),

    SliderTrack = Color3.fromRGB(12, 12, 15),
    SliderFill = Color3.fromRGB(0, 175, 255),
    SliderText = Color3.fromRGB(255, 255, 255),
}

local function getSafeParent()
    local gethui = rawget(getfenv(), "gethui")
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if ok and coreGui then return coreGui end
    local lp = Players.LocalPlayer
    if lp then return lp:WaitForChild("PlayerGui") end
    error("[snow.cc] Failed to find UI parent container.")
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
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
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
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- keybind registry shared by every toggle
local keybinds = {}
local openPopup = nil

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local kb = keybinds[input.KeyCode]
    if not kb then return end
    if kb.mode == "Always" then return end
    if kb.mode == "Toggle" then kb.active = not kb.active else kb.active = true end
    kb.apply()
end)

UserInputService.InputEnded:Connect(function(input)
    local kb = keybinds[input.KeyCode]
    if kb and kb.mode == "Hold" then
        kb.active = false
        kb.apply()
    end
end)

function Library.CreateWindow(config)
    local title = config.Title or "snow.cc"
    local gameName = config.Game or "Hood"
    local windowSize = config.Size or Vector2.new(680, 720)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "snow_cc_" .. tostring(math.random(100000, 999999))
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999999
    screenGui.Parent = getSafeParent()
    Library.ScreenGui = screenGui

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

    local outerBorder = Instance.new("UIStroke")
    outerBorder.Color = Library.Theme.WindowBorder
    outerBorder.Thickness = 1
    outerBorder.Parent = mainFrame

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
    titleLabel.Text = string.format("%s  |  %s", title, gameName)
    titleLabel.Parent = titleBar

    makeDraggable(titleBar, mainFrame)

    local isVisible = true
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == toggleKey then
            isVisible = not isVisible
            mainFrame.Visible = isVisible
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

    local Window = { ScreenGui = screenGui, MainFrame = mainFrame, Tabs = {}, CurrentTab = nil }

    function Window:CreateTab(tabName)
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
            Name = tabName, Button = tabBtn, Stroke = tabStroke,
            Content = tabContent, Left = leftCol, Right = rightCol,
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

        function Tab:CreateGroupbox(groupTitle, columnSide)
            groupboxCount += 1
            local parentCol = (columnSide == "Right") and rightCol or leftCol

            local groupbox = Instance.new("Frame")
            groupbox.Name = "Group_" .. tostring(groupboxCount) .. "_" .. groupTitle
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
            groupTitle.Text = groupTitle.Text
            groupTitle.Text = groupbox.Name:gsub("^Group_%d+_", "")
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
                itemOrder += 1
                return itemOrder
            end

            function Group:AddToggle(label, default, options)
                local armed = default or false
                local modeActive = true
                local mode = (options and options.Mode) or "Always"
                local callback = options and options.Callback
                local key = options and options.Keybind or nil

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
                box.BackgroundColor3 = armed and Library.Theme.Accent or Library.Theme.InputBg
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
                textBtn.TextColor3 = armed and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                textBtn.TextXAlignment = Enum.TextXAlignment.Left
                textBtn.Text = label
                textBtn.Parent = row

                local keybindBtn, kbObj

                local function paint()
                    local on = armed and modeActive
                    box.BackgroundColor3 = armed and Library.Theme.Accent or Library.Theme.InputBg
                    textBtn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Library.Theme.LabelText
                    if kbObj then
                        keybindBtn.TextColor3 = on and Library.Theme.Accent or Library.Theme.MutedText
                    end
                end

                local function apply()
                    paint()
                    if callback then pcall(callback, armed and modeActive) end
                end

                local function setArmed(v)
                    armed = v
                    apply()
                end

                if key then
                    keybindBtn = Instance.new("TextButton")
                    keybindBtn.Name = "Keybind"
                    keybindBtn.Size = UDim2.new(0, 28, 0, 16)
                    keybindBtn.Position = UDim2.new(1, -28, 0.5, -8)
                    keybindBtn.BackgroundColor3 = Library.Theme.InputBg
                    keybindBtn.BorderSizePixel = 0
                    keybindBtn.Font = Enum.Font.RobotoMono
                    keybindBtn.TextSize = 10
                    keybindBtn.TextColor3 = Library.Theme.MutedText
                    keybindBtn.Text = key.Name
                    keybindBtn.Parent = row

                    local kbStroke = Instance.new("UIStroke")
                    kbStroke.Color = Library.Theme.InputBorder
                    kbStroke.Thickness = 1
                    kbStroke.Parent = keybindBtn

                    kbObj = { mode = mode, active = true, apply = apply }
                    keybinds[key] = kbObj

                    local listening = false
                    keybindBtn.MouseButton1Click:Connect(function()
                        listening = true
                        keybindBtn.Text = "..."
                        keybindBtn.TextColor3 = Library.Theme.Accent
                    end)

                    UserInputService.InputBegan:Connect(function(input, gpe)
                        if listening and not gpe and input.UserInputType == Enum.UserInputType.Keyboard then
                            keybinds[key] = nil
                            key = input.KeyCode
                            keybinds[key] = kbObj
                            keybindBtn.Text = key.Name
                            paint()
                            listening = false
                        end
                    end)

                    keybindBtn.MouseButton2Click:Connect(function()
                        if openPopup then
                            pcall(function() openPopup:Destroy() end)
                            openPopup = nil
                        end
                        local pop = Instance.new("Frame")
                        pop.Name = "ModePopup"
                        pop.Size = UDim2.new(0, 78, 0, 66)
                        pop.Position = UDim2.new(0, keybindBtn.AbsolutePosition.X - 50,
                            0, keybindBtn.AbsolutePosition.Y + 18)
                        pop.BackgroundColor3 = Library.Theme.GroupboxBg
                        pop.BorderSizePixel = 0
                        pop.ZIndex = 500
                        pop.Parent = screenGui

                        local ps = Instance.new("UIStroke")
                        ps.Color = Library.Theme.Accent
                        ps.Thickness = 1
                        ps.Parent = pop

                        local pl = Instance.new("UIListLayout")
                        pl.Padding = UDim.new(0, 2)
                        pl.Parent = pop

                        for i, m in ipairs({ "Always", "Toggle", "Hold" }) do
                            local opt = Instance.new("TextButton")
                            opt.Size = UDim2.new(1, -4, 0, 19)
                            opt.Position = UDim2.new(0, 2, 0, 2 + (i - 1) * 21)
                            opt.LayoutOrder = i
                            opt.BackgroundColor3 = Library.Theme.InputBg
                            opt.BorderSizePixel = 0
                            opt.Font = Enum.Font.RobotoMono
                            opt.TextSize = 10
                            opt.TextColor3 = (m == mode) and Library.Theme.Accent or Library.Theme.LabelText
                            opt.Text = m
                            opt.ZIndex = 501
                            opt.AutoButtonColor = false
                            opt.Parent = pop
                            opt.MouseButton1Click:Connect(function()
                                mode = m
                                kbObj.mode = m
                                kbObj.active = true
                                paint()
                                pop:Destroy()
                                openPopup = nil
                            end)
                        end
                        openPopup = pop
                    end)

                    UserInputService.InputBegan:Connect(function(input, gpe)
                        if gpe then return end
                        if openPopup and input.UserInputType == Enum.UserInputType.MouseButton1 then
                            local pos = input.Position
                            local ap = openPopup.AbsolutePosition
                            local as = openPopup.AbsoluteSize
                            if not (pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y) then
                                openPopup:Destroy()
                                openPopup = nil
                            end
                        end
                    end)
                end

                box.MouseButton1Click:Connect(function() setArmed(not armed) end)
                textBtn.MouseButton1Click:Connect(function() setArmed(not armed) end)

                paint()

                return {
                    SetValue = function(v) setArmed(v) end,
                    GetValue = function() return armed end,
                    SetMode = function(m)
                        mode = m
                        if kbObj then kbObj.mode = m; kbObj.active = true end
                        paint()
                    end,
                    GetMode = function() return mode end,
                }
            end

            function Group:AddSlider(label, min, max, default, unit, callback)
                local currentVal = math.clamp(default or min, min, max)
                local u = unit or ""

                local sliderContainer = Instance.new("Frame")
                sliderContainer.Name = "Slider_" .. label
                sliderContainer.LayoutOrder = nextOrder()
                sliderContainer.Size = UDim2.new(1, 0, 0, 34)
                sliderContainer.BackgroundTransparency = 1
                sliderContainer.Parent = itemsContainer

                local labelText = Instance.new("TextLabel")
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
                local alpha = (currentVal - min) / (max - min)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                fill.BackgroundColor3 = Library.Theme.SliderFill
                fill.BorderSizePixel = 0
                fill.Parent = track

                local valueText = Instance.new("TextLabel")
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
                    local pct = math.clamp((input.Position.X - trackX) / trackW, 0, 1)
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
                local BASE_H = 40
                local OPEN_H = BASE_H + 4 + (#items * 22)

                local dropContainer = Instance.new("Frame")
                dropContainer.Name = "Dropdown_" .. label
                dropContainer.LayoutOrder = nextOrder()
                dropContainer.Size = UDim2.new(1, 0, 0, BASE_H)
                dropContainer.BackgroundTransparency = 1
                dropContainer.ClipsDescendants = false
                dropContainer.Parent = itemsContainer

                local dropTitle = Instance.new("TextLabel")
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
                optionsFrame.Position = UDim2.new(0, 0, 0, BASE_H + 4)
                optionsFrame.BackgroundColor3 = Library.Theme.GroupboxBg
                optionsFrame.BorderSizePixel = 0
                optionsFrame.Visible = false
                optionsFrame.Parent = dropContainer

                local optStroke = Instance.new("UIStroke")
                optStroke.Color = Library.Theme.Accent
                optStroke.Thickness = 1
                optStroke.Parent = optionsFrame

                local optLayout = Instance.new("UIListLayout")
                optLayout.SortOrder = Enum.SortOrder.LayoutOrder
                optLayout.Parent = optionsFrame

                for idx, item in ipairs(items) do
                    local opt = Instance.new("TextButton")
                    opt.LayoutOrder = idx
                    opt.Size = UDim2.new(1, 0, 0, 22)
                    opt.BackgroundColor3 = Library.Theme.GroupboxBg
                    opt.BorderSizePixel = 0
                    opt.Font = Enum.Font.RobotoMono
                    opt.TextSize = 11
                    opt.TextColor3 = (item == selected) and Library.Theme.Accent or Library.Theme.LabelText
                    opt.TextXAlignment = Enum.TextXAlignment.Left
                    opt.Text = "  " .. item
                    opt.AutoButtonColor = false
                    opt.Parent = optionsFrame

                    opt.MouseButton1Click:Connect(function()
                        selected = item
                        dropBtn.Text = "  " .. selected
                        optionsFrame.Visible = false
                        dropContainer.Size = UDim2.new(1, 0, 0, BASE_H)
                        isOpen = false
                        arrow.Text = "v"
                        if callback then pcall(callback, selected) end
                    end)
                end

                dropBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    optionsFrame.Visible = isOpen
                    dropContainer.Size = UDim2.new(1, 0, 0, isOpen and OPEN_H or BASE_H)
                    arrow.Text = isOpen and "^" or "v"
                end)

                return {
                    GetValue = function() return selected end,
                    SetValue = function(v)
                        selected = v
                        dropBtn.Text = "  " .. selected
                        if callback then pcall(callback, selected) end
                    end,
                }
            end

            function Group:AddColorPicker(label, default, callback)
                local currentColor = default or Color3.fromRGB(0, 175, 255)

                local colorRow = Instance.new("Frame")
                colorRow.LayoutOrder = nextOrder()
                colorRow.Size = UDim2.new(1, 0, 0, 22)
                colorRow.BackgroundTransparency = 1
                colorRow.Parent = itemsContainer

                local colorLabel = Instance.new("TextLabel")
                colorLabel.Size = UDim2.new(1, -50, 1, 0)
                colorLabel.BackgroundTransparency = 1
                colorLabel.Font = Enum.Font.RobotoMono
                colorLabel.TextSize = 11
                colorLabel.TextColor3 = Library.Theme.LabelText
                colorLabel.TextXAlignment = Enum.TextXAlignment.Left
                colorLabel.Text = label
                colorLabel.Parent = colorRow

                local colorPreview = Instance.new("TextButton")
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

                colorPreview.MouseButton1Click:Connect(function()
                    currentColor = Color3.fromHSV(math.random(), 1, 1)
                    colorPreview.BackgroundColor3 = currentColor
                    if callback then pcall(callback, currentColor) end
                end)

                return {
                    SetColor = function(c)
                        currentColor = c
                        colorPreview.BackgroundColor3 = c
                        if callback then pcall(callback, c) end
                    end,
                    GetColor = function() return currentColor end,
                }
            end

            function Group:AddButton(label, callback)
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

return Library
end)()

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
    if not tool or gunLocks[tool] then return end
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
    local tool = toolEquipped()
    local origin = params.ForcedOrigin or params.Origin
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

    if state.rangeOverride then
        params.Range = state.rangeValue
    elseif params.Range ~= nil and params.Range < dist + 10 then
        -- Guarantee weapon range covers the target so server check passes
        params.Range = dist + 50
    end

    if state.wallbangMode == "Hard" then
        local back = origin - pos
        if back.Magnitude > 0.01 then
            params.ForcedOrigin = pos + back.Unit * 1.5
        end
    end

    local pre = params.Precomputed
    if typeof(pre) == "CFrame" then
        params.Precomputed = CFrame.lookAt(pos, pos + dir)
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
    if self then return orig(self, first, ...) end
    return orig(first, ...)
end

local function forcedTrace(part)
    local origin = cam().CFrame.Position
    local dir = part.Position - origin
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { part.Parent }
    local hit = workspace:Raycast(origin, dir, rp)
    if hit then return hit end
    return { Instance = part, Position = part.Position, Normal = -dir.Unit }
end

local silPart, silPos, silAt = nil, nil, 0

local function liveSilentPart()
    if not state.silent then return nil end
    if silPart and silPos and os.clock() - silAt < 0.25 then
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
    local ok, orig = pcall(function()
        return hookfunction(fn, function(...) return wrapper(orig, ...) end)
    end)
    if not ok or type(orig) ~= "function" then
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
        if res.n >= 3 then
            res[1] = cachedPos
            res[2] = part
            res[3] = -cachedDir
        else
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
            if rt == "Vector3" then return pos end
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
        if part then return forcedTrace(part) end
    end
    return callOrig(orig, self, first, ...)
end

local canShootWrapper = function(orig, ...)
    if not state.unloaded and (state.infiniteAmmo or state.rapidFire) then return true end
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
    local centre = Vector2.new(vp.X / 2, vp.Y)

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

                t.tracer.Visible = state.espTracer
                t.tracer.Color = col
                t.tracer.From = centre
                t.tracer.To = Vector2.new(top.X, y + h)
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

    if state.speed then
        if state.speedMode == "CFrame" then
            hum.WalkSpeed = 16
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                root.CFrame = root.CFrame + moveDir.Unit * (state.speedValue / 60)
            end
        else
            hum.WalkSpeed = state.speedValue
        end
    else
        hum.WalkSpeed = 16
    end
    if state.jump then
        hum.UseJumpPower = true
        hum.JumpPower = state.jumpValue
    end
    if state.hipHeight then
        pcall(function() hum.HipHeight = state.hipValue end)
    end

    if state.noclip then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end

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
    Size = Vector2.new(680, 720),
    ToggleKey = Enum.KeyCode.RightShift,
})

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
SilentGroup:AddDropdown("Hit limb", { "HumanoidRootPart", "Head", "Torso" }, "HumanoidRootPart", function(v) state.silentPart = v end)
local silFov = SilentGroup:AddSlider("FOV", 20, 800, 300, "px", function(v) state.silentFov = v end)
register("silent.fov", silFov.SetValue, 300)
local silChance = SilentGroup:AddSlider("Hit Chance", 1, 100, 100, "%", function(v) state.silentChance = v end)
register("silent.chance", silChance.SetValue, 100)
SilentGroup:AddToggle("Team Check", true, { Callback = function(v) state.silentTeamCheck = v end })
SilentGroup:AddDropdown("Wallbang", { "Off", "Soft", "Hard" }, "Off", function(v) state.wallbangMode = v end)
SilentGroup:AddToggle("Prediction", true, { Callback = function(v) state.silentPrediction = v end })
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
EspGroup:AddToggle("Tracer", false, { Callback = function(v) state.espTracer = v end })
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

    -- shield first so Adonis detectors are already zombied when the
    -- namecall hook goes live
    pcall(armShield)
    if Shield.armed or not hookmetamethod then
        installNamecall()
    else
        -- If game does not use Adonis (e.g. Zee Hood), install namecall immediately
        installNamecall()
    end
end)

print("[snow] loaded | GunHandler:", GunHandler and "hooked" or "missing")