-- ════════════════════════════════════════════════════════════════════
-- MORNINGDRIFT UI LIBRARY (MDuiLib)
-- General-Purpose Exploit UI Library for Roblox
-- ════════════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

-- ── Single-Instance Cleanup ──────────────────────────────────────────
if getgenv and getgenv().LIBRARY_CLEANUP then
    pcall(getgenv().LIBRARY_CLEANUP)
end

local Library = {}
Library.Flags           = {}
Library.Elements        = {}
Library.Connections     = {}
Library.Threads         = {}
Library.Unloaded        = false
Library.ConfigName      = nil
Library.IsLoadingConfig = false

getgenv().LIBRARY_CLEANUP = function()
    Library:Destroy()
end

-- ── Environment & Gui Parent ──────────────────────────────────────────
local parentGui
if gethui then
    parentGui = gethui()
elseif typeof(syn) == "table" and syn.protect_gui then
    local sg = Instance.new("ScreenGui")
    pcall(function() syn.protect_gui(sg) end)
    sg.Parent = CoreGui
    parentGui = sg
else
    parentGui = CoreGui
end

local randomId = "Lib_" .. string.gsub(HttpService:GenerateGUID(false), "-", "")
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = randomId
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
pcall(function()
    screenGui.Parent = (parentGui ~= CoreGui and parentGui ~= screenGui) and parentGui or CoreGui
end)

-- ── Dropdown & Overlay Layer (Root Level for z-index sorting) ─────────
local overlayLayer = Instance.new("Folder", screenGui)
overlayLayer.Name = "OverlayLayer"

local notificationHolder = Instance.new("Frame", screenGui)
notificationHolder.Name                   = "NotificationHolder"
notificationHolder.Size                   = UDim2.new(0, 300, 1, -40)
notificationHolder.Position               = UDim2.new(1, -20, 1, -20)
notificationHolder.AnchorPoint            = Vector2.new(1, 1)
notificationHolder.BackgroundTransparency = 1
notificationHolder.ZIndex                 = 1000

local notifLayout = Instance.new("UIListLayout", notificationHolder)
notifLayout.SortOrder            = Enum.SortOrder.LayoutOrder
notifLayout.VerticalAlignment    = Enum.VerticalAlignment.Bottom
notifLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Right
notifLayout.Padding              = UDim.new(0, 8)

-- ── Tracking Helpers ──────────────────────────────────────────────────
function Library:TrackConnection(conn)
    if conn then
        table.insert(self.Connections, conn)
    end
    return conn
end

function Library:TrackThread(thread)
    if thread then
        table.insert(self.Threads, thread)
    end
    return thread
end

-- ── Dropdown Outside-Click Management ───────────────────────────────
local activeMenuFrame = nil
local activeCloseMenuFn = nil

Library:TrackConnection(UserInputService.InputBegan:Connect(function(input)
    if activeMenuFrame and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local pos = input.Position
        local absPos = activeMenuFrame.AbsolutePosition
        local absSize = activeMenuFrame.AbsoluteSize
        if pos.X < absPos.X or pos.X > absPos.X + absSize.X or
           pos.Y < absPos.Y or pos.Y > absPos.Y + absSize.Y then
            if activeCloseMenuFn then
                activeCloseMenuFn()
            end
        end
    end
end))

-- ── Async Font Loading ────────────────────────────────────────────────
local fontBold, fontMedium, fontSemi

task.spawn(function()
    local function loadFont(url, fileName, weight)
        local customFont = nil
        pcall(function()
            if writefile and isfile and getcustomasset and game.HttpGet then
                if not isfile(fileName) then
                    local d = game:HttpGet(url)
                    if d and #d > 500 then writefile(fileName, d) end
                end
                if isfile(fileName) then
                    local assetId = getcustomasset(fileName)
                    customFont = Font.new(assetId, weight or Enum.FontWeight.Bold, Enum.FontStyle.Normal)
                end
            end
        end)
        return customFont
    end

    fontBold   = loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-Bold.ttf",     "MDHub_Kanit_Bold.ttf",     Enum.FontWeight.Bold)
    fontMedium = loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-Medium.ttf",   "MDHub_Kanit_Medium.ttf",   Enum.FontWeight.Medium)
    fontSemi   = loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-SemiBold.ttf", "MDHub_Kanit_SemiBold.ttf", Enum.FontWeight.SemiBold)
end)

local function applyFont(inst, fType)
    local targetFont = fontBold
    local fallbackEnum = Enum.Font.GothamBold

    if fType == "Medium" then
        targetFont = fontMedium or fontBold
        fallbackEnum = Enum.Font.GothamMedium
    elseif fType == "Semi" or fType == "SemiBold" then
        targetFont = fontSemi or fontBold
        fallbackEnum = Enum.Font.GothamBold
    end

    if targetFont then
        pcall(function() inst.FontFace = targetFont end)
    else
        pcall(function() inst.Font = fallbackEnum end)
    end
end

-- ── Theme System ──────────────────────────────────────────────────────
local ThemePresets = {
    ["Dark"] = {
        Accent      = Color3.fromRGB(249, 115, 22),
        Background  = Color3.fromRGB(10,  11,  14),
        Surface     = Color3.fromRGB(14,  15,  19),
        Panel       = Color3.fromRGB(18,  19,  25),
        Elevated    = Color3.fromRGB(24,  26,  34),
        Border      = Color3.fromRGB(32,  34,  44),
        Separator   = Color3.fromRGB(24,  25,  33),
        Text        = Color3.fromRGB(240, 241, 245),
        TextMid     = Color3.fromRGB(160, 162, 175),
        TextDim     = Color3.fromRGB(95,  98,  112),
        AccentDim   = Color3.fromRGB(180, 75,  10),
    },
    ["Light"] = {
        Accent      = Color3.fromRGB(249, 115, 22),
        Background  = Color3.fromRGB(244, 245, 248),
        Surface     = Color3.fromRGB(232, 234, 240),
        Panel       = Color3.fromRGB(255, 255, 255),
        Elevated    = Color3.fromRGB(220, 223, 230),
        Border      = Color3.fromRGB(197, 201, 211),
        Separator   = Color3.fromRGB(215, 218, 226),
        Text        = Color3.fromRGB(20,  22,  29),
        TextMid     = Color3.fromRGB(75,  80,  96),
        TextDim     = Color3.fromRGB(128, 133, 149),
        AccentDim   = Color3.fromRGB(200, 90,  10),
    },
    ["Midnight"] = {
        Accent      = Color3.fromRGB(139, 92,  246),
        Background  = Color3.fromRGB(6,   6,   11),
        Surface     = Color3.fromRGB(11,  11,  20),
        Panel       = Color3.fromRGB(16,  16,  29),
        Elevated    = Color3.fromRGB(22,  22,  40),
        Border      = Color3.fromRGB(34,  34,  60),
        Separator   = Color3.fromRGB(26,  26,  48),
        Text        = Color3.fromRGB(243, 240, 255),
        TextMid     = Color3.fromRGB(156, 149, 186),
        TextDim     = Color3.fromRGB(90,  84,  117),
        AccentDim   = Color3.fromRGB(95,  55,  180),
    },
    ["Ocean"] = {
        Accent      = Color3.fromRGB(6,   182, 212),
        Background  = Color3.fromRGB(5,   14,  23),
        Surface     = Color3.fromRGB(10,  23,  36),
        Panel       = Color3.fromRGB(15,  32,  48),
        Elevated    = Color3.fromRGB(22,  44,  64),
        Border      = Color3.fromRGB(31,  62,  90),
        Separator   = Color3.fromRGB(22,  48,  72),
        Text        = Color3.fromRGB(236, 254, 255),
        TextMid     = Color3.fromRGB(136, 189, 199),
        TextDim     = Color3.fromRGB(76,  117, 130),
        AccentDim   = Color3.fromRGB(2,   125, 150),
    }
}

local Theme = {}
for k, v in pairs(ThemePresets["Dark"]) do
    Theme[k] = v
end

local themeRegistry = {}
for k in pairs(Theme) do themeRegistry[k] = {} end

local function registerTheme(inst, prop, key)
    if not themeRegistry[key] then themeRegistry[key] = {} end
    table.insert(themeRegistry[key], {Inst = inst, Prop = prop})
    pcall(function() inst[prop] = Theme[key] end)
end

local function updateTheme(key, color)
    Theme[key] = color
    if themeRegistry[key] then
        for _, e in ipairs(themeRegistry[key]) do
            if e.Inst and e.Inst.Parent then
                pcall(function() e.Inst[e.Prop] = color end)
            end
        end
    end
end

function Library:SetTheme(themeInput)
    local targetTable = nil
    if typeof(themeInput) == "string" and ThemePresets[themeInput] then
        targetTable = ThemePresets[themeInput]
    elseif typeof(themeInput) == "table" then
        targetTable = themeInput
    end

    if targetTable then
        for k, color in pairs(targetTable) do
            if Theme[k] ~= nil then
                updateTheme(k, color)
            end
        end
    end
end

-- ── Tween Helpers ─────────────────────────────────────────────────────
local function tw(inst, duration, style, dir, goals)
    style = style or Enum.EasingStyle.Quart
    dir   = dir   or Enum.EasingDirection.Out
    local ti = TweenInfo.new(duration, style, dir)
    local tweenObj = TweenService:Create(inst, ti, goals)
    tweenObj:Play()
    return tweenObj
end

local function twQ(inst, duration, goals)
    return tw(inst, duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, goals)
end

local function twB(inst, duration, goals)
    return tw(inst, duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out, goals)
end

-- ── UI Creation Primitives ───────────────────────────────────────────
local function corner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 6)
    return c
end

local function stroke(parent, thickness, colorKey)
    local s = Instance.new("UIStroke", parent)
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    registerTheme(s, "Color", colorKey or "Border")
    return s
end

local function label(parent, props)
    local t = Instance.new("TextLabel", parent)
    t.BackgroundTransparency = 1
    t.BorderSizePixel        = 0
    t.TextWrapped            = props.wrap or false
    t.Size                   = props.size or UDim2.new(1, 0, 0, 20)
    t.Position               = props.pos or UDim2.new(0, 0, 0, 0)
    t.Text                   = props.text or ""
    applyFont(t, props.fontType or "Bold")
    t.TextSize               = props.ts or 13
    t.TextXAlignment         = props.ax or Enum.TextXAlignment.Left
    t.TextYAlignment         = props.ay or Enum.TextYAlignment.Center
    t.ZIndex                 = props.z or 3
    if props.theme then
        registerTheme(t, "TextColor3", props.theme)
    else
        t.TextColor3 = props.color or Theme.Text
    end
    return t
end

-- ── Tooltip Helper ───────────────────────────────────────────────────
local currentTooltip = nil
local function attachTooltip(inst, text)
    if not text or text == "" then return end
    inst.MouseEnter:Connect(function()
        if currentTooltip then pcall(function() currentTooltip:Destroy() end) end
        local mLoc = UserInputService:GetMouseLocation()
        local tip = Instance.new("Frame", overlayLayer)
        tip.Size                   = UDim2.new(0, 0, 0, 22)
        tip.AutomaticSize          = Enum.AutomaticSize.X
        tip.Position               = UDim2.new(0, mLoc.X + 12, 0, mLoc.Y + 12)
        tip.BorderSizePixel        = 0
        tip.ZIndex                 = 3000
        registerTheme(tip, "BackgroundColor3", "Elevated")
        corner(tip, 4)
        stroke(tip, 1, "Border")

        local tPad = Instance.new("UIPadding", tip)
        tPad.PaddingLeft  = UDim.new(0, 8)
        tPad.PaddingRight = UDim.new(0, 8)

        local tLbl = label(tip, {
            size = UDim2.new(0, 0, 1, 0),
            text = text,
            fontType = "Medium",
            ts = 12,
            theme = "Text",
            z = 3001
        })
        tLbl.AutomaticSize = Enum.AutomaticSize.X
        currentTooltip = tip

        Library:TrackConnection(UserInputService.InputChanged:Connect(function(i)
            if currentTooltip == tip and i.UserInputType == Enum.UserInputType.MouseMovement then
                local loc = UserInputService:GetMouseLocation()
                tip.Position = UDim2.new(0, loc.X + 12, 0, loc.Y + 12)
            end
        end))
    end)

    inst.MouseLeave:Connect(function()
        if currentTooltip then
            pcall(function() currentTooltip:Destroy() end)
            currentTooltip = nil
        end
    end)
end

-- ── Safe Dragging Function ───────────────────────────────────────────
local function isInteractiveObject(pos)
    local ok, guis = pcall(function() return screenGui:GetGuiObjectsAtPosition(pos.X, pos.Y) end)
    if ok and guis then
        for _, obj in ipairs(guis) do
            if obj.Name == "ResizeHandle" or obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("TextBox") then
                return true
            end
        end
    end
    return false
end

local function makeDraggable(frame, handle, clickCallback)
    handle = handle or frame
    local dragging  = false
    local movedFar  = false
    local dragStart = Vector3.new()
    local startPos  = UDim2.new()

    Library:TrackConnection(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isInteractiveObject(Vector2.new(input.Position.X, input.Position.Y)) then
                return
            end
            dragging  = true
            movedFar  = false
            dragStart = input.Position
            startPos  = frame.Position
        end
    end))

    Library:TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then
                movedFar = true
            end
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    Library:TrackConnection(handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if not movedFar and clickCallback then
                    clickCallback()
                end
            end
        end
    end))
end

-- ── Config Serialization & Management ───────────────────────────────
local function serializeValue(val)
    if typeof(val) == "Color3" then
        return { R = val.R, G = val.G, B = val.B }
    elseif typeof(val) == "EnumItem" then
        return { EnumType = tostring(val.EnumType), Name = val.Name }
    elseif typeof(val) == "table" then
        local tbl = {}
        for k, v in pairs(val) do
            tbl[k] = serializeValue(v)
        end
        return tbl
    end
    return val
end

local function deserializeValue(val)
    if typeof(val) == "table" then
        if val.R and val.G and val.B then
            return Color3.new(val.R, val.G, val.B)
        elseif val.EnumType and val.Name then
            local ok, item = pcall(function()
                local enumName = string.match(val.EnumType, "Enum%.(.*)") or val.EnumType
                if Enum[enumName] and Enum[enumName][val.Name] then
                    return Enum[enumName][val.Name]
                end
            end)
            if ok and item then return item end
        else
            local tbl = {}
            for k, v in pairs(val) do
                tbl[k] = deserializeValue(v)
            end
            return tbl
        end
    end
    return val
end

function Library:SaveConfig()
    if not self.ConfigName or self.IsLoadingConfig then return end
    pcall(function()
        if not writefile then return end
        local serialData = {}
        for flag, val in pairs(self.Flags) do
            serialData[flag] = serializeValue(val)
        end
        writefile(self.ConfigName .. ".json", HttpService:JSONEncode(serialData))
    end)
end

function Library:LoadConfig()
    if not self.ConfigName or not isfile or not readfile then return end
    local fileName = self.ConfigName .. ".json"
    if not isfile(fileName) then return end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(fileName))
    end)

    if ok and typeof(data) == "table" then
        self.IsLoadingConfig = true
        for _, elem in ipairs(self.Elements) do
            if elem.Flag and data[elem.Flag] ~= nil then
                local val = deserializeValue(data[elem.Flag])
                elem:Set(val, true)
            end
        end
        self.IsLoadingConfig = false
    end
end

function Library:ResetConfig()
    self.IsLoadingConfig = true
    for _, elem in ipairs(self.Elements) do
        if elem.Flag and elem.Default ~= nil then
            elem:Set(elem.Default, true)
        end
    end
    self.IsLoadingConfig = false
    self:SaveConfig()
end

-- ── Notifications ─────────────────────────────────────────────────────
function Library:Notify(options)
    options = options or {}
    local titleText = options.Title or "Notification"
    local contentText = options.Content or ""
    local duration = options.Duration or 4
    local iconId = options.Icon

    local toast = Instance.new("Frame", notificationHolder)
    toast.Size                    = UDim2.new(1, 0, 0, 68)
    toast.BorderSizePixel         = 0
    toast.ClipsDescendants        = true
    toast.BackgroundTransparency  = 1
    registerTheme(toast, "BackgroundColor3", "Panel")
    corner(toast, 6)
    stroke(toast, 1, "Border")

    local pad = Instance.new("UIPadding", toast)
    pad.PaddingLeft   = UDim.new(0, 12)
    pad.PaddingRight  = UDim.new(0, 12)
    pad.PaddingTop    = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)

    local iconOffset = 0
    if iconId then
        iconOffset = 26
        local ic = Instance.new("ImageLabel", toast)
        ic.Size                   = UDim2.new(0, 20, 0, 20)
        ic.Position               = UDim2.new(0, 0, 0, 2)
        ic.BackgroundTransparency = 1
        ic.Image                  = iconId
        registerTheme(ic, "ImageColor3", "Accent")
    end

    label(toast, {
        size = UDim2.new(1, -iconOffset - 20, 0, 20),
        pos = UDim2.new(0, iconOffset, 0, 0),
        text = titleText,
        fontType = "Bold",
        ts = 13,
        theme = "Text"
    })

    label(toast, {
        size = UDim2.new(1, -iconOffset, 0, 30),
        pos = UDim2.new(0, iconOffset, 0, 20),
        text = contentText,
        fontType = "Medium",
        ts = 11,
        theme = "TextDim",
        wrap = true
    })

    local closeBtn = Instance.new("TextButton", toast)
    closeBtn.Size                   = UDim2.new(0, 16, 0, 16)
    closeBtn.Position               = UDim2.new(1, -16, 0, 2)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text                   = "x"
    applyFont(closeBtn, "Bold")
    closeBtn.TextSize               = 14
    registerTheme(closeBtn, "TextColor3", "TextDim")

    local progressBar = Instance.new("Frame", toast)
    progressBar.Size             = UDim2.new(1, 24, 0, 2)
    progressBar.Position         = UDim2.new(0, -12, 1, -2)
    progressBar.BorderSizePixel    = 0
    registerTheme(progressBar, "BackgroundColor3", "Accent")

    toast.BackgroundTransparency = 1
    twQ(toast, 0.25, { BackgroundTransparency = 0 })

    local isDismissed = false
    local function dismiss()
        if isDismissed then return end
        isDismissed = true
        twQ(toast, 0.25, { BackgroundTransparency = 1 })
        task.wait(0.25)
        toast:Destroy()
    end

    closeBtn.MouseButton1Click:Connect(dismiss)

    tw(progressBar, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, { Size = UDim2.new(0, 0, 0, 2) })

    task.spawn(function()
        task.wait(duration)
        dismiss()
    end)
end

-- ── Window Creation ───────────────────────────────────────────────────
function Library:CreateWindow(options)
    options = options or {}
    local winTitle    = options.Title or "Window"
    local winSubTitle = options.SubTitle or "v1.0"
    local winIcon     = options.Icon
    local winSize     = options.Size or Vector2.new(660, 420)

    self.ConfigName = options.ConfigName

    if options.Theme then
        self:SetTheme(options.Theme)
    end

    local MAIN_W, MAIN_H = winSize.X, winSize.Y
    local TOPBAR_H       = 46
    local SIDEBAR_W      = 140

    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Name             = "MainFrame"
    mainFrame.Size             = UDim2.new(0, MAIN_W, 0, MAIN_H)
    mainFrame.Position         = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    mainFrame.BorderSizePixel  = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Active           = false
    registerTheme(mainFrame, "BackgroundColor3", "Background")
    corner(mainFrame, 8)
    stroke(mainFrame, 1, "Border")

    local mainScale = Instance.new("UIScale", mainFrame)
    mainScale.Scale = 0
    twB(mainScale, 0.4, { Scale = 1.0 })

    makeDraggable(mainFrame, mainFrame)

    -- Resize handle
    local resizeBtn = Instance.new("ImageButton", mainFrame)
    resizeBtn.Name                   = "ResizeHandle"
    resizeBtn.Size                   = UDim2.new(0, 22, 0, 22)
    resizeBtn.Position               = UDim2.new(1, -24, 1, -24)
    resizeBtn.BackgroundTransparency   = 1
    resizeBtn.Image                  = "rbxassetid://108376906768065"
    resizeBtn.ZIndex                 = 100
    registerTheme(resizeBtn, "ImageColor3", "TextDim")

    resizeBtn.MouseEnter:Connect(function() twQ(resizeBtn, 0.12, { ImageColor3 = Theme.Text }) end)
    resizeBtn.MouseLeave:Connect(function() twQ(resizeBtn, 0.12, { ImageColor3 = Theme.TextDim }) end)

    local resizing   = false
    local rDragStart = Vector3.new()
    local rStartSize = Vector2.new()
    local rStartPos  = UDim2.new()

    Library:TrackConnection(resizeBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing   = true
            rDragStart = input.Position
            rStartSize = Vector2.new(mainFrame.AbsoluteSize.X, mainFrame.AbsoluteSize.Y)
            rStartPos  = mainFrame.Position
        end
    end))

    Library:TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - rDragStart
            local newW  = math.max(480, rStartSize.X + delta.X)
            local newH  = math.max(300, rStartSize.Y + delta.Y)

            mainFrame.Size = UDim2.new(0, newW, 0, newH)
            mainFrame.Position = UDim2.new(
                rStartPos.X.Scale, rStartPos.X.Offset + (newW - rStartSize.X) / 2,
                rStartPos.Y.Scale, rStartPos.Y.Offset + (newH - rStartSize.Y) / 2
            )
        end
    end))

    Library:TrackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end))

    -- Top bar
    local topBar = Instance.new("Frame", mainFrame)
    topBar.Name                   = "TopBar"
    topBar.Size                   = UDim2.new(1, 0, 0, TOPBAR_H)
    topBar.BackgroundTransparency = 1
    topBar.BorderSizePixel        = 0
    topBar.ZIndex                 = 5

    local tbLine = Instance.new("Frame", topBar)
    tbLine.Size             = UDim2.new(1, 0, 0, 1)
    tbLine.Position         = UDim2.new(0, 0, 1, -1)
    tbLine.BorderSizePixel  = 0
    tbLine.ZIndex           = 6
    registerTheme(tbLine, "BackgroundColor3", "Border")

    local brandArea = Instance.new("Frame", topBar)
    brandArea.Size                   = UDim2.new(0, 260, 1, 0)
    brandArea.BackgroundTransparency = 1
    brandArea.ZIndex                 = 6
    local bPad = Instance.new("UIPadding", brandArea); bPad.PaddingLeft = UDim.new(0, 10)

    local brandRow = Instance.new("Frame", brandArea)
    brandRow.Size                   = UDim2.new(1, 0, 1, 0)
    brandRow.BackgroundTransparency = 1
    brandRow.ZIndex                 = 6
    local brL = Instance.new("UIListLayout", brandRow)
    brL.SortOrder         = Enum.SortOrder.LayoutOrder
    brL.FillDirection     = Enum.FillDirection.Horizontal
    brL.VerticalAlignment = Enum.VerticalAlignment.Center
    brL.Padding           = UDim.new(0, 10)

    if winIcon then
        local iconImg = Instance.new("ImageLabel", brandRow)
        iconImg.Size                   = UDim2.new(0, 28, 0, 28)
        iconImg.BackgroundTransparency = 1
        iconImg.Image                  = winIcon
        iconImg.LayoutOrder            = 1
        iconImg.ZIndex                 = 7
        registerTheme(iconImg, "ImageColor3", "Accent")
    end

    local titleGroup = Instance.new("Frame", brandRow)
    titleGroup.Size                   = UDim2.new(0, 200, 0, 36)
    titleGroup.BackgroundTransparency = 1
    titleGroup.LayoutOrder            = 2
    titleGroup.ZIndex                 = 7

    local tMain = label(titleGroup, {
        size = UDim2.new(1, 0, 0, 20),
        pos = UDim2.new(0, 0, 0, 1),
        text = winTitle,
        fontType = "Bold",
        ts = 15,
        theme = "Text",
        z = 7
    })

    local tSub = label(titleGroup, {
        size = UDim2.new(1, 0, 0, 15),
        pos = UDim2.new(0, 0, 0, 20),
        text = winSubTitle,
        fontType = "Medium",
        ts = 11,
        theme = "TextDim",
        z = 7
    })

    -- Control buttons
    local ctrlArea = Instance.new("Frame", topBar)
    ctrlArea.Size                   = UDim2.new(0, 96, 1, 0)
    ctrlArea.Position               = UDim2.new(1, -100, 0, 0)
    ctrlArea.BackgroundTransparency = 1
    ctrlArea.ZIndex                 = 6
    local ctrlL = Instance.new("UIListLayout", ctrlArea)
    ctrlL.FillDirection        = Enum.FillDirection.Horizontal
    ctrlL.HorizontalAlignment  = Enum.HorizontalAlignment.Right
    ctrlL.VerticalAlignment    = Enum.VerticalAlignment.Center
    ctrlL.Padding              = UDim.new(0, 2)

    local function makeIconBtn(assetId, iconSize)
        local btn = Instance.new("TextButton", ctrlArea)
        btn.Size                   = UDim2.new(0, 28, 0, 28)
        btn.BackgroundTransparency = 1
        btn.BackgroundColor3       = Theme.Elevated
        btn.BorderSizePixel        = 0
        btn.Text                   = ""
        btn.ZIndex                 = 7
        corner(btn, 5)

        local icon = Instance.new("ImageLabel", btn)
        local sz = iconSize or 14
        icon.Size                   = UDim2.new(0, sz, 0, sz)
        icon.AnchorPoint            = Vector2.new(0.5, 0.5)
        icon.Position               = UDim2.new(0.5, 0, 0.5, 0)
        icon.BackgroundTransparency = 1
        icon.Image                  = assetId
        icon.ZIndex                 = 8
        registerTheme(icon, "ImageColor3", "TextDim")

        btn.MouseEnter:Connect(function()
            btn.BackgroundTransparency = 0
            twQ(icon, 0.12, { ImageColor3 = Theme.Text })
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundTransparency = 1
            twQ(icon, 0.12, { ImageColor3 = Theme.TextDim })
        end)
        return btn
    end

    local minimiseBtn = makeIconBtn("rbxassetid://80688800908127", 14)
    local closeBtn    = makeIconBtn("rbxassetid://110946743687809", 14)

    -- Sidebar
    local sidebar = Instance.new("Frame", mainFrame)
    sidebar.Name             = "Sidebar"
    sidebar.Size             = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H)
    sidebar.Position         = UDim2.new(0, 0, 0, TOPBAR_H)
    sidebar.BorderSizePixel  = 0
    sidebar.ZIndex           = 4
    sidebar.ClipsDescendants = true
    registerTheme(sidebar, "BackgroundColor3", "Surface")
    corner(sidebar, 8)

    local sbLine = Instance.new("Frame", sidebar)
    sbLine.Size             = UDim2.new(0, 1, 1, 0)
    sbLine.Position         = UDim2.new(1, -1, 0, 0)
    sbLine.BorderSizePixel  = 0
    sbLine.ZIndex           = 5
    registerTheme(sbLine, "BackgroundColor3", "Border")

    local sbScroll = Instance.new("ScrollingFrame", sidebar)
    sbScroll.Size                   = UDim2.new(1, -1, 1, 0)
    sbScroll.BackgroundTransparency = 1
    sbScroll.BorderSizePixel        = 0
    sbScroll.ScrollBarThickness     = 0
    sbScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    sbScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
    sbScroll.ZIndex                 = 5

    local sbLayout = Instance.new("UIListLayout", sbScroll)
    sbLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sbLayout.Padding   = UDim.new(0, 2)
    local sbPad = Instance.new("UIPadding", sbScroll)
    sbPad.PaddingLeft   = UDim.new(0, 8)
    sbPad.PaddingRight  = UDim.new(0, 8)
    sbPad.PaddingTop    = UDim.new(0, 8)
    sbPad.PaddingBottom = UDim.new(0, 8)

    -- Content Bg
    local contentBg = Instance.new("Frame", mainFrame)
    contentBg.Name             = "ContentBg"
    contentBg.Size             = UDim2.new(1, -SIDEBAR_W, 1, -TOPBAR_H)
    contentBg.Position         = UDim2.new(0, SIDEBAR_W, 0, TOPBAR_H)
    contentBg.BackgroundTransparency = 1
    contentBg.ZIndex           = 3
    contentBg.ClipsDescendants = true
    corner(contentBg, 8)

    -- Thin Tab Indicator (2px)
    local slidingIndicator = Instance.new("Frame", sidebar)
    slidingIndicator.Name             = "SlidingIndicator"
    slidingIndicator.Size             = UDim2.new(0, 2, 0, 24)
    slidingIndicator.Position         = UDim2.new(0, 4, 0, 38)
    slidingIndicator.BorderSizePixel = 0
    slidingIndicator.ZIndex           = 10
    registerTheme(slidingIndicator, "BackgroundColor3", "Accent")
    corner(slidingIndicator, 2)

    -- Tab Management
    local WindowObj = {
        Tabs = {},
        CurrentTab = nil
    }

    local function syncIndicator(instant)
        if WindowObj.CurrentTab and WindowObj.CurrentTab.Btn and WindowObj.CurrentTab.Btn.Parent then
            local btnY = WindowObj.CurrentTab.Btn.AbsolutePosition.Y
            local sbY  = sidebar.AbsolutePosition.Y
            if btnY > 10 and sbY > 10 then
                local relY = btnY - sbY + 7
                local targetPos = UDim2.new(0, 4, 0, relY)
                if instant then
                    slidingIndicator.Position = targetPos
                else
                    twQ(slidingIndicator, 0.22, { Position = targetPos })
                end
            end
        end
    end

    Library:TrackConnection(sbScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        syncIndicator(true)
    end))

    local function selectTab(tabObj, instant)
        for _, t in ipairs(WindowObj.Tabs) do
            if t ~= tabObj then
                t.Page.Visible               = false
                t.Btn.BackgroundTransparency = 1
                twQ(t.Btn, 0.15, { TextColor3 = Theme.TextMid })
                if t.IconInst then
                    if t.IconInst:IsA("ImageLabel") then
                        twQ(t.IconInst, 0.15, { ImageColor3 = Theme.TextDim })
                    else
                        twQ(t.IconInst, 0.15, { TextColor3 = Theme.TextDim })
                    end
                end
            end
        end

        tabObj.Page.Visible               = true
        tabObj.Btn.BackgroundTransparency = 0
        tabObj.Btn.BackgroundColor3       = Theme.Elevated

        if instant then
            tabObj.Btn.TextColor3 = Theme.Text
            if tabObj.IconInst then
                if tabObj.IconInst:IsA("ImageLabel") then
                    tabObj.IconInst.ImageColor3 = Theme.Accent
                else
                    tabObj.IconInst.TextColor3 = Theme.Accent
                end
            end
        else
            twQ(tabObj.Btn, 0.18, { TextColor3 = Theme.Text })
            if tabObj.IconInst then
                if tabObj.IconInst:IsA("ImageLabel") then
                    twQ(tabObj.IconInst, 0.18, { ImageColor3 = Theme.Accent })
                else
                    twQ(tabObj.IconInst, 0.18, { TextColor3 = Theme.Accent })
                end
            end
        end

        WindowObj.CurrentTab = tabObj
        task.defer(function() syncIndicator(instant) end)
        task.delay(0.05, function() syncIndicator(instant) end)
    end

    -- AddTab
    function WindowObj:AddTab(tabOptions)
        tabOptions = tabOptions or {}
        local tabName = tabOptions.Name or "Tab"
        local tabIcon = tabOptions.Icon

        local btn = Instance.new("TextButton", sbScroll)
        btn.Name                   = "Nav_" .. tabName
        btn.Size                   = UDim2.new(1, 0, 0, 38)
        btn.BackgroundTransparency = 1
        btn.BackgroundColor3       = Theme.Elevated
        btn.BorderSizePixel        = 0
        btn.Text                   = ""
        btn.ZIndex                 = 6
        corner(btn, 5)

        local iconInst = nil
        local textLeftOffset = 12

        if typeof(tabIcon) == "string" and tabIcon ~= "" then
            if string.sub(tabIcon, 1, 10) == "rbxassetid" or string.sub(tabIcon, 1, 4) == "http" or tonumber(tabIcon) then
                local assetId = (string.sub(tabIcon, 1, 10) == "rbxassetid" or string.sub(tabIcon, 1, 4) == "http") and tabIcon or ("rbxassetid://" .. tabIcon)
                iconInst = Instance.new("ImageLabel", btn)
                iconInst.Size                   = UDim2.new(0, 16, 0, 16)
                iconInst.Position               = UDim2.new(0, 10, 0.5, -8)
                iconInst.BackgroundTransparency = 1
                iconInst.Image                  = assetId
                iconInst.ZIndex                 = 7
                registerTheme(iconInst, "ImageColor3", "TextDim")
                textLeftOffset = 34
            end
        end

        local nameLbl = Instance.new("TextLabel", btn)
        nameLbl.Size                   = UDim2.new(1, -textLeftOffset - 6, 1, 0)
        nameLbl.Position               = UDim2.new(0, textLeftOffset, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text                   = tabName
        applyFont(nameLbl, "Bold")
        nameLbl.TextSize               = 14
        nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
        nameLbl.ZIndex                 = 7
        registerTheme(nameLbl, "TextColor3", "TextMid")

        local page = Instance.new("ScrollingFrame", contentBg)
        page.Name                   = "Page_" .. tabName
        page.Size                   = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel        = 0
        page.ScrollBarThickness     = 3
        registerTheme(page, "ScrollBarImageColor3", "Border")
        page.Visible                = false
        page.CanvasSize             = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize    = Enum.AutomaticSize.Y
        page.ZIndex                 = 4

        local pageLayout = Instance.new("UIListLayout", page)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Padding   = UDim.new(0, 10)

        local pagePad = Instance.new("UIPadding", page)
        pagePad.PaddingTop    = UDim.new(0, 14)
        pagePad.PaddingBottom = UDim.new(0, 14)
        pagePad.PaddingLeft   = UDim.new(0, 14)
        pagePad.PaddingRight  = UDim.new(0, 14)

        local TabObj = {
            Btn = btn,
            Page = page,
            IconInst = iconInst,
            NameLbl = nameLbl,
            Name = tabName,
            SectionCount = 0
        }

        btn.MouseEnter:Connect(function()
            if WindowObj.CurrentTab == TabObj then return end
            btn.BackgroundTransparency = 0
            twQ(nameLbl, 0.1, { TextColor3 = Theme.Text })
            if iconInst then
                twQ(iconInst, 0.1, { ImageColor3 = Theme.TextMid })
            end
        end)

        btn.MouseLeave:Connect(function()
            if WindowObj.CurrentTab == TabObj then return end
            btn.BackgroundTransparency = 1
            twQ(nameLbl, 0.1, { TextColor3 = Theme.TextMid })
            if iconInst then
                twQ(iconInst, 0.1, { ImageColor3 = Theme.TextDim })
            end
        end)

        btn.MouseButton1Click:Connect(function() selectTab(TabObj) end)

        table.insert(WindowObj.Tabs, TabObj)
        if #WindowObj.Tabs == 1 then
            selectTab(TabObj, true)
            task.delay(1.0, function() selectTab(TabObj, true) end)
        end

        -- AddSection
        function TabObj:AddSection(sectionName)
            TabObj.SectionCount = TabObj.SectionCount + 1

            local secCard = Instance.new("Frame", page)
            secCard.Size                  = UDim2.new(1, 0, 0, 0)
            secCard.AutomaticSize         = Enum.AutomaticSize.Y
            secCard.BorderSizePixel        = 0
            secCard.LayoutOrder           = TabObj.SectionCount
            secCard.ZIndex                = 5
            registerTheme(secCard, "BackgroundColor3", "Panel")
            corner(secCard, 6)
            stroke(secCard, 1, "Border")

            local secPad = Instance.new("UIPadding", secCard)
            secPad.PaddingLeft   = UDim.new(0, 12)
            secPad.PaddingRight  = UDim.new(0, 12)
            secPad.PaddingTop    = UDim.new(0, 10)
            secPad.PaddingBottom = UDim.new(0, 10)

            local secLayout = Instance.new("UIListLayout", secCard)
            secLayout.SortOrder = Enum.SortOrder.LayoutOrder
            secLayout.Padding   = UDim.new(0, 8)

            if sectionName and sectionName ~= "" then
                local headerLbl = label(secCard, {
                    size = UDim2.new(1, 0, 0, 20),
                    text = sectionName,
                    fontType = "Bold",
                    ts = 12,
                    theme = "TextDim",
                    z = 6
                })
                headerLbl.LayoutOrder = 0
            end

            local SectionObj = { Frame = secCard, ElementCount = 0 }

            -- ── Section:AddToggle ───────────────────────────────────────
            function SectionObj:AddToggle(toggleOpts)
                toggleOpts = toggleOpts or {}
                local nameText = toggleOpts.Name or "Toggle"
                local flag     = toggleOpts.Flag
                local default  = toggleOpts.Default or false
                local callback = toggleOpts.Callback or function() end
                local tooltip  = toggleOpts.Tooltip

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local rowBtn = Instance.new("TextButton", secCard)
                rowBtn.Size                   = UDim2.new(1, 0, 0, 36)
                rowBtn.BackgroundTransparency = 1
                rowBtn.BorderSizePixel        = 0
                rowBtn.LayoutOrder            = SectionObj.ElementCount
                rowBtn.Text                   = ""
                rowBtn.ZIndex                 = 6

                label(rowBtn, {
                    size = UDim2.new(1, -60, 1, 0),
                    pos = UDim2.new(0, 0, 0, 0),
                    text = nameText,
                    fontType = "Medium",
                    ts = 12,
                    theme = "Text",
                    z = 6
                })

                if tooltip then
                    attachTooltip(rowBtn, tooltip)
                end

                local track = Instance.new("Frame", rowBtn)
                track.Size                   = UDim2.new(0, 36, 0, 18)
                track.Position               = UDim2.new(1, -36, 0.5, -9)
                track.BorderSizePixel        = 0
                track.ZIndex                 = 6
                registerTheme(track, "BackgroundColor3", default and "Accent" or "Elevated")
                corner(track, 9)

                local thumb = Instance.new("Frame", track)
                thumb.Size                   = UDim2.new(0, 14, 0, 14)
                thumb.AnchorPoint            = Vector2.new(0.5, 0.5)
                thumb.Position               = default and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0)
                thumb.BorderSizePixel        = 0
                thumb.ZIndex                 = 7
                registerTheme(thumb, "BackgroundColor3", "Text")
                corner(thumb, 7)

                local state = default
                if flag then
                    Library.Flags[flag] = state
                end

                local ToggleObj = { Flag = flag, Default = default }

                function ToggleObj:Set(val, skipCallback)
                    state = not not val
                    if flag then Library.Flags[flag] = state end
                    twQ(track, 0.15, { BackgroundColor3 = state and Theme.Accent or Theme.Elevated })
                    twQ(thumb, 0.15, { Position = state and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0) })
                    if not skipCallback and not Library.IsLoadingConfig then
                        pcall(callback, state)
                    end
                    Library:SaveConfig()
                end

                function ToggleObj:Get()
                    return state
                end

                function ToggleObj:Destroy()
                    rowBtn:Destroy()
                end

                rowBtn.MouseButton1Click:Connect(function()
                    ToggleObj:Set(not state)
                end)

                table.insert(Library.Elements, ToggleObj)
                return ToggleObj
            end

            -- ── Section:AddSlider ───────────────────────────────────────
            function SectionObj:AddSlider(sliderOpts)
                sliderOpts = sliderOpts or {}
                local nameText = sliderOpts.Name or "Slider"
                local flag     = sliderOpts.Flag
                local minVal   = sliderOpts.Min or 0
                local maxVal   = sliderOpts.Max or 100
                local default  = sliderOpts.Default or minVal
                local step     = sliderOpts.Step or 1
                local suffix   = sliderOpts.Suffix or ""
                local callback = sliderOpts.Callback or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local container = Instance.new("Frame", secCard)
                container.Size                   = UDim2.new(1, 0, 0, 42)
                container.BackgroundTransparency = 1
                container.BorderSizePixel        = 0
                container.LayoutOrder            = SectionObj.ElementCount
                container.ZIndex                 = 6

                label(container, {
                    size = UDim2.new(1, -80, 0, 18),
                    pos = UDim2.new(0, 0, 0, 0),
                    text = nameText,
                    fontType = "Medium",
                    ts = 12,
                    theme = "Text",
                    z = 6
                })

                local valLbl = label(container, {
                    size = UDim2.new(0, 70, 0, 18),
                    pos = UDim2.new(1, -70, 0, 0),
                    text = tostring(default) .. suffix,
                    fontType = "Medium",
                    ts = 11,
                    theme = "TextDim",
                    ax = Enum.TextXAlignment.Right,
                    z = 6
                })

                local trackBg = Instance.new("TextButton", container)
                trackBg.Size                   = UDim2.new(1, 0, 0, 6)
                trackBg.Position               = UDim2.new(0, 0, 0, 26)
                trackBg.BorderSizePixel        = 0
                trackBg.Text                   = ""
                trackBg.ZIndex                 = 7
                registerTheme(trackBg, "BackgroundColor3", "Elevated")
                corner(trackBg, 3)

                local relInit = math.clamp((default - minVal) / (maxVal - minVal), 0, 1)

                local fill = Instance.new("Frame", trackBg)
                fill.Size                   = UDim2.new(relInit, 0, 1, 0)
                fill.BorderSizePixel        = 0
                fill.ZIndex                 = 8
                registerTheme(fill, "BackgroundColor3", "Accent")
                corner(fill, 3)

                local thumb = Instance.new("Frame", trackBg)
                thumb.Size                   = UDim2.new(0, 12, 0, 12)
                thumb.AnchorPoint            = Vector2.new(0.5, 0.5)
                thumb.Position               = UDim2.new(relInit, 0, 0.5, 0)
                thumb.BorderSizePixel        = 0
                thumb.ZIndex                 = 9
                registerTheme(thumb, "BackgroundColor3", "Text")
                corner(thumb, 6)

                local currVal = default
                if flag then Library.Flags[flag] = currVal end

                local SliderObj = { Flag = flag, Default = default }

                local function updateSlider(px, skipCallback)
                    local rel = math.clamp((px - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
                    local raw = minVal + rel * (maxVal - minVal)
                    local stepped = math.floor(raw / step + 0.5) * step
                    stepped = math.clamp(stepped, minVal, maxVal)

                    currVal = stepped
                    if flag then Library.Flags[flag] = currVal end

                    local newRel = math.clamp((currVal - minVal) / (maxVal - minVal), 0, 1)
                    fill.Size = UDim2.new(newRel, 0, 1, 0)
                    thumb.Position = UDim2.new(newRel, 0, 0.5, 0)
                    valLbl.Text = tostring(currVal) .. suffix

                    if not skipCallback and not Library.IsLoadingConfig then
                        pcall(callback, currVal)
                    end
                    Library:SaveConfig()
                end

                function SliderObj:Set(val, skipCallback)
                    val = math.clamp(val, minVal, maxVal)
                    currVal = val
                    if flag then Library.Flags[flag] = currVal end
                    local newRel = math.clamp((currVal - minVal) / (maxVal - minVal), 0, 1)
                    fill.Size = UDim2.new(newRel, 0, 1, 0)
                    thumb.Position = UDim2.new(newRel, 0, 0.5, 0)
                    valLbl.Text = tostring(currVal) .. suffix

                    if not skipCallback and not Library.IsLoadingConfig then
                        pcall(callback, currVal)
                    end
                    Library:SaveConfig()
                end

                function SliderObj:Get()
                    return currVal
                end

                function SliderObj:Destroy()
                    container:Destroy()
                end

                local sliding = false
                Library:TrackConnection(trackBg.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        updateSlider(i.Position.X)
                    end
                end))

                Library:TrackConnection(UserInputService.InputChanged:Connect(function(i)
                    if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        updateSlider(i.Position.X)
                    end
                end))

                Library:TrackConnection(UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end))

                table.insert(Library.Elements, SliderObj)
                return SliderObj
            end

            -- ── Section:AddDropdown ─────────────────────────────────────
            function SectionObj:AddDropdown(dropOpts)
                dropOpts = dropOpts or {}
                local nameText = dropOpts.Name or "Dropdown"
                local flag     = dropOpts.Flag
                local options  = dropOpts.Options or {}
                local default  = dropOpts.Default
                local isMulti  = dropOpts.Multi or false
                local callback = dropOpts.Callback or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local container = Instance.new("Frame", secCard)
                container.Size                   = UDim2.new(1, 0, 0, 56)
                container.BackgroundTransparency = 1
                container.BorderSizePixel        = 0
                container.LayoutOrder            = SectionObj.ElementCount
                container.ZIndex                 = 6

                label(container, {
                    size = UDim2.new(1, 0, 0, 18),
                    pos = UDim2.new(0, 0, 0, 0),
                    text = nameText,
                    fontType = "Medium",
                    ts = 12,
                    theme = "Text",
                    z = 6
                })

                local dropBtn = Instance.new("TextButton", container)
                dropBtn.Size                   = UDim2.new(1, 0, 0, 30)
                dropBtn.Position               = UDim2.new(0, 0, 0, 22)
                dropBtn.BorderSizePixel        = 0
                dropBtn.Text                   = ""
                dropBtn.ZIndex                 = 6
                registerTheme(dropBtn, "BackgroundColor3", "Elevated")
                corner(dropBtn, 5)
                stroke(dropBtn, 1, "Border")

                local selectedTextLbl = label(dropBtn, {
                    size = UDim2.new(1, -24, 1, 0),
                    pos = UDim2.new(0, 10, 0, 0),
                    text = "Select...",
                    fontType = "Medium",
                    ts = 11,
                    theme = "TextMid",
                    z = 7
                })

                local arrow = label(dropBtn, {
                    size = UDim2.new(0, 16, 1, 0),
                    pos = UDim2.new(1, -20, 0, 0),
                    text = "v",
                    fontType = "Bold",
                    ts = 11,
                    theme = "TextDim",
                    ax = Enum.TextXAlignment.Center,
                    z = 7
                })

                local selectedVal
                if isMulti then
                    selectedVal = typeof(default) == "table" and default or {}
                else
                    selectedVal = default or options[1] or ""
                end

                if flag then Library.Flags[flag] = selectedVal end

                local DropdownObj = { Flag = flag, Default = default }

                local function formatSelected()
                    if isMulti then
                        local list = {}
                        if typeof(selectedVal) == "table" then
                            for k, v in pairs(selectedVal) do
                                if v == true then table.insert(list, k) end
                            end
                        end
                        return #list > 0 and table.concat(list, ", ") or "None"
                    else
                        return tostring(selectedVal)
                    end
                end

                selectedTextLbl.Text = formatSelected()

                local popupOpen = false
                local menuFrame = nil
                local optionButtons = {}

                local function closeMenu()
                    if menuFrame then
                        menuFrame:Destroy()
                        menuFrame = nil
                    end
                    activeMenuFrame = nil
                    activeCloseMenuFn = nil
                    popupOpen = false
                    arrow.Text = "v"
                end

                function DropdownObj:Set(val, skipCallback)
                    selectedVal = val
                    if flag then Library.Flags[flag] = selectedVal end
                    selectedTextLbl.Text = formatSelected()

                    if menuFrame and optionButtons then
                        for opt, optInfo in pairs(optionButtons) do
                            local isSel = isMulti and (typeof(selectedVal) == "table" and selectedVal[opt] == true) or (selectedVal == opt)
                            optInfo.Lbl.TextColor3 = isSel and Theme.Accent or Theme.TextMid
                        end
                    end

                    if not skipCallback and not Library.IsLoadingConfig then
                        pcall(callback, selectedVal)
                    end
                    Library:SaveConfig()
                end

                function DropdownObj:Get()
                    return selectedVal
                end

                function DropdownObj:Destroy()
                    closeMenu()
                    container:Destroy()
                end

                dropBtn.MouseButton1Click:Connect(function()
                    if popupOpen then
                        closeMenu()
                        return
                    end
                    popupOpen = true
                    arrow.Text = "^"

                    local btnAbsPos = dropBtn.AbsolutePosition
                    local btnAbsSz  = dropBtn.AbsoluteSize

                    menuFrame = Instance.new("Frame", overlayLayer)
                    menuFrame.Size                   = UDim2.new(0, btnAbsSz.X, 0, math.min(#options * 28 + 8, 140))
                    menuFrame.Position               = UDim2.new(0, btnAbsPos.X, 0, btnAbsPos.Y + btnAbsSz.Y + 4)
                    menuFrame.BorderSizePixel        = 0
                    menuFrame.ZIndex                 = 2000
                    registerTheme(menuFrame, "BackgroundColor3", "Elevated")
                    corner(menuFrame, 6)
                    stroke(menuFrame, 1, "Border")

                    activeMenuFrame   = menuFrame
                    activeCloseMenuFn = closeMenu

                    local scroll = Instance.new("ScrollingFrame", menuFrame)
                    scroll.Size                   = UDim2.new(1, 0, 1, 0)
                    scroll.BackgroundTransparency = 1
                    scroll.BorderSizePixel        = 0
                    scroll.ScrollBarThickness     = 3
                    registerTheme(scroll, "ScrollBarImageColor3", "Border")
                    scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
                    scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
                    scroll.ZIndex                 = 2001

                    local sLayout = Instance.new("UIListLayout", scroll)
                    sLayout.SortOrder = Enum.SortOrder.LayoutOrder
                    sLayout.Padding   = UDim.new(0, 2)
                    local sPad = Instance.new("UIPadding", scroll)
                    sPad.PaddingLeft   = UDim.new(0, 4)
                    sPad.PaddingRight  = UDim.new(0, 4)
                    sPad.PaddingTop    = UDim.new(0, 4)
                    sPad.PaddingBottom = UDim.new(0, 4)

                    optionButtons = {}
                    for idx, opt in ipairs(options) do
                        local optBtn = Instance.new("TextButton", scroll)
                        optBtn.Size                   = UDim2.new(1, 0, 0, 26)
                        optBtn.BackgroundTransparency = 1
                        optBtn.BorderSizePixel        = 0
                        optBtn.Text                   = ""
                        optBtn.ZIndex                 = 2002
                        corner(optBtn, 4)

                        local isSel = false
                        if isMulti then
                            isSel = typeof(selectedVal) == "table" and selectedVal[opt] == true
                        else
                            isSel = selectedVal == opt
                        end

                        local optLbl = label(optBtn, {
                            size = UDim2.new(1, -10, 1, 0),
                            pos = UDim2.new(0, 6, 0, 0),
                            text = opt,
                            fontType = "Medium",
                            ts = 11,
                            color = isSel and Theme.Accent or Theme.TextMid,
                            z = 2003
                        })

                        optionButtons[opt] = { Btn = optBtn, Lbl = optLbl }

                        optBtn.MouseButton1Click:Connect(function()
                            if isMulti then
                                if typeof(selectedVal) ~= "table" then selectedVal = {} end
                                selectedVal[opt] = not selectedVal[opt]
                            else
                                selectedVal = opt
                                closeMenu()
                            end
                            DropdownObj:Set(selectedVal)
                        end)
                    end
                end)

                table.insert(Library.Elements, DropdownObj)
                return DropdownObj
            end

            -- ── Section:AddTextBox ──────────────────────────────────────
            function SectionObj:AddTextBox(boxOpts)
                boxOpts = boxOpts or {}
                local nameText     = boxOpts.Name or "Text Box"
                local flag         = boxOpts.Flag
                local default      = boxOpts.Default or ""
                local placeholder  = boxOpts.Placeholder or "Enter..."
                local clearOnFocus = boxOpts.ClearOnFocus or false
                local callback     = boxOpts.Callback or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local container = Instance.new("Frame", secCard)
                container.Size                   = UDim2.new(1, 0, 0, 56)
                container.BackgroundTransparency = 1
                container.BorderSizePixel        = 0
                container.LayoutOrder            = SectionObj.ElementCount
                container.ZIndex                 = 6

                label(container, {
                    size = UDim2.new(1, 0, 0, 18),
                    pos = UDim2.new(0, 0, 0, 0),
                    text = nameText,
                    fontType = "Medium",
                    ts = 12,
                    theme = "Text",
                    z = 6
                })

                local inputFrame = Instance.new("Frame", container)
                inputFrame.Size                   = UDim2.new(1, 0, 0, 30)
                inputFrame.Position               = UDim2.new(0, 0, 0, 22)
                inputFrame.BorderSizePixel        = 0
                inputFrame.ZIndex                 = 6
                registerTheme(inputFrame, "BackgroundColor3", "Elevated")
                corner(inputFrame, 5)
                local inputStroke = stroke(inputFrame, 1, "Border")

                local box = Instance.new("TextBox", inputFrame)
                box.Size                   = UDim2.new(1, -16, 1, 0)
                box.Position               = UDim2.new(0, 8, 0, 0)
                box.BackgroundTransparency = 1
                box.BorderSizePixel        = 0
                box.Text                   = default
                box.PlaceholderText        = placeholder
                box.ClearTextOnFocus       = clearOnFocus
                applyFont(box, "Medium")
                box.TextSize               = 12
                box.TextXAlignment         = Enum.TextXAlignment.Left
                box.ZIndex                 = 7
                registerTheme(box, "TextColor3", "Text")
                registerTheme(box, "PlaceholderColor3", "TextDim")

                local currText = default
                if flag then Library.Flags[flag] = currText end

                local TextBoxObj = { Flag = flag, Default = default }

                function TextBoxObj:Set(val, skipCallback)
                    currText = tostring(val or "")
                    box.Text = currText
                    if flag then Library.Flags[flag] = currText end
                    if not skipCallback and not Library.IsLoadingConfig then
                        pcall(callback, currText)
                    end
                    Library:SaveConfig()
                end

                function TextBoxObj:Get()
                    return currText
                end

                function TextBoxObj:Destroy()
                    container:Destroy()
                end

                box.FocusLost:Connect(function(enterPressed)
                    local text = box.Text
                    if text == "" then
                        inputStroke.Color = Color3.fromRGB(220, 70, 70)
                        task.delay(1.2, function()
                            inputStroke.Color = Theme.Border
                        end)
                        return
                    end
                    TextBoxObj:Set(text)
                end)

                table.insert(Library.Elements, TextBoxObj)
                return TextBoxObj
            end

            -- ── Section:AddKeybind ──────────────────────────────────────
            function SectionObj:AddKeybind(keyOpts)
                keyOpts = keyOpts or {}
                local nameText = keyOpts.Name or "Keybind"
                local flag     = keyOpts.Flag
                local default  = keyOpts.Default or Enum.KeyCode.F
                local mode     = keyOpts.Mode or "Toggle"
                local callback = keyOpts.Callback or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local container = Instance.new("Frame", secCard)
                container.Size                   = UDim2.new(1, 0, 0, 36)
                container.BackgroundTransparency = 1
                container.BorderSizePixel        = 0
                container.LayoutOrder            = SectionObj.ElementCount
                container.ZIndex                 = 6

                label(container, {
                    size = UDim2.new(1, -90, 1, 0),
                    pos = UDim2.new(0, 0, 0, 0),
                    text = nameText,
                    fontType = "Medium",
                    ts = 12,
                    theme = "Text",
                    z = 6
                })

                local bindBtn = Instance.new("TextButton", container)
                bindBtn.Size                   = UDim2.new(0, 80, 0, 26)
                bindBtn.Position               = UDim2.new(1, -80, 0.5, -13)
                bindBtn.BorderSizePixel        = 0
                bindBtn.Text                   = ""
                bindBtn.ZIndex                 = 6
                registerTheme(bindBtn, "BackgroundColor3", "Elevated")
                corner(bindBtn, 5)
                stroke(bindBtn, 1, "Border")

                local bindLbl = label(bindBtn, {
                    size = UDim2.new(1, 0, 1, 0),
                    text = typeof(default) == "EnumItem" and default.Name or tostring(default),
                    fontType = "Bold",
                    ts = 11,
                    theme = "Accent",
                    ax = Enum.TextXAlignment.Center,
                    z = 7
                })

                local currKey = default
                local isToggled = false
                local isListening = false

                if flag then Library.Flags[flag] = currKey end

                local KeybindObj = { Flag = flag, Default = default }

                function KeybindObj:Set(key, skipCallback)
                    currKey = key
                    bindLbl.Text = typeof(currKey) == "EnumItem" and currKey.Name or tostring(currKey)
                    if flag then Library.Flags[flag] = currKey end
                    Library:SaveConfig()
                end

                function KeybindObj:Get()
                    return currKey
                end

                function KeybindObj:Destroy()
                    container:Destroy()
                end

                bindBtn.MouseButton1Click:Connect(function()
                    isListening = true
                    bindLbl.Text = "Press key..."
                end)

                Library:TrackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
                    if isListening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            if input.KeyCode == Enum.KeyCode.Escape then
                                isListening = false
                                bindLbl.Text = typeof(currKey) == "EnumItem" and currKey.Name or tostring(currKey)
                            else
                                isListening = false
                                KeybindObj:Set(input.KeyCode)
                            end
                        end
                        return
                    end

                    if not gpe and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currKey then
                        if mode == "Toggle" then
                            isToggled = not isToggled
                            pcall(callback, isToggled)
                        elseif mode == "Hold" then
                            pcall(callback, true)
                        end
                    end
                end))

                Library:TrackConnection(UserInputService.InputEnded:Connect(function(input, gpe)
                    if not gpe and mode == "Hold" and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currKey then
                        pcall(callback, false)
                    end
                end))

                table.insert(Library.Elements, KeybindObj)
                return KeybindObj
            end

            -- ── Section:AddColorPicker ──────────────────────────────────
            function SectionObj:AddColorPicker(cpOpts)
                cpOpts = cpOpts or {}
                local nameText  = cpOpts.Name or "Color Picker"
                local flag      = cpOpts.Flag
                local default   = cpOpts.Default or Color3.fromRGB(255, 0, 0)
                local hasAlpha  = cpOpts.Alpha or false
                local callback  = cpOpts.Callback or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local container = Instance.new("Frame", secCard)
                container.Size                   = UDim2.new(1, 0, 0, 36)
                container.BackgroundTransparency = 1
                container.BorderSizePixel        = 0
                container.LayoutOrder            = SectionObj.ElementCount
                container.ZIndex                 = 6

                label(container, {
                    size = UDim2.new(1, -50, 1, 0),
                    pos = UDim2.new(0, 0, 0, 0),
                    text = nameText,
                    fontType = "Medium",
                    ts = 12,
                    theme = "Text",
                    z = 6
                })

                local swatch = Instance.new("TextButton", container)
                swatch.Size                   = UDim2.new(0, 36, 0, 20)
                swatch.Position               = UDim2.new(1, -36, 0.5, -10)
                swatch.BorderSizePixel        = 0
                swatch.Text                   = ""
                swatch.BackgroundColor3       = default
                swatch.ZIndex                 = 6
                corner(swatch, 4)
                stroke(swatch, 1, "Border")

                local currColor = default
                local currAlpha = 1
                if flag then Library.Flags[flag] = currColor end

                local ColorPickerObj = { Flag = flag, Default = default }

                function ColorPickerObj:Set(color, alphaVal, skipCallback)
                    currColor = color
                    if alphaVal ~= nil then currAlpha = alphaVal end
                    swatch.BackgroundColor3 = currColor
                    if flag then Library.Flags[flag] = currColor end
                    if not skipCallback and not Library.IsLoadingConfig then
                        pcall(callback, currColor, currAlpha)
                    end
                    Library:SaveConfig()
                end

                function ColorPickerObj:Get()
                    return currColor, currAlpha
                end

                function ColorPickerObj:Destroy()
                    container:Destroy()
                end

                -- Color Picker Dialog Toggle
                local pickerOpen = false
                local pickerFrame = nil

                swatch.MouseButton1Click:Connect(function()
                    if pickerOpen then
                        if pickerFrame then pickerFrame:Destroy() end
                        pickerOpen = false
                        return
                    end
                    pickerOpen = true

                    local sAbsPos = swatch.AbsolutePosition
                    pickerFrame = Instance.new("Frame", overlayLayer)
                    pickerFrame.Size                   = UDim2.new(0, 180, 0, 150)
                    pickerFrame.Position               = UDim2.new(0, sAbsPos.X - 144, 0, sAbsPos.Y + 26)
                    pickerFrame.BorderSizePixel        = 0
                    pickerFrame.ZIndex                 = 2000
                    registerTheme(pickerFrame, "BackgroundColor3", "Elevated")
                    corner(pickerFrame, 6)
                    stroke(pickerFrame, 1, "Border")

                    local pPad = Instance.new("UIPadding", pickerFrame)
                    pPad.PaddingLeft   = UDim.new(0, 8)
                    pPad.PaddingRight  = UDim.new(0, 8)
                    pPad.PaddingTop    = UDim.new(0, 8)
                    pPad.PaddingBottom = UDim.new(0, 8)

                    local r = math.floor(currColor.R * 255)
                    local g = math.floor(currColor.G * 255)
                    local b = math.floor(currColor.B * 255)

                    local hexBox = Instance.new("TextBox", pickerFrame)
                    hexBox.Size                   = UDim2.new(1, 0, 0, 22)
                    hexBox.Position               = UDim2.new(0, 0, 0, 94)
                    hexBox.BorderSizePixel        = 0
                    hexBox.Text                   = string.format("#%02X%02X%02X", r, g, b)
                    applyFont(hexBox, "Medium")
                    hexBox.TextSize               = 11
                    registerTheme(hexBox, "BackgroundColor3", "Panel")
                    registerTheme(hexBox, "TextColor3", "Text")
                    corner(hexBox, 4)
                    stroke(hexBox, 1, "Border")

                    hexBox.FocusLost:Connect(function()
                        local str = hexBox.Text:gsub("#", "")
                        if #str == 6 then
                            local hr, hg, hb = str:sub(1, 2), str:sub(3, 4), str:sub(5, 6)
                            local nr, ng, nb = tonumber(hr, 16), tonumber(hg, 16), tonumber(hb, 16)
                            if nr and ng and nb then
                                ColorPickerObj:Set(Color3.fromRGB(nr, ng, nb))
                            end
                        end
                    end)

                    local function makeRgbSlider(posY, letter, initial, colorKey, onVal)
                        local sRow = Instance.new("Frame", pickerFrame)
                        sRow.Size                   = UDim2.new(1, 0, 0, 24)
                        sRow.Position               = UDim2.new(0, 0, 0, posY)
                        sRow.BackgroundTransparency = 1

                        label(sRow, { size = UDim2.new(0, 14, 1, 0), text = letter, fontType = "Bold", ts = 11, color = colorKey })
                        local tTrack = Instance.new("TextButton", sRow)
                        tTrack.Size                   = UDim2.new(1, -20, 0, 6)
                        tTrack.Position               = UDim2.new(0, 20, 0.5, -3)
                        tTrack.BorderSizePixel        = 0
                        tTrack.Text                   = ""
                        registerTheme(tTrack, "BackgroundColor3", "Panel")
                        corner(tTrack, 3)

                        local tFill = Instance.new("Frame", tTrack)
                        tFill.Size                   = UDim2.new(initial / 255, 0, 1, 0)
                        tFill.BorderSizePixel        = 0
                        tFill.BackgroundColor3       = colorKey
                        corner(tFill, 3)

                        local sliding = false
                        local function update(px)
                            local rel = math.clamp((px - tTrack.AbsolutePosition.X) / tTrack.AbsoluteSize.X, 0, 1)
                            local v = math.floor(rel * 255)
                            tFill.Size = UDim2.new(rel, 0, 1, 0)
                            onVal(v)
                            hexBox.Text = string.format("#%02X%02X%02X", r, g, b)
                        end

                        Library:TrackConnection(tTrack.InputBegan:Connect(function(i)
                            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                                sliding = true
                                update(i.Position.X)
                            end
                        end))
                        Library:TrackConnection(UserInputService.InputChanged:Connect(function(i)
                            if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                                update(i.Position.X)
                            end
                        end))
                        Library:TrackConnection(UserInputService.InputEnded:Connect(function(i)
                            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                                sliding = false
                            end
                        end))
                    end

                    makeRgbSlider(4,  "R", r, Color3.fromRGB(240, 80, 80), function(v) r = v; ColorPickerObj:Set(Color3.fromRGB(r, g, b)) end)
                    makeRgbSlider(34, "G", g, Color3.fromRGB(80, 220, 120), function(v) g = v; ColorPickerObj:Set(Color3.fromRGB(r, g, b)) end)
                    makeRgbSlider(64, "B", b, Color3.fromRGB(80, 140, 240), function(v) b = v; ColorPickerObj:Set(Color3.fromRGB(r, g, b)) end)

                    local closeP = Instance.new("TextButton", pickerFrame)
                    closeP.Size                   = UDim2.new(1, 0, 0, 22)
                    closeP.Position               = UDim2.new(0, 0, 1, -22)
                    closeP.BorderSizePixel        = 0
                    closeP.Text                   = "Close"
                    applyFont(closeP, "Bold")
                    closeP.TextSize               = 12
                    registerTheme(closeP, "BackgroundColor3", "Accent")
                    registerTheme(closeP, "TextColor3", "Text")
                    corner(closeP, 4)

                    closeP.MouseButton1Click:Connect(function()
                        pickerFrame:Destroy()
                        pickerOpen = false
                    end)
                end)

                table.insert(Library.Elements, ColorPickerObj)
                return ColorPickerObj
            end

            -- ── Section:AddButton ───────────────────────────────────────
            function SectionObj:AddButton(btnOpts)
                btnOpts = btnOpts or {}
                local nameText = btnOpts.Name or "Button"
                local descText = btnOpts.Desc
                local callback = btnOpts.Callback or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local rowBtn = Instance.new("TextButton", secCard)
                rowBtn.Size                   = UDim2.new(1, 0, 0, descText and 44 or 34)
                rowBtn.BorderSizePixel        = 0
                rowBtn.LayoutOrder            = SectionObj.ElementCount
                rowBtn.Text                   = ""
                rowBtn.ZIndex                 = 6
                registerTheme(rowBtn, "BackgroundColor3", "Elevated")
                corner(rowBtn, 5)
                stroke(rowBtn, 1, "Border")

                if descText then
                    label(rowBtn, {
                        size = UDim2.new(1, -20, 0, 20),
                        pos = UDim2.new(0, 10, 0, 4),
                        text = nameText,
                        fontType = "Bold",
                        ts = 12,
                        theme = "Text",
                        z = 7
                    })
                    label(rowBtn, {
                        size = UDim2.new(1, -20, 0, 16),
                        pos = UDim2.new(0, 10, 0, 22),
                        text = descText,
                        fontType = "Medium",
                        ts = 10,
                        theme = "TextDim",
                        z = 7
                    })
                else
                    label(rowBtn, {
                        size = UDim2.new(1, -20, 1, 0),
                        pos = UDim2.new(0, 10, 0, 0),
                        text = nameText,
                        fontType = "Bold",
                        ts = 12,
                        theme = "Text",
                        z = 7
                    })
                end

                local hoverCol = Color3.fromRGB(36, 40, 52)
                rowBtn.MouseEnter:Connect(function()
                    twQ(rowBtn, 0.12, { BackgroundColor3 = hoverCol })
                end)
                rowBtn.MouseLeave:Connect(function()
                    twQ(rowBtn, 0.12, { BackgroundColor3 = Theme.Elevated })
                end)
                rowBtn.MouseButton1Down:Connect(function()
                    twQ(rowBtn, 0.08, { BackgroundColor3 = Theme.Panel })
                end)
                rowBtn.MouseButton1Up:Connect(function()
                    twQ(rowBtn, 0.12, { BackgroundColor3 = hoverCol })
                end)
                rowBtn.MouseButton1Click:Connect(function()
                    pcall(callback)
                end)

                local ButtonObj = {}
                function ButtonObj:Destroy()
                    rowBtn:Destroy()
                end
                return ButtonObj
            end

            -- ── Static Display Elements ────────────────────────────────
            function SectionObj:AddLabel(textStr)
                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local lblObj = label(secCard, {
                    size = UDim2.new(1, 0, 0, 22),
                    text = textStr or "",
                    fontType = "Medium",
                    ts = 12,
                    theme = "TextMid",
                    z = 6
                })
                lblObj.LayoutOrder = SectionObj.ElementCount

                local LabelObj = {}
                function LabelObj:Set(t) lblObj.Text = t end
                function LabelObj:Destroy() lblObj:Destroy() end
                return LabelObj
            end

            function SectionObj:AddSeparator()
                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local sepFrame = Instance.new("Frame", secCard)
                sepFrame.Size                   = UDim2.new(1, 0, 0, 1)
                sepFrame.BorderSizePixel        = 0
                sepFrame.LayoutOrder            = SectionObj.ElementCount
                sepFrame.ZIndex                 = 6
                registerTheme(sepFrame, "BackgroundColor3", "Separator")

                local SepObj = {}
                function SepObj:Destroy() sepFrame:Destroy() end
                return SepObj
            end

            function SectionObj:AddParagraph(pOpts)
                pOpts = pOpts or {}
                local pTitle   = pOpts.Title or ""
                local pContent = pOpts.Content or ""

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local pFrame = Instance.new("Frame", secCard)
                pFrame.Size                   = UDim2.new(1, 0, 0, 0)
                pFrame.AutomaticSize          = Enum.AutomaticSize.Y
                pFrame.BackgroundTransparency = 1
                pFrame.BorderSizePixel        = 0
                pFrame.LayoutOrder            = SectionObj.ElementCount
                pFrame.ZIndex                 = 6

                local pList = Instance.new("UIListLayout", pFrame)
                pList.SortOrder = Enum.SortOrder.LayoutOrder
                pList.Padding   = UDim.new(0, 2)

                local tLbl = label(pFrame, {
                    size = UDim2.new(1, 0, 0, 18),
                    text = pTitle,
                    fontType = "Bold",
                    ts = 12,
                    theme = "Text",
                    z = 6
                })

                local cLbl = label(pFrame, {
                    size = UDim2.new(1, 0, 0, 0),
                    text = pContent,
                    fontType = "Medium",
                    ts = 11,
                    theme = "TextDim",
                    wrap = true,
                    z = 6
                })
                cLbl.AutomaticSize = Enum.AutomaticSize.Y

                local ParagraphObj = {}
                function ParagraphObj:Set(title, content)
                    if title then tLbl.Text = title end
                    if content then cLbl.Text = content end
                end
                function ParagraphObj:Destroy() pFrame:Destroy() end
                return ParagraphObj
            end

            return SectionObj
        end

        return TabObj
    end

    -- Minimize behavior
    local miniIcon = Instance.new("ImageButton", screenGui)
    miniIcon.Name                   = "MiniIcon"
    miniIcon.Size                   = UDim2.new(0, 50, 0, 50)
    miniIcon.Position               = UDim2.new(0.5, 0, 0.5, 0)
    miniIcon.AnchorPoint            = Vector2.new(0.5, 0.5)
    miniIcon.BorderSizePixel        = 0
    miniIcon.Visible                = false
    miniIcon.ZIndex                 = 200
    miniIcon.ClipsDescendants       = true
    registerTheme(miniIcon, "BackgroundColor3", "Surface")
    corner(miniIcon, 25)

    local miniSt = Instance.new("UIStroke", miniIcon)
    miniSt.Thickness       = 3.5
    miniSt.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    miniSt.Color           = Color3.fromRGB(255, 255, 255)

    local miniGrad = Instance.new("UIGradient", miniSt)
    miniGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 90,  0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 0)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 90,  0)),
    })

    Library:TrackConnection(RunService.RenderStepped:Connect(function()
        if miniIcon and miniIcon.Parent and miniIcon.Visible then
            miniGrad.Rotation = (tick() * 160) % 360
        end
    end))

    local miniImg = Instance.new("ImageLabel", miniIcon)
    miniImg.Size                   = UDim2.new(1, 0, 1, 0)
    miniImg.BackgroundTransparency = 1
    miniImg.Image                  = winIcon or "rbxassetid://77044087750639"
    miniImg.ZIndex                 = 201
    corner(miniImg, 25)

    local isAnimating = false

    local function restoreWindow()
        if isAnimating then return end
        isAnimating = true

        mainFrame.Position = miniIcon.Position
        mainFrame.Visible  = true

        local tw1 = twQ(mainScale, 0.3, { Scale = 1.0 })
        local tw2 = twQ(miniIcon,  0.3, { Rotation = 360 })

        tw1.Completed:Once(function()
            miniIcon.Visible  = false
            miniIcon.Rotation = 0
            isAnimating       = false
        end)
    end

    makeDraggable(miniIcon, miniIcon, function()
        restoreWindow()
    end)

    minimiseBtn.MouseButton1Click:Connect(function()
        if isAnimating then return end
        isAnimating = true

        miniIcon.Position = mainFrame.Position
        miniIcon.Rotation = -360
        miniIcon.Visible  = true

        local tw1 = twQ(mainScale, 0.3, { Scale = 0 })
        local tw2 = twQ(miniIcon,  0.3, { Rotation = 0 })

        tw1.Completed:Once(function()
            mainFrame.Visible = false
            mainScale.Scale   = 1.0
            isAnimating       = false
        end)
    end)

    -- Close Confirmation Dialog (Parented to overlayLayer with high ZIndex)
    local CW_W, CW_H = 320, 150
    local closeWin = Instance.new("Frame", overlayLayer)
    closeWin.Name                   = "CloseConfirmation"
    closeWin.Size                   = UDim2.new(0, CW_W, 0, CW_H)
    closeWin.Position               = UDim2.new(0.5, -CW_W/2, 0.5, -CW_H/2)
    closeWin.BorderSizePixel        = 0
    closeWin.Visible                = false
    closeWin.ZIndex                 = 5000
    registerTheme(closeWin, "BackgroundColor3", "Background")
    corner(closeWin, 8)
    stroke(closeWin, 1, "Border")

    label(closeWin, {
        size = UDim2.new(1, -24, 0, 30),
        pos = UDim2.new(0, 14, 0, 8),
        text = "Close Window",
        fontType = "Bold",
        ts = 14,
        theme = "Text",
        z = 5001
    })

    label(closeWin, {
        size = UDim2.new(1, -28, 0, 34),
        pos = UDim2.new(0, 14, 0, 42),
        text = "Are you sure you want to close this script window?",
        fontType = "Medium",
        ts = 11,
        theme = "TextDim",
        wrap = true,
        z = 5001
    })

    local cwBtnRow = Instance.new("Frame", closeWin)
    cwBtnRow.Size                   = UDim2.new(1, -28, 0, 32)
    cwBtnRow.Position               = UDim2.new(0, 14, 1, -44)
    cwBtnRow.BackgroundTransparency = 1
    cwBtnRow.ZIndex                 = 5001

    local cancelBtn = Instance.new("TextButton", cwBtnRow)
    cancelBtn.Size                   = UDim2.new(0.47, 0, 1, 0)
    cancelBtn.Position               = UDim2.new(0, 0, 0, 0)
    cancelBtn.BorderSizePixel        = 0
    cancelBtn.Text                   = "Cancel"
    applyFont(cancelBtn, "Bold")
    cancelBtn.TextSize               = 13
    cancelBtn.ZIndex                 = 5002
    registerTheme(cancelBtn, "BackgroundColor3", "Panel")
    registerTheme(cancelBtn, "TextColor3", "TextMid")
    corner(cancelBtn, 5)

    cancelBtn.MouseButton1Click:Connect(function()
        closeWin.Visible = false
    end)

    local confirmBtn = Instance.new("TextButton", cwBtnRow)
    confirmBtn.Size                   = UDim2.new(0.47, 0, 1, 0)
    confirmBtn.Position               = UDim2.new(0.53, 0, 0, 0)
    confirmBtn.BorderSizePixel        = 0
    confirmBtn.Text                   = "Close"
    applyFont(confirmBtn, "Bold")
    confirmBtn.TextSize               = 13
    confirmBtn.ZIndex                 = 5002
    registerTheme(confirmBtn, "BackgroundColor3", "Accent")
    registerTheme(confirmBtn, "TextColor3", "Text")
    corner(confirmBtn, 5)

    confirmBtn.MouseButton1Click:Connect(function()
        Library:Destroy()
    end)

    closeBtn.MouseButton1Click:Connect(function()
        closeWin.Visible = true
    end)

    -- Auto-load Config after window & elements creation
    task.defer(function()
        Library:LoadConfig()
    end)

    return WindowObj
end

-- ── Destroy / Cleanup ────────────────────────────────────────────────
function Library:Destroy()
    if self.Unloaded then return end
    self.Unloaded = true

    for _, conn in ipairs(self.Connections) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    self.Connections = {}

    for _, thread in ipairs(self.Threads) do
        if thread then pcall(function() task.cancel(thread) end) end
    end
    self.Threads = {}

    pcall(function()
        screenGui:Destroy()
    end)

    if getgenv then
        getgenv().LIBRARY_CLEANUP = nil
    end

    self.Flags    = {}
    self.Elements = {}
end

return Library
