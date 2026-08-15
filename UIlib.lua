print("hi")
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
Library.Options         = {}
Library.Elements        = {}
Library.Connections     = {}
Library.Threads         = {}
Library.Unloaded        = false
Library.ConfigName      = nil
Library.IsLoadingConfig = false
Library.MinimizeKey     = Enum.KeyCode.LeftControl
Library.DialogOpen      = false

function Library:SafeCallback(func, ...)
    if not func then return end
    local success, result = pcall(func, ...)
    if not success then
        warn("[MDuiLib] Error in callback: " .. tostring(result))
        pcall(function()
            Library:Notify({
                Title = "Callback Error",
                Content = tostring(result),
                Duration = 5
            })
        end)
    end
    return success, result
end

function Library:Round(number, factor)
    if not factor or factor == 0 then
        return math.floor(number + 0.5)
    end
    local mult = 10 ^ factor
    return math.floor(number * mult + 0.5) / mult
end

Library.Icons = {
    Gear     = "rbxassetid://137812568290912",
    Minimise = "rbxassetid://80688800908127",
    Home     = "rbxassetid://95747170083656",
    Expand   = "rbxassetid://108376906768065",
    Diamond  = "rbxassetid://118376432250064",
    Cross    = "rbxassetid://110946743687809",
    Game     = "rbxassetid://71655163787303",
}

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
notificationHolder.Size                   = UDim2.new(0, 300, 0, 0)
notificationHolder.AutomaticSize          = Enum.AutomaticSize.Y
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

local function trySyncLoad(fileName, weight)
    pcall(function()
        if isfile and isfile(fileName) and getcustomasset then
            local id = getcustomasset(fileName)
            if id and #id > 5 then
                local f = Font.new(id, weight or Enum.FontWeight.Bold, Enum.FontStyle.Normal)
                if weight == Enum.FontWeight.Bold     then fontBold   = f end
                if weight == Enum.FontWeight.Medium   then fontMedium = f end
                if weight == Enum.FontWeight.SemiBold then fontSemi   = f end
            end
        end
    end)
end

trySyncLoad("MDHub_Kanit_Bold.ttf",     Enum.FontWeight.Bold)
trySyncLoad("MDHub_Kanit_Medium.ttf",   Enum.FontWeight.Medium)
trySyncLoad("MDHub_Kanit_SemiBold.ttf", Enum.FontWeight.SemiBold)

local function refreshAllFonts()
    for i = #fontRegistry, 1, -1 do
        local item = fontRegistry[i]
        if not item.Inst or not item.Inst.Parent then
            table.remove(fontRegistry, i)
        else
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
        if not (writefile and isfile and getcustomasset) then return end
        if not isfile(fileName) then
            local d = game:HttpGet(url)
            if not d or #d < 500 then return end
            writefile(fileName, d)
        end
        local assetId = nil
        for _ = 1, 20 do
            local id = getcustomasset(fileName)
            if id and #id > 5 then assetId = id; break end
            task.wait(0.1)
        end
        if not assetId then return end
        local f = Font.new(assetId, weight or Enum.FontWeight.Bold, Enum.FontStyle.Normal)
        if weight == Enum.FontWeight.Bold     then fontBold   = f end
        if weight == Enum.FontWeight.Medium   then fontMedium = f end
        if weight == Enum.FontWeight.SemiBold then fontSemi   = f end
        refreshAllFonts()
    end)
end

task.spawn(function() loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-Bold.ttf",     "MDHub_Kanit_Bold.ttf",     Enum.FontWeight.Bold) end)
task.spawn(function() loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-Medium.ttf",   "MDHub_Kanit_Medium.ttf",   Enum.FontWeight.Medium) end)
task.spawn(function() loadFont("https://raw.githubusercontent.com/cadsondemak/kanit/master/fonts/ttf/Kanit-SemiBold.ttf", "MDHub_Kanit_SemiBold.ttf", Enum.FontWeight.SemiBold) end)

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
        if getcustomasset and writefile then
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

-- label: base helper (matching hub 1.3x text scaling)
local function label(parent, props)
    local t = Instance.new("TextLabel", parent)
    t.BackgroundTransparency = 1
    t.BorderSizePixel        = 0
    t.TextWrapped            = props.wrap or false
    t.Size                   = props.size or UDim2.new(1, 0, 0, 20)
    t.Position               = props.pos or UDim2.new(0, 0, 0, 0)
    t.Text                   = props.text or ""
    applyFont(t, props.fontType or "Bold")
    local baseTs             = props.ts or 12
    t.TextSize               = math.floor(baseTs * 1.3 + 0.5)
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

-- lbl: alias to label primitive (1.3x scaling applied in label)
local function lbl(parent, props)
    return label(parent, props)
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

local activeDraggingObject = nil

local function makeDraggable(frame, handle, clickCallback)
    handle = handle or frame
    local dragging  = false
    local movedFar  = false
    local dragStart = Vector3.new()
    local startPos  = UDim2.new()

    Library:TrackConnection(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if activeDraggingObject and activeDraggingObject ~= frame then return end
            if isInteractiveObject(Vector2.new(input.Position.X, input.Position.Y)) then
                return
            end
            activeDraggingObject = frame
            dragging  = true
            movedFar  = false
            dragStart = input.Position
            startPos  = frame.Position
        end
    end))

    Library:TrackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and activeDraggingObject == frame and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
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
                if activeDraggingObject == frame then activeDraggingObject = nil end
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
                local rawType = tostring(val.EnumType)
                local enumName = rawType:match("Enum%.([%w_]+)") or rawType:match("([%w_]+)$") or rawType
                if Enum[enumName] and Enum[enumName][val.Name] then
                    return Enum[enumName][val.Name]
                end
                if Enum.KeyCode[val.Name] then return Enum.KeyCode[val.Name] end
                if Enum.UserInputType[val.Name] then return Enum.UserInputType[val.Name] end
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
    toast.Size                    = UDim2.new(1, 0, 0, 60)
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
        size = UDim2.new(1, -iconOffset - 28, 0, 20),
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
    closeBtn.Size                   = UDim2.new(0, 14, 0, 14)
    closeBtn.Position               = UDim2.new(1, -20, 0, 6)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text                   = "x"
    applyFont(closeBtn, "Bold")
    closeBtn.TextSize               = 14
    registerTheme(closeBtn, "TextColor3", "TextDim")

    local progressBar = Instance.new("Frame", toast)
    progressBar.Size             = UDim2.new(1, 0, 0, 2)
    progressBar.Position         = UDim2.new(0, 0, 1, -2)
    progressBar.BorderSizePixel    = 0
    registerTheme(progressBar, "BackgroundColor3", "Accent")

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

--  Dialog System (Modal Popups)
function Library:Dialog(options)
    options = options or {}
    local titleText   = options.Title or "Dialog"
    local contentText = options.Content or ""
    local buttons     = options.Buttons or {}

    local CW_W, CW_H = 340, 160

    local backdrop = Instance.new("TextButton", overlayLayer)
    backdrop.Name                   = "MD_DialogBackdrop"
    backdrop.Size                   = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundTransparency = 1
    backdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    backdrop.BorderSizePixel        = 0
    backdrop.Text                   = ""
    backdrop.ZIndex                 = 4999

    local dialogWin = Instance.new("Frame", overlayLayer)
    dialogWin.Name             = "MD_DialogWindow"
    dialogWin.Size             = UDim2.new(0, CW_W, 0, CW_H)
    dialogWin.Position         = UDim2.new(0.5, -CW_W/2, 0.5, -CW_H/2)
    dialogWin.BorderSizePixel  = 0
    dialogWin.Active           = true
    dialogWin.ZIndex           = 5000
    registerTheme(dialogWin, "BackgroundColor3", "Background")
    corner(dialogWin, 8)
    stroke(dialogWin, 1, "Border")

    Library.DialogOpen = true
    twQ(backdrop, 0.2, { BackgroundTransparency = 0.5 })
    dialogWin.Size     = UDim2.new(0, CW_W, 0, 0)
    dialogWin.Position = UDim2.new(0.5, -CW_W/2, 0.5, 0)
    twB(dialogWin, 0.3, { Size = UDim2.new(0, CW_W, 0, CW_H), Position = UDim2.new(0.5, -CW_W/2, 0.5, -CW_H/2) })

    local function closeDialog()
        Library.DialogOpen = false
        twQ(backdrop, 0.2, { BackgroundTransparency = 1 })
        twQ(dialogWin, 0.2, { Size = UDim2.new(0, CW_W, 0, 0), Position = UDim2.new(0.5, -CW_W/2, 0.5, 0) })
        task.delay(0.22, function()
            dialogWin:Destroy()
            backdrop:Destroy()
        end)
    end

    local dHead = Instance.new("Frame", dialogWin)
    dHead.Size = UDim2.new(1, 0, 0, 36)
    dHead.BackgroundTransparency = 1
    dHead.BorderSizePixel = 0
    dHead.ZIndex = 5001
    label(dHead, { size = UDim2.new(1, -24, 1, 0), pos = UDim2.new(0, 14, 0, 0), text = titleText, fontType = "Bold", ts = 13, theme = "Text", z = 5002 })
    makeDraggable(dialogWin, dHead)

    label(dialogWin, { size = UDim2.new(1, -28, 0, 38), pos = UDim2.new(0, 14, 0, 40), text = contentText, fontType = "Medium", ts = 11, theme = "TextDim", wrap = true, z = 5002 })

    local btnRow = Instance.new("Frame", dialogWin)
    btnRow.Size                   = UDim2.new(1, -28, 0, 32)
    btnRow.Position               = UDim2.new(0, 14, 1, -44)
    btnRow.BackgroundTransparency = 1
    btnRow.ZIndex                 = 5002

    local btnCount = #buttons > 0 and #buttons or 1
    for idx, btnData in ipairs(buttons) do
        local btnTitle = btnData.Title or "Button"
        local btnCb    = btnData.Callback or function() end
        local btnObj   = Instance.new("TextButton", btnRow)
        local widthFrac = 1 / btnCount
        btnObj.Size                   = UDim2.new(widthFrac, -((btnCount - 1) * 6 / btnCount), 1, 0)
        btnObj.Position               = UDim2.new((idx - 1) * widthFrac, (idx - 1) * 6 / btnCount, 0, 0)
        btnObj.BorderSizePixel        = 0
        btnObj.Text                   = btnTitle
        applyFont(btnObj, "Bold")
        btnObj.TextSize               = 14
        btnObj.ZIndex                 = 5003
        registerTheme(btnObj, "BackgroundColor3", idx == btnCount and "Accent" or "Panel")
        registerTheme(btnObj, "TextColor3", idx == btnCount and "Text" or "TextMid")
        corner(btnObj, 5)

        btnObj.MouseButton1Click:Connect(function()
            Library:SafeCallback(btnCb)
            closeDialog()
        end)
    end

    return { Close = closeDialog }
end

--  Window Creation 
function Library:CreateWindow(options)
    options = options or {}
    local winTitle    = options.Title or "Window"
    local winSubTitle = options.SubTitle or "v1.0"
    local winIcon     = options.Icon
    local winSize     = options.Size or Vector2.new(660, 420)

    self.ConfigName = options.ConfigName
    if options.MinimizeKey then
        self.MinimizeKey = options.MinimizeKey
    end

    if options.Theme then
        self:SetTheme(options.Theme)
    end

    local MAIN_W, MAIN_H = winSize.X, winSize.Y
    local TOPBAR_H       = 65
    local SIDEBAR_W      = options.TabWidth or 150

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
    resizeBtn.Image                  = Library.Icons.Expand
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

    local settingsBtn = makeIconBtn(Library.Icons.Gear, 20)
    local minimiseBtn = makeIconBtn(Library.Icons.Minimise, 20)
    local closeBtn    = makeIconBtn(Library.Icons.Cross, 17)

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
    miniImg.Image                  = Library.Icons.Gear
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

    --  MinimizeKey Keyboard Shortcut (Fluent-style toggle minimize)
    Library:TrackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if Library.MinimizeKey and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Library.MinimizeKey then
            if isAnimating then return end
            if mainFrame.Visible then
                -- Minimize
                isAnimating = true
                miniIcon.Position = mainFrame.Position
                miniIconScale.Scale = 0
                miniIcon.Rotation = -360
                miniIcon.Visible = true
                local twMS = twQ(mainScale, 0.3, { Scale = 0 })
                twQ(miniIconScale, 0.3, { Scale = 1.0 })
                twQ(miniIcon, 0.3, { Rotation = 0 })
                twMS.Completed:Once(function()
                    mainFrame.Visible = false
                    mainScale.Scale   = 1.0
                    isAnimating       = false
                end)
            else
                -- Restore
                isAnimating = true
                mainFrame.Position = miniIcon.Position
                mainScale.Scale    = 0
                mainFrame.Visible  = true
                local twMS = twQ(mainScale, 0.3, { Scale = 1.0 })
                twQ(miniIconScale, 0.3, { Scale = 0 })
                twQ(miniIcon, 0.3, { Rotation = 360 })
                twMS.Completed:Once(function()
                    miniIcon.Visible    = false
                    miniIconScale.Scale = 1.0
                    miniIcon.Rotation   = 0
                    isAnimating         = false
                end)
            end
        end
    end))

    --  Close Confirmation Modal 
    local CW_W, CW_H = 320, 170

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

    modalBackdrop.MouseButton1Click:Connect(function()
        closeCloseWin()
    end)

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

    local cLabel = label(closeWin, {
        size = UDim2.new(1, -28, 0, 0),
        pos = UDim2.new(0, 14, 0, 44),
        text = "Are you sure you want to unload the script UI?",
        fontType = "Medium",
        ts = 11,
        theme = "TextDim",
        wrap = true,
        z = 5002
    })
    cLabel.AutomaticSize = Enum.AutomaticSize.Y

    local cwBtnRow = Instance.new("Frame", closeWin)
    cwBtnRow.Size                   = UDim2.new(1, -28, 0, 34)
    cwBtnRow.Position               = UDim2.new(0, 14, 1, -46)
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

    unloadBtn.MouseEnter:Connect(function() twQ(unloadBtn, 0.1, { BackgroundColor3 = Theme.AccentHover or Color3.fromRGB(230, 95, 10) }) end)
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
    slidingIndicator.Size             = UDim2.new(0, 2, 0, 20)
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

        WindowObj._tabOrder = WindowObj._tabOrder + 1
        local btn = Instance.new("TextButton", sbScroll)
        btn.Name                   = "Nav_" .. tabName
        btn.Size                   = UDim2.new(1, 0, 0, 30)
        btn.BackgroundTransparency = 1
        btn.BackgroundColor3       = Theme.Elevated
        btn.BorderSizePixel        = 0
        btn.Text                   = ""
        btn.LayoutOrder            = WindowObj._tabOrder
        btn.ZIndex                 = 6
        corner(btn, 5)

        local iconInst = nil
        local textLeftOffset = 12

        if typeof(tabIcon) == "string" and tabIcon ~= "" then
            if string.sub(tabIcon, 1, 10) == "rbxassetid" or string.sub(tabIcon, 1, 4) == "http" or tonumber(tabIcon) then
                local assetId = (string.sub(tabIcon, 1, 10) == "rbxassetid" or string.sub(tabIcon, 1, 4) == "http") and tabIcon or ("rbxassetid://" .. tabIcon)
                iconInst = Instance.new("ImageLabel", btn)
                iconInst.Size                   = UDim2.new(0, 22, 0, 22)
                iconInst.Position               = UDim2.new(0, 6, 0.5, -12)
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
        nameLbl.TextSize               = 16
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
        pagePad.PaddingTop    = UDim.new(0, 18)
        pagePad.PaddingBottom = UDim.new(0, 18)
        pagePad.PaddingLeft   = UDim.new(0, 18)
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
        function TabObj:AddSection(sectionName, targetParent)
            self.SectionCount = (self.SectionCount or 0) + 1

            local secCard = Instance.new("Frame", targetParent or self.Page)
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

                local state = default
                if flag then
                    Library.Flags[flag] = state
                end

                local titleLbl = label(rowBtn, {
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
                track.Size                   = UDim2.new(0, 40, 0, 20)
                track.Position               = UDim2.new(1, -48, 0.5, -10)
                track.BorderSizePixel        = 0
                track.ZIndex                 = 6
                registerTheme(track, "BackgroundColor3", default and "Accent" or "Elevated")
                corner(track, 10)

                local thumb = Instance.new("Frame", track)
                thumb.Size                   = UDim2.new(0, 14, 0, 14)
                thumb.AnchorPoint            = Vector2.new(0.5, 0.5)
                thumb.Position               = default and UDim2.new(1, -10, 0.5, 0) or UDim2.new(0, 10, 0.5, 0)
                thumb.BorderSizePixel        = 0
                thumb.ZIndex                 = 7
                registerTheme(thumb, "BackgroundColor3", "Text")
                corner(thumb, 7)

                local ToggleObj = { Flag = flag, Default = default, Type = "Toggle" }

                function ToggleObj:Set(val, skipCallback)
                    state = not not val
                    if flag then Library.Flags[flag] = state end
                    twQ(track, 0.15, { BackgroundColor3 = state and Theme.Accent or Theme.Elevated })
                    twQ(thumb, 0.15, { Position = state and UDim2.new(1, -9, 0.5, 0) or UDim2.new(0, 9, 0.5, 0) })
                    if not skipCallback and not Library.IsLoadingConfig then
                        Library:SafeCallback(callback, state)
                        if ToggleObj.Changed then Library:SafeCallback(ToggleObj.Changed, state) end
                    end
                    Library:SaveConfig()
                end

                function ToggleObj:SetValue(val) ToggleObj:Set(val) end
                function ToggleObj:Get() return state end
                function ToggleObj:GetValue() return state end
                function ToggleObj:OnChanged(cb)
                    ToggleObj.Changed = cb
                    cb(state)
                end
                function ToggleObj:SetTitle(t) titleLbl.Text = t end

                function ToggleObj:Destroy()
                    rowBtn:Destroy()
                    if flag then Library.Options[flag] = nil end
                end

                rowBtn.MouseButton1Click:Connect(function()
                    ToggleObj:Set(not state)
                end)

                if flag then Library.Options[flag] = ToggleObj end
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
                if minVal >= maxVal then maxVal = minVal + 1 end
                local step     = math.max(0.0001, sliderOpts.Step or 1)
                local default  = sliderOpts.Default or minVal
                default        = math.clamp(default, minVal, maxVal)
                local suffix   = sliderOpts.Suffix or ""
                local callback = sliderOpts.Callback or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local container = Instance.new("Frame", secCard)
                container.Size                   = UDim2.new(1, 0, 0, 36)
                container.BackgroundTransparency = 1
                container.BorderSizePixel        = 0
                container.LayoutOrder            = SectionObj.ElementCount
                container.ZIndex                 = 6

                label(container, {
                    size = UDim2.new(0.44, 0, 1, 0),
                    pos = UDim2.new(0, 0, 0, 0),
                    text = nameText,
                    fontType = "Medium",
                    ts = 12,
                    theme = "Text",
                    z = 6
                })

                local valLbl = label(container, {
                    size = UDim2.new(0, 32, 1, 0),
                    pos = UDim2.new(0.45, 0, 0, 0),
                    text = tostring(default) .. suffix,
                    fontType = "Medium",
                    ts = 11,
                    theme = "TextDim",
                    ax = Enum.TextXAlignment.Right,
                    z = 6
                })

                local trackBg = Instance.new("TextButton", container)
                trackBg.Size                   = UDim2.new(0.50, -6, 0, 4)
                trackBg.Position               = UDim2.new(0.50, 6, 0.5, -2)
                trackBg.BorderSizePixel        = 0
                trackBg.Text                   = ""
                trackBg.ZIndex                 = 7
                registerTheme(trackBg, "BackgroundColor3", "Elevated")
                corner(trackBg, 2)

                local relInit = math.clamp((default - minVal) / (maxVal - minVal), 0, 1)

                local fill = Instance.new("Frame", trackBg)
                fill.Size                   = UDim2.new(relInit, 0, 1, 0)
                fill.BorderSizePixel        = 0
                fill.ZIndex                 = 8
                registerTheme(fill, "BackgroundColor3", "Accent")
                corner(fill, 2)

                local thumb = Instance.new("Frame", trackBg)
                thumb.Size                   = UDim2.new(0, 14, 0, 14)
                thumb.AnchorPoint            = Vector2.new(0.5, 0.5)
                thumb.Position               = UDim2.new(relInit, 0, 0.5, 0)
                thumb.BorderSizePixel        = 0
                thumb.ZIndex                 = 9
                registerTheme(thumb, "BackgroundColor3", "Accent")
                corner(thumb, 7)

                local currVal = default
                if flag then Library.Flags[flag] = currVal end

                local SliderObj = { Flag = flag, Default = default, Type = "Slider" }

                local function updateSlider(px, skipCallback)
                    local rel = math.clamp((px - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
                    local raw = minVal + rel * (maxVal - minVal)
                    local stepped = math.floor((raw - minVal) / step + 0.5) * step + minVal
                    stepped = math.clamp(stepped, minVal, maxVal)

                    currVal = stepped
                    if flag then Library.Flags[flag] = currVal end

                    local newRel = math.clamp((currVal - minVal) / (maxVal - minVal), 0, 1)
                    fill.Size = UDim2.new(newRel, 0, 1, 0)
                    thumb.Position = UDim2.new(newRel, 0, 0.5, 0)
                    valLbl.Text = tostring(currVal) .. suffix

                    if not skipCallback and not Library.IsLoadingConfig then
                        Library:SafeCallback(callback, currVal)
                        if SliderObj.Changed then Library:SafeCallback(SliderObj.Changed, currVal) end
                    end
                end

                function SliderObj:Set(val, skipCallback)
                    val = math.clamp(val or minVal, minVal, maxVal)
                    local stepped = math.floor((val - minVal) / step + 0.5) * step + minVal
                    currVal = math.clamp(stepped, minVal, maxVal)
                    if flag then Library.Flags[flag] = currVal end
                    local newRel = math.clamp((currVal - minVal) / (maxVal - minVal), 0, 1)
                    fill.Size = UDim2.new(newRel, 0, 1, 0)
                    thumb.Position = UDim2.new(newRel, 0, 0.5, 0)
                    valLbl.Text = tostring(currVal) .. suffix

                    if not skipCallback and not Library.IsLoadingConfig then
                        Library:SafeCallback(callback, currVal)
                        if SliderObj.Changed then Library:SafeCallback(SliderObj.Changed, currVal) end
                    end
                    Library:SaveConfig()
                end

                function SliderObj:SetValue(val) SliderObj:Set(val) end
                function SliderObj:Get() return currVal end
                function SliderObj:GetValue() return currVal end
                function SliderObj:OnChanged(cb)
                    SliderObj.Changed = cb
                    cb(currVal)
                end

                function SliderObj:Destroy()
                    container:Destroy()
                    if flag then Library.Options[flag] = nil end
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
                        if sliding then
                            sliding = false
                            Library:SaveConfig()
                        end
                    end
                end))

                if flag then Library.Options[flag] = SliderObj end
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

                local DropdownObj = { Flag = flag, Default = default, Type = "Dropdown" }

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
                        Library:SafeCallback(callback, selectedVal)
                        if DropdownObj.Changed then Library:SafeCallback(DropdownObj.Changed, selectedVal) end
                    end
                    Library:SaveConfig()
                end

                function DropdownObj:SetOptions(newOptions)
                    options = newOptions or {}
                    if not isMulti then
                        if not table.find(options, selectedVal) then
                            selectedVal = options[1] or ""
                        end
                    end
                    selectedTextLbl.Text = formatSelected()
                    if popupOpen then closeMenu() end
                end

                function DropdownObj:SetValues(newOptions)
                    DropdownObj:SetOptions(newOptions)
                end

                function DropdownObj:SetValue(val) DropdownObj:Set(val) end
                function DropdownObj:Get() return selectedVal end
                function DropdownObj:GetValue() return selectedVal end
                function DropdownObj:OnChanged(cb)
                    DropdownObj.Changed = cb
                    cb(selectedVal)
                end

                function DropdownObj:Destroy()
                    closeMenu()
                    container:Destroy()
                    if flag then Library.Options[flag] = nil end
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

                    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
                    local hasSearch = #options > 5
                    local searchH = hasSearch and 32 or 0
                    local mWidth = btnAbsSz.X
                    local mHeight = math.min(#options * 28 + searchH + 8, 180)
                    local posX = math.clamp(btnAbsPos.X, 4, math.max(4, vp.X - mWidth - 4))
                    local posY = btnAbsPos.Y + btnAbsSz.Y + 4
                    if posY + mHeight > vp.Y - 10 then
                        posY = math.max(4, btnAbsPos.Y - mHeight - 4)
                    end

                    menuFrame = Instance.new("Frame", overlayLayer)
                    menuFrame.Size                   = UDim2.new(0, mWidth, 0, mHeight)
                    menuFrame.Position               = UDim2.new(0, posX, 0, posY)
                    menuFrame.BorderSizePixel        = 0
                    menuFrame.ZIndex                 = 2000
                    menuFrame.BackgroundTransparency = 1
                    registerTheme(menuFrame, "BackgroundColor3", "Elevated")
                    corner(menuFrame, 6)
                    stroke(menuFrame, 1, "Border")

                    twQ(menuFrame, 0.15, { BackgroundTransparency = 0 })

                    activeMenuFrame   = menuFrame
                    activeCloseMenuFn = closeMenu

                    local scrollPos = hasSearch and UDim2.new(0, 0, 0, 32) or UDim2.new(0, 0, 0, 0)
                    local scrollSz  = hasSearch and UDim2.new(1, 0, 1, -32) or UDim2.new(1, 0, 1, 0)

                    if hasSearch then
                        local searchFrame = Instance.new("Frame", menuFrame)
                        searchFrame.Size                   = UDim2.new(1, -8, 0, 26)
                        searchFrame.Position               = UDim2.new(0, 4, 0, 4)
                        searchFrame.BackgroundTransparency = 1
                        searchFrame.ZIndex                 = 2001

                        local sBox = Instance.new("TextBox", searchFrame)
                        sBox.Size                   = UDim2.new(1, 0, 1, 0)
                        sBox.BackgroundTransparency = 0.8
                        sBox.BorderSizePixel        = 0
                        sBox.Text                   = ""
                        sBox.PlaceholderText        = "Search options..."
                        applyFont(sBox, "Medium")
                        sBox.TextSize               = 11
                        sBox.ZIndex                 = 2002
                        registerTheme(sBox, "BackgroundColor3", "Background")
                        registerTheme(sBox, "TextColor3", "Text")
                        registerTheme(sBox, "PlaceholderColor3", "TextDim")
                        corner(sBox, 4)

                        sBox:GetPropertyChangedSignal("Text"):Connect(function()
                            local query = string.lower(sBox.Text)
                            for opt, optInfo in pairs(optionButtons) do
                                if query == "" or string.find(string.lower(opt), query, 1, true) then
                                    optInfo.Btn.Visible = true
                                else
                                    optInfo.Btn.Visible = false
                                end
                            end
                        end)
                    end

                    local scroll = Instance.new("ScrollingFrame", menuFrame)
                    scroll.Size                   = scrollSz
                    scroll.Position               = scrollPos
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

                if flag then Library.Options[flag] = DropdownObj end
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

                box:GetPropertyChangedSignal("Text"):Connect(function()
                    currText = box.Text
                    if flag then Library.Flags[flag] = currText end
                end)

                local TextBoxObj = { Flag = flag, Default = default, Type = "Input" }

                function TextBoxObj:Set(val, skipCallback)
                    currText = tostring(val or "")
                    box.Text = currText
                    if flag then Library.Flags[flag] = currText end
                    if not skipCallback and not Library.IsLoadingConfig then
                        Library:SafeCallback(callback, currText)
                        if TextBoxObj.Changed then Library:SafeCallback(TextBoxObj.Changed, currText) end
                    end
                    Library:SaveConfig()
                end

                function TextBoxObj:SetValue(val) TextBoxObj:Set(val) end
                function TextBoxObj:Get() return currText end
                function TextBoxObj:GetValue() return currText end
                function TextBoxObj:OnChanged(cb)
                    TextBoxObj.Changed = cb
                    cb(currText)
                end

                function TextBoxObj:Destroy()
                    container:Destroy()
                    if flag then Library.Options[flag] = nil end
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

                if flag then Library.Options[flag] = TextBoxObj end
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

                local KeybindObj = { Flag = flag, Default = default, Type = "Keybind" }

                function KeybindObj:GetState()
                    if UserInputService:GetFocusedTextBox() and mode ~= "Always" then
                        return false
                    end
                    if mode == "Always" then
                        return typeof(currKey) == "EnumItem" and UserInputService:IsKeyDown(currKey)
                    elseif mode == "Hold" then
                        if typeof(currKey) == "EnumItem" then
                            return UserInputService:IsKeyDown(currKey)
                        end
                        return false
                    else
                        return isToggled
                    end
                end

                local beganConn = UserInputService.InputBegan:Connect(function(input, gpe)
                    if isListening then
                        local key
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            key = input.KeyCode
                        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                            key = "MouseLeft"
                        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                            key = "MouseRight"
                        end
                        if key then
                            if key == Enum.KeyCode.Escape then
                                isListening = false
                                bindLbl.Text = typeof(currKey) == "EnumItem" and currKey.Name or tostring(currKey)
                            else
                                isListening = false
                                KeybindObj:Set(key)
                            end
                        end
                        return
                    end

                    if not gpe and not UserInputService:GetFocusedTextBox() then
                        local isMatch = false
                        if typeof(currKey) == "EnumItem" and input.UserInputType == Enum.UserInputType.Keyboard then
                            isMatch = input.KeyCode == currKey
                        elseif currKey == "MouseLeft" and input.UserInputType == Enum.UserInputType.MouseButton1 then
                            isMatch = true
                        elseif currKey == "MouseRight" and input.UserInputType == Enum.UserInputType.MouseButton2 then
                            isMatch = true
                        end

                        if isMatch then
                            if mode == "Toggle" then
                                isToggled = not isToggled
                                Library:SafeCallback(callback, isToggled)
                                if KeybindObj.Clicked then Library:SafeCallback(KeybindObj.Clicked, isToggled) end
                            elseif mode == "Hold" then
                                Library:SafeCallback(callback, true)
                            end
                        end
                    end
                end)
                Library:TrackConnection(beganConn)

                local endedConn = UserInputService.InputEnded:Connect(function(input, gpe)
                    if mode == "Hold" then
                        local isMatch = false
                        if typeof(currKey) == "EnumItem" and input.UserInputType == Enum.UserInputType.Keyboard then
                            isMatch = input.KeyCode == currKey
                        elseif currKey == "MouseLeft" and input.UserInputType == Enum.UserInputType.MouseButton1 then
                            isMatch = true
                        elseif currKey == "MouseRight" and input.UserInputType == Enum.UserInputType.MouseButton2 then
                            isMatch = true
                        end
                        if isMatch then
                            Library:SafeCallback(callback, false)
                        end
                    end
                end)
                Library:TrackConnection(endedConn)

                function KeybindObj:Set(key, skipCallback)
                    currKey = key
                    bindLbl.Text = typeof(currKey) == "EnumItem" and currKey.Name or tostring(currKey)
                    if flag then Library.Flags[flag] = currKey end
                    if not skipCallback then
                        if KeybindObj.ChangedCallback then Library:SafeCallback(KeybindObj.ChangedCallback, currKey) end
                    end
                    Library:SaveConfig()
                end

                function KeybindObj:SetValue(key, newMode)
                    if newMode then mode = newMode end
                    KeybindObj:Set(key)
                end
                function KeybindObj:Get() return currKey end
                function KeybindObj:GetValue() return currKey end
                function KeybindObj:OnChanged(cb)
                    KeybindObj.ChangedCallback = cb
                    cb(currKey)
                end
                function KeybindObj:OnClick(cb)
                    KeybindObj.Clicked = cb
                end
                function KeybindObj:DoClick()
                    Library:SafeCallback(callback, isToggled)
                    if KeybindObj.Clicked then Library:SafeCallback(KeybindObj.Clicked, isToggled) end
                end

                function KeybindObj:Destroy()
                    pcall(function() beganConn:Disconnect() end)
                    pcall(function() endedConn:Disconnect() end)
                    container:Destroy()
                    if flag then Library.Options[flag] = nil end
                end

                bindBtn.MouseButton1Click:Connect(function()
                    isListening = true
                    bindLbl.Text = "..."
                end)

                if flag then Library.Options[flag] = KeybindObj end
                table.insert(Library.Elements, KeybindObj)
                return KeybindObj
            end

            -- ── Section:AddColorPicker ──────────────────────────────────
            function SectionObj:AddColorPicker(cpOpts)
                cpOpts = cpOpts or {}
                local nameText  = cpOpts.Name or "Color Picker"
                local flag      = cpOpts.Flag
                local default   = cpOpts.Default or Color3.fromRGB(255, 0, 0)
                local callback  = cpOpts.Callback or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local container = Instance.new("Frame", SectionObj.Frame)
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
                if flag then Library.Flags[flag] = currColor end

                local ColorPickerObj = { Flag = flag, Default = default, Value = default, Type = "Colorpicker" }

                function ColorPickerObj:Set(color, skipCallback)
                    currColor = color
                    ColorPickerObj.Value = color
                    swatch.BackgroundColor3 = currColor
                    if flag then Library.Flags[flag] = currColor end
                    if not skipCallback and not Library.IsLoadingConfig then
                        Library:SafeCallback(callback, currColor)
                        if ColorPickerObj.Changed then Library:SafeCallback(ColorPickerObj.Changed, currColor) end
                    end
                    Library:SaveConfig()
                end

                function ColorPickerObj:SetValue(color) ColorPickerObj:Set(color) end
                function ColorPickerObj:Get() return currColor end
                function ColorPickerObj:GetValue() return currColor end
                function ColorPickerObj:OnChanged(cb)
                    ColorPickerObj.Changed = cb
                    cb(currColor)
                end
                function ColorPickerObj:Destroy()
                    container:Destroy()
                    if flag then Library.Options[flag] = nil end
                end

                local pickerOpen = false
                local modalBackdrop = nil
                local modalWindow = nil
                local popupConns = {}

                local function closePicker()
                    for _, conn in ipairs(popupConns) do pcall(function() conn:Disconnect() end) end
                    popupConns = {}
                    if modalBackdrop then modalBackdrop:Destroy(); modalBackdrop = nil end
                    if modalWindow then modalWindow:Destroy(); modalWindow = nil end
                    pickerOpen = false
                end

                swatch.MouseButton1Click:Connect(function()
                    if pickerOpen then
                        closePicker()
                        return
                    end
                    pickerOpen = true

                    local activeColor = ColorPickerObj.Value or currColor
                    local h, s, v = Color3.toHSV(activeColor)
                    local origColor = activeColor

                    local MW_W, MW_H = 430, 290

                    modalBackdrop = Instance.new("TextButton", overlayLayer)
                    modalBackdrop.Name                   = "MD_ColorPickerBackdrop"
                    modalBackdrop.Size                   = UDim2.new(1, 0, 1, 0)
                    modalBackdrop.BackgroundTransparency = 1
                    modalBackdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
                    modalBackdrop.BorderSizePixel        = 0
                    modalBackdrop.ZIndex                 = 4000
                    modalBackdrop.Text                   = ""
                    twQ(modalBackdrop, 0.2, { BackgroundTransparency = 0.5 })

                    modalWindow = Instance.new("Frame", overlayLayer)
                    modalWindow.Name             = "MD_ColorPickerModal"
                    modalWindow.Size             = UDim2.new(0, MW_W, 0, MW_H)
                    modalWindow.Position         = UDim2.new(0.5, -MW_W/2, 0.5, -MW_H/2)
                    modalWindow.BorderSizePixel  = 0
                    modalWindow.Active           = true
                    modalWindow.ZIndex           = 4001
                    registerTheme(modalWindow, "BackgroundColor3", "Background")
                    corner(modalWindow, 8)
                    stroke(modalWindow, 1, "Border")

                    makeDraggable(modalWindow, modalWindow)

                    lbl(modalWindow, {
                        size = UDim2.new(1, -30, 0, 24),
                        pos = UDim2.new(0, 20, 0, 16),
                        text = nameText,
                        fontType = "Bold",
                        ts = 16,
                        theme = "Text",
                        z = 4002
                    })

                    local satVibMap = Instance.new("ImageLabel", modalWindow)
                    satVibMap.Size                   = UDim2.new(0, 180, 0, 160)
                    satVibMap.Position               = UDim2.new(0, 20, 0, 48)
                    satVibMap.BackgroundColor3       = Color3.fromHSV(h, 1, 1)
                    satVibMap.BorderSizePixel        = 0
                    satVibMap.Image                  = "rbxassetid://4155801252"
                    satVibMap.ZIndex                 = 4002
                    corner(satVibMap, 5)

                    local cursor = Instance.new("ImageLabel", satVibMap)
                    cursor.Size                   = UDim2.new(0, 14, 0, 14)
                    cursor.AnchorPoint            = Vector2.new(0.5, 0.5)
                    cursor.Position               = UDim2.new(s, 0, 1 - v, 0)
                    cursor.BackgroundTransparency = 1
                    cursor.Image                  = "rbxassetid://4805639000"
                    cursor.ZIndex                 = 4003

                    local hueBar = Instance.new("Frame", modalWindow)
                    hueBar.Size                   = UDim2.new(0, 14, 0, 160)
                    hueBar.Position               = UDim2.new(0, 210, 0, 48)
                    hueBar.BorderSizePixel        = 0
                    hueBar.ZIndex                 = 4002
                    corner(hueBar, 7)

                    local hueGrad = Instance.new("UIGradient", hueBar)
                    hueGrad.Rotation = 90
                    local rainbowSeq = {}
                    for col = 0, 1, 0.1 do
                        table.insert(rainbowSeq, ColorSequenceKeypoint.new(col, Color3.fromHSV(col, 1, 1)))
                    end
                    hueGrad.Color = ColorSequence.new(rainbowSeq)

                    local hueCursor = Instance.new("Frame", hueBar)
                    hueCursor.Size                   = UDim2.new(0, 18, 0, 10)
                    hueCursor.AnchorPoint            = Vector2.new(0.5, 0.5)
                    hueCursor.Position               = UDim2.new(0.5, 0, h, 0)
                    hueCursor.BorderSizePixel        = 0
                    hueCursor.ZIndex                 = 4003
                    registerTheme(hueCursor, "BackgroundColor3", "Text")
                    corner(hueCursor, 5)

                    local origSwatch = Instance.new("Frame", modalWindow)
                    origSwatch.Size                   = UDim2.new(0, 85, 0, 26)
                    origSwatch.Position               = UDim2.new(0, 20, 0, 216)
                    origSwatch.BackgroundColor3       = origColor
                    origSwatch.BorderSizePixel        = 0
                    origSwatch.ZIndex                 = 4002
                    corner(origSwatch, 5)
                    stroke(origSwatch, 1, "Border")

                    local newSwatch = Instance.new("Frame", modalWindow)
                    newSwatch.Size                   = UDim2.new(0, 85, 0, 26)
                    newSwatch.Position               = UDim2.new(0, 115, 0, 216)
                    newSwatch.BackgroundColor3       = activeColor
                    newSwatch.BorderSizePixel        = 0
                    newSwatch.ZIndex                 = 4002
                    corner(newSwatch, 5)
                    stroke(newSwatch, 1, "Border")

                    local inputsFrame = Instance.new("Frame", modalWindow)
                    inputsFrame.Size                   = UDim2.new(0, 170, 0, 194)
                    inputsFrame.Position               = UDim2.new(0, 240, 0, 48)
                    inputsFrame.BackgroundTransparency = 1
                    inputsFrame.ZIndex                 = 4002

                    local function toHex(c)
                        return string.format("#%02X%02X%02X", math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
                    end

                    local hexInput, redInput, greenInput, blueInput

                    local function makeInputRow(posY, labelText, defaultText)
                        local box = Instance.new("TextBox", inputsFrame)
                        box.Size                   = UDim2.new(0, 100, 0, 32)
                        box.Position               = UDim2.new(0, 0, 0, posY)
                        box.BorderSizePixel        = 0
                        box.Text                   = defaultText
                        applyFont(box, "Medium")
                        box.TextSize               = 12
                        box.ZIndex                 = 4003
                        registerTheme(box, "BackgroundColor3", "Elevated")
                        registerTheme(box, "TextColor3", "Text")
                        corner(box, 5)
                        stroke(box, 1, "Border")

                        lbl(inputsFrame, {
                            size = UDim2.new(0, 60, 0, 32),
                            pos = UDim2.new(0, 110, 0, posY),
                            text = labelText,
                            fontType = "Medium",
                            ts = 11,
                            theme = "TextDim",
                            z = 4003
                        })
                        return box
                    end

                    hexInput   = makeInputRow(0,   "Hex",   toHex(activeColor))
                    redInput   = makeInputRow(40,  "Red",   tostring(math.floor(activeColor.R*255)))
                    greenInput = makeInputRow(80,  "Green", tostring(math.floor(activeColor.G*255)))
                    blueInput  = makeInputRow(120, "Blue",  tostring(math.floor(activeColor.B*255)))

                    local function updatePickerUI(updateInputs)
                        activeColor = Color3.fromHSV(h, s, v)
                        satVibMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                        cursor.Position = UDim2.new(s, 0, 1 - v, 0)
                        hueCursor.Position = UDim2.new(0.5, 0, h, 0)
                        newSwatch.BackgroundColor3 = activeColor

                        if updateInputs then
                            hexInput.Text   = toHex(activeColor)
                            redInput.Text   = tostring(math.floor(activeColor.R*255))
                            greenInput.Text = tostring(math.floor(activeColor.G*255))
                            blueInput.Text  = tostring(math.floor(activeColor.B*255))
                        end
                    end

                    local draggingSat = false
                    table.insert(popupConns, satVibMap.InputBegan:Connect(function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                            draggingSat = true
                            local relX = math.clamp((i.Position.X - satVibMap.AbsolutePosition.X) / satVibMap.AbsoluteSize.X, 0, 1)
                            local relY = math.clamp((i.Position.Y - satVibMap.AbsolutePosition.Y) / satVibMap.AbsoluteSize.Y, 0, 1)
                            s = relX
                            v = 1 - relY
                            updatePickerUI(true)
                        end
                    end))

                    table.insert(popupConns, UserInputService.InputChanged:Connect(function(i)
                        if draggingSat and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                            local relX = math.clamp((i.Position.X - satVibMap.AbsolutePosition.X) / satVibMap.AbsoluteSize.X, 0, 1)
                            local relY = math.clamp((i.Position.Y - satVibMap.AbsolutePosition.Y) / satVibMap.AbsoluteSize.Y, 0, 1)
                            s = relX
                            v = 1 - relY
                            updatePickerUI(true)
                        end
                    end))

                    local draggingHue = false
                    table.insert(popupConns, hueBar.InputBegan:Connect(function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                            draggingHue = true
                            h = math.clamp((i.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
                            updatePickerUI(true)
                        end
                    end))

                    table.insert(popupConns, UserInputService.InputChanged:Connect(function(i)
                        if draggingHue and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                            h = math.clamp((i.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
                            updatePickerUI(true)
                        end
                    end))

                    table.insert(popupConns, UserInputService.InputEnded:Connect(function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                            draggingSat = false
                            draggingHue = false
                        end
                    end))

                    table.insert(popupConns, hexInput.FocusLost:Connect(function()
                        local str = hexInput.Text:gsub("#", "")
                        if #str == 6 then
                            local nr, ng, nb = tonumber(str:sub(1,2), 16), tonumber(str:sub(3,4), 16), tonumber(str:sub(5,6), 16)
                            if nr and ng and nb then
                                activeColor = Color3.fromRGB(nr, ng, nb)
                                h, s, v = Color3.toHSV(activeColor)
                                updatePickerUI(true)
                            end
                        end
                    end))

                    local function onRgbInput()
                        local nr = math.clamp(tonumber(redInput.Text) or 0, 0, 255)
                        local ng = math.clamp(tonumber(greenInput.Text) or 0, 0, 255)
                        local nb = math.clamp(tonumber(blueInput.Text) or 0, 0, 255)
                        activeColor = Color3.fromRGB(nr, ng, nb)
                        h, s, v = Color3.toHSV(activeColor)
                        updatePickerUI(true)
                    end

                    table.insert(popupConns, redInput.FocusLost:Connect(onRgbInput))
                    table.insert(popupConns, greenInput.FocusLost:Connect(onRgbInput))
                    table.insert(popupConns, blueInput.FocusLost:Connect(onRgbInput))

                    local doneBtn = Instance.new("TextButton", modalWindow)
                    doneBtn.Size                   = UDim2.new(0, 185, 0, 34)
                    doneBtn.Position               = UDim2.new(0, 20, 0, 244)
                    doneBtn.BorderSizePixel        = 0
                    doneBtn.Text                   = "Done"
                    applyFont(doneBtn, "Bold")
                    doneBtn.TextSize               = 13
                    doneBtn.ZIndex                 = 4003
                    registerTheme(doneBtn, "BackgroundColor3", "Elevated")
                    registerTheme(doneBtn, "TextColor3", "Text")
                    corner(doneBtn, 6)
                    stroke(doneBtn, 1, "Border")

                    table.insert(popupConns, doneBtn.MouseButton1Click:Connect(function()
                        ColorPickerObj:Set(activeColor)
                        closePicker()
                    end))

                    local cancelBtn = Instance.new("TextButton", modalWindow)
                    cancelBtn.Size                   = UDim2.new(0, 185, 0, 34)
                    cancelBtn.Position               = UDim2.new(0, 225, 0, 244)
                    cancelBtn.BorderSizePixel        = 0
                    cancelBtn.Text                   = "Cancel"
                    applyFont(cancelBtn, "Bold")
                    cancelBtn.TextSize               = 13
                    cancelBtn.ZIndex                 = 4003
                    registerTheme(cancelBtn, "BackgroundColor3", "Elevated")
                    registerTheme(cancelBtn, "TextColor3", "TextDim")
                    corner(cancelBtn, 6)
                    stroke(cancelBtn, 1, "Border")

                    table.insert(popupConns, cancelBtn.MouseButton1Click:Connect(function()
                        closePicker()
                    end))

                    table.insert(popupConns, modalBackdrop.MouseButton1Click:Connect(function()
                        closePicker()
                    end))
                end)

                if flag then Library.Options[flag] = ColorPickerObj end
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

                rowBtn.MouseEnter:Connect(function()
                    twQ(rowBtn, 0.12, { BackgroundColor3 = Theme.Surface })
                end)
                rowBtn.MouseLeave:Connect(function()
                    twQ(rowBtn, 0.12, { BackgroundColor3 = Theme.Elevated })
                end)
                rowBtn.MouseButton1Down:Connect(function()
                    twQ(rowBtn, 0.08, { BackgroundColor3 = Theme.Panel })
                end)
                rowBtn.MouseButton1Up:Connect(function()
                    twQ(rowBtn, 0.12, { BackgroundColor3 = Theme.Surface })
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

            -- ── Section:AddScriptRow ─────────────────────────────────────
            function SectionObj:AddScriptRow(rowOpts)
                rowOpts = rowOpts or {}
                local titleText = rowOpts.Title or rowOpts.Name or "Script"
                local descText  = rowOpts.Desc or rowOpts.Description
                local callback  = rowOpts.Callback or rowOpts.Execute or function() end

                SectionObj.ElementCount = SectionObj.ElementCount + 1

                local dummy = Instance.new("Frame", secCard)
                dummy.Size                   = UDim2.new(1, 0, 0, 50)
                dummy.BackgroundTransparency = 1
                dummy.BorderSizePixel        = 0
                dummy.LayoutOrder            = SectionObj.ElementCount
                dummy.ZIndex                 = 5

                local card = Instance.new("Frame", dummy)
                card.Size                   = UDim2.new(1, 0, 1, 0)
                card.BorderSizePixel        = 0
                card.ZIndex                 = 5
                registerTheme(card, "BackgroundColor3", "Panel")
                corner(card, 6)
                stroke(card, 1, "Border")

                local dot = Instance.new("Frame", card)
                dot.Size                   = UDim2.new(0, 4, 0, 4)
                dot.Position               = UDim2.new(0, 14, 0.5, -2)
                dot.BorderSizePixel        = 0
                dot.ZIndex                 = 6
                registerTheme(dot, "BackgroundColor3", "TextDim")
                corner(dot, 2)

                if descText and descText ~= "" then
                    label(card, { size = UDim2.new(1, -110, 0, 22), pos = UDim2.new(0, 28, 0, 8), text = titleText, fontType = "Bold", ts = 13, theme = "Text", z = 6 })
                    label(card, { size = UDim2.new(1, -110, 0, 18), pos = UDim2.new(0, 28, 0, 27), text = descText, fontType = "Medium", ts = 10, theme = "TextDim", z = 6 })
                else
                    local tLbl = label(card, { size = UDim2.new(1, -110, 1, 0), pos = UDim2.new(0, 28, 0, 0), text = titleText, fontType = "Bold", ts = 13, theme = "Text", z = 6 })
                    tLbl.TextYAlignment = Enum.TextYAlignment.Center
                end

                local execBtn = Instance.new("TextButton", card)
                execBtn.Size                   = UDim2.new(0, 76, 0, 28)
                execBtn.Position               = UDim2.new(1, -84, 0.5, -14)
                execBtn.BorderSizePixel        = 0
                execBtn.Text                   = "Execute"
                applyFont(execBtn, "Bold")
                execBtn.TextSize               = 13
                execBtn.ZIndex                 = 7
                registerTheme(execBtn, "BackgroundColor3", "Accent")
                registerTheme(execBtn, "TextColor3", "Text")
                corner(execBtn, 5)

                execBtn.MouseEnter:Connect(function() twQ(execBtn, 0.1, { BackgroundColor3 = Color3.fromRGB(230, 95, 10) }) end)
                execBtn.MouseLeave:Connect(function() twQ(execBtn, 0.1, { BackgroundColor3 = Theme.Accent }) end)
                execBtn.MouseButton1Click:Connect(function() pcall(callback) end)

                local ScriptRowObj = {}
                function ScriptRowObj:Destroy() dummy:Destroy() end
                return ScriptRowObj
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

            -- Alias: Fluent uses AddInput, we use AddTextBox
            SectionObj.AddInput = SectionObj.AddTextBox

            return SectionObj
        end

        function TabObj:AddCollapsibleSection(opts, targetPage)
            if typeof(opts) == "string" then
                opts = { Name = opts }
            end
            opts = opts or {}
            local secName     = opts.Name or opts.Title or "Section"
            local secDesc     = opts.Desc or opts.Description
            local defaultOpen = opts.DefaultOpen ~= false

            TabObj.SectionCount = TabObj.SectionCount + 1

            local secCard = Instance.new("Frame", targetPage or page)
            secCard.Size                  = UDim2.new(1, 0, 0, 0)
            secCard.AutomaticSize         = defaultOpen and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
            secCard.BorderSizePixel        = 0
            secCard.LayoutOrder           = TabObj.SectionCount
            secCard.ClipsDescendants      = true
            secCard.ZIndex                = 5
            registerTheme(secCard, "BackgroundColor3", "Panel")
            corner(secCard, 6)
            stroke(secCard, 1, "Border")

            local headBtn = Instance.new("TextButton", secCard)
            headBtn.Size                   = UDim2.new(1, 0, 0, secDesc and 40 or 32)
            headBtn.BackgroundTransparency = 1
            headBtn.BorderSizePixel        = 0
            headBtn.Text                   = ""
            headBtn.LayoutOrder            = -999
            headBtn.ZIndex                 = 6

            if secDesc and secDesc ~= "" then
                label(headBtn, { size = UDim2.new(1, -30, 0, 20), pos = UDim2.new(0, 12, 0, 4), text = secName, fontType = "Bold", ts = 13, theme = "Text", z = 7 })
                label(headBtn, { size = UDim2.new(1, -30, 0, 16), pos = UDim2.new(0, 12, 0, 22), text = secDesc, fontType = "Medium", ts = 10, theme = "TextDim", z = 7 })
            else
                label(headBtn, { size = UDim2.new(1, -30, 1, 0), pos = UDim2.new(0, 12, 0, 0), text = secName, fontType = "Bold", ts = 13, theme = "Text", z = 7 })
            end

            local arrow = label(headBtn, { size = UDim2.new(0, 20, 1, 0), pos = UDim2.new(1, -24, 0, 0), text = defaultOpen and "^" or "v", fontType = "Bold", ts = 11, theme = "TextDim", ax = Enum.TextXAlignment.Center, z = 7 })

            local contentContainer = Instance.new("Frame", secCard)
            contentContainer.Size                   = UDim2.new(1, 0, 0, 0)
            contentContainer.AutomaticSize          = Enum.AutomaticSize.Y
            contentContainer.BackgroundTransparency = 1
            contentContainer.BorderSizePixel        = 0
            contentContainer.LayoutOrder            = 1
            contentContainer.Visible                = defaultOpen
            contentContainer.ZIndex                 = 6

            local cPad = Instance.new("UIPadding", contentContainer)
            cPad.PaddingLeft   = UDim.new(0, 12)
            cPad.PaddingRight  = UDim.new(0, 12)
            cPad.PaddingTop    = UDim.new(0, 4)
            cPad.PaddingBottom = UDim.new(0, 10)

            local cLayout = Instance.new("UIListLayout", contentContainer)
            cLayout.SortOrder = Enum.SortOrder.LayoutOrder
            cLayout.Padding   = UDim.new(0, 8)

            local isOpen = defaultOpen
            headBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                arrow.Text = isOpen and "^" or "v"
                contentContainer.Visible = isOpen
                if isOpen then
                    secCard.Size = UDim2.new(1, 0, 0, 0)
                    secCard.AutomaticSize = Enum.AutomaticSize.Y
                else
                    secCard.AutomaticSize = Enum.AutomaticSize.None
                    secCard.Size = UDim2.new(1, 0, 0, secDesc and 40 or 32)
                end
            end)

            local secObj = TabObj:AddSection("", contentContainer)
            secObj.Card  = secCard
            return secObj
        end

        function TabObj:AddColumns()
            TabObj.SectionCount = TabObj.SectionCount + 1

            local gridFrame = Instance.new("Frame", page)
            gridFrame.Size                   = UDim2.new(1, 0, 0, 0)
            gridFrame.AutomaticSize          = Enum.AutomaticSize.Y
            gridFrame.BackgroundTransparency = 1
            gridFrame.BorderSizePixel        = 0
            gridFrame.LayoutOrder            = TabObj.SectionCount
            gridFrame.ZIndex                 = 5

            local leftCol = Instance.new("Frame", gridFrame)
            leftCol.Size                   = UDim2.new(0.49, 0, 0, 0)
            leftCol.Position               = UDim2.new(0, 0, 0, 0)
            leftCol.AutomaticSize          = Enum.AutomaticSize.Y
            leftCol.BackgroundTransparency = 1
            leftCol.BorderSizePixel        = 0
            leftCol.ZIndex                 = 5

            local lLayout = Instance.new("UIListLayout", leftCol)
            lLayout.SortOrder = Enum.SortOrder.LayoutOrder
            lLayout.Padding   = UDim.new(0, 10)

            local rightCol = Instance.new("Frame", gridFrame)
            rightCol.Size                   = UDim2.new(0.49, 0, 0, 0)
            rightCol.Position               = UDim2.new(0.51, 0, 0, 0)
            rightCol.AutomaticSize          = Enum.AutomaticSize.Y
            rightCol.BackgroundTransparency = 1
            rightCol.BorderSizePixel        = 0
            rightCol.ZIndex                 = 5

            local rLayout = Instance.new("UIListLayout", rightCol)
            rLayout.SortOrder = Enum.SortOrder.LayoutOrder
            rLayout.Padding   = UDim.new(0, 10)

            local LeftTabObj = { Page = leftCol, SectionCount = 0 }
            LeftTabObj.AddSection = function(self, secName) return TabObj:AddSection(secName, leftCol) end
            LeftTabObj.AddCollapsibleSection = function(self, opts) return TabObj:AddCollapsibleSection(opts, leftCol) end

            local RightTabObj = { Page = rightCol, SectionCount = 0 }
            RightTabObj.AddSection = function(self, secName) return TabObj:AddSection(secName, rightCol) end
            RightTabObj.AddCollapsibleSection = function(self, opts) return TabObj:AddCollapsibleSection(opts, rightCol) end

            return LeftTabObj, RightTabObj
        end

        function TabObj:AddSubTabs(subTabNames, mode)
            mode = mode or "Dropdown"
            TabObj.SectionCount = TabObj.SectionCount + 1

            local subContainer = Instance.new("Frame", page)
            subContainer.Size                   = UDim2.new(1, 0, 0, 0)
            subContainer.AutomaticSize          = Enum.AutomaticSize.Y
            subContainer.BackgroundTransparency = 1
            subContainer.BorderSizePixel        = 0
            subContainer.LayoutOrder            = TabObj.SectionCount
            subContainer.ZIndex                 = 5

            local subPages = {}
            local subTabObjs = {}

            local proxyNav = { Page = subContainer, SectionCount = 0 }
            proxyNav.AddSection = function(self, secName) return TabObj:AddSection(secName, subContainer) end

            if mode == "Dropdown" then
                local selectorSection = proxyNav:AddSection("Sub Navigation")
                local drop = selectorSection:AddDropdown({
                    Name = "Select View",
                    Options = subTabNames,
                    Default = subTabNames[1],
                    Callback = function(selected)
                        for name, subP in pairs(subPages) do
                            subP.Visible = (name == selected)
                        end
                    end
                })
            end

            for idx, sName in ipairs(subTabNames) do
                local subPage = Instance.new("Frame", subContainer)
                subPage.Name                   = "SubPage_" .. sName
                subPage.Size                   = UDim2.new(1, 0, 0, 0)
                subPage.AutomaticSize          = Enum.AutomaticSize.Y
                subPage.BackgroundTransparency = 1
                subPage.BorderSizePixel        = 0
                subPage.Visible                = (idx == 1)
                subPage.ZIndex                 = 5

                local sLayout = Instance.new("UIListLayout", subPage)
                sLayout.SortOrder = Enum.SortOrder.LayoutOrder
                sLayout.Padding   = UDim.new(0, 10)

                subPages[sName] = subPage

                local subTabObj = { Page = subPage, SectionCount = 0 }
                subTabObj.AddSection = function(self, secName) return TabObj:AddSection(secName, subPage) end
                subTabObj.AddCollapsibleSection = function(self, opts) return TabObj:AddCollapsibleSection(opts, subPage) end
                subTabObjs[sName] = subTabObj
            end

            return subTabObjs
        end

        return TabObj
    end

    local function buildSettingsTab()
        if WindowObj._settingsTabObj then return end
        local sep = WindowObj:AddSeparator()
        sep.LayoutOrder = 9997
        local secLbl = WindowObj:AddSectionLabel("OTHER")
        secLbl.LayoutOrder = 9998
        local settingsTab = WindowObj:AddTab({ Name = "Settings", Icon = Library.Icons.Gear })
        settingsTab.Btn.LayoutOrder = 9999
        WindowObj._settingsTabObj = settingsTab

        -- Section 1: Theme & Unload Controls
        local themeSec = settingsTab:AddCollapsibleSection({
            Name = "Theme & Unload",
            Desc = "Manage color presets, configs, and UI lifecycle",
            DefaultOpen = true
        })

        themeSec:AddDropdown({
            Name = "Theme Preset",
            Options = { "Dark", "Darker", "Light", "Aqua", "Amethyst", "Rose" },
            Default = Library.Theme or "Dark",
            Callback = function(themeName)
                Library:SetTheme(themeName)
            end
        })

        themeSec:AddButton({
            Name = "Save Config",
            Desc = "Save current element states to file",
            Callback = function()
                Library:SaveConfig()
                Library:Notify({ Title = "Settings", Content = "Configuration saved successfully!", Duration = 3 })
            end
        })

        themeSec:AddButton({
            Name = "Reset Config",
            Desc = "Reset all element states to defaults",
            Callback = function()
                Library:ResetConfig()
                Library:Notify({ Title = "Settings", Content = "Configuration reset to default!", Duration = 3 })
            end
        })

        themeSec:AddButton({
            Name = "Unload Script",
            Desc = "Stops all script activities and destroys UI",
            Callback = function()
                Library:Dialog({
                    Title = "Unload Script?",
                    Content = "Are you sure you want to unload the script and destroy the interface?",
                    Buttons = {
                        { Title = "Cancel", Callback = function() end },
                        { Title = "Unload", Callback = function() Library:Destroy() end }
                    }
                })
            end
        })

        -- Section 2: Custom Appearance & Fluent RGB/HSV ColorPicker
        local apSec = settingsTab:AddCollapsibleSection({
            Name = "Appearance Colors",
            Desc = "Fine-tune individual color groups with RGB sliders and preview",
            DefaultOpen = true
        })

        local appearancePage = apSec.Card

        local apSegFrame = Instance.new("Frame", appearancePage)
        apSegFrame.Size = UDim2.new(1, 0, 0, 32)
        apSegFrame.BorderSizePixel = 0
        apSegFrame.LayoutOrder = 1
        apSegFrame.ZIndex = 5
        registerTheme(apSegFrame, "BackgroundColor3", "Panel")
        corner(apSegFrame, 6)
        local apSegStroke = Instance.new("UIStroke", apSegFrame)
        apSegStroke.Thickness = 1
        apSegStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        registerTheme(apSegStroke, "Color", "Border")

        local apSegInner = Instance.new("Frame", apSegFrame)
        apSegInner.Size = UDim2.new(1, -4, 1, -4)
        apSegInner.Position = UDim2.new(0, 2, 0, 2)
        apSegInner.BackgroundTransparency = 1
        apSegInner.ZIndex = 6

        local apSegLayout = Instance.new("UIListLayout", apSegInner)
        apSegLayout.FillDirection = Enum.FillDirection.Horizontal
        apSegLayout.Padding = UDim.new(0, 2)
        apSegLayout.VerticalAlignment = Enum.VerticalAlignment.Center

        local activeGroup = "Accent"
        local groupBtns   = {}
        local apGroups = {
            { Key = "Accent",     Label = "Accent" },
            { Key = "Background", Label = "Background" },
            { Key = "Panel",      Label = "Panels" },
            { Key = "Text",       Label = "Text" },
        }

        local sliderRed, sliderGreen, sliderBlue
        local hexLabel, previewSwatch

        local function toHex(c)
            return string.format("#%02X%02X%02X", math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
        end

        local function updateSegBtns(key)
            for k, b in pairs(groupBtns) do
                if k == key then
                    b.BackgroundTransparency = 0
                    b.BackgroundColor3 = Theme.Elevated
                    twQ(b, 0.12, { TextColor3 = Theme.Text })
                else
                    b.BackgroundTransparency = 1
                    twQ(b, 0.12, { TextColor3 = Theme.TextDim })
                end
            end
        end

        local function updateSlidersFromGroup(key)
            activeGroup = key
            local c = Theme[key] or Color3.new(1, 1, 1)
            local r, g, b = math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)
            if sliderRed   then sliderRed.setValue(r)   end
            if sliderGreen then sliderGreen.setValue(g) end
            if sliderBlue  then sliderBlue.setValue(b)  end
            if previewSwatch then previewSwatch.BackgroundColor3 = c end
            if hexLabel then hexLabel.Text = toHex(c) end
            updateSegBtns(key)
        end

        for _, g in ipairs(apGroups) do
            local gb = Instance.new("TextButton", apSegInner)
            gb.Size = UDim2.new(0.25, -2, 1, 0)
            gb.BackgroundTransparency = 1
            gb.BackgroundColor3 = Theme.Elevated
            gb.BorderSizePixel = 0
            gb.Text = g.Label
            applyFont(gb, "Bold")
            gb.TextSize = 13
            gb.ZIndex = 7
            registerTheme(gb, "TextColor3", "TextDim")
            corner(gb, 4)
            groupBtns[g.Key] = gb
            gb.MouseButton1Click:Connect(function() updateSlidersFromGroup(g.Key) end)
        end

        -- Preview + hex row
        local apPreviewRow = Instance.new("Frame", appearancePage)
        apPreviewRow.Size = UDim2.new(1, 0, 0, 28)
        apPreviewRow.BackgroundTransparency = 1
        apPreviewRow.LayoutOrder = 2
        apPreviewRow.ZIndex = 5

        lbl(apPreviewRow, { size = UDim2.new(1, -100, 1, 0), pos = UDim2.new(0, 12, 0, 0), text = "Color Swatch", fontType = "Bold", ts = 10, theme = "TextDim", z = 5 })

        previewSwatch = Instance.new("Frame", apPreviewRow)
        previewSwatch.Size = UDim2.new(0, 18, 0, 18)
        previewSwatch.Position = UDim2.new(1, -80, 0.5, -9)
        previewSwatch.BorderSizePixel = 0
        previewSwatch.ZIndex = 6
        previewSwatch.BackgroundColor3 = Theme.Accent
        corner(previewSwatch, 4)

        hexLabel = lbl(apPreviewRow, { size = UDim2.new(0, 58, 1, 0), pos = UDim2.new(1, -58, 0, 0), text = toHex(Theme.Accent), fontType = "Medium", ts = 10, theme = "TextDim", ax = Enum.TextXAlignment.Right, z = 5 })

        -- Sliders container
        local apSlidersFrame = Instance.new("Frame", appearancePage)
        apSlidersFrame.Size = UDim2.new(1, 0, 0, 130)
        apSlidersFrame.BorderSizePixel = 0
        apSlidersFrame.LayoutOrder = 3
        apSlidersFrame.ZIndex = 5
        registerTheme(apSlidersFrame, "BackgroundColor3", "Panel")
        corner(apSlidersFrame, 6)
        local apSF_stroke = Instance.new("UIStroke", apSlidersFrame)
        apSF_stroke.Thickness = 1
        apSF_stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        registerTheme(apSF_stroke, "Color", "Border")
        local apSFPad = Instance.new("UIPadding", apSlidersFrame)
        apSFPad.PaddingLeft = UDim.new(0, 14)
        apSFPad.PaddingRight = UDim.new(0, 14)
        apSFPad.PaddingTop = UDim.new(0, 8)
        apSFPad.PaddingBottom = UDim.new(0, 8)

        local function makeColorSlider(parent, labelText, posY, initVal, trackColor, onChange)
            local row = Instance.new("Frame", parent)
            row.Size = UDim2.new(1, 0, 0, 34)
            row.Position = UDim2.new(0, 0, 0, posY)
            row.BackgroundTransparency = 1
            row.ZIndex = 6

            lbl(row, { size = UDim2.new(0, 14, 0, 14), pos = UDim2.new(0, 0, 0, 0), text = labelText, fontType = "Bold", ts = 11, color = trackColor, z = 7 })
            local valLbl = lbl(row, { size = UDim2.new(0, 28, 0, 14), pos = UDim2.new(1, -28, 0, 0), text = tostring(initVal), fontType = "Medium", ts = 10, theme = "TextDim", ax = Enum.TextXAlignment.Right, z = 7 })

            local trackBg = Instance.new("TextButton", row)
            trackBg.Size = UDim2.new(1, 0, 0, 6)
            trackBg.Position = UDim2.new(0, 0, 0, 18)
            trackBg.BorderSizePixel = 0
            trackBg.Text = ""
            trackBg.ZIndex = 7
            registerTheme(trackBg, "BackgroundColor3", "Elevated")
            corner(trackBg, 3)

            local fill = Instance.new("Frame", trackBg)
            fill.Size = UDim2.new(initVal/255, 0, 1, 0)
            fill.BorderSizePixel = 0
            fill.BackgroundColor3 = trackColor
            fill.ZIndex = 8
            corner(fill, 3)

            local thumb = Instance.new("Frame", trackBg)
            thumb.Size = UDim2.new(0, 11, 0, 11)
            thumb.AnchorPoint = Vector2.new(0.5, 0.5)
            thumb.Position = UDim2.new(initVal/255, 0, 0.5, 0)
            thumb.BackgroundColor3 = Color3.fromRGB(225, 225, 235)
            thumb.BorderSizePixel = 0
            thumb.ZIndex = 9
            corner(thumb, 6)

            local sliding = false
            local obj = { value = initVal }

            local function update(px)
                local rel = math.clamp((px - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
                local v = math.floor(rel * 255)
                obj.value = v
                fill.Size = UDim2.new(rel, 0, 1, 0)
                thumb.Position = UDim2.new(rel, 0, 0.5, 0)
                valLbl.Text = tostring(v)
                onChange(v)
            end
            obj.setValue = function(v)
                obj.value = v
                local rel = math.clamp(v/255, 0, 1)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                thumb.Position = UDim2.new(rel, 0, 0.5, 0)
                valLbl.Text = tostring(v)
            end

            local sliderConns = {}
            table.insert(sliderConns, trackBg.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    sliding = true
                    update(i.Position.X)
                end
            end))

            table.insert(sliderConns, UserInputService.InputChanged:Connect(function(i)
                if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                    update(i.Position.X)
                end
            end))

            table.insert(sliderConns, UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                    sliding = false
                end
            end))

            row.Destroying:Connect(function()
                for _, conn in ipairs(sliderConns) do pcall(function() conn:Disconnect() end) end
                sliderConns = {}
            end)

            return obj
        end

        local function applyRGB()
            local r = sliderRed   and sliderRed.value   or 0
            local g = sliderGreen and sliderGreen.value or 0
            local b = sliderBlue  and sliderBlue.value  or 0
            local c = Color3.fromRGB(r, g, b)
            updateTheme(activeGroup, c)

            if not ThemePresets["Custom"] then
                ThemePresets["Custom"] = {}
                for k, v in pairs(ThemePresets["Dark"]) do
                    ThemePresets["Custom"][k] = v
                end
            end
            ThemePresets["Custom"][activeGroup] = c
            Library.Theme = "Custom"

            if previewSwatch then previewSwatch.BackgroundColor3 = c end
            if hexLabel then hexLabel.Text = toHex(c) end
            if activeGroup == "Accent" and miniIcon then miniIcon.BackgroundColor3 = c end
        end

        sliderRed   = makeColorSlider(apSlidersFrame, "R", 2,  math.floor(Theme.Accent.R*255), Color3.fromRGB(220, 70, 70),  function() applyRGB() end)
        sliderGreen = makeColorSlider(apSlidersFrame, "G", 38, math.floor(Theme.Accent.G*255), Color3.fromRGB(50, 180, 110), function() applyRGB() end)
        sliderBlue  = makeColorSlider(apSlidersFrame, "B", 74, math.floor(Theme.Accent.B*255), Color3.fromRGB(70, 130, 220), function() applyRGB() end)

        updateSlidersFromGroup("Accent")
    end

    buildSettingsTab()

    settingsBtn.MouseButton1Click:Connect(function()
        if WindowObj._settingsTabObj then
            selectTab(WindowObj._settingsTabObj)
        end
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
    self.Options  = {}
    self.Elements = {}
    fontRegistry  = {}
    themeRegistry = {}
end

if getgenv then
    getgenv().MDuiLib = Library
end

return Library
