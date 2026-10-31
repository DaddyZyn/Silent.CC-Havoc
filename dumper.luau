--!strict
--[[
    silent.cc - Havoc Inspector & Dumper UI
    Engineered for in-game reverse engineering, remote exploration, and module inspection.
    Features:
    - Real-time scanning of Network Remotes, Weapon Modules, and Character Rigs
    - Interactive UI with Remotes list, Modules breakdown, and Export tools
    - Multi-method clipboard copying (setclipboard, toclipboard, set_clipboard)
    - Fallback in-UI selectable multiline TextBox for direct Ctrl+A / Ctrl+C
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Theme Tokens (Matching silent.cc Tactical Obsidian)
local Theme = {
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
    AccentSuccess = Color3.fromRGB(0, 230, 140),
    AccentViolet = Color3.fromRGB(120, 87, 255),

    GroupboxBg = Color3.fromRGB(16, 16, 20),
    GroupboxBorder = Color3.fromRGB(32, 32, 38),

    LabelText = Color3.fromRGB(190, 190, 198),
    MutedText = Color3.fromRGB(110, 110, 120),

    InputBg = Color3.fromRGB(10, 10, 12),
    InputBorder = Color3.fromRGB(38, 38, 46),
}

-- Safe Parent Resolution
local function getSafeParent(): Instance
    local gethui = (rawget(getfenv(), "gethui") :: any)
    if typeof(gethui) == "function" then
        local success, hui = pcall(gethui)
        if success and hui then return hui end
    end

    local success, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if success and coreGui then return coreGui end

    if LocalPlayer then
        return LocalPlayer:WaitForChild("PlayerGui")
    end

    error("[silent.cc] Failed to find UI container.")
end

-- Universal Multi-Method Clipboard Copy
local function copyToClipboard(text: string): boolean
    local env = getfenv()
    local methods = {
        rawget(env, "setclipboard"),
        rawget(env, "toclipboard"),
        rawget(env, "set_clipboard"),
    }

    local clipObj = rawget(env, "Clipboard")
    if typeof(clipObj) == "table" and typeof(clipObj.set) == "function" then
        table.insert(methods, clipObj.set)
    end

    for _, fn in ipairs(methods) do
        if typeof(fn) == "function" then
            local success = pcall(fn, text)
            if success then
                return true
            end
        end
    end
    return false
end

-- Pretty JSON Formatter
local function formatJson(val: any, indentLevel: number?): string
    local indent = indentLevel or 0
    local pad = string.rep("  ", indent)
    local nextPad = string.rep("  ", indent + 1)

    if typeof(val) == "table" then
        local isArray = true
        local maxIdx = 0
        local count = 0
        for k, _ in pairs(val) do
            count += 1
            if typeof(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                isArray = false
            else
                if k > maxIdx then maxIdx = k end
            end
        end
        if isArray and maxIdx == count and count > 0 then
            local pieces = {}
            for i = 1, maxIdx do
                table.insert(pieces, nextPad .. formatJson(val[i], indent + 1))
            end
            return "[\n" .. table.concat(pieces, ",\n") .. "\n" .. pad .. "]"
        else
            local pieces = {}
            local keys = {}
            for k in pairs(val) do table.insert(keys, tostring(k)) end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v = val[k] or val[tonumber(k)]
                table.insert(pieces, string.format('%s"%s": %s', nextPad, k, formatJson(v, indent + 1)))
            end
            return "{\n" .. table.concat(pieces, ",\n") .. "\n" .. pad .. "}"
        end
    elseif typeof(val) == "string" then
        return string.format('"%s"', val:gsub('"', '\\"'):gsub("\n", "\\n"))
    elseif typeof(val) == "number" or typeof(val) == "boolean" then
        return tostring(val)
    else
        return string.format('"%s"', tostring(val))
    end
end

-- =========================================================================
-- SCANNING CORE ENGINE
-- =========================================================================
local function runScan()
    local dump = {
        Timestamp = os.date("!%Y-%m-%d %H:%M:%SZ"),
        PlaceId = game.PlaceId,
        GameId = game.GameId,
        LocalPlayer = LocalPlayer and LocalPlayer.Name or "Unknown",
        Remotes = {},
        WeaponModules = {},
        CharacterRig = {},
    }

    local function getFullName(inst: Instance): string
        local parts = {}
        local cur: Instance? = inst
        while cur and cur ~= game do
            table.insert(parts, 1, cur.Name)
            cur = cur.Parent
        end
        return table.concat(parts, ".")
    end

    -- 1. Scan Network Remotes
    local function scanRemotes(container: Instance)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
                table.insert(dump.Remotes, {
                    Class = obj.ClassName,
                    Name = obj.Name,
                    Path = getFullName(obj),
                })
            end
        end
    end
    pcall(scanRemotes, ReplicatedStorage)
    pcall(scanRemotes, Workspace)
    if LocalPlayer then pcall(scanRemotes, LocalPlayer) end

    -- 2. Scan Weapon Modules
    local moduleKeywords = {
        "gun", "weapon", "bullet", "ballistics", "damage", "hit", "recoil",
        "spread", "fire", "ammo", "reload", "inventory", "framework", "config", "client"
    }
    local function isRelevant(name: string): boolean
        local lower = string.lower(name)
        for _, kw in ipairs(moduleKeywords) do
            if string.find(lower, kw) then return true end
        end
        return false
    end

    local function scanModules(container: Instance)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("ModuleScript") and isRelevant(obj.Name) then
                local modInfo = {
                    Name = obj.Name,
                    Path = getFullName(obj),
                    ExportedKeys = {},
                    TablePreview = {},
                }

                local reqSuccess, res = pcall(function()
                    return require(obj :: any)
                end)

                if reqSuccess and typeof(res) == "table" then
                    for k, v in pairs(res) do
                        table.insert(modInfo.ExportedKeys, tostring(k))
                        if typeof(v) ~= "function" and typeof(v) ~= "table" then
                            modInfo.TablePreview[tostring(k)] = tostring(v)
                        elseif typeof(v) == "table" then
                            local sub = {}
                            for sk, sv in pairs(v) do
                                if typeof(sv) ~= "function" and typeof(sv) ~= "table" then
                                    sub[tostring(sk)] = tostring(sv)
                                end
                            end
                            modInfo.TablePreview[tostring(k)] = sub
                        end
                    end
                end

                table.insert(dump.WeaponModules, modInfo)
            end
        end
    end
    pcall(scanModules, ReplicatedStorage)
    if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") then
        pcall(scanModules, LocalPlayer.PlayerScripts)
    end

    -- 3. Character Rig Bones
    if LocalPlayer and LocalPlayer.Character then
        for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
            if child:IsA("BasePart") then
                table.insert(dump.CharacterRig, {
                    Name = child.Name,
                    Size = tostring(child.Size),
                })
            end
        end
    end

    return dump
end

-- =========================================================================
-- BUILD DUMPER GUI
-- =========================================================================
local function createDumperUI()
    local DumpData = runScan()
    local rawJson = formatJson(DumpData)

    -- Auto-copy on scan
    local initialCopySuccess = copyToClipboard(rawJson)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "silent_dumper_" .. tostring(math.random(100000, 999999))
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999999
    screenGui.Parent = getSafeParent()

    local windowSize = Vector2.new(660, 580)

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "DumperWindow"
    mainFrame.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y)
    mainFrame.Position = UDim2.new(0.5, -windowSize.X / 2, 0.5, -windowSize.Y / 2)
    mainFrame.BackgroundColor3 = Theme.WindowBg
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local windowStroke = Instance.new("UIStroke")
    windowStroke.Color = Theme.WindowStroke
    windowStroke.Thickness = 1
    windowStroke.Parent = mainFrame

    -- Titlebar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 28)
    titleBar.BackgroundColor3 = Theme.TitlebarBg
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.RobotoMono
    titleLabel.TextSize = 12
    titleLabel.TextColor3 = Theme.TitlebarText
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = "silent.cc  |  Havoc Inspector & Dumper  |  discord.gg/silentcc"
    titleLabel.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "Close"
    closeBtn.Size = UDim2.new(0, 20, 0, 18)
    closeBtn.Position = UDim2.new(1, -26, 0, 5)
    closeBtn.BackgroundColor3 = Theme.InputBg
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.RobotoMono
    closeBtn.TextSize = 11
    closeBtn.TextColor3 = Theme.MutedText
    closeBtn.Text = "X"
    closeBtn.Parent = titleBar

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Draggable
    local dragging = false
    local dragInput: InputObject? = nil
    local dragStart = Vector2.zero
    local startPos = UDim2.new()

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Top Navigation Bar
    local navBar = Instance.new("Frame")
    navBar.Name = "NavBar"
    navBar.Size = UDim2.new(1, -20, 0, 30)
    navBar.Position = UDim2.new(0, 10, 0, 30)
    navBar.BackgroundColor3 = Theme.NavbarBg
    navBar.BorderSizePixel = 0
    navBar.Parent = mainFrame

    local navLayout = Instance.new("UIListLayout")
    navLayout.FillDirection = Enum.FillDirection.Horizontal
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Padding = UDim.new(0, 6)
    navLayout.Parent = navBar

    local navAccentLine = Instance.new("Frame")
    navAccentLine.Name = "NavAccentLine"
    navAccentLine.Size = UDim2.new(1, -20, 0, 1)
    navAccentLine.Position = UDim2.new(0, 10, 0, 62)
    navAccentLine.BackgroundColor3 = Theme.Accent
    navAccentLine.BorderSizePixel = 0
    navAccentLine.Parent = mainFrame

    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -20, 1, -72)
    contentArea.Position = UDim2.new(0, 10, 0, 66)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    local tabs = {}

    local function addTab(name: string, order: number)
        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. name
        btn.LayoutOrder = order
        btn.Size = UDim2.new(0, 130, 0, 24)
        btn.BackgroundColor3 = Theme.NavbarBg
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.RobotoMono
        btn.TextSize = 11
        btn.TextColor3 = Theme.TabInactiveText
        btn.Text = name
        btn.AutoButtonColor = false
        btn.Parent = navBar

        local stroke = Instance.new("UIStroke")
        stroke.Color = Theme.TabActiveBorder
        stroke.Thickness = 1
        stroke.Enabled = false
        stroke.Parent = btn

        local page = Instance.new("Frame")
        page.Name = "Page_" .. name
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.Parent = contentArea

        local tabEntry = {
            Button = btn,
            Stroke = stroke,
            Page = page,
        }

        btn.MouseButton1Click:Connect(function()
            for _, t in ipairs(tabs) do
                t.Page.Visible = false
                t.Stroke.Enabled = false
                t.Button.BackgroundColor3 = Theme.NavbarBg
                t.Button.TextColor3 = Theme.TabInactiveText
            end
            page.Visible = true
            stroke.Enabled = true
            btn.BackgroundColor3 = Theme.TabActiveBg
            btn.TextColor3 = Theme.TabActiveText
        end)

        table.insert(tabs, tabEntry)
        return page
    end

    -- =====================================================================
    -- TAB 1: OVERVIEW & EXPORT
    -- =====================================================================
    local overviewPage = addTab("Overview & Export", 1)

    local statusBox = Instance.new("Frame")
    statusBox.Name = "StatusBox"
    statusBox.Size = UDim2.new(1, 0, 0, 130)
    statusBox.BackgroundColor3 = Theme.GroupboxBg
    statusBox.BorderSizePixel = 0
    statusBox.Parent = overviewPage

    local statusStroke = Instance.new("UIStroke")
    statusStroke.Color = Theme.GroupboxBorder
    statusStroke.Thickness = 1
    statusStroke.Parent = statusBox

    local summaryText = Instance.new("TextLabel")
    summaryText.Name = "Summary"
    summaryText.Size = UDim2.new(1, -24, 0, 75)
    summaryText.Position = UDim2.new(0, 12, 0, 10)
    summaryText.BackgroundTransparency = 1
    summaryText.Font = Enum.Font.RobotoMono
    summaryText.TextSize = 12
    summaryText.TextColor3 = Theme.LabelText
    summaryText.TextXAlignment = Enum.TextXAlignment.Left
    summaryText.TextYAlignment = Enum.TextYAlignment.Top
    summaryText.Text = string.format(
        "GAME ID: %s | PLACE ID: %s\n" ..
        "DETECTED NETWORK REMOTES: %d\n" ..
        "DETECTED WEAPON/SYSTEM MODULES: %d\n" ..
        "CHARACTER RIG BONES: %d\n" ..
        "JSON PAYLOAD SIZE: %.1f KB",
        tostring(DumpData.GameId),
        tostring(DumpData.PlaceId),
        #DumpData.Remotes,
        #DumpData.WeaponModules,
        #DumpData.CharacterRig,
        #rawJson / 1024
    )
    summaryText.Parent = statusBox

    -- Action Buttons Row
    local copyStatusLabel = Instance.new("TextLabel")
    copyStatusLabel.Name = "CopyStatus"
    copyStatusLabel.Size = UDim2.new(1, -24, 0, 18)
    copyStatusLabel.Position = UDim2.new(0, 12, 0, 95)
    copyStatusLabel.BackgroundTransparency = 1
    copyStatusLabel.Font = Enum.Font.RobotoMono
    copyStatusLabel.TextSize = 11
    copyStatusLabel.TextColor3 = initialCopySuccess and Theme.AccentSuccess or Theme.MutedText
    copyStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    copyStatusLabel.Text = initialCopySuccess and "[+] Full dump copied to clipboard automatically!" or "[*] Click button below to copy dump."
    copyStatusLabel.Parent = statusBox

    local btnContainer = Instance.new("Frame")
    btnContainer.Name = "Buttons"
    btnContainer.Size = UDim2.new(1, 0, 0, 32)
    btnContainer.Position = UDim2.new(0, 0, 0, 140)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent = overviewPage

    local copyBtn = Instance.new("TextButton")
    copyBtn.Name = "CopyFullBtn"
    copyBtn.Size = UDim2.new(0.5, -4, 1, 0)
    copyBtn.BackgroundColor3 = Theme.Accent
    copyBtn.BorderSizePixel = 0
    copyBtn.Font = Enum.Font.RobotoMono
    copyBtn.TextSize = 12
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.Text = "COPY FULL JSON TO CLIPBOARD"
    copyBtn.Parent = btnContainer

    local saveFileBtn = Instance.new("TextButton")
    saveFileBtn.Name = "SaveFileBtn"
    saveFileBtn.Size = UDim2.new(0.5, -4, 1, 0)
    saveFileBtn.Position = UDim2.new(0.5, 4, 0, 0)
    saveFileBtn.BackgroundColor3 = Theme.GroupboxBg
    saveFileBtn.BorderSizePixel = 0
    saveFileBtn.Font = Enum.Font.RobotoMono
    saveFileBtn.TextSize = 12
    saveFileBtn.TextColor3 = Theme.LabelText
    saveFileBtn.Text = "SAVE TO WORKSPACE FILE"
    saveFileBtn.Parent = btnContainer

    local saveStroke = Instance.new("UIStroke")
    saveStroke.Color = Theme.InputBorder
    saveStroke.Thickness = 1
    saveStroke.Parent = saveFileBtn

    copyBtn.MouseButton1Click:Connect(function()
        local success = copyToClipboard(rawJson)
        if success then
            copyStatusLabel.Text = "[+] SUCCESS: Copied full JSON dump to clipboard!"
            copyStatusLabel.TextColor3 = Theme.AccentSuccess
        else
            copyStatusLabel.Text = "[-] Failed to copy via API. Use Raw JSON tab below to copy manually."
            copyStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)

    saveFileBtn.MouseButton1Click:Connect(function()
        local writefile = (rawget(getfenv(), "writefile") :: any)
        if typeof(writefile) == "function" then
            pcall(writefile, "havoc_dump.json", rawJson)
            copyStatusLabel.Text = "[+] Saved dump to executor workspace/havoc_dump.json"
            copyStatusLabel.TextColor3 = Theme.AccentSuccess
        else
            copyStatusLabel.Text = "[-] writefile() not supported in this executor."
            copyStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)

    -- In-UI Selectable JSON Text Box
    local previewLabel = Instance.new("TextLabel")
    previewLabel.Name = "PreviewLabel"
    previewLabel.Size = UDim2.new(1, 0, 0, 18)
    previewLabel.Position = UDim2.new(0, 0, 0, 180)
    previewLabel.BackgroundTransparency = 1
    previewLabel.Font = Enum.Font.RobotoMono
    previewLabel.TextSize = 11
    previewLabel.TextColor3 = Theme.MutedText
    previewLabel.TextXAlignment = Enum.TextXAlignment.Left
    previewLabel.Text = "Raw JSON (Click inside to select all and copy manually if needed):"
    previewLabel.Parent = overviewPage

    local previewScroll = Instance.new("ScrollingFrame")
    previewScroll.Name = "PreviewScroll"
    previewScroll.Size = UDim2.new(1, 0, 1, -205)
    previewScroll.Position = UDim2.new(0, 0, 0, 202)
    previewScroll.BackgroundColor3 = Theme.InputBg
    previewScroll.BorderSizePixel = 0
    previewScroll.ScrollBarThickness = 3
    previewScroll.ScrollBarImageColor3 = Theme.Accent
    previewScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
    previewScroll.Parent = overviewPage

    local prevStroke = Instance.new("UIStroke")
    prevStroke.Color = Theme.InputBorder
    prevStroke.Thickness = 1
    prevStroke.Parent = previewScroll

    local jsonTextBox = Instance.new("TextBox")
    jsonTextBox.Name = "JsonBox"
    jsonTextBox.Size = UDim2.new(1, 0, 1, 0)
    jsonTextBox.AutomaticSize = Enum.AutomaticSize.XY
    jsonTextBox.BackgroundTransparency = 1
    jsonTextBox.Font = Enum.Font.RobotoMono
    jsonTextBox.TextSize = 10
    jsonTextBox.TextColor3 = Theme.LabelText
    jsonTextBox.TextXAlignment = Enum.TextXAlignment.Left
    jsonTextBox.TextYAlignment = Enum.TextYAlignment.Top
    jsonTextBox.ClearTextOnFocus = false
    jsonTextBox.TextEditable = false
    jsonTextBox.MultiLine = true
    jsonTextBox.Text = rawJson
    jsonTextBox.Parent = previewScroll

    -- =====================================================================
    -- TAB 2: REMOTES LIST (109)
    -- =====================================================================
    local remotesPage = addTab(string.format("Remotes (%d)", #DumpData.Remotes), 2)

    local remotesScroll = Instance.new("ScrollingFrame")
    remotesScroll.Name = "RemotesScroll"
    remotesScroll.Size = UDim2.new(1, 0, 1, 0)
    remotesScroll.BackgroundTransparency = 1
    remotesScroll.BorderSizePixel = 0
    remotesScroll.ScrollBarThickness = 3
    remotesScroll.ScrollBarImageColor3 = Theme.Accent
    remotesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    remotesScroll.Parent = remotesPage

    local remLayout = Instance.new("UIListLayout")
    remLayout.FillDirection = Enum.FillDirection.Vertical
    remLayout.Padding = UDim.new(0, 4)
    remLayout.Parent = remotesScroll

    for _, rem in ipairs(DumpData.Remotes) do
        local row = Instance.new("Frame")
        row.Name = "Remote_" .. rem.Name
        row.Size = UDim2.new(1, -6, 0, 24)
        row.BackgroundColor3 = Theme.GroupboxBg
        row.BorderSizePixel = 0
        row.Parent = remotesScroll

        local rowStroke = Instance.new("UIStroke")
        rowStroke.Color = Theme.GroupboxBorder
        rowStroke.Thickness = 1
        rowStroke.Parent = row

        local typeLabel = Instance.new("TextLabel")
        typeLabel.Name = "Class"
        typeLabel.Size = UDim2.new(0, 110, 1, 0)
        typeLabel.Position = UDim2.new(0, 8, 0, 0)
        typeLabel.BackgroundTransparency = 1
        typeLabel.Font = Enum.Font.RobotoMono
        typeLabel.TextSize = 10
        typeLabel.TextColor3 = (rem.Class == "RemoteEvent") and Theme.Accent or Theme.AccentViolet
        typeLabel.TextXAlignment = Enum.TextXAlignment.Left
        typeLabel.Text = "[" .. rem.Class .. "]"
        typeLabel.Parent = row

        local pathLabel = Instance.new("TextLabel")
        pathLabel.Name = "Path"
        pathLabel.Size = UDim2.new(1, -180, 1, 0)
        pathLabel.Position = UDim2.new(0, 120, 0, 0)
        pathLabel.BackgroundTransparency = 1
        pathLabel.Font = Enum.Font.RobotoMono
        pathLabel.TextSize = 10
        pathLabel.TextColor3 = Theme.LabelText
        pathLabel.TextXAlignment = Enum.TextXAlignment.Left
        pathLabel.Text = rem.Path
        pathLabel.Parent = row

        local copyPathBtn = Instance.new("TextButton")
        copyPathBtn.Name = "CopyBtn"
        copyPathBtn.Size = UDim2.new(0, 50, 0, 18)
        copyPathBtn.Position = UDim2.new(1, -54, 0.5, -9)
        copyPathBtn.BackgroundColor3 = Theme.InputBg
        copyPathBtn.BorderSizePixel = 0
        copyPathBtn.Font = Enum.Font.RobotoMono
        copyPathBtn.TextSize = 9
        copyPathBtn.TextColor3 = Theme.MutedText
        copyPathBtn.Text = "Copy"
        copyPathBtn.Parent = row

        copyPathBtn.MouseButton1Click:Connect(function()
            copyToClipboard(rem.Path)
            copyPathBtn.Text = "Copied"
            copyPathBtn.TextColor3 = Theme.AccentSuccess
            task.delay(1, function()
                copyPathBtn.Text = "Copy"
                copyPathBtn.TextColor3 = Theme.MutedText
            end)
        end)
    end

    -- =====================================================================
    -- TAB 3: WEAPON MODULES LIST (66)
    -- =====================================================================
    local modulesPage = addTab(string.format("Modules (%d)", #DumpData.WeaponModules), 3)

    local modulesScroll = Instance.new("ScrollingFrame")
    modulesScroll.Name = "ModulesScroll"
    modulesScroll.Size = UDim2.new(1, 0, 1, 0)
    modulesScroll.BackgroundTransparency = 1
    modulesScroll.BorderSizePixel = 0
    modulesScroll.ScrollBarThickness = 3
    modulesScroll.ScrollBarImageColor3 = Theme.Accent
    modulesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    modulesScroll.Parent = modulesPage

    local modLayout = Instance.new("UIListLayout")
    modLayout.FillDirection = Enum.FillDirection.Vertical
    modLayout.Padding = UDim.new(0, 6)
    modLayout.Parent = modulesScroll

    for _, mod in ipairs(DumpData.WeaponModules) do
        local mBox = Instance.new("Frame")
        mBox.Name = "Mod_" .. mod.Name
        mBox.Size = UDim2.new(1, -6, 0, 0)
        mBox.AutomaticSize = Enum.AutomaticSize.Y
        mBox.BackgroundColor3 = Theme.GroupboxBg
        mBox.BorderSizePixel = 0
        mBox.Parent = modulesScroll

        local mStroke = Instance.new("UIStroke")
        mStroke.Color = Theme.GroupboxBorder
        mStroke.Thickness = 1
        mStroke.Parent = mBox

        local mTitle = Instance.new("TextLabel")
        mTitle.Name = "Name"
        mTitle.Size = UDim2.new(1, -70, 0, 20)
        mTitle.Position = UDim2.new(0, 8, 0, 4)
        mTitle.BackgroundTransparency = 1
        mTitle.Font = Enum.Font.RobotoMono
        mTitle.TextSize = 11
        mTitle.TextColor3 = Theme.Accent
        mTitle.TextXAlignment = Enum.TextXAlignment.Left
        mTitle.Text = mod.Name .. "  (" .. mod.Path .. ")"
        mTitle.Parent = mBox

        local copyModBtn = Instance.new("TextButton")
        copyModBtn.Name = "CopyBtn"
        copyModBtn.Size = UDim2.new(0, 50, 0, 18)
        copyModBtn.Position = UDim2.new(1, -56, 0, 4)
        copyModBtn.BackgroundColor3 = Theme.InputBg
        copyModBtn.BorderSizePixel = 0
        copyModBtn.Font = Enum.Font.RobotoMono
        copyModBtn.TextSize = 9
        copyModBtn.TextColor3 = Theme.MutedText
        copyModBtn.Text = "Copy"
        copyModBtn.Parent = mBox

        copyModBtn.MouseButton1Click:Connect(function()
            local modJson = HttpService:JSONEncode(mod)
            copyToClipboard(modJson)
            copyModBtn.Text = "Copied"
            copyModBtn.TextColor3 = Theme.AccentSuccess
            task.delay(1, function()
                copyModBtn.Text = "Copy"
                copyModBtn.TextColor3 = Theme.MutedText
            end)
        end)

        local keysString = (#mod.ExportedKeys > 0)
            and ("Exported Keys: " .. table.concat(mod.ExportedKeys, ", "))
            or "Exported Keys: [None or non-table return]"

        local mKeys = Instance.new("TextLabel")
        mKeys.Name = "Keys"
        mKeys.Size = UDim2.new(1, -16, 0, 0)
        mKeys.Position = UDim2.new(0, 8, 0, 24)
        mKeys.AutomaticSize = Enum.AutomaticSize.Y
        mKeys.BackgroundTransparency = 1
        mKeys.Font = Enum.Font.RobotoMono
        mKeys.TextSize = 10
        mKeys.TextColor3 = Theme.MutedText
        mKeys.TextXAlignment = Enum.TextXAlignment.Left
        mKeys.TextWrapped = true
        mKeys.Text = keysString
        mKeys.Parent = mBox

        local mPad = Instance.new("UIPadding")
        mPad.PaddingBottom = UDim.new(0, 6)
        mPad.Parent = mBox
    end

    -- Trigger default tab
    if #tabs > 0 then
        tabs[1].Page.Visible = true
        tabs[1].Stroke.Enabled = true
        tabs[1].Button.BackgroundColor3 = Theme.TabActiveBg
        tabs[1].Button.TextColor3 = Theme.TabActiveText
    end

    print("[silent.cc dumper] Dumper UI opened successfully. Data auto-copied to clipboard.")
    return DumpData
end

return createDumperUI()
