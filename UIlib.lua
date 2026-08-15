
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

--  Single-Instance Cleanup 
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

--  Environment & Gui Parent 
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

--  Dropdown & Overlay Layer (Root Level for z-index sorting) 
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

--  Tracking Helpers 
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

--  Dropdown Outside-Click Management 
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

--  Async Font Loading 
local fontBold, fontMedium, fontSemi = nil, nil, nil
local fontRegistry = {}

local function refreshAllFonts()
    for _, item in ipairs(fontRegistry) do
        if item.Inst and item.Inst.Parent then
            local fType = item.Type
            local targetFont = fontBold
            if fType == "Medium" then
                targetFont = fontMedium or fontBold
            elseif fType == "Semi" or fType == "SemiBold" then
                targetFont = fontSemi or fontBold
            end
            if targetFont then
                pcall(function() item.Inst.FontFace = targetFont end)
            end
        end
    end
end

local function loadFont(url, fileName, weight)
    pcall(function()
        if not (writefile and isfile and getcustomasset and game.HttpGet) then return end
        if not isfile(fileName) then
            local d = game:HttpGet(url)
            if not d or #d < 500 then return end
            writefile(fileName, d)
        end
        local assetId = nil
        for _ = 1, 20 do
            task.wait(0.1)
            local id = getcustomasset(fileName)
            if id and #id > 5 then assetId = id; break end
        end
        if not assetId then return end
        local f = Font.new(assetId, weight or Enum.FontWeight.Bold, Enum.FontStyle.Normal)
        if weight == Enum.FontWeight.Bold     then fontBold   = f end
        if weight == Enum.FontWeight.Medium   then fontMedium = f end
        if weight == Enum.FontWeight.SemiBold then fontSemi   = f end
        refreshAllFonts()
    end)
end

coroutine.wrap(function()
    loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-Bold.ttf",     "MDHub_Kanit_Bold.ttf",     Enum.FontWeight.Bold)
    loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-Medium.ttf",   "MDHub_Kanit_Medium.ttf",   Enum.FontWeight.Medium)
    loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-SemiBold.ttf", "MDHub_Kanit_SemiBold.ttf", Enum.FontWeight.SemiBold)
end)()

local function applyFont(inst, fType)
    table.insert(fontRegistry, { Inst = inst, Type = fType })
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

--  Background Asset 
local bgAssetId = ""
task.spawn(function()
    pcall(function()
        if getcustomasset and writefile and game.HttpGet then
            if not (isfile and isfile("MD_Hub_Bg.jpg")) then
                local d = game:HttpGet("https://wallpapercave.com/wp/wp13409289.jpg")
                if d and #d > 500 then writefile("MD_Hub_Bg.jpg", d) end
            end
            if isfile and isfile("MD_Hub_Bg.jpg") then
                bgAssetId = getcustomasset("MD_Hub_Bg.jpg")
            end
        end
    end)
end)

--  Theme System 
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
        TextureColor= Color3.fromRGB(255, 255, 255),
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
        TextureColor= Color3.fromRGB(0,   0,   0),
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
        TextureColor= Color3.fromRGB(255, 255, 255),
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
        TextureColor= Color3.fromRGB(255, 255, 255),
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
        local alive = {}
        for _, e in ipairs(themeRegistry[key]) do
            if e.Inst and e.Inst.Parent then
                pcall(function() e.Inst[e.Prop] = color end)
                table.insert(alive, e)
            end
        end
        themeRegistry[key] = alive
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

--  Tween Helpers 
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

--  UI Creation Primitives 
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

-- label: base helper (no scaling)
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

-- lbl: 1.3x scaled version matching MD_Hub style
local function lbl(parent, props)
    local baseTs = props.ts or 12
    local scaled = math.floor(baseTs * 1.3 + 0.5)
    local p2 = {}
    for k, v in pairs(props) do p2[k] = v end
    p2.ts = scaled
    return label(parent, p2)
end

--  Tooltip Helper 
local currentTooltip = nil
local function attachTooltip(inst, text)
    if not text or text == "" then return end
    local moveConn = nil
    inst.MouseEnter:Connect(function()
        if currentTooltip then pcall(function() currentTooltip:Destroy() end) end
        if moveConn then pcall(function() moveConn:Disconnect() end); moveConn = nil end
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

        moveConn = UserInputService.InputChanged:Connect(function(i)
            if currentTooltip == tip and i.UserInputType == Enum.UserInputType.MouseMovement then
                local loc = UserInputService:GetMouseLocation()
                tip.Position = UDim2.new(0, loc.X + 12, 0, loc.Y + 12)
            end
        end)
    end)

    inst.MouseLeave:Connect(function()
        if moveConn then pcall(function() moveConn:Disconnect() end); moveConn = nil end
        if currentTooltip then
            pcall(function() currentTooltip:Destroy() end)
            currentTooltip = nil
        end
    end)
end

--  Safe Dragging Function 
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

--  Config Serialization & Management 
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

--  Notifications 
function Library:Notify(options)
    options = options or {}
    local titleText = options.Title or "Notification"
    local contentText = options.Content or ""
    local duration = options.Duration or 4
    local iconId = options.Icon

    local toast = Instance.new("Frame", notificationHolder)
    toast.Size                    = UDim2.new(1, 0, 0, 0)
    toast.AutomaticSize           = Enum.AutomaticSize.Y
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
    pad.PaddingBottom = UDim.new(0, 12)

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

    local cLbl = label(toast, {
        size = UDim2.new(1, -iconOffset, 0, 0),
        pos = UDim2.new(0, iconOffset, 0, 22),
        text = contentText,
        fontType = "Medium",
        ts = 11,
        theme = "TextDim",
        wrap = true
    })
    cLbl.AutomaticSize = Enum.AutomaticSize.Y

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

--  Window Creation 
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
    local TOPBAR_H       = 65
    local SIDEBAR_W      = 150

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

    -- Subtle background texture
    task.spawn(function()
        task.wait(0.3)
        if bgAssetId ~= "" then
            local bg = Instance.new("ImageLabel", mainFrame)
            bg.Size                   = UDim2.new(1, 0, 1, 0)
            bg.BackgroundTransparency = 1
            bg.Image                  = bgAssetId
            bg.ScaleType              = Enum.ScaleType.Crop
            bg.ImageTransparency      = 0.95
            bg.ZIndex                 = 1
            registerTheme(bg, "ImageColor3", "Text")
        end
    end)

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

    -- Always show MD brand icon (like the hub)
    local mdIconImg = Instance.new("ImageLabel", brandRow)
    mdIconImg.Size                   = UDim2.new(0, 30, 0, 30)
    mdIconImg.BackgroundTransparency = 1
    mdIconImg.Image                  = winIcon or "rbxthumb://type=Asset&id=140295322336049&w=150&h=150"
    mdIconImg.LayoutOrder            = 1
    mdIconImg.ZIndex                 = 7
    corner(mdIconImg, 7)

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
        ts = 17,
        theme = "Text",
        z = 7
    })

    local tSub = label(titleGroup, {
        size = UDim2.new(1, 0, 0, 15),
        pos = UDim2.new(0, 0, 0, 20),
        text = winSubTitle,
        fontType = "Medium",
        ts = 13,
        theme = "TextDim",
        z = 7
    })

    -- Control buttons (settings, minimise, close  matching hub order)
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

    local settingsBtn = makeIconBtn("rbxassetid://86579518783109", 20)
    local minimiseBtn = makeIconBtn("rbxassetid://80688800908127", 20)
    local closeBtn    = makeIconBtn("rbxassetid://110946743687809", 17)

    --  Minimized Floating Circle Icon 
    local miniIcon = Instance.new("ImageButton", screenGui)
    miniIcon.Name             = "MD_MinimizedIcon"
    miniIcon.Size             = UDim2.new(0, 50, 0, 50)
    miniIcon.Position         = UDim2.new(0.5, 0, 0.5, 0)
    miniIcon.AnchorPoint      = Vector2.new(0.5, 0.5)
    miniIcon.BorderSizePixel  = 0
    miniIcon.Active           = true
    miniIcon.Visible          = false
    miniIcon.ZIndex           = 200
    registerTheme(miniIcon, "BackgroundColor3", "Surface")
    miniIcon.ClipsDescendants = true
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

    local gradConn = RunService.RenderStepped:Connect(function()
        if miniIcon and miniIcon.Parent and miniIcon.Visible then
            miniGrad.Rotation = (tick() * 160) % 360
        end
    end)
    Library:TrackConnection(gradConn)

    local miniImg = Instance.new("ImageLabel", miniIcon)
    miniImg.Size                   = UDim2.new(1, 0, 1, 0)
    miniImg.Position               = UDim2.new(0, 0, 0, 0)
    miniImg.BackgroundTransparency = 1
    miniImg.Image                  = "rbxassetid://77044087750639"
    miniImg.ZIndex                 = 201
    corner(miniImg, 25)

    local miniIconScale = Instance.new("UIScale", miniIcon)
    miniIconScale.Scale = 1.0

    miniIcon.MouseEnter:Connect(function()
        if miniIcon.Visible and miniIconScale.Scale >= 0.9 then twQ(miniIconScale, 0.15, { Scale = 1.08 }) end
    end)
    miniIcon.MouseLeave:Connect(function()
        if miniIcon.Visible and miniIconScale.Scale >= 0.9 then twQ(miniIconScale, 0.15, { Scale = 1.0 }) end
    end)

    makeDraggable(miniIcon, miniIcon)

    local isAnimating = false

    minimiseBtn.MouseButton1Click:Connect(function()
        if isAnimating then return end
        isAnimating = true

        miniIcon.Position = mainFrame.Position
        miniIconScale.Scale = 0
        miniIcon.Rotation = -360
        miniIcon.Visible = true

        local twMainScale = twQ(mainScale, 0.3, { Scale = 0 })
        local twMiniScale = twQ(miniIconScale, 0.3, { Scale = 1.0 })
        local twMiniRot   = twQ(miniIcon, 0.3, { Rotation = 0 })

        twMainScale.Completed:Once(function()
            mainFrame.Visible = false
            mainScale.Scale   = 1.0
            isAnimating       = false
        end)
    end)

    miniIcon.MouseButton1Click:Connect(function()
        if isAnimating then return end
        isAnimating = true

        mainFrame.Position = miniIcon.Position
        mainScale.Scale    = 0
        mainFrame.Visible  = true

        local twMainScale = twQ(mainScale, 0.3, { Scale = 1.0 })
        local twMiniScale = twQ(miniIconScale, 0.3, { Scale = 0 })
        local twMiniRot   = twQ(miniIcon, 0.3, { Rotation = 360 })

        twMainScale.Completed:Once(function()
            miniIcon.Visible  = false
            miniIconScale.Scale = 1.0
            miniIcon.Rotation = 0
            isAnimating       = false
        end)
    end)

    --  Close Confirmation Modal 
    local CW_W, CW_H = 320, 152

    local modalBackdrop = Instance.new("TextButton", overlayLayer)
    modalBackdrop.Name                   = "MD_ModalBackdrop"
    modalBackdrop.Size                   = UDim2.new(1, 0, 1, 0)
    modalBackdrop.BackgroundTransparency = 1
    modalBackdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    modalBackdrop.BorderSizePixel        = 0
    modalBackdrop.Visible                = false
    modalBackdrop.ZIndex                 = 4999
    modalBackdrop.Text                   = ""

    local closeWin = Instance.new("Frame", overlayLayer)
    closeWin.Name             = "MD_CloseWindow"
    closeWin.Size             = UDim2.new(0, CW_W, 0, CW_H)
    closeWin.Position         = UDim2.new(0.5, -CW_W/2, 0.5, -CW_H/2)
    closeWin.BorderSizePixel  = 0
    closeWin.Active           = true
    closeWin.Visible          = false
    closeWin.ZIndex           = 5000
    registerTheme(closeWin, "BackgroundColor3", "Background")
    corner(closeWin, 8)
    stroke(closeWin, 1, "Border")

    local cwOpen = false
    local function openCloseWin()
        if cwOpen then return end
        cwOpen = true
        modalBackdrop.Visible = true
        twQ(modalBackdrop, 0.2, { BackgroundTransparency = 0.5 })
        closeWin.Size     = UDim2.new(0, CW_W, 0, 0)
        closeWin.Position = UDim2.new(0.5, -CW_W/2, 0.5, 0)
        closeWin.Visible  = true
        twB(closeWin, 0.3, { Size = UDim2.new(0, CW_W, 0, CW_H), Position = UDim2.new(0.5, -CW_W/2, 0.5, -CW_H/2) })
    end

    local function closeCloseWin()
        if not cwOpen then return end
        cwOpen = false
        twQ(modalBackdrop, 0.2, { BackgroundTransparency = 1 })
        twQ(closeWin, 0.2, { Size = UDim2.new(0, CW_W, 0, 0), Position = UDim2.new(0.5, -CW_W/2, 0.5, 0) })
        task.delay(0.22, function()
            closeWin.Visible = false
            modalBackdrop.Visible = false
        end)
    end

    local cwHead = Instance.new("Frame", closeWin)
    cwHead.Size                   = UDim2.new(1, 0, 0, 36)
    cwHead.BackgroundTransparency = 1
    cwHead.BorderSizePixel        = 0
    cwHead.ZIndex                 = 5001
    label(cwHead, {
        size = UDim2.new(1, -24, 1, 0),
        pos = UDim2.new(0, 14, 0, 0),
        text = "Close " .. winTitle .. "?",
        fontType = "Bold",
        ts = 13,
        theme = "Text",
        z = 5002
    })
    makeDraggable(closeWin, cwHead)

    label(closeWin, {
        size = UDim2.new(1, -28, 0, 34),
        pos = UDim2.new(0, 14, 0, 40),
        text = "Are you sure you want to unload the script UI?",
        fontType = "Medium",
        ts = 11,
        theme = "TextDim",
        wrap = true,
        z = 5002
    })

    local cwBtnRow = Instance.new("Frame", closeWin)
    cwBtnRow.Size                   = UDim2.new(1, -28, 0, 32)
    cwBtnRow.Position               = UDim2.new(0, 14, 1, -44)
    cwBtnRow.BackgroundTransparency = 1
    cwBtnRow.ZIndex                 = 5002

    local cancelBtn = Instance.new("TextButton", cwBtnRow)
    cancelBtn.Size                   = UDim2.new(0.47, 0, 1, 0)
    cancelBtn.Position               = UDim2.new(0, 0, 0, 0)
    cancelBtn.BorderSizePixel        = 0
    cancelBtn.Text                   = "Cancel"
    applyFont(cancelBtn, "Bold")
    cancelBtn.TextSize               = 14
    cancelBtn.ZIndex                 = 5003
    registerTheme(cancelBtn, "BackgroundColor3", "Panel")
    registerTheme(cancelBtn, "TextColor3", "TextMid")
    corner(cancelBtn, 5)

    cancelBtn.MouseEnter:Connect(function() twQ(cancelBtn, 0.1, { BackgroundColor3 = Theme.Elevated }) end)
    cancelBtn.MouseLeave:Connect(function() twQ(cancelBtn, 0.1, { BackgroundColor3 = Theme.Panel }) end)
    cancelBtn.MouseButton1Click:Connect(function() closeCloseWin() end)

    local unloadBtn = Instance.new("TextButton", cwBtnRow)
    unloadBtn.Size                   = UDim2.new(0.53, -6, 1, 0)
    unloadBtn.Position               = UDim2.new(0.47, 6, 0, 0)
    unloadBtn.BorderSizePixel        = 0
    unloadBtn.Text                   = "Unload"
    applyFont(unloadBtn, "Bold")
    unloadBtn.TextSize               = 14
    unloadBtn.ZIndex                 = 5003
    registerTheme(unloadBtn, "BackgroundColor3", "Accent")
    registerTheme(unloadBtn, "TextColor3", "Text")
    corner(unloadBtn, 5)

    unloadBtn.MouseEnter:Connect(function() twQ(unloadBtn, 0.1, { BackgroundColor3 = Color3.fromRGB(230, 95, 10) }) end)
    unloadBtn.MouseLeave:Connect(function() twQ(unloadBtn, 0.1, { BackgroundColor3 = Theme.Accent }) end)
    unloadBtn.MouseButton1Click:Connect(function()
        closeCloseWin()
        self:Destroy()
    end)

    closeBtn.MouseButton1Click:Connect(function()
        openCloseWin()
    end)

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
    sbLayout.Padding   = UDim.new(0, 3)
    local sbPad = Instance.new("UIPadding", sbScroll)
    sbPad.PaddingLeft   = UDim.new(0, 8)
    sbPad.PaddingRight  = UDim.new(0, 8)

    -- Top padding spacer (matches hub)
    local topPadFrame = Instance.new("Frame", sbScroll)
    topPadFrame.Size                   = UDim2.new(1, 0, 0, 6)
    topPadFrame.BackgroundTransparency = 1
    topPadFrame.LayoutOrder            = -9999

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
        CurrentTab = nil,
        _tabOrder = 0,
        _settingsTabObj = nil  -- filled once an Appearance tab is auto-created
    }

    --  Sidebar helpers exposed on WindowObj 
    function WindowObj:AddSectionLabel(text)
        self._tabOrder = self._tabOrder + 1
        local f = Instance.new("Frame", sbScroll)
        f.Size                   = UDim2.new(1, 0, 0, 28)
        f.BackgroundTransparency = 1
        f.LayoutOrder            = self._tabOrder
        f.ZIndex                 = 5
        local lp = Instance.new("UIPadding", f)
        lp.PaddingLeft = UDim.new(0, 4)
        lp.PaddingTop  = UDim.new(0, 8)
        local t = Instance.new("TextLabel", f)
        t.Size                   = UDim2.new(1, 0, 1, 0)
        t.BackgroundTransparency = 1
        t.Text                   = text
        applyFont(t, "Bold")
        t.TextSize               = 12
        t.TextXAlignment         = Enum.TextXAlignment.Left
        t.ZIndex                 = 5
        registerTheme(t, "TextColor3", "TextDim")
        return f
    end

    function WindowObj:AddSeparator()
        self._tabOrder = self._tabOrder + 1
        local f = Instance.new("Frame", sbScroll)
        f.Size                   = UDim2.new(1, 0, 0, 8)
        f.BackgroundTransparency = 1
        f.BorderSizePixel        = 0
        f.LayoutOrder            = self._tabOrder
        f.ZIndex                 = 5
        local ln = Instance.new("Frame", f)
        ln.Size             = UDim2.new(1, 0, 0, 1)
        ln.Position         = UDim2.new(0, 0, 0.5, 0)
        ln.BorderSizePixel  = 0
        ln.ZIndex           = 5
        registerTheme(ln, "BackgroundColor3", "Separator")
        return f
    end

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

    -- Auto-load Config after window & elements creation
    task.defer(function()
        Library:LoadConfig()
    end)

    return WindowObj
end

--  Destroy / Cleanup 
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
