for _, gui in pairs(game.CoreGui:GetChildren()) do
    if gui.Name:find("QWEN") then pcall(function() gui:Destroy() end) end
end
if game:GetService("Lighting"):FindFirstChild("QWENBlur") then
    game:GetService("Lighting").QWENBlur:Destroy()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Camera = workspace.CurrentCamera

local Running = true
local MenuOpen = false
local StartTime = os.time()
local blurEffect = nil
local isWaitingForKey = false
local MenuToggleKey = "Delete"

local State = {
    Speed=16, JumpPower=50, FlySpeed=50,
    TpTool=false, Noclip=false, Fly=false,
    ESP=false, FlingDuration=3,
}

local ToggleStateMap = {
    ["TP Tool"]="TpTool", ["Noclip"]="Noclip",
    ["Fly"]="Fly", ["ESP Players"]="ESP",
}

local SAVE_KEY = "QWENv10"
local Binds = {}
local bindLabels = {}
local allConnections = {}
local toggleCallbacks = {}
local toggleSetters = {}
local activeBindIndicators = {}

local noclipConnection = nil
local flyBV, flyBG, flyConnection = nil, nil, nil
local espHighlights = {}
local espBillboards = {}
local tpToolConnection = nil

local fpsValue = 60
local fpsFrameCount = 0
local fpsLastTime = tick()
local activeSliderDrag = nil

local FlingActive = false
local SelectedFlingTargets = {}
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local voidActive = false
local voidConnection = nil
local voidYOffset = -150
local voidTargetY = nil
local voidSavedPos = nil

local ADMIN_GROUP_ID = 367140785
local ADMIN_MIN_RANK = 249
local ADMIN_MAX_RANK = 255
local AdminCache = {}
local AdminAlertEnabled = true
local AdminESPEnabled = true

local snowParticles = {}
local snowEnabled = true

local HUD_POS_KEY = "QWENHUDPos"
local BINDBOX_POS_KEY = "QWENBindBoxPos"
local ADMINWIN_POS_KEY = "QWENAdminWinPos"

-- Teleport State
local selectedTeleportPlayers = {}
local teleportLoopEnabled = false
local teleportLoopConnection = nil

local THEME = {
    primary        = Color3.fromRGB(0, 0, 0),
    primaryDark    = Color3.fromRGB(0, 0, 0),
    primaryLight   = Color3.fromRGB(0, 0, 0),
    accent         = Color3.fromRGB(0, 0, 0),
    text           = Color3.fromRGB(255, 255, 255),
    textDim        = Color3.fromRGB(156, 163, 175),
    textMuted      = Color3.fromRGB(107, 114, 128),
    background     = Color3.fromRGB(12, 12, 16),
    backgroundLight  = Color3.fromRGB(18, 18, 24),
    backgroundLighter= Color3.fromRGB(26, 26, 32),
    border         = Color3.fromRGB(40, 40, 50),
    success        = Color3.fromRGB(34, 197, 94),
    danger         = Color3.fromRGB(239, 68, 68),
    warning        = Color3.fromRGB(185, 148, 55),
    graphFill      = Color3.fromRGB(0, 0, 0),
}

local themedElements = {}
local state_theme = { themeHue=0, themeSat=0, themeVal=0 }

local function trackTheme(obj, prop, themeKey)
    table.insert(themedElements, {obj=obj, prop=prop, themeKey=themeKey})
end

local function updateThemeColors()
    local h, s, v = state_theme.themeHue, state_theme.themeSat, state_theme.themeVal
    THEME.primary      = Color3.fromHSV(h, s, v)
    THEME.primaryDark  = Color3.fromHSV(h, math.min(s+0.07,1), math.max(v-0.16,0))
    THEME.primaryLight = Color3.fromHSV(h, math.max(s-0.35,0), math.min(v+0.03,1))
    THEME.accent       = Color3.fromHSV(h, math.max(s-0.13,0), math.max(v-0.01,0))
    THEME.graphFill    = Color3.fromHSV(h, math.max(s-0.01,0), math.max(v-0.05,0))
    for _, e in ipairs(themedElements) do
        if e.obj and e.obj.Parent then
            pcall(function() e.obj[e.prop] = THEME[e.themeKey] end)
        end
    end
end

local function Corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end
local function Stroke(p, col, t, trans)
    local s = Instance.new("UIStroke")
    s.Color = col or THEME.border
    s.Thickness = t or 1
    s.Transparency = trans or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end
local function Tween(o, pr, d, style, dir)
    if not o or not o.Parent then return end
    pcall(function()
        TS:Create(o, TweenInfo.new(d or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), pr):Play()
    end)
end
local function Smooth(o, pr, d) Tween(o, pr, d or 0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) end
local function GetHRP() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function FormatTime(s) return string.format("%02d:%02d:%02d", math.floor(s/3600), math.floor((s%3600)/60), s%60) end

local function SetBlur(size)
    if not blurEffect then
        blurEffect = Instance.new("BlurEffect")
        blurEffect.Name = "QWENBlur"
        blurEffect.Size = 0
        blurEffect.Parent = Lighting
    end
    Tween(blurEffect, {Size=size}, 0.3)
end
local function RemoveBlur()
    if blurEffect then
        Tween(blurEffect, {Size=0}, 0.25)
        task.delay(0.3, function()
            if blurEffect then blurEffect:Destroy() end
            blurEffect = nil
        end)
    end
end

local function SaveSettings()
    local data = {}
    for k, v in pairs(State) do data[k] = v end
    data.Binds = Binds
    data.AdminAlertEnabled = AdminAlertEnabled
    data.AdminESPEnabled = AdminESPEnabled
    data.MenuToggleKey = MenuToggleKey
    data.themeHue = state_theme.themeHue
    data.themeSat = state_theme.themeSat
    data.themeVal = state_theme.themeVal
    data.snowEnabled = snowEnabled
    pcall(function() writefile(SAVE_KEY..".json", HttpService:JSONEncode(data)) end)
end

local function SaveHUDPos(pos)
    pcall(function() writefile(HUD_POS_KEY..".json", HttpService:JSONEncode({x=pos.X.Scale, xo=pos.X.Offset, y=pos.Y.Scale, yo=pos.Y.Offset})) end)
end
local function LoadHUDPos()
    local ok, r = pcall(function()
        if isfile and isfile(HUD_POS_KEY..".json") then
            return HttpService:JSONDecode(readfile(HUD_POS_KEY..".json"))
        end
    end)
    if ok and r then return UDim2.new(r.x or 0, r.xo or 12, r.y or 0, r.yo or 12) end
    return UDim2.new(0, 12, 0, 12)
end

local function SaveBindBoxPos(pos)
    pcall(function() writefile(BINDBOX_POS_KEY..".json", HttpService:JSONEncode({x=pos.X.Scale, xo=pos.X.Offset, y=pos.Y.Scale, yo=pos.Y.Offset})) end)
end
local function LoadBindBoxPos()
    local ok, r = pcall(function()
        if isfile and isfile(BINDBOX_POS_KEY..".json") then
            return HttpService:JSONDecode(readfile(BINDBOX_POS_KEY..".json"))
        end
    end)
    if ok and r then return UDim2.new(r.x or 1, r.xo or -176, r.y or 0.5, r.yo or -60) end
    return UDim2.new(1, -176, 0.5, -60)
end

local function SaveAdminWinPos(pos)
    pcall(function() writefile(ADMINWIN_POS_KEY..".json", HttpService:JSONEncode({x=pos.X.Scale, xo=pos.X.Offset, y=pos.Y.Scale, yo=pos.Y.Offset})) end)
end
local function LoadAdminWinPos()
    local ok, r = pcall(function()
        if isfile and isfile(ADMINWIN_POS_KEY..".json") then
            return HttpService:JSONDecode(readfile(ADMINWIN_POS_KEY..".json"))
        end
    end)
    if ok and r then return UDim2.new(r.x or 0, r.xo or 12, r.y or 0, r.yo or 120) end
    return UDim2.new(0, 12, 0, 120)
end

local function LoadSettings()
    local ok, r = pcall(function()
        if isfile and isfile(SAVE_KEY..".json") then
            return HttpService:JSONDecode(readfile(SAVE_KEY..".json"))
        end
    end)
    if ok and r then
        for k, v in pairs(r) do
            if k == "Binds" then if type(v)=="table" then Binds=v end
            elseif k == "AdminAlertEnabled" then AdminAlertEnabled=v
            elseif k == "AdminESPEnabled" then AdminESPEnabled=v
            elseif k == "MenuToggleKey" then MenuToggleKey=v
            elseif k == "themeHue" then state_theme.themeHue=v
            elseif k == "themeSat" then state_theme.themeSat=v
            elseif k == "themeVal" then state_theme.themeVal=v
            elseif k == "snowEnabled" then snowEnabled=v
            elseif State[k] ~= nil then State[k]=v end
        end
    end
end
LoadSettings()

table.insert(allConnections, RS.RenderStepped:Connect(function()
    fpsFrameCount += 1
    local now = tick()
    if now - fpsLastTime >= 1 then
        fpsValue = math.floor(fpsFrameCount / (now - fpsLastTime))
        fpsFrameCount = 0
        fpsLastTime = now
    end
end))

local function CheckIfAdmin(p)
    if AdminCache[p.UserId] ~= nil then
        return AdminCache[p.UserId].IsAdmin, AdminCache[p.UserId].Rank
    end
    local s, r = pcall(function() return p:GetRankInGroup(ADMIN_GROUP_ID) end)
    local a = s and r >= ADMIN_MIN_RANK and r <= ADMIN_MAX_RANK
    AdminCache[p.UserId] = {IsAdmin=a, Rank=r or 0}
    return a, r or 0
end

-- NOTIFICATIONS
local NOTIF_WIDTH = 280
local NOTIF_HEIGHT = 44
local NOTIF_GAP = 6
local NOTIF_BOTTOM_OFFSET = 70
local MAX_NOTIFICATIONS = 6

local NotifSG = Instance.new("ScreenGui")
NotifSG.Name = "QWENNotif"
NotifSG.Parent = game.CoreGui
NotifSG.ResetOnSpawn = false
NotifSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local NotifContainer = Instance.new("Frame")
NotifContainer.Size = UDim2.new(0, NOTIF_WIDTH + 20, 1, 0)
NotifContainer.Position = UDim2.new(1, -(NOTIF_WIDTH + 20), 0, 0)
NotifContainer.BackgroundTransparency = 1
NotifContainer.ZIndex = 10000
NotifContainer.ClipsDescendants = false
NotifContainer.Parent = NotifSG

local notificationStack = {}

local function repositionNotifications()
    for i, nd in ipairs(notificationStack) do
        if nd.frame and nd.frame.Parent and NotifContainer then
            local targetY = 1 - ((NOTIF_BOTTOM_OFFSET + i * (NOTIF_HEIGHT + NOTIF_GAP)) / NotifContainer.AbsoluteSize.Y)
            TS:Create(nd.frame, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, targetY, 0)
            }):Play()
        end
    end
end

local function removeNotification(notifData)
    for i, nd in ipairs(notificationStack) do
        if nd == notifData then table.remove(notificationStack, i) break end
    end
    if notifData.frame and notifData.frame.Parent then
        local tw = TS:Create(notifData.frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 20, notifData.frame.Position.Y.Scale, 0)
        })
        tw:Play()
        tw.Completed:Connect(function()
            if notifData.frame and notifData.frame.Parent then notifData.frame:Destroy() end
        end)
    end
    task.delay(0.05, repositionNotifications)
end

local function Notify(title, message, duration, nType)
    duration = duration or 3
    nType = nType or "info"
    local barColor = THEME.textDim
    if nType == "success" then barColor = THEME.success
    elseif nType == "error" then barColor = THEME.danger
    elseif nType == "warning" then barColor = THEME.warning
    elseif nType == "admin" then barColor = Color3.fromRGB(185, 148, 55)
    elseif nType == "info" then barColor = Color3.fromRGB(99, 179, 237) end

    if #notificationStack >= MAX_NOTIFICATIONS then
        removeNotification(notificationStack[#notificationStack])
    end

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, NOTIF_HEIGHT)
    notif.Position = UDim2.new(1, 20, 1, -NOTIF_HEIGHT)
    notif.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    notif.BorderSizePixel = 0
    notif.ZIndex = 10001
    notif.Parent = NotifContainer
    Corner(notif, 8)

    local ns = Instance.new("UIStroke")
    ns.Thickness = 1; ns.Color = barColor; ns.Transparency = 0.3; ns.Parent = notif

    local ab = Instance.new("Frame")
    ab.Size = UDim2.new(0, 3, 0.7, 0)
    ab.Position = UDim2.new(0, 0, 0.15, 0)
    ab.BackgroundColor3 = barColor
    ab.BorderSizePixel = 0; ab.ZIndex = 10002; ab.Parent = notif
    Corner(ab, 2)

    local ic = Instance.new("Frame")
    ic.Size = UDim2.new(0, 20, 0, 20)
    ic.Position = UDim2.new(0, 12, 0.5, -10)
    ic.BackgroundColor3 = barColor
    ic.BorderSizePixel = 0; ic.ZIndex = 10003; ic.Parent = notif
    Corner(ic, 10)

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -42, 0, 14)
    titleL.Position = UDim2.new(0, 38, 0, 6)
    titleL.BackgroundTransparency = 1
    titleL.Font = Enum.Font.GothamBold
    titleL.Text = title or "Notification"
    titleL.TextColor3 = Color3.new(1,1,1)
    titleL.TextSize = 11
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.ZIndex = 10003; titleL.Parent = notif

    local msgL = Instance.new("TextLabel")
    msgL.Size = UDim2.new(1, -42, 0, 12)
    msgL.Position = UDim2.new(0, 38, 0, 22)
    msgL.BackgroundTransparency = 1
    msgL.Font = Enum.Font.Gotham
    msgL.Text = message or ""
    msgL.TextColor3 = Color3.fromRGB(156, 163, 175)
    msgL.TextSize = 9
    msgL.TextXAlignment = Enum.TextXAlignment.Left
    msgL.TextTruncate = Enum.TextTruncate.AtEnd
    msgL.ZIndex = 10003; msgL.Parent = notif

    local nd = {frame = notif, time = tick()}
    table.insert(notificationStack, 1, nd)
    repositionNotifications()

    task.delay(0.05, function()
        if notif and notif.Parent then
            TS:Create(notif, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, notif.Position.Y.Scale, 0)
            }):Play()
        end
    end)
    task.delay(duration, function() removeNotification(nd) end)
end

local function ApplySpeed()
    local h = GetHum()
    if h then
        h.WalkSpeed = State.Speed
        h.JumpPower = State.JumpPower
    end
end

local function StartNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection = RS.Stepped:Connect(function()
        local c = LP.Character
        if c then
            for _, p in pairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
    table.insert(allConnections, noclipConnection)
end
local function StopNoclip()
    if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
end

local function StartFly()
    local c = LP.Character; if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if not State.Noclip then StartNoclip() end
    if flyBV then pcall(function() flyBV:Destroy() end) end
    if flyBG then pcall(function() flyBG:Destroy() end) end
    if flyConnection then pcall(function() flyConnection:Disconnect() end) end
    flyBV = Instance.new("BodyVelocity"); flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge); flyBV.Velocity = Vector3.zero; flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro"); flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); flyBG.D = 200; flyBG.P = 10000; flyBG.Parent = hrp
    flyConnection = RS.RenderStepped:Connect(function()
        if not State.Fly or not hrp or not hrp.Parent then
            if flyConnection then flyConnection:Disconnect(); flyConnection = nil end; return
        end
        flyBG.CFrame = Camera.CFrame
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then dir = dir.Unit end
        flyBV.Velocity = dir * State.FlySpeed
    end)
    table.insert(allConnections, flyConnection)
end
local function StopFly()
    if flyBV then pcall(function() flyBV:Destroy() end); flyBV = nil end
    if flyBG then pcall(function() flyBG:Destroy() end); flyBG = nil end
    if flyConnection then pcall(function() flyConnection:Disconnect() end); flyConnection = nil end
    if not State.Noclip then StopNoclip() end
end

local function ClearESP()
    for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end; espHighlights = {}
    for _, b in pairs(espBillboards) do pcall(function() b:Destroy() end) end; espBillboards = {}
end
local function UpdateESP()
    ClearESP(); if not State.ESP then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LP and player.Character then
            local char = player.Character
            local head = char:FindFirstChild("Head")
            local isAdmin = CheckIfAdmin(player)
            local espColor = (isAdmin and AdminESPEnabled) and Color3.fromRGB(185,148,55) or THEME.accent
            local hl = Instance.new("Highlight"); hl.Adornee = char; hl.FillColor = espColor
            hl.FillTransparency = 0.82; hl.OutlineColor = espColor; hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = char
            table.insert(espHighlights, hl)
            if head then
                local bb = Instance.new("BillboardGui"); bb.Name = "QWEN_ESP"; bb.Adornee = head
                bb.Size = UDim2.new(0, 160, 0, 36); bb.StudsOffset = Vector3.new(0, 2.5, 0)
                bb.AlwaysOnTop = true; bb.MaxDistance = 1000; bb.Parent = head
                local nL = Instance.new("TextLabel"); nL.Size = UDim2.new(1,0,0.55,0); nL.BackgroundTransparency = 1
                nL.Font = Enum.Font.GothamBold; nL.Text = player.DisplayName; nL.TextColor3 = espColor; nL.TextSize = 13
                nL.TextStrokeColor3 = Color3.new(0,0,0); nL.TextStrokeTransparency = 0.3; nL.Parent = bb
                local uL = Instance.new("TextLabel"); uL.Size = UDim2.new(1,0,0.35,0); uL.Position = UDim2.new(0,0,0.55,0)
                uL.BackgroundTransparency = 1; uL.Font = Enum.Font.Gotham
                uL.Text = "@"..player.Name
                uL.TextColor3 = THEME.textDim; uL.TextSize = 10; uL.TextStrokeColor3 = Color3.new(0,0,0); uL.TextStrokeTransparency = 0.4; uL.Parent = bb
                table.insert(espBillboards, bb)
            end
        end
    end
end
task.spawn(function() while Running do if State.ESP then pcall(UpdateESP) end; task.wait(3) end end)

local UpdateVoidStatus = function() end

local function FindLowestY()
    local lowestY = math.huge
    pcall(function()
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(LP.Character or Instance.new("Folder")) then
                local y = obj.Position.Y - obj.Size.Y/2
                if y < lowestY then lowestY = y end
            end
        end
    end)
    if lowestY == math.huge then lowestY = 0 end
    return lowestY
end

local function StartVoid()
    if voidActive then return end
    local hrp = GetHRP(); if not hrp then Notify("Void", "No character", 2, "error"); return end
    voidSavedPos = hrp.CFrame
    local lowestY = FindLowestY(); voidTargetY = lowestY + voidYOffset
    pcall(function() workspace.FallenPartsDestroyHeight = -1e9 end)
    hrp.CFrame = CFrame.new(hrp.Position.X, voidTargetY, hrp.Position.Z); hrp.Velocity = Vector3.zero; voidActive = true
    if voidConnection then pcall(function() voidConnection:Disconnect() end) end
    voidConnection = RS.Heartbeat:Connect(function()
        if not voidActive or not Running then if voidConnection then voidConnection:Disconnect(); voidConnection = nil end; return end
        local h = GetHRP(); if h then
            h.CFrame = CFrame.new(h.Position.X, voidTargetY, h.Position.Z) * CFrame.Angles(0, math.rad(h.Orientation.Y), 0)
            h.Velocity = Vector3.new(h.Velocity.X*0.5, 0, h.Velocity.Z*0.5); h.RotVelocity = Vector3.zero
            local ch = LP.Character; if ch then for _, p in pairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
        end
    end)
    table.insert(allConnections, voidConnection)
    Notify("Void", "Under map", 2, "info"); UpdateVoidStatus()
end

local function StopVoid()
    if not voidActive then return end; voidActive = false
    if voidConnection then pcall(function() voidConnection:Disconnect() end); voidConnection = nil end
    pcall(function() workspace.FallenPartsDestroyHeight = getgenv().FPDH end)
    local hrp = GetHRP(); if hrp then
        if voidSavedPos then hrp.CFrame = voidSavedPos; hrp.Velocity = Vector3.zero
        else
            local safeY = 50
            pcall(function()
                local ray = workspace:Raycast(Vector3.new(hrp.Position.X, 5000, hrp.Position.Z), Vector3.new(0,-10000,0))
                if ray then safeY = ray.Position.Y + 5 end
            end)
            hrp.CFrame = CFrame.new(hrp.Position.X, safeY, hrp.Position.Z); hrp.Velocity = Vector3.zero
        end
    end
    voidSavedPos = nil; Notify("Void", "Returned", 2, "success"); UpdateVoidStatus()
end

local function SkidFling(TargetPlayer, duration)
    if not Running or not FlingActive then return end
    duration = duration or State.FlingDuration or 3
    local Character = LP.Character; if not Character then return end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid"); if not Humanoid then return end
    local RootPart = Humanoid.RootPart; if not RootPart then return end
    local TCharacter = TargetPlayer.Character; if not TCharacter then return end
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")
    if not TRootPart and not THead and not Handle then return end
    if THumanoid and THumanoid.Health <= 0 then return end
    if Humanoid.Health <= 0 then return end
    if THumanoid and THumanoid.Sit then return end
    local wasVoid = voidActive; local savedCF = RootPart.CFrame
    if RootPart.Velocity.Magnitude < 50 then getgenv().OldPos = RootPart.CFrame end
    if wasVoid and voidConnection then pcall(function() voidConnection:Disconnect() end); voidConnection = nil end
    if THead then workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid then workspace.CurrentCamera.CameraSubject = THumanoid end
    local function GetTargetPart()
        if TRootPart and TRootPart.Parent then return TRootPart end
        if THead and THead.Parent then return THead end
        if Handle and Handle.Parent then return Handle end
    end
    local function FPos(BP, Pos, Ang)
        if not RootPart or not RootPart.Parent then return end
        local cf = CFrame.new(BP.Position) * Pos * Ang
        RootPart.CFrame = cf; pcall(function() Character:PivotTo(cf) end)
        RootPart.Velocity = Vector3.new(9e7, 9e7*10, 9e7); RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end
    local function SFBasePart(BP)
        if not BP or not BP.Parent then return end
        local startT = tick(); local A = 0
        repeat
            if not Running or not FlingActive then break end
            if not RootPart or not RootPart.Parent then break end
            if not THumanoid or not THumanoid.Parent then break end
            if THumanoid.Health <= 0 then break end
            local curBP = GetTargetPart(); if not curBP or not curBP.Parent then break end
            local targetVel = curBP.Velocity.Magnitude; local predictOffset = Vector3.zero
            if targetVel > 5 then predictOffset = curBP.Velocity.Unit * math.min(targetVel*0.08, 10) end
            if targetVel < 50 then
                A = A + 100; local md = THumanoid.MoveDirection * targetVel/1.25
                FPos(curBP, CFrame.new(predictOffset+Vector3.new(0,1.5,0)+md), CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset+Vector3.new(0,-1.5,0)+md), CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset+Vector3.new(0,1.5,0)+THumanoid.MoveDirection), CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset+Vector3.new(0,-1.5,0)+THumanoid.MoveDirection), CFrame.Angles(math.rad(A),0,0)); task.wait()
            else
                A = A + 150
                local chaseDir = (curBP.Position - RootPart.Position)
                if chaseDir.Magnitude > 0.1 then chaseDir = chaseDir.Unit else chaseDir = THumanoid.MoveDirection end
                local speedBoost = math.max(THumanoid.WalkSpeed, targetVel*0.5)
                FPos(curBP, CFrame.new(predictOffset+Vector3.new(0,1.5,0)+chaseDir*speedBoost*0.03), CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset+Vector3.new(0,-1.5,0)-chaseDir*speedBoost*0.03), CFrame.Angles(math.rad(-A),0,0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset+Vector3.new(0,0.5,0)), CFrame.Angles(math.rad(A),math.rad(A),0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset+Vector3.new(0,-0.5,0)), CFrame.Angles(0,0,math.rad(A))); task.wait()
                if targetVel > 100 then
                    FPos(curBP, CFrame.new(predictOffset+Vector3.new(1.5,0,0)), CFrame.Angles(math.rad(A*2),0,0)); task.wait()
                    FPos(curBP, CFrame.new(predictOffset+Vector3.new(-1.5,0,0)), CFrame.Angles(math.rad(-A*2),0,0)); task.wait()
                end
            end
        until tick()-startT >= duration or not FlingActive or not Running
    end
    pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)
    local BV = Instance.new("BodyVelocity"); BV.Parent = RootPart; BV.Velocity = Vector3.zero; BV.MaxForce = Vector3.new(9e9,9e9,9e9)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    local mainBP = GetTargetPart(); if mainBP then SFBasePart(mainBP) end
    pcall(function() BV:Destroy() end)
    pcall(function() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
    pcall(function() workspace.CurrentCamera.CameraSubject = Humanoid end)
    local returnCF = wasVoid and savedCF or getgenv().OldPos
    if returnCF and RootPart and RootPart.Parent then
        local att = 0
        repeat att += 1; pcall(function()
            RootPart.CFrame = returnCF * CFrame.new(0,.5,0); Character:PivotTo(returnCF * CFrame.new(0,.5,0))
            Humanoid:ChangeState("GettingUp")
            for _, p in pairs(Character:GetChildren()) do
                if p:IsA("BasePart") then p.Velocity = Vector3.zero; p.RotVelocity = Vector3.zero end
            end
        end); task.wait()
        until (RootPart.Position - returnCF.Position).Magnitude < 25 or att > 150
    end
    if wasVoid and voidActive then
        pcall(function() workspace.FallenPartsDestroyHeight = -1e9 end)
        voidConnection = RS.Heartbeat:Connect(function()
            if not voidActive or not Running then if voidConnection then voidConnection:Disconnect(); voidConnection = nil end; return end
            local h = GetHRP(); if h then
                h.CFrame = CFrame.new(h.Position.X, voidTargetY, h.Position.Z) * CFrame.Angles(0, math.rad(h.Orientation.Y), 0)
                h.Velocity = Vector3.new(h.Velocity.X*0.5, 0, h.Velocity.Z*0.5); h.RotVelocity = Vector3.zero
                local ch = LP.Character; if ch then for _, p in pairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
            end
        end)
        table.insert(allConnections, voidConnection)
    else
        pcall(function() workspace.FallenPartsDestroyHeight = getgenv().FPDH end)
    end
end

-- MAIN GUI
local WIN_W, WIN_H = 560, 440
local SIDEBAR_W = 110
local HEADER_H = 48

local SG = Instance.new("ScreenGui")
SG.Name = "QWENGui"
SG.Parent = game.CoreGui
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
SG.Enabled = false

local canvasGroupOK = pcall(function() local t = Instance.new("CanvasGroup"); t:Destroy() end)
local menuFrame
if canvasGroupOK then
    menuFrame = Instance.new("CanvasGroup")
    menuFrame.GroupTransparency = 1
else
    menuFrame = Instance.new("Frame")
end
menuFrame.Name = "Main"
menuFrame.Size = UDim2.new(0, WIN_W, 0, WIN_H)
menuFrame.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
menuFrame.BackgroundColor3 = THEME.background
menuFrame.BorderSizePixel = 0
menuFrame.Visible = false
menuFrame.ZIndex = 200
menuFrame.Parent = SG
Corner(menuFrame, 8)
Stroke(menuFrame, THEME.border, 1, 0)

local snowContainer

local function createSnowContainer(parent)
    if snowContainer and snowContainer.Parent then snowContainer:Destroy() end
    snowContainer = Instance.new("Frame")
    snowContainer.Size = UDim2.new(1,0,1,0)
    snowContainer.BackgroundTransparency = 1
    snowContainer.ClipsDescendants = true
    snowContainer.ZIndex = 203
    snowContainer.Name = "SnowContainer"
    snowContainer.Parent = parent
end

local function updateSnow()
    if not snowEnabled then
        if snowContainer and snowContainer.Parent then
            for _, child in pairs(snowContainer:GetChildren()) do child:Destroy() end
        end
        snowParticles = {}
        return
    end
    if not snowContainer or not snowContainer.Parent then return end
    if math.random() < 0.25 then
        local size = math.random(2,4)
        local flake = Instance.new("Frame")
        flake.Size = UDim2.new(0,size,0,size)
        flake.Position = UDim2.new(math.random()*1.2-0.1, 0, -0.02, 0)
        flake.BackgroundColor3 = Color3.new(1,1,1)
        flake.BackgroundTransparency = math.random()*0.3+0.4
        flake.BorderSizePixel = 0
        flake.ZIndex = 204
        flake.Parent = snowContainer
        Corner(flake, 10)
        table.insert(snowParticles, {frame=flake, speed=math.random(40,100)/100, drift=(math.random()-0.5)*0.25, startX=flake.Position.X.Scale, time=0})
    end
    for i = #snowParticles, 1, -1 do
        local p = snowParticles[i]
        if p.frame and p.frame.Parent then
            p.time += 0.016
            local newY = p.frame.Position.Y.Scale + p.speed * 0.004
            p.frame.Position = UDim2.new(p.startX + math.sin(p.time*2)*p.drift, 0, newY, 0)
            if newY > 1.05 then p.frame:Destroy(); table.remove(snowParticles, i) end
        else table.remove(snowParticles, i) end
    end
end

createSnowContainer(menuFrame)

-- HEADER
do
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, HEADER_H)
    header.BackgroundColor3 = THEME.backgroundLight
    header.BorderSizePixel = 0
    header.ZIndex = 210
    header.Parent = menuFrame
    Corner(header, 8)

    local hf = Instance.new("Frame")
    hf.Size = UDim2.new(1,0,0,10)
    hf.Position = UDim2.new(0,0,1,-10)
    hf.BackgroundColor3 = THEME.backgroundLight
    hf.BorderSizePixel = 0; hf.ZIndex = 209; hf.Parent = header

    local ta = Instance.new("Frame")
    ta.Size = UDim2.new(1,0,0,3)
    ta.BackgroundColor3 = THEME.primary
    ta.BorderSizePixel = 0; ta.ZIndex = 211; ta.Parent = header
    Corner(ta, 8); trackTheme(ta, "BackgroundColor3", "primary")
    local ag = Instance.new("UIGradient")
    ag.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.primaryDark),
        ColorSequenceKeypoint.new(0.5, THEME.primaryLight),
        ColorSequenceKeypoint.new(1, THEME.primaryDark)
    })
    ag.Parent = ta
    task.spawn(function()
        local o = 0
        while ta and ta.Parent do
            o = (o+0.01)%1
            ag.Offset = Vector2.new(math.sin(o*math.pi*2)*0.3, 0)
            ag.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.primaryDark),
                ColorSequenceKeypoint.new(0.5, THEME.primaryLight),
                ColorSequenceKeypoint.new(1, THEME.primaryDark)
            })
            task.wait(0.02)
        end
    end)

    local mainDrag = false; local mainDragStart, mainStartPos
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            mainDrag = true; mainDragStart = i.Position; mainStartPos = menuFrame.Position
        end
    end)
    header.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then mainDrag = false end
    end)
    table.insert(allConnections, UIS.InputChanged:Connect(function(i)
        if mainDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - mainDragStart
            menuFrame.Position = UDim2.new(mainStartPos.X.Scale, mainStartPos.X.Offset+d.X, mainStartPos.Y.Scale, mainStartPos.Y.Offset+d.Y)
        end
    end))

    local lc = Instance.new("Frame")
    lc.Size = UDim2.new(0,32,0,32); lc.Position = UDim2.new(0,12,0,10)
    lc.BackgroundColor3 = THEME.backgroundLighter; lc.BorderSizePixel = 0; lc.ZIndex = 213; lc.Parent = header
    Corner(lc, 6)
    local ls = Instance.new("UIStroke"); ls.Thickness = 1; ls.Color = THEME.primary; ls.Parent = lc; trackTheme(ls, "Color", "primary")
    local lt = Instance.new("TextLabel")
    lt.Size = UDim2.new(1,0,1,0); lt.BackgroundTransparency = 1
    lt.Font = Enum.Font.GothamBlack; lt.Text = "Q"; lt.TextColor3 = THEME.primary; lt.TextSize = 18; lt.ZIndex = 214; lt.Parent = lc
    trackTheme(lt, "TextColor3", "primary")

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(0,160,0,28); tl.Position = UDim2.new(0,52,0.5,-14)
    tl.BackgroundTransparency = 1; tl.Font = Enum.Font.GothamBlack
    tl.Text = "QWEN"; tl.TextColor3 = THEME.text; tl.TextSize = 17
    tl.TextXAlignment = Enum.TextXAlignment.Left; tl.ZIndex = 212; tl.Parent = header
    local tg = Instance.new("UIGradient")
    tg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.text),
        ColorSequenceKeypoint.new(0.5, THEME.primaryLight),
        ColorSequenceKeypoint.new(1, THEME.text)
    })
    tg.Parent = tl
    task.spawn(function()
        local o = 0
        while tl and tl.Parent do
            o = (o+0.02)%2
            tg.Offset = Vector2.new(o-0.5, 0)
            tg.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.text),
                ColorSequenceKeypoint.new(0.5, THEME.primaryLight),
                ColorSequenceKeypoint.new(1, THEME.text)
            })
            task.wait(0.03)
        end
    end)
end

local tabButtons = {}
local tabContents = {}
local currentTab = "Player"

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -HEADER_H-8)
sidebar.Position = UDim2.new(0, 8, 0, HEADER_H+4)
sidebar.BackgroundColor3 = THEME.backgroundLight
sidebar.BackgroundTransparency = 0.3
sidebar.BorderSizePixel = 0; sidebar.ZIndex = 210; sidebar.Parent = menuFrame
Corner(sidebar, 6); Stroke(sidebar, THEME.border, 1, 0)

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -(SIDEBAR_W+24), 1, -HEADER_H-8)
contentArea.Position = UDim2.new(0, SIDEBAR_W+16, 0, HEADER_H+4)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.ZIndex = 210; contentArea.Parent = menuFrame

local tabs = {"Player", "Fling", "Teleport", "Void", "Admin", "Settings"}

local function SetTab(name)
    if currentTab == name then return end
    for n, content in pairs(tabContents) do content.Visible = (n == name) end
    for n, btn in pairs(tabButtons) do
        local active = (n == name)
        Smooth(btn, {
            BackgroundColor3 = active and THEME.backgroundLighter or THEME.backgroundLighter,
            BackgroundTransparency = active and 0.1 or 0.5,
            TextColor3 = active and THEME.text or THEME.textMuted
        }, 0.2)
        local ind = btn:FindFirstChild("Indicator")
        if ind then Smooth(ind, {BackgroundTransparency = active and 0 or 1}, 0.2) end
    end
    currentTab = name
end

local tabPad = Instance.new("UIPadding", sidebar)
tabPad.PaddingTop = UDim.new(0,6); tabPad.PaddingLeft = UDim.new(0,4); tabPad.PaddingRight = UDim.new(0,4)
local tabLayout = Instance.new("UIListLayout", sidebar)
tabLayout.Padding = UDim.new(0,2); tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

for i, name in ipairs(tabs) do
    local isFirst = (i == 1)
    local tb = Instance.new("TextButton")
    tb.Name = name
    tb.Size = UDim2.new(1,0,0,30)
    tb.BackgroundColor3 = THEME.backgroundLighter
    tb.BackgroundTransparency = isFirst and 0.1 or 0.5
    tb.Font = Enum.Font.GothamBold
    tb.Text = name
    tb.TextColor3 = isFirst and THEME.text or THEME.textMuted
    tb.TextSize = 11
    tb.BorderSizePixel = 0
    tb.ZIndex = 211
    tb.LayoutOrder = i
    tb.AutoButtonColor = false
    tb.Parent = sidebar
    Corner(tb, 4)

    local ind = Instance.new("Frame")
    ind.Name = "Indicator"
    ind.Size = UDim2.new(0,3,0.6,0)
    ind.Position = UDim2.new(0,0,0.2,0)
    ind.BackgroundColor3 = THEME.primary
    ind.BackgroundTransparency = isFirst and 0 or 1
    ind.BorderSizePixel = 0; ind.ZIndex = 212; ind.Parent = tb
    Corner(ind, 2); trackTheme(ind, "BackgroundColor3", "primary")

    tabButtons[name] = tb

    tb.MouseEnter:Connect(function()
        if currentTab ~= name then
            Smooth(tb, {BackgroundTransparency=0.3, TextColor3=THEME.textDim}, 0.15)
        end
    end)
    tb.MouseLeave:Connect(function()
        if currentTab ~= name then
            Smooth(tb, {BackgroundTransparency=0.5, TextColor3=THEME.textMuted}, 0.15)
        end
    end)
    tb.MouseButton1Click:Connect(function() SetTab(name) end)
end

local function MakePage(visible)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1,0,1,0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = THEME.primary
    page.CanvasSize = UDim2.new(0,0,0,0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = visible or false
    page.ZIndex = 211
    page.Parent = contentArea
    trackTheme(page, "ScrollBarImageColor3", "primary")
    local pad = Instance.new("UIPadding", page)
    pad.PaddingTop = UDim.new(0,4); pad.PaddingBottom = UDim.new(0,8)
    pad.PaddingLeft = UDim.new(0,2); pad.PaddingRight = UDim.new(0,4)
    local lay = Instance.new("UIListLayout", page)
    lay.Padding = UDim.new(0,4); lay.SortOrder = Enum.SortOrder.LayoutOrder
    return page
end

for i, name in ipairs(tabs) do
    tabContents[name] = MakePage(i==1)
end

local function SectionLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,18)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = text:upper()
    lbl.TextColor3 = THEME.textMuted
    lbl.TextSize = 9
    lbl.ZIndex = 212
    lbl.Parent = parent
end

local function Toggle(parent, name, desc, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,42)
    container.BackgroundColor3 = THEME.backgroundLighter
    container.BackgroundTransparency = 0.5
    container.BorderSizePixel = 0; container.ZIndex = 211; container.Parent = parent
    Corner(container, 6)
    local cS = Instance.new("UIStroke"); cS.Thickness = 1; cS.Color = THEME.border; cS.Transparency = 0.5; cS.Parent = container

    container.MouseEnter:Connect(function()
        Smooth(container, {BackgroundTransparency=0.3}, 0.15)
        Smooth(cS, {Color=THEME.primary, Transparency=0.3}, 0.15)
    end)
    container.MouseLeave:Connect(function()
        Smooth(container, {BackgroundTransparency=0.5}, 0.15)
        Smooth(cS, {Color=THEME.border, Transparency=0.5}, 0.15)
    end)

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1,-130,0,16); nameL.Position = UDim2.new(0,10,0,4)
    nameL.BackgroundTransparency = 1; nameL.Font = Enum.Font.GothamSemibold
    nameL.Text = name; nameL.TextColor3 = THEME.text; nameL.TextSize = 11
    nameL.TextXAlignment = Enum.TextXAlignment.Left; nameL.ZIndex = 212; nameL.Parent = container

    local descL = Instance.new("TextLabel")
    descL.Size = UDim2.new(1,-130,0,12); descL.Position = UDim2.new(0,10,0,23)
    descL.BackgroundTransparency = 1; descL.Font = Enum.Font.Gotham
    descL.Text = desc or ""; descL.TextColor3 = THEME.textMuted; descL.TextSize = 8
    descL.TextXAlignment = Enum.TextXAlignment.Left; descL.ZIndex = 212; descL.Parent = container

    local kbBtn = Instance.new("TextButton")
    kbBtn.Size = UDim2.new(0,44,0,20)
    kbBtn.Position = UDim2.new(1,-130,0.5,-10)
    kbBtn.BackgroundColor3 = THEME.background
    kbBtn.BorderSizePixel = 0
    kbBtn.Font = Enum.Font.GothamBold
    kbBtn.Text = Binds[name] and ("["..Binds[name].."]") or "BIND"
    kbBtn.TextColor3 = Binds[name] and THEME.textDim or THEME.textMuted
    kbBtn.TextSize = 8
    kbBtn.AutoButtonColor = false
    kbBtn.ZIndex = 215
    kbBtn.Parent = container
    Corner(kbBtn, 4)
    local kbStroke = Instance.new("UIStroke"); kbStroke.Thickness = 1; kbStroke.Color = THEME.border; kbStroke.Parent = kbBtn
    bindLabels[name] = kbBtn

    local isWaitingBind = false

    kbBtn.MouseEnter:Connect(function()
        if not isWaitingBind then Smooth(kbBtn, {BackgroundColor3=THEME.backgroundLighter}, 0.1) end
    end)
    kbBtn.MouseLeave:Connect(function()
        if not isWaitingBind then Smooth(kbBtn, {BackgroundColor3=THEME.background}, 0.1) end
    end)

    kbBtn.MouseButton1Click:Connect(function()
        if isWaitingBind then return end
        isWaitingBind = true
        kbBtn.Text = "..."
        kbBtn.TextColor3 = THEME.primary
        Smooth(kbBtn, {BackgroundColor3=THEME.primaryDark}, 0.1)
        Smooth(kbStroke, {Color=THEME.primary}, 0.1)

        local conn; conn = UIS.InputBegan:Connect(function(i2, gp2)
            if gp2 then return end
            if i2.UserInputType == Enum.UserInputType.Keyboard then
                isWaitingBind = false
                conn:Disconnect()
                if i2.KeyCode == Enum.KeyCode.Escape then
                    kbBtn.Text = Binds[name] and ("["..Binds[name].."]") or "BIND"
                    kbBtn.TextColor3 = Binds[name] and THEME.textDim or THEME.textMuted
                    Smooth(kbBtn, {BackgroundColor3=THEME.background}, 0.1)
                    Smooth(kbStroke, {Color=THEME.border}, 0.1)
                    return
                end
                if i2.KeyCode == Enum.KeyCode.Backspace then
                    Binds[name] = nil
                    kbBtn.Text = "BIND"
                    kbBtn.TextColor3 = THEME.textMuted
                    Smooth(kbBtn, {BackgroundColor3=THEME.background}, 0.1)
                    Smooth(kbStroke, {Color=THEME.border}, 0.1)
                    SaveSettings()
                    Notify("Keybind", name.." unbound", 2, "info")
                    return
                end
                local kn2 = tostring(i2.KeyCode):gsub("Enum.KeyCode.","")
                Binds[name] = kn2
                kbBtn.Text = "["..kn2.."]"
                kbBtn.TextColor3 = THEME.textDim
                Smooth(kbBtn, {BackgroundColor3=THEME.background}, 0.1)
                Smooth(kbStroke, {Color=THEME.border}, 0.1)
                SaveSettings()
                Notify("Keybind", name.." → ["..kn2.."]", 2, "success")
            end
        end)
    end)

    local stateKey = ToggleStateMap[name]
    local enabled = stateKey and State[stateKey] or false

    local tBg = Instance.new("Frame")
    tBg.Size = UDim2.new(0,36,0,20); tBg.Position = UDim2.new(1,-44,0.5,-10)
    tBg.BackgroundColor3 = THEME.backgroundLighter
    tBg.BorderSizePixel = 0; tBg.ZIndex = 212; tBg.Parent = container
    Corner(tBg, 10)
    local tSt = Instance.new("UIStroke"); tSt.Thickness = 1; tSt.Color = enabled and THEME.primary or THEME.border; tSt.Parent = tBg
    local tK = Instance.new("Frame")
    tK.Size = UDim2.new(0,16,0,16)
    tK.Position = enabled and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)
    tK.BackgroundColor3 = enabled and THEME.primary or THEME.textMuted
    tK.BorderSizePixel = 0; tK.ZIndex = 213; tK.Parent = tBg
    Corner(tK, 8)

    local tBtn = Instance.new("TextButton")
    tBtn.Size = UDim2.new(0,36,0,20); tBtn.Position = UDim2.new(1,-44,0.5,-10)
    tBtn.BackgroundTransparency = 1; tBtn.Text = ""; tBtn.ZIndex = 215; tBtn.Parent = container

    local function updateVisual()
        Smooth(tBg, {BackgroundColor3 = THEME.backgroundLighter}, 0.2)
        Smooth(tSt, {Color = enabled and THEME.primary or THEME.border}, 0.2)
        Tween(tK, {Position = enabled and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)}, 0.2, Enum.EasingStyle.Back)
        Smooth(tK, {BackgroundColor3 = enabled and THEME.primary or THEME.textMuted}, 0.2)
    end

    local function setEnabled(val)
        enabled = val
        if stateKey then State[stateKey] = val end
        updateVisual()
        callback(enabled)
        SaveSettings()
    end
    toggleSetters[name] = setEnabled

    tBtn.MouseButton1Click:Connect(function()
        if isWaitingBind then return end
        setEnabled(not enabled)
        Notify(name, enabled and "Enabled" or "Disabled", 2, enabled and "success" or "info")
    end)

    return setEnabled
end

local function Slider(parent, name, minV, maxV, def, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,46)
    container.BackgroundColor3 = THEME.backgroundLighter
    container.BackgroundTransparency = 0.5
    container.BorderSizePixel = 0; container.ZIndex = 211; container.Parent = parent
    Corner(container, 6); Stroke(container, THEME.border, 1, 0)

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1,-60,0,16); nameL.Position = UDim2.new(0,10,0,4)
    nameL.BackgroundTransparency = 1; nameL.Font = Enum.Font.GothamSemibold
    nameL.Text = name; nameL.TextColor3 = THEME.text; nameL.TextSize = 10
    nameL.TextXAlignment = Enum.TextXAlignment.Left; nameL.ZIndex = 212; nameL.Parent = container

    local vl = Instance.new("TextLabel")
    vl.Size = UDim2.new(0,50,0,16); vl.Position = UDim2.new(1,-58,0,4)
    vl.BackgroundTransparency = 1; vl.Font = Enum.Font.GothamBold
    vl.Text = tostring(def); vl.TextColor3 = THEME.primary; vl.TextSize = 10
    vl.TextXAlignment = Enum.TextXAlignment.Right; vl.ZIndex = 212; vl.Parent = container
    trackTheme(vl, "TextColor3", "primary")

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-20,0,6); track.Position = UDim2.new(0,10,0,30)
    track.BackgroundColor3 = THEME.background; track.BorderSizePixel = 0; track.ZIndex = 212; track.Parent = container
    Corner(track, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((def-minV)/(maxV-minV),0,1), 0, 1, 0)
    fill.BackgroundColor3 = THEME.primary; fill.BorderSizePixel = 0; fill.ZIndex = 213; fill.Parent = track
    Corner(fill, 3); trackTheme(fill, "BackgroundColor3", "primary")

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,14,0,14)
    knob.Position = UDim2.new(math.clamp((def-minV)/(maxV-minV),0,1), -7, 0.5, -7)
    knob.BackgroundColor3 = THEME.text; knob.BorderSizePixel = 0; knob.ZIndex = 214; knob.Parent = track
    Corner(knob, 7)
    local ks = Instance.new("UIStroke"); ks.Thickness = 1; ks.Color = THEME.primary; ks.Parent = knob; trackTheme(ks, "Color", "primary")

    local curVal = def

    local function apply(v)
        v = math.clamp(math.floor(v+0.5), minV, maxV)
        if curVal == v then return end
        curVal = v
        local pct = (v-minV)/(maxV-minV)
        fill.Size = UDim2.new(pct,0,1,0)
        knob.Position = UDim2.new(pct,-7,0.5,-7)
        vl.Text = tostring(v)
        callback(v)
        SaveSettings()
    end

    local function applyFromMouse(inputX)
        local aP, aS = track.AbsolutePosition.X, track.AbsoluteSize.X
        if aS > 0 then
            apply(minV + (maxV-minV) * math.clamp((inputX-aP)/aS, 0, 1))
        end
    end

    local dragBtn = Instance.new("TextButton")
    dragBtn.Size = UDim2.new(1,0,5,0); dragBtn.Position = UDim2.new(0,0,-2,0)
    dragBtn.BackgroundTransparency = 1; dragBtn.Text = ""; dragBtn.Parent = track; dragBtn.ZIndex = 216

    dragBtn.MouseButton1Down:Connect(function(x, y)
        Smooth(knob, {Size=UDim2.new(0,16,0,16)}, 0.06)
        applyFromMouse(x)
        activeSliderDrag = {track = track, apply = applyFromMouse, knob = knob}
    end)

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            Smooth(knob, {Size=UDim2.new(0,16,0,16)}, 0.06)
            applyFromMouse(i.Position.X)
            activeSliderDrag = {track = track, apply = applyFromMouse, knob = knob}
        end
    end)
end

-- ACTIVE WINDOW
local BindGui = Instance.new("ScreenGui")
BindGui.Name = "QWENBind"; BindGui.ResetOnSpawn = false; BindGui.Parent = game.CoreGui

local BindBox = Instance.new("Frame")
BindBox.Size = UDim2.new(0, 160, 0, 32)
BindBox.Position = LoadBindBoxPos()
BindBox.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
BindBox.BackgroundTransparency = 0.3
BindBox.BorderSizePixel = 0
BindBox.AutomaticSize = Enum.AutomaticSize.Y
BindBox.Active = true
BindBox.Visible = false
BindBox.Parent = BindGui
Corner(BindBox, 12)
local bindBoxStroke = Instance.new("UIStroke")
bindBoxStroke.Thickness = 1
bindBoxStroke.Color = Color3.fromRGB(50, 50, 65)
bindBoxStroke.Transparency = 0.3
bindBoxStroke.Parent = BindBox

local bbHeaderFrame = Instance.new("Frame")
bbHeaderFrame.Size = UDim2.new(1,0,0,26)
bbHeaderFrame.BackgroundTransparency = 1
bbHeaderFrame.Parent = BindBox

local bbDot = Instance.new("Frame")
bbDot.Size = UDim2.new(0,5,0,5)
bbDot.Position = UDim2.new(0,10,0.5,-2.5)
bbDot.BackgroundColor3 = THEME.success
bbDot.BorderSizePixel = 0
bbDot.ZIndex = 3
bbDot.Parent = bbHeaderFrame
Corner(bbDot, 3)

local bbTitle = Instance.new("TextLabel")
bbTitle.Size = UDim2.new(1,-24,1,0)
bbTitle.Position = UDim2.new(0,20,0,0)
bbTitle.BackgroundTransparency = 1
bbTitle.Font = Enum.Font.GothamBold
bbTitle.Text = "ACTIVE"
bbTitle.TextColor3 = Color3.fromRGB(130, 130, 150)
bbTitle.TextSize = 9
bbTitle.TextXAlignment = Enum.TextXAlignment.Left
bbTitle.ZIndex = 3
bbTitle.Parent = bbHeaderFrame

local bbDivider = Instance.new("Frame")
bbDivider.Size = UDim2.new(1,-16,0,1)
bbDivider.Position = UDim2.new(0,8,0,26)
bbDivider.BackgroundColor3 = Color3.fromRGB(40,40,55)
bbDivider.BackgroundTransparency = 0.3
bbDivider.BorderSizePixel = 0
bbDivider.Parent = BindBox

local BindI = Instance.new("Frame")
BindI.Size = UDim2.new(1,0,0,0)
BindI.Position = UDim2.new(0,0,0,30)
BindI.BackgroundTransparency = 1
BindI.AutomaticSize = Enum.AutomaticSize.Y
BindI.Parent = BindBox
local bLay = Instance.new("UIListLayout", BindI); bLay.Padding = UDim.new(0,2)
local bPa = Instance.new("UIPadding", BindI)
bPa.PaddingLeft = UDim.new(0,6); bPa.PaddingRight = UDim.new(0,6); bPa.PaddingBottom = UDim.new(0,8); bPa.PaddingTop = UDim.new(0,4)

local bD = false; local bDS, bSP
BindBox.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        bD=true; bDS=i.Position; bSP=BindBox.Position
    end
end)
BindBox.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        bD=false
        SaveBindBoxPos(BindBox.Position)
    end
end)
table.insert(allConnections, UIS.InputChanged:Connect(function(i)
    if bD and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - bDS
        BindBox.Position = UDim2.new(bSP.X.Scale, bSP.X.Offset+d.X, bSP.Y.Scale, bSP.Y.Offset+d.Y)
    end
end))

local function UpdateBindVis()
    local ct = 0; for _ in pairs(activeBindIndicators) do ct+=1 end
    if ct > 0 then
        BindBox.Visible = true
        Smooth(BindBox, {BackgroundTransparency=0.3}, 0.2)
    else
        Smooth(BindBox, {BackgroundTransparency=1}, 0.2)
        task.delay(0.25, function()
            if next(activeBindIndicators)==nil then BindBox.Visible=false end
        end)
    end
end

function ShowBindIndicator(name)
    if activeBindIndicators[name] then return end

    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,20)
    f.BackgroundColor3 = Color3.fromRGB(20,20,28)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Parent = BindI
    Corner(f, 6)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0,2,0.65,0)
    accent.Position = UDim2.new(0,0,0.175,0)
    accent.BackgroundColor3 = THEME.primary
    accent.BorderSizePixel = 0
    accent.ZIndex = 3
    accent.Parent = f
    Corner(accent, 1)
    trackTheme(accent, "BackgroundColor3", "primary")

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-10,1,0)
    lbl.Position = UDim2.new(0,7,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.Text = name
    lbl.TextColor3 = Color3.fromRGB(220,220,230)
    lbl.TextSize = 9
    lbl.TextTransparency = 1
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 3
    lbl.Parent = f

    activeBindIndicators[name] = f
    Smooth(f, {BackgroundTransparency=0.5}, 0.2)
    Smooth(lbl, {TextTransparency=0}, 0.2)
    UpdateBindVis()
end

function HideBindIndicator(name)
    local f = activeBindIndicators[name]; if not f then return end
    activeBindIndicators[name] = nil
    local function findLbl(p)
        for _, ch in pairs(p:GetChildren()) do
            if ch:IsA("TextLabel") then return ch end
            local fd = findLbl(ch); if fd then return fd end
        end
    end
    local rl = findLbl(f)
    if rl then Smooth(rl, {TextTransparency=1}, 0.18) end
    Smooth(f, {BackgroundTransparency=1}, 0.18)
    task.delay(0.22, function() pcall(function() f:Destroy() end) end)
    UpdateBindVis()
end

table.insert(allConnections, UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and activeSliderDrag then
        Smooth(activeSliderDrag.knob, {Size=UDim2.new(0,14,0,14)}, 0.1)
        activeSliderDrag = nil
    end
end))
table.insert(allConnections, UIS.InputChanged:Connect(function(i)
    if activeSliderDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
        activeSliderDrag.apply(i.Position.X)
    end
end))

-- ADMIN WINDOW
local AdminWinGui = Instance.new("ScreenGui")
AdminWinGui.Name = "QWENAdminWin"
AdminWinGui.ResetOnSpawn = false
AdminWinGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
AdminWinGui.Parent = game.CoreGui

local AdminWin = Instance.new("Frame")
AdminWin.Name = "AdminWindow"
AdminWin.Size = UDim2.new(0, 180, 0, 32)
AdminWin.Position = LoadAdminWinPos()
AdminWin.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
AdminWin.BackgroundTransparency = 0.25
AdminWin.BorderSizePixel = 0
AdminWin.AutomaticSize = Enum.AutomaticSize.Y
AdminWin.Active = true
AdminWin.Visible = false
AdminWin.Parent = AdminWinGui
Corner(AdminWin, 12)
local adminWinStroke = Instance.new("UIStroke")
adminWinStroke.Thickness = 1
adminWinStroke.Color = Color3.fromRGB(185, 148, 55)
adminWinStroke.Transparency = 0.5
adminWinStroke.Parent = AdminWin

local awHeader = Instance.new("Frame")
awHeader.Size = UDim2.new(1,0,0,26)
awHeader.BackgroundTransparency = 1
awHeader.Parent = AdminWin

local awDot = Instance.new("Frame")
awDot.Size = UDim2.new(0,5,0,5)
awDot.Position = UDim2.new(0,10,0.5,-2.5)
awDot.BackgroundColor3 = Color3.fromRGB(185, 148, 55)
awDot.BorderSizePixel = 0
awDot.ZIndex = 3
awDot.Parent = awHeader
Corner(awDot, 3)

local awTitle = Instance.new("TextLabel")
awTitle.Size = UDim2.new(1,-24,1,0)
awTitle.Position = UDim2.new(0,20,0,0)
awTitle.BackgroundTransparency = 1
awTitle.Font = Enum.Font.GothamBold
awTitle.Text = "ADMINS"
awTitle.TextColor3 = Color3.fromRGB(185, 148, 55)
awTitle.TextSize = 9
awTitle.TextXAlignment = Enum.TextXAlignment.Left
awTitle.ZIndex = 3
awTitle.Parent = awHeader

local awDivider = Instance.new("Frame")
awDivider.Size = UDim2.new(1,-16,0,1)
awDivider.Position = UDim2.new(0,8,0,26)
awDivider.BackgroundColor3 = Color3.fromRGB(185, 148, 55)
awDivider.BackgroundTransparency = 0.7
awDivider.BorderSizePixel = 0
awDivider.Parent = AdminWin

local awList = Instance.new("Frame")
awList.Size = UDim2.new(1,0,0,0)
awList.Position = UDim2.new(0,0,0,30)
awList.BackgroundTransparency = 1
awList.AutomaticSize = Enum.AutomaticSize.Y
awList.Parent = AdminWin
local awListLayout = Instance.new("UIListLayout", awList)
awListLayout.Padding = UDim.new(0,2)
local awPad = Instance.new("UIPadding", awList)
awPad.PaddingLeft = UDim.new(0,6)
awPad.PaddingRight = UDim.new(0,6)
awPad.PaddingBottom = UDim.new(0,8)
awPad.PaddingTop = UDim.new(0,4)

local awDrag = false; local awDragStart, awStartPos
AdminWin.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        awDrag=true; awDragStart=i.Position; awStartPos=AdminWin.Position
    end
end)
AdminWin.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        awDrag=false
        SaveAdminWinPos(AdminWin.Position)
    end
end)
table.insert(allConnections, UIS.InputChanged:Connect(function(i)
    if awDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - awDragStart
        AdminWin.Position = UDim2.new(awStartPos.X.Scale, awStartPos.X.Offset+d.X, awStartPos.Y.Scale, awStartPos.Y.Offset+d.Y)
    end
end))

local adminWinEntries = {}

local function RefreshAdminWindow()
    for _, f in pairs(adminWinEntries) do pcall(function() f:Destroy() end) end
    adminWinEntries = {}

    local found = false
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP then
            local isAdmin, rank = CheckIfAdmin(plr)
            if isAdmin then
                found = true
                local ef = Instance.new("Frame")
                ef.Size = UDim2.new(1,0,0,44)
                ef.BackgroundColor3 = Color3.fromRGB(22,18,8)
                ef.BackgroundTransparency = 0.5
                ef.BorderSizePixel = 0
                ef.Parent = awList
                Corner(ef, 6)

                local eAccent = Instance.new("Frame")
                eAccent.Size = UDim2.new(0,2,0.65,0)
                eAccent.Position = UDim2.new(0,0,0.175,0)
                eAccent.BackgroundColor3 = Color3.fromRGB(185,148,55)
                eAccent.BorderSizePixel = 0
                eAccent.ZIndex = 3
                eAccent.Parent = ef
                Corner(eAccent, 1)

                local eName = Instance.new("TextLabel")
                eName.Size = UDim2.new(1,-8,0,14)
                eName.Position = UDim2.new(0,7,0,4)
                eName.BackgroundTransparency = 1
                eName.Font = Enum.Font.GothamBold
                eName.Text = plr.DisplayName
                eName.TextColor3 = Color3.fromRGB(220,180,80)
                eName.TextSize = 10
                eName.TextXAlignment = Enum.TextXAlignment.Left
                eName.ZIndex = 3
                eName.Parent = ef

                local eUser = Instance.new("TextLabel")
                eUser.Size = UDim2.new(1,-8,0,10)
                eUser.Position = UDim2.new(0,7,0,20)
                eUser.BackgroundTransparency = 1
                eUser.Font = Enum.Font.Gotham
                eUser.Text = "@"..plr.Name
                eUser.TextColor3 = Color3.fromRGB(140,110,50)
                eUser.TextSize = 8
                eUser.TextXAlignment = Enum.TextXAlignment.Left
                eUser.ZIndex = 3
                eUser.Parent = ef

                local eRank = Instance.new("TextLabel")
                eRank.Size = UDim2.new(1,-8,0,10)
                eRank.Position = UDim2.new(0,7,0,32)
                eRank.BackgroundTransparency = 1
                eRank.Font = Enum.Font.GothamBold
                eRank.Text = "Rank: "..tostring(rank)
                eRank.TextColor3 = Color3.fromRGB(185,148,55)
                eRank.TextSize = 8
                eRank.TextXAlignment = Enum.TextXAlignment.Left
                eRank.ZIndex = 3
                eRank.Parent = ef

                table.insert(adminWinEntries, ef)
            end
        end
    end

    if found then
        AdminWin.Visible = true
        Smooth(AdminWin, {BackgroundTransparency=0.25}, 0.3)
    else
        Smooth(AdminWin, {BackgroundTransparency=1}, 0.3)
        task.delay(0.35, function()
            if #adminWinEntries == 0 then AdminWin.Visible = false end
        end)
    end
end

-- PLAYER TAB
do
    local PP = tabContents["Player"]
    SectionLabel(PP, "Movement")
    Slider(PP, "Walk Speed", 16, 200, State.Speed, function(v)
        State.Speed = v
        local h = GetHum()
        if h then h.WalkSpeed = v end
    end)
    Slider(PP, "Jump Power", 50, 350, State.JumpPower, function(v)
        State.JumpPower = v
        local h = GetHum()
        if h then h.JumpPower = v end
    end)

    SectionLabel(PP, "Options")
    Toggle(PP, "Noclip", "Walk through walls", function(s)
        State.Noclip = s
        if s then StartNoclip(); ShowBindIndicator("Noclip")
        else if not State.Fly then StopNoclip() end; HideBindIndicator("Noclip") end
    end)
    toggleCallbacks["Noclip"] = function()
        if toggleSetters["Noclip"] then toggleSetters["Noclip"](not State.Noclip) end
    end

    Toggle(PP, "Fly", "WASD + Space / Shift", function(s)
        State.Fly = s
        if s then StartFly(); ShowBindIndicator("Fly")
        else StopFly(); HideBindIndicator("Fly") end
    end)
    toggleCallbacks["Fly"] = function()
        if toggleSetters["Fly"] then toggleSetters["Fly"](not State.Fly) end
    end

    Slider(PP, "Fly Speed", 10, 200, State.FlySpeed, function(v) State.FlySpeed = v end)

    Toggle(PP, "TP Tool", "Click to teleport", function(s)
        State.TpTool = s
        if s then
            if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end) end
            for _, item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end
            if LP.Character then for _, item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end
            local tool = Instance.new("Tool"); tool.Name="TP_Tool"; tool.RequiresHandle=false; tool.Parent=LP.Backpack
            tpToolConnection = tool.Activated:Connect(function()
                local c = LP.Character; if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end
            end)
            ShowBindIndicator("TP Tool")
        else
            if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end); tpToolConnection=nil end
            for _, item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end
            if LP.Character then for _, item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end
            HideBindIndicator("TP Tool")
        end
    end)
    toggleCallbacks["TP Tool"] = function()
        if toggleSetters["TP Tool"] then toggleSetters["TP Tool"](not State.TpTool) end
    end

    SectionLabel(PP, "Visuals")
    Toggle(PP, "ESP Players", "Show players through walls", function(s)
        State.ESP = s
        if s then pcall(UpdateESP); ShowBindIndicator("ESP Players")
        else ClearESP(); HideBindIndicator("ESP Players") end
    end)
    toggleCallbacks["ESP Players"] = function()
        if toggleSetters["ESP Players"] then toggleSetters["ESP Players"](not State.ESP) end
    end
end

-- FLING TAB
local flingStatusL, flingDot, flingPlrCont, flingPlayerBtns

do
    local FP = tabContents["Fling"]

    local flingStatusF = Instance.new("Frame")
    flingStatusF.Size = UDim2.new(1,0,0,36); flingStatusF.BackgroundColor3 = THEME.backgroundLighter
    flingStatusF.BackgroundTransparency = 0.5; flingStatusF.BorderSizePixel = 0; flingStatusF.Parent = FP
    Corner(flingStatusF,6); Stroke(flingStatusF, THEME.border, 1, 0)
    flingDot = Instance.new("Frame"); flingDot.Size = UDim2.new(0,5,0,5); flingDot.Position = UDim2.new(0,12,0.5,-2); flingDot.BackgroundColor3 = THEME.textMuted; flingDot.BorderSizePixel = 0; flingDot.Parent = flingStatusF; Corner(flingDot,3)
    flingStatusL = Instance.new("TextLabel"); flingStatusL.Size = UDim2.new(1,-26,1,0); flingStatusL.Position = UDim2.new(0,24,0,0); flingStatusL.BackgroundTransparency = 1; flingStatusL.Font = Enum.Font.GothamMedium; flingStatusL.Text = "Select targets"; flingStatusL.TextColor3 = THEME.textMuted; flingStatusL.TextSize = 11; flingStatusL.TextXAlignment = Enum.TextXAlignment.Left; flingStatusL.Parent = flingStatusF

    SectionLabel(FP, "Duration")
    Slider(FP, "Duration (sec)", 1, 10, State.FlingDuration, function(v) State.FlingDuration = v end)

    SectionLabel(FP, "Controls")

    local function SmallBtn(parent, text, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.48,-3,0,28)
        b.BackgroundColor3 = color or THEME.backgroundLighter
        b.BackgroundTransparency = 0.5
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.TextColor3 = THEME.text
        b.TextSize = 10
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Parent = parent
        Corner(b,6); Stroke(b, THEME.border, 1, 0)
        b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=0.2},0.1) end)
        b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=0.5},0.1) end)
        return b
    end

    local btnRow = Instance.new("Frame"); btnRow.Size = UDim2.new(1,0,0,28); btnRow.BackgroundTransparency = 1; btnRow.Parent = FP
    local btnLay = Instance.new("UIListLayout"); btnLay.FillDirection = Enum.FillDirection.Horizontal; btnLay.Padding = UDim.new(0,4); btnLay.Parent = btnRow
    local StartFBtn = SmallBtn(btnRow, "▶ Start", THEME.success)
    local StopFBtn = SmallBtn(btnRow, "■ Stop", THEME.danger)

    local selRow = Instance.new("Frame"); selRow.Size = UDim2.new(1,0,0,24); selRow.BackgroundTransparency = 1; selRow.Parent = FP
    local selLay = Instance.new("UIListLayout"); selLay.FillDirection = Enum.FillDirection.Horizontal; selLay.Padding = UDim.new(0,4); selLay.Parent = selRow
    local selAllBtn = SmallBtn(selRow, "Select All")
    local deselAllBtn = SmallBtn(selRow, "Unselect All")

    SectionLabel(FP, "Players")
    flingPlrCont = Instance.new("Frame"); flingPlrCont.Size = UDim2.new(1,0,0,0); flingPlrCont.AutomaticSize = Enum.AutomaticSize.Y; flingPlrCont.BackgroundTransparency = 1; flingPlrCont.Parent = FP
    Instance.new("UIListLayout", flingPlrCont).Padding = UDim.new(0,3)
    flingPlayerBtns = {}

    local function UpdateFlingStatus()
        local cnt = 0; for _ in pairs(SelectedFlingTargets) do cnt+=1 end
        if FlingActive then flingStatusL.Text="Flinging "..cnt.."..."; flingStatusL.TextColor3=THEME.text; Smooth(flingDot,{BackgroundColor3=THEME.success},0.2)
        elseif cnt>0 then flingStatusL.Text="Selected: "..cnt; flingStatusL.TextColor3=THEME.textDim; Smooth(flingDot,{BackgroundColor3=THEME.textDim},0.2)
        else flingStatusL.Text="Select targets"; flingStatusL.TextColor3=THEME.textMuted; Smooth(flingDot,{BackgroundColor3=THEME.textMuted},0.2) end
    end

    local playerFrameData = {}

    local function RefreshFlingList()
        for _, b in pairs(flingPlayerBtns) do pcall(function() b:Destroy() end) end
        flingPlayerBtns={}; playerFrameData = {}

        local plrs = Players:GetPlayers()
        table.sort(plrs, function(a,b2) return a.Name:lower()<b2.Name:lower() end)

        for _, plr in ipairs(plrs) do
            if plr ~= LP then
                local isSel = SelectedFlingTargets[plr.Name] ~= nil
                local isAdmin = CheckIfAdmin(plr)

                local pF = Instance.new("Frame")
                pF.Size = UDim2.new(1,0,0,44)
                pF.BackgroundColor3 = THEME.backgroundLighter
                pF.BackgroundTransparency = isSel and 0.2 or 0.6
                pF.BorderSizePixel = 0
                pF.Parent = flingPlrCont
                Corner(pF,6)
                local pStroke = Stroke(pF, isSel and THEME.primary or THEME.border, 1, 0)

                local nL = Instance.new("TextLabel")
                nL.Size = UDim2.new(1,-50,0,16); nL.Position = UDim2.new(0,10,0,6)
                nL.BackgroundTransparency = 1; nL.Font = Enum.Font.GothamSemibold
                nL.Text = isAdmin and (plr.DisplayName.." [A]") or plr.DisplayName
                nL.TextColor3 = THEME.text; nL.TextSize = 12
                nL.TextXAlignment = Enum.TextXAlignment.Left; nL.Parent = pF

                local uL = Instance.new("TextLabel")
                uL.Size = UDim2.new(1,-50,0,12); uL.Position = UDim2.new(0,10,0,24)
                uL.BackgroundTransparency = 1; uL.Font = Enum.Font.Gotham
                uL.Text = "@"..plr.Name; uL.TextColor3 = THEME.textMuted; uL.TextSize = 9
                uL.TextXAlignment = Enum.TextXAlignment.Left; uL.Parent = pF

                local chk = Instance.new("Frame")
                chk.Size = UDim2.new(0,22,0,22); chk.Position = UDim2.new(1,-32,0.5,-11)
                chk.BackgroundColor3 = isSel and THEME.primary or THEME.backgroundLighter
                chk.BorderSizePixel = 0; chk.ZIndex = 213; chk.Parent = pF
                Corner(chk,5); Stroke(chk, THEME.border, 1, 0)

                local chkL = Instance.new("TextLabel")
                chkL.Size = UDim2.new(1,0,1,0); chkL.BackgroundTransparency = 1
                chkL.Font = Enum.Font.GothamBold; chkL.Text = isSel and "✓" or ""
                chkL.TextColor3 = THEME.text; chkL.TextSize = 13; chkL.ZIndex = 214; chkL.Parent = chk

                local clickArea = Instance.new("TextButton")
                clickArea.Size = UDim2.new(1,0,1,0); clickArea.BackgroundTransparency = 1
                clickArea.Text = ""; clickArea.ZIndex = 215; clickArea.Parent = pF

                local cp = plr; local cpName = plr.Name

                local function setSelected(sel)
                    if sel then
                        SelectedFlingTargets[cpName] = cp
                        Smooth(pF,{BackgroundTransparency=0.2},0.12)
                        Smooth(chk,{BackgroundColor3=THEME.primary},0.12)
                        Smooth(pStroke,{Color=THEME.primary},0.12)
                        chkL.Text="✓"
                    else
                        SelectedFlingTargets[cpName] = nil
                        Smooth(pF,{BackgroundTransparency=0.6},0.12)
                        Smooth(chk,{BackgroundColor3=THEME.backgroundLighter},0.12)
                        Smooth(pStroke,{Color=THEME.border},0.12)
                        chkL.Text=""
                    end
                    UpdateFlingStatus()
                end

                playerFrameData[cpName] = setSelected

                clickArea.MouseButton1Click:Connect(function()
                    setSelected(SelectedFlingTargets[cpName] == nil)
                end)
                clickArea.MouseEnter:Connect(function()
                    if not SelectedFlingTargets[cpName] then Smooth(pF,{BackgroundTransparency=0.4},0.08) end
                end)
                clickArea.MouseLeave:Connect(function()
                    if not SelectedFlingTargets[cpName] then Smooth(pF,{BackgroundTransparency=0.6},0.08) end
                end)

                table.insert(flingPlayerBtns, pF)
            end
        end

        if #flingPlayerBtns == 0 then
            local eL = Instance.new("TextLabel")
            eL.Size = UDim2.new(1,0,0,28); eL.BackgroundTransparency = 1
            eL.Font = Enum.Font.Gotham; eL.Text = "No other players"
            eL.TextColor3 = THEME.textMuted; eL.TextSize = 10; eL.Parent = flingPlrCont
            table.insert(flingPlayerBtns, eL)
        end
    end

    StartFBtn.MouseButton1Click:Connect(function()
        local cnt = 0; for _ in pairs(SelectedFlingTargets) do cnt+=1 end
        if cnt == 0 then Notify("Fling","Select targets first",2,"warning"); return end
        FlingActive = true; UpdateFlingStatus(); ShowBindIndicator("Fling"); Notify("Fling","Flinging "..cnt,2,"info")
        task.spawn(function()
            while FlingActive and Running do
                for n2, pl in pairs(SelectedFlingTargets) do if not pl or not pl.Parent then SelectedFlingTargets[n2]=nil end end
                local c2=0; for _ in pairs(SelectedFlingTargets) do c2+=1 end
                if c2==0 then FlingActive=false; break end
                UpdateFlingStatus()
                for _, pl in pairs(SelectedFlingTargets) do
                    if FlingActive and Running and pl and pl.Parent then
                        pcall(function() SkidFling(pl,State.FlingDuration) end); task.wait(0.15)
                    end
                end
                task.wait(0.2)
            end
            FlingActive=false; UpdateFlingStatus(); HideBindIndicator("Fling")
        end)
    end)

    StopFBtn.MouseButton1Click:Connect(function()
        FlingActive=false; UpdateFlingStatus(); HideBindIndicator("Fling"); Notify("Fling","Stopped",2,"info")
    end)

    selAllBtn.MouseButton1Click:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p~=LP then
                SelectedFlingTargets[p.Name]=p
                if playerFrameData[p.Name] then playerFrameData[p.Name](true) end
            end
        end
        UpdateFlingStatus()
    end)

    deselAllBtn.MouseButton1Click:Connect(function()
        SelectedFlingTargets={}
        for name, fn in pairs(playerFrameData) do fn(false) end
        UpdateFlingStatus()
    end)

    Players.PlayerAdded:Connect(function(p) task.wait(1); RefreshFlingList() end)
    Players.PlayerRemoving:Connect(function(p)
        task.wait(0.1); SelectedFlingTargets[p.Name] = nil
        RefreshFlingList(); UpdateFlingStatus()
    end)

    task.spawn(RefreshFlingList)
end

-- ============================================================
-- TELEPORT TAB (встроенный во вкладку как Fling)
-- ============================================================
local teleportStatusL, teleportStatusDot, teleportPlrCont, teleportPlayerBtns

do
    local TP = tabContents["Teleport"]

    local teleportStatusF = Instance.new("Frame")
    teleportStatusF.Size = UDim2.new(1,0,0,36)
    teleportStatusF.BackgroundColor3 = THEME.backgroundLighter
    teleportStatusF.BackgroundTransparency = 0.5
    teleportStatusF.BorderSizePixel = 0
    teleportStatusF.Parent = TP
    Corner(teleportStatusF,6)
    Stroke(teleportStatusF, THEME.border, 1, 0)

    teleportStatusDot = Instance.new("Frame")
    teleportStatusDot.Size = UDim2.new(0,5,0,5)
    teleportStatusDot.Position = UDim2.new(0,12,0.5,-2)
    teleportStatusDot.BackgroundColor3 = THEME.textMuted
    teleportStatusDot.BorderSizePixel = 0
    teleportStatusDot.Parent = teleportStatusF
    Corner(teleportStatusDot,3)

    teleportStatusL = Instance.new("TextLabel")
    teleportStatusL.Size = UDim2.new(1,-26,1,0)
    teleportStatusL.Position = UDim2.new(0,24,0,0)
    teleportStatusL.BackgroundTransparency = 1
    teleportStatusL.Font = Enum.Font.GothamMedium
    teleportStatusL.Text = "Select players"
    teleportStatusL.TextColor3 = THEME.textMuted
    teleportStatusL.TextSize = 11
    teleportStatusL.TextXAlignment = Enum.TextXAlignment.Left
    teleportStatusL.Parent = teleportStatusF

    SectionLabel(TP, "Controls")

    local function SmallBtn(parent, text, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.48,-3,0,28)
        b.BackgroundColor3 = color or THEME.backgroundLighter
        b.BackgroundTransparency = 0.5
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.TextColor3 = THEME.text
        b.TextSize = 10
        b.AutoButtonColor = false
        b.BorderSizePixel = 0
        b.Parent = parent
        Corner(b,6)
        Stroke(b, THEME.border, 1, 0)
        b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=0.2},0.1) end)
        b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=0.5},0.1) end)
        return b
    end

    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1,0,0,28)
    btnRow.BackgroundTransparency = 1
    btnRow.Parent = TP
    local btnLay = Instance.new("UIListLayout")
    btnLay.FillDirection = Enum.FillDirection.Horizontal
    btnLay.Padding = UDim.new(0,4)
    btnLay.Parent = btnRow

    local TeleportBtn = SmallBtn(btnRow, "Teleport", THEME.success)
    local LoopToggle = SmallBtn(btnRow, "Auto: OFF")

    local selRow = Instance.new("Frame")
    selRow.Size = UDim2.new(1,0,0,24)
    selRow.BackgroundTransparency = 1
    selRow.Parent = TP
    local selLay = Instance.new("UIListLayout")
    selLay.FillDirection = Enum.FillDirection.Horizontal
    selLay.Padding = UDim.new(0,4)
    selLay.Parent = selRow
    local selAllBtn = SmallBtn(selRow, "Select All")
    local deselAllBtn = SmallBtn(selRow, "Unselect All")

    SectionLabel(TP, "Players")
    teleportPlrCont = Instance.new("Frame")
    teleportPlrCont.Size = UDim2.new(1,0,0,0)
    teleportPlrCont.AutomaticSize = Enum.AutomaticSize.Y
    teleportPlrCont.BackgroundTransparency = 1
    teleportPlrCont.Parent = TP
    Instance.new("UIListLayout", teleportPlrCont).Padding = UDim.new(0,3)
    teleportPlayerBtns = {}

    local function UpdateTeleportStatus()
        local cnt = 0
        for _ in pairs(selectedTeleportPlayers) do cnt += 1 end
        if teleportLoopEnabled then
            teleportStatusL.Text = "Auto: " .. cnt
            teleportStatusL.TextColor3 = THEME.success
            Smooth(teleportStatusDot, {BackgroundColor3=THEME.success}, 0.2)
        elseif cnt > 0 then
            teleportStatusL.Text = "Selected: " .. cnt
            teleportStatusL.TextColor3 = THEME.textDim
            Smooth(teleportStatusDot, {BackgroundColor3=THEME.textDim}, 0.2)
        else
            teleportStatusL.Text = "Select players"
            teleportStatusL.TextColor3 = THEME.textMuted
            Smooth(teleportStatusDot, {BackgroundColor3=THEME.textMuted}, 0.2)
        end
    end

    local teleportFrameData = {}

    local function RefreshTeleportList()
        for _, b in pairs(teleportPlayerBtns) do pcall(function() b:Destroy() end) end
        teleportPlayerBtns = {}
        teleportFrameData = {}

        local plrs = Players:GetPlayers()
        table.sort(plrs, function(a,b) return a.Name:lower() < b.Name:lower() end)

        for _, plr in ipairs(plrs) do
            if plr ~= LP then
                local isSel = selectedTeleportPlayers[plr.Name] ~= nil
                local isAdmin = CheckIfAdmin(plr)

                local pF = Instance.new("Frame")
                pF.Size = UDim2.new(1,0,0,44)
                pF.BackgroundColor3 = THEME.backgroundLighter
                pF.BackgroundTransparency = isSel and 0.2 or 0.6
                pF.BorderSizePixel = 0
                pF.Parent = teleportPlrCont
                Corner(pF,6)
                local pStroke = Stroke(pF, isSel and THEME.primary or THEME.border, 1, 0)

                local nL = Instance.new("TextLabel")
                nL.Size = UDim2.new(1,-50,0,16)
                nL.Position = UDim2.new(0,10,0,6)
                nL.BackgroundTransparency = 1
                nL.Font = Enum.Font.GothamSemibold
                nL.Text = isAdmin and (plr.DisplayName.." [A]") or plr.DisplayName
                nL.TextColor3 = THEME.text
                nL.TextSize = 12
                nL.TextXAlignment = Enum.TextXAlignment.Left
                nL.Parent = pF

                local uL = Instance.new("TextLabel")
                uL.Size = UDim2.new(1,-50,0,12)
                uL.Position = UDim2.new(0,10,0,24)
                uL.BackgroundTransparency = 1
                uL.Font = Enum.Font.Gotham
                uL.Text = "@"..plr.Name
                uL.TextColor3 = THEME.textMuted
                uL.TextSize = 9
                uL.TextXAlignment = Enum.TextXAlignment.Left
                uL.Parent = pF

                local chk = Instance.new("Frame")
                chk.Size = UDim2.new(0,22,0,22)
                chk.Position = UDim2.new(1,-32,0.5,-11)
                chk.BackgroundColor3 = isSel and THEME.primary or THEME.backgroundLighter
                chk.BorderSizePixel = 0
                chk.ZIndex = 213
                chk.Parent = pF
                Corner(chk,5)
                Stroke(chk, THEME.border, 1, 0)

                local chkL = Instance.new("TextLabel")
                chkL.Size = UDim2.new(1,0,1,0)
                chkL.BackgroundTransparency = 1
                chkL.Font = Enum.Font.GothamBold
                chkL.Text = isSel and "✓" or ""
                chkL.TextColor3 = THEME.text
                chkL.TextSize = 13
                chkL.ZIndex = 214
                chkL.Parent = chk

                local clickArea = Instance.new("TextButton")
                clickArea.Size = UDim2.new(1,0,1,0)
                clickArea.BackgroundTransparency = 1
                clickArea.Text = ""
                clickArea.ZIndex = 215
                clickArea.Parent = pF

                local cp = plr
                local cpName = plr.Name

                local function setSelected(sel)
                    if sel then
                        selectedTeleportPlayers[cpName] = cp
                        Smooth(pF, {BackgroundTransparency=0.2}, 0.12)
                        Smooth(chk, {BackgroundColor3=THEME.primary}, 0.12)
                        Smooth(pStroke, {Color=THEME.primary}, 0.12)
                        chkL.Text = "✓"
                    else
                        selectedTeleportPlayers[cpName] = nil
                        Smooth(pF, {BackgroundTransparency=0.6}, 0.12)
                        Smooth(chk, {BackgroundColor3=THEME.backgroundLighter}, 0.12)
                        Smooth(pStroke, {Color=THEME.border}, 0.12)
                        chkL.Text = ""
                    end
                    UpdateTeleportStatus()
                end

                teleportFrameData[cpName] = setSelected

                clickArea.MouseButton1Click:Connect(function()
                    setSelected(selectedTeleportPlayers[cpName] == nil)
                end)

                clickArea.MouseEnter:Connect(function()
                    if not selectedTeleportPlayers[cpName] then
                        Smooth(pF, {BackgroundTransparency=0.4}, 0.08)
                    end
                end)

                clickArea.MouseLeave:Connect(function()
                    if not selectedTeleportPlayers[cpName] then
                        Smooth(pF, {BackgroundTransparency=0.6}, 0.08)
                    end
                end)

                table.insert(teleportPlayerBtns, pF)
            end
        end

        if #teleportPlayerBtns == 0 then
            local eL = Instance.new("TextLabel")
            eL.Size = UDim2.new(1,0,0,28)
            eL.BackgroundTransparency = 1
            eL.Font = Enum.Font.Gotham
            eL.Text = "No other players"
            eL.TextColor3 = THEME.textMuted
            eL.TextSize = 10
            eL.Parent = teleportPlrCont
            table.insert(teleportPlayerBtns, eL)
        end
    end

    local function TeleportPlayers()
        local localPlayer = LP
        if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return
        end
        local hrp = localPlayer.Character.HumanoidRootPart
        local distance = 3
        for pname, player in pairs(selectedTeleportPlayers) do
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 0, -distance)
            end
        end
    end

    TeleportBtn.MouseButton1Click:Connect(function()
        local cnt = 0
        for _ in pairs(selectedTeleportPlayers) do cnt += 1 end
        if cnt == 0 then
            Notify("Teleport", "Select players first", 2, "warning")
            return
        end
        TeleportPlayers()
        Notify("Teleport", "Teleported " .. cnt, 2, "success")
    end)

    LoopToggle.MouseButton1Click:Connect(function()
        teleportLoopEnabled = not teleportLoopEnabled
        if teleportLoopEnabled then
            LoopToggle.Text = "Auto: ON"
            Smooth(LoopToggle, {BackgroundColor3=THEME.success}, 0.15)
            if teleportLoopConnection then
                pcall(function() teleportLoopConnection:Disconnect() end)
                teleportLoopConnection = nil
            end
            teleportLoopConnection = RS.Heartbeat:Connect(function()
                if teleportLoopEnabled and Running then
                    TeleportPlayers()
                end
            end)
            table.insert(allConnections, teleportLoopConnection)
            Notify("Teleport", "Auto enabled", 2, "success")
        else
            LoopToggle.Text = "Auto: OFF"
            Smooth(LoopToggle, {BackgroundColor3=THEME.backgroundLighter}, 0.15)
            if teleportLoopConnection then
                pcall(function() teleportLoopConnection:Disconnect() end)
                teleportLoopConnection = nil
            end
            Notify("Teleport", "Auto disabled", 2, "info")
        end
        UpdateTeleportStatus()
    end)

    selAllBtn.MouseButton1Click:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                selectedTeleportPlayers[p.Name] = p
                if teleportFrameData[p.Name] then
                    teleportFrameData[p.Name](true)
                end
            end
        end
        UpdateTeleportStatus()
    end)

    deselAllBtn.MouseButton1Click:Connect(function()
        selectedTeleportPlayers = {}
        for name, fn in pairs(teleportFrameData) do
            fn(false)
        end
        UpdateTeleportStatus()
    end)

    Players.PlayerAdded:Connect(function(p)
        task.wait(1)
        RefreshTeleportList()
    end)

    Players.PlayerRemoving:Connect(function(p)
        task.wait(0.1)
        selectedTeleportPlayers[p.Name] = nil
        RefreshTeleportList()
        UpdateTeleportStatus()
    end)

    task.spawn(RefreshTeleportList)
end

-- VOID TAB
local voidStatusL2, voidStatusDot2

do
    local VP = tabContents["Void"]

    local voidStatusF = Instance.new("Frame")
    voidStatusF.Size = UDim2.new(1,0,0,36); voidStatusF.BackgroundColor3 = THEME.backgroundLighter
    voidStatusF.BackgroundTransparency = 0.5; voidStatusF.BorderSizePixel = 0; voidStatusF.Parent = VP
    Corner(voidStatusF,6); Stroke(voidStatusF, THEME.border, 1, 0)
    voidStatusDot2 = Instance.new("Frame"); voidStatusDot2.Size = UDim2.new(0,5,0,5); voidStatusDot2.Position = UDim2.new(0,12,0.5,-2); voidStatusDot2.BackgroundColor3 = THEME.textMuted; voidStatusDot2.BorderSizePixel = 0; voidStatusDot2.Parent = voidStatusF; Corner(voidStatusDot2,3)
    voidStatusL2 = Instance.new("TextLabel"); voidStatusL2.Size = UDim2.new(1,-26,1,0); voidStatusL2.Position = UDim2.new(0,24,0,0); voidStatusL2.BackgroundTransparency = 1; voidStatusL2.Font = Enum.Font.GothamMedium; voidStatusL2.Text = "Above ground"; voidStatusL2.TextColor3 = THEME.textMuted; voidStatusL2.TextSize = 11; voidStatusL2.TextXAlignment = Enum.TextXAlignment.Left; voidStatusL2.Parent = voidStatusF

    SectionLabel(VP, "Depth")
    Slider(VP, "Y Offset", -500, -10, voidYOffset, function(v)
        voidYOffset = v; if voidActive then local ly=FindLowestY(); voidTargetY=ly+voidYOffset end
    end)

    SectionLabel(VP, "Controls")
    local vBtnRow = Instance.new("Frame"); vBtnRow.Size = UDim2.new(1,0,0,28); vBtnRow.BackgroundTransparency = 1; vBtnRow.Parent = VP
    local vBtnLay = Instance.new("UIListLayout"); vBtnLay.FillDirection = Enum.FillDirection.Horizontal; vBtnLay.Padding = UDim.new(0,6); vBtnLay.Parent = vBtnRow

    local function VBtn(parent, text)
        local b = Instance.new("TextButton"); b.Size = UDim2.new(0.48,-3,0,28); b.BackgroundColor3 = THEME.backgroundLighter; b.BackgroundTransparency = 0.5; b.Font = Enum.Font.GothamBold; b.Text = text; b.TextColor3 = THEME.text; b.TextSize = 10; b.AutoButtonColor = false; b.BorderSizePixel = 0; b.Parent = parent; Corner(b,6); Stroke(b,THEME.border,1,0)
        b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=0.2},0.1) end)
        b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=0.5},0.1) end)
        return b
    end

    local voidGoBtn = VBtn(vBtnRow, "Go Under")
    local voidBackBtn = VBtn(vBtnRow, "Return")
    voidGoBtn.MouseButton1Click:Connect(function() if voidActive then Notify("Void","Already under",2,"warning"); return end; StartVoid() end)
    voidBackBtn.MouseButton1Click:Connect(function() if not voidActive then Notify("Void","Not under map",2,"info"); return end; StopVoid() end)
end

UpdateVoidStatus = function()
    if not voidStatusL2 or not voidStatusDot2 then return end
    if voidActive then
        voidStatusL2.Text="Under map"; voidStatusL2.TextColor3=THEME.success; Smooth(voidStatusDot2,{BackgroundColor3=THEME.success},0.2)
    else
        voidStatusL2.Text="Above ground"; voidStatusL2.TextColor3=THEME.textMuted; Smooth(voidStatusDot2,{BackgroundColor3=THEME.textMuted},0.2)
    end
end

-- ADMIN TAB
local adminListCont, adminListItems, adminStatusL2

do
    local AP = tabContents["Admin"]

    local adminStatusF = Instance.new("Frame")
    adminStatusF.Size = UDim2.new(1,0,0,36); adminStatusF.BackgroundColor3 = THEME.backgroundLighter
    adminStatusF.BackgroundTransparency = 0.5; adminStatusF.BorderSizePixel = 0; adminStatusF.Parent = AP
    Corner(adminStatusF,6); Stroke(adminStatusF, THEME.border, 1, 0)
    adminStatusL2 = Instance.new("TextLabel"); adminStatusL2.Size = UDim2.new(1,-16,1,0); adminStatusL2.Position = UDim2.new(0,12,0,0); adminStatusL2.BackgroundTransparency = 1; adminStatusL2.Font = Enum.Font.GothamMedium; adminStatusL2.Text = "Scanning..."; adminStatusL2.TextColor3 = THEME.textMuted; adminStatusL2.TextSize = 11; adminStatusL2.TextXAlignment = Enum.TextXAlignment.Left; adminStatusL2.Parent = adminStatusF

    SectionLabel(AP, "Settings")

    local function AdminTog(parent, name, defVal, cb)
        local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,38); f.BackgroundColor3 = THEME.backgroundLighter; f.BackgroundTransparency = 0.5; f.BorderSizePixel = 0; f.Parent = parent; Corner(f,6); Stroke(f,THEME.border,1,0)
        local nL = Instance.new("TextLabel"); nL.Size = UDim2.new(1,-60,0,16); nL.Position = UDim2.new(0,10,0.5,-8); nL.BackgroundTransparency = 1; nL.Font = Enum.Font.GothamSemibold; nL.Text = name; nL.TextColor3 = THEME.text; nL.TextSize = 11; nL.TextXAlignment = Enum.TextXAlignment.Left; nL.Parent = f
        local tBg = Instance.new("Frame"); tBg.Size = UDim2.new(0,36,0,20); tBg.Position = UDim2.new(1,-44,0.5,-10); tBg.BackgroundColor3 = THEME.backgroundLighter; tBg.BorderSizePixel = 0; tBg.Parent = f; Corner(tBg,10)
        local tSt = Instance.new("UIStroke"); tSt.Thickness = 1; tSt.Color = defVal and THEME.primary or THEME.border; tSt.Parent = tBg
        local tK = Instance.new("Frame"); tK.Size = UDim2.new(0,16,0,16); tK.Position = defVal and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2); tK.BackgroundColor3 = defVal and THEME.primary or THEME.textMuted; tK.BorderSizePixel = 0; tK.Parent = tBg; Corner(tK,8)
        local en = defVal
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = f
        btn.MouseButton1Click:Connect(function()
            en = not en
            Smooth(tBg, {BackgroundColor3 = THEME.backgroundLighter}, 0.18)
            Smooth(tSt, {Color = en and THEME.primary or THEME.border}, 0.18)
            Tween(tK, {Position = en and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)}, 0.2, Enum.EasingStyle.Back)
            Smooth(tK, {BackgroundColor3 = en and THEME.primary or THEME.textMuted}, 0.18)
            cb(en); SaveSettings()
        end)
        f.MouseEnter:Connect(function() Smooth(f,{BackgroundTransparency=0.3},0.1) end)
        f.MouseLeave:Connect(function() Smooth(f,{BackgroundTransparency=0.5},0.1) end)
    end

    AdminTog(AP, "Join Alerts", AdminAlertEnabled, function(v) AdminAlertEnabled = v end)
    AdminTog(AP, "ESP Highlight", AdminESPEnabled, function(v) AdminESPEnabled = v; if State.ESP then pcall(UpdateESP) end end)

    SectionLabel(AP, "Admins In Server")
    adminListCont = Instance.new("Frame"); adminListCont.Size = UDim2.new(1,0,0,0); adminListCont.AutomaticSize = Enum.AutomaticSize.Y; adminListCont.BackgroundTransparency = 1; adminListCont.Parent = AP; Instance.new("UIListLayout",adminListCont).Padding = UDim.new(0,4)
    adminListItems = {}
end

local function RefreshAdminList()
    for _, item in pairs(adminListItems) do pcall(function() item:Destroy() end) end; adminListItems = {}
    local adminCount = 0
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LP then
            local isAdmin, rank = CheckIfAdmin(plr)
            if isAdmin then
                adminCount += 1
                local aF = Instance.new("Frame"); aF.Size = UDim2.new(1,0,0,56); aF.BackgroundColor3 = THEME.backgroundLighter; aF.BackgroundTransparency = 0.5; aF.BorderSizePixel = 0; aF.Parent = adminListCont; Corner(aF,6); Stroke(aF,THEME.border,1,0)
                local strip = Instance.new("Frame"); strip.Size = UDim2.new(0,3,0.7,0); strip.Position = UDim2.new(0,0,0.15,0); strip.BackgroundColor3 = Color3.fromRGB(185,148,55); strip.BorderSizePixel = 0; strip.Parent = aF; Corner(strip,2)
                local nL = Instance.new("TextLabel"); nL.Size = UDim2.new(1,-16,0,16); nL.Position = UDim2.new(0,14,0,6); nL.BackgroundTransparency = 1; nL.Font = Enum.Font.GothamBold; nL.Text = plr.DisplayName; nL.TextColor3 = THEME.text; nL.TextSize = 11; nL.TextXAlignment = Enum.TextXAlignment.Left; nL.Parent = aF
                local uL = Instance.new("TextLabel"); uL.Size = UDim2.new(1,-16,0,11); uL.Position = UDim2.new(0,14,0,24); uL.BackgroundTransparency = 1; uL.Font = Enum.Font.Gotham; uL.Text = "@"..plr.Name; uL.TextColor3 = THEME.textMuted; uL.TextSize = 9; uL.TextXAlignment = Enum.TextXAlignment.Left; uL.Parent = aF
                local rL = Instance.new("TextLabel"); rL.Size = UDim2.new(1,-16,0,11); rL.Position = UDim2.new(0,14,0,37); rL.BackgroundTransparency = 1; rL.Font = Enum.Font.GothamBold; rL.Text = "Rank: "..tostring(rank); rL.TextColor3 = Color3.fromRGB(185,148,55); rL.TextSize = 9; rL.TextXAlignment = Enum.TextXAlignment.Left; rL.Parent = aF
                table.insert(adminListItems, aF)
            end
        end
    end
    if adminCount == 0 then
        local eL = Instance.new("Frame"); eL.Size = UDim2.new(1,0,0,36); eL.BackgroundColor3 = THEME.backgroundLighter; eL.BackgroundTransparency = 0.5; eL.BorderSizePixel = 0; eL.Parent = adminListCont; Corner(eL,6); Stroke(eL,THEME.border,1,0)
        local eLT = Instance.new("TextLabel"); eLT.Size = UDim2.new(1,0,1,0); eLT.BackgroundTransparency = 1; eLT.Font = Enum.Font.GothamMedium; eLT.Text = "No admins detected"; eLT.TextColor3 = THEME.textMuted; eLT.TextSize = 10; eLT.Parent = eL; table.insert(adminListItems, eL)
        if adminStatusL2 then adminStatusL2.Text = "No admins detected"; adminStatusL2.TextColor3 = THEME.textMuted end
    else
        if adminStatusL2 then adminStatusL2.Text = adminCount.." admin(s) in server"; adminStatusL2.TextColor3 = THEME.textDim end
    end

    RefreshAdminWindow()
end

-- SETTINGS TAB
do
    local SP = tabContents["Settings"]
    SectionLabel(SP, "Menu")

    local keyCard = Instance.new("Frame"); keyCard.Size = UDim2.new(1,0,0,46); keyCard.BackgroundColor3 = THEME.backgroundLighter; keyCard.BackgroundTransparency = 0.5; keyCard.BorderSizePixel = 0; keyCard.Parent = SP; Corner(keyCard,6); Stroke(keyCard,THEME.border,1,0)
    local keyTitle = Instance.new("TextLabel"); keyTitle.Size = UDim2.new(0.6,0,0,16); keyTitle.Position = UDim2.new(0,10,0,6); keyTitle.BackgroundTransparency = 1; keyTitle.Font = Enum.Font.GothamSemibold; keyTitle.Text = "Menu Toggle Key"; keyTitle.TextColor3 = THEME.text; keyTitle.TextSize = 11; keyTitle.TextXAlignment = Enum.TextXAlignment.Left; keyTitle.Parent = keyCard
    local keyDesc = Instance.new("TextLabel"); keyDesc.Size = UDim2.new(0.6,0,0,11); keyDesc.Position = UDim2.new(0,10,0,26); keyDesc.BackgroundTransparency = 1; keyDesc.Font = Enum.Font.Gotham; keyDesc.Text = "Click to change"; keyDesc.TextColor3 = THEME.textMuted; keyDesc.TextSize = 9; keyDesc.TextXAlignment = Enum.TextXAlignment.Left; keyDesc.Parent = keyCard
    local keyBadge = Instance.new("TextButton"); keyBadge.Size = UDim2.new(0,80,0,24); keyBadge.Position = UDim2.new(1,-90,0.5,-12); keyBadge.BackgroundColor3 = THEME.backgroundLighter; keyBadge.Font = Enum.Font.GothamBold; keyBadge.Text = MenuToggleKey; keyBadge.TextColor3 = THEME.textDim; keyBadge.TextSize = 10; keyBadge.AutoButtonColor = false; keyBadge.Parent = keyCard; Corner(keyBadge,6); Stroke(keyBadge,THEME.border,1,0)
    keyCard.MouseEnter:Connect(function() Smooth(keyCard,{BackgroundTransparency=0.3},0.1) end)
    keyCard.MouseLeave:Connect(function() Smooth(keyCard,{BackgroundTransparency=0.5},0.1) end)
    keyBadge.MouseEnter:Connect(function() if not isWaitingForKey then Smooth(keyBadge,{BackgroundTransparency=0.3,TextColor3=THEME.text},0.1) end end)
    keyBadge.MouseLeave:Connect(function() if not isWaitingForKey then Smooth(keyBadge,{BackgroundTransparency=0.5,TextColor3=THEME.textDim},0.1) end end)
    keyBadge.MouseButton1Click:Connect(function()
        if isWaitingForKey then return end
        isWaitingForKey = true; keyBadge.Text = "..."; keyBadge.TextColor3 = THEME.primary; Smooth(keyBadge,{BackgroundTransparency=0.2},0.1)
        local kconn; kconn = UIS.InputBegan:Connect(function(i2,gp2)
            if gp2 then return end
            if i2.UserInputType == Enum.UserInputType.Keyboard then
                if i2.KeyCode == Enum.KeyCode.Escape then
                    isWaitingForKey=false; keyBadge.Text=MenuToggleKey; keyBadge.TextColor3=THEME.textDim; Smooth(keyBadge,{BackgroundTransparency=0.5},0.1); kconn:Disconnect(); return
                end
                local kn2 = tostring(i2.KeyCode):gsub("Enum.KeyCode.","")
                MenuToggleKey = kn2; keyBadge.Text = kn2; keyBadge.TextColor3 = THEME.textDim
                Smooth(keyBadge,{BackgroundTransparency=0.5},0.1); isWaitingForKey=false; kconn:Disconnect()
                SaveSettings(); Notify("Settings","Menu key → ["..kn2.."]",2,"success")
            end
        end)
    end)

    local snowCard = Instance.new("Frame"); snowCard.Size = UDim2.new(1,0,0,46); snowCard.BackgroundColor3 = THEME.backgroundLighter; snowCard.BackgroundTransparency = 0.5; snowCard.BorderSizePixel = 0; snowCard.Parent = SP; Corner(snowCard,6); Stroke(snowCard,THEME.border,1,0)
    local snowTitle = Instance.new("TextLabel"); snowTitle.Size = UDim2.new(0.6,0,0,16); snowTitle.Position = UDim2.new(0,10,0,6); snowTitle.BackgroundTransparency = 1; snowTitle.Font = Enum.Font.GothamSemibold; snowTitle.Text = "Snow Effect"; snowTitle.TextColor3 = THEME.text; snowTitle.TextSize = 11; snowTitle.TextXAlignment = Enum.TextXAlignment.Left; snowTitle.Parent = snowCard
    local snowDesc = Instance.new("TextLabel"); snowDesc.Size = UDim2.new(0.6,0,0,11); snowDesc.Position = UDim2.new(0,10,0,26); snowDesc.BackgroundTransparency = 1; snowDesc.Font = Enum.Font.Gotham; snowDesc.Text = "Falling snow in menu"; snowDesc.TextColor3 = THEME.textMuted; snowDesc.TextSize = 9; snowDesc.TextXAlignment = Enum.TextXAlignment.Left; snowDesc.Parent = snowCard

    local sBg = Instance.new("Frame"); sBg.Size = UDim2.new(0,36,0,20); sBg.Position = UDim2.new(1,-44,0.5,-10); sBg.BackgroundColor3 = THEME.backgroundLighter; sBg.BorderSizePixel = 0; sBg.Parent = snowCard; Corner(sBg,10)
    local sSt = Instance.new("UIStroke"); sSt.Thickness = 1; sSt.Color = snowEnabled and THEME.primary or THEME.border; sSt.Parent = sBg
    local sK = Instance.new("Frame"); sK.Size = UDim2.new(0,16,0,16); sK.Position = snowEnabled and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2); sK.BackgroundColor3 = snowEnabled and THEME.primary or THEME.textMuted; sK.BorderSizePixel = 0; sK.ZIndex = 213; sK.Parent = sBg; Corner(sK,8)
    local sBtn = Instance.new("TextButton"); sBtn.Size = UDim2.new(0,36,0,20); sBtn.Position = UDim2.new(1,-44,0.5,-10); sBtn.BackgroundTransparency = 1; sBtn.Text = ""; sBtn.ZIndex = 215; sBtn.Parent = snowCard
    snowCard.MouseEnter:Connect(function() Smooth(snowCard,{BackgroundTransparency=0.3},0.1) end)
    snowCard.MouseLeave:Connect(function() Smooth(snowCard,{BackgroundTransparency=0.5},0.1) end)
    sBtn.MouseButton1Click:Connect(function()
        snowEnabled = not snowEnabled
        Smooth(sBg, {BackgroundColor3 = THEME.backgroundLighter}, 0.18)
        Smooth(sSt, {Color = snowEnabled and THEME.primary or THEME.border}, 0.18)
        Tween(sK, {Position = snowEnabled and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)}, 0.2, Enum.EasingStyle.Back)
        Smooth(sK, {BackgroundColor3 = snowEnabled and THEME.primary or THEME.textMuted}, 0.18)
        if snowEnabled then
            createSnowContainer(menuFrame)
        else
            if snowContainer and snowContainer.Parent then
                for _, child in pairs(snowContainer:GetChildren()) do child:Destroy() end
            end
            snowParticles = {}
        end
        SaveSettings()
        Notify("Snow", snowEnabled and "Enabled" or "Disabled", 2, snowEnabled and "success" or "info")
    end)

    SectionLabel(SP, "Accent Color")

    local colorCard = Instance.new("Frame"); colorCard.Size = UDim2.new(1,0,0,56); colorCard.BackgroundColor3 = THEME.backgroundLighter; colorCard.BackgroundTransparency = 0.5; colorCard.BorderSizePixel = 0; colorCard.Parent = SP; Corner(colorCard,6); Stroke(colorCard,THEME.border,1,0)
    local colorLabel = Instance.new("TextLabel"); colorLabel.Size = UDim2.new(1,-60,0,16); colorLabel.Position = UDim2.new(0,10,0,4); colorLabel.BackgroundTransparency = 1; colorLabel.Font = Enum.Font.GothamSemibold; colorLabel.Text = "Hue"; colorLabel.TextColor3 = THEME.text; colorLabel.TextSize = 10; colorLabel.TextXAlignment = Enum.TextXAlignment.Left; colorLabel.Parent = colorCard
    local preview = Instance.new("Frame"); preview.Size = UDim2.new(0,16,0,16); preview.Position = UDim2.new(1,-26,0,4); preview.BackgroundColor3 = THEME.primary; preview.BorderSizePixel = 0; preview.Parent = colorCard; Corner(preview,4); Stroke(preview,THEME.border,1,0)

    local hueTrack = Instance.new("Frame"); hueTrack.Size = UDim2.new(1,-20,0,10); hueTrack.Position = UDim2.new(0,10,0,24); hueTrack.BackgroundColor3 = Color3.new(1,1,1); hueTrack.BorderSizePixel = 0; hueTrack.Parent = colorCard; Corner(hueTrack,3)
    local hueGrad = Instance.new("UIGradient"); hueGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
        ColorSequenceKeypoint.new(0.16, Color3.fromHSV(0.16,1,1)),
        ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33,1,1)),
        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5,1,1)),
        ColorSequenceKeypoint.new(0.66, Color3.fromHSV(0.66,1,1)),
        ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83,1,1)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1))
    }); hueGrad.Parent = hueTrack

    local hueKnob = Instance.new("Frame"); hueKnob.Size = UDim2.new(0,12,0,14); hueKnob.Position = UDim2.new(state_theme.themeHue,-6,0.5,-7); hueKnob.BackgroundColor3 = THEME.text; hueKnob.BorderSizePixel = 0; hueKnob.ZIndex = 3; hueKnob.Parent = hueTrack; Corner(hueKnob,3); Stroke(hueKnob,Color3.new(0,0,0),1,0)

    local svTrack = Instance.new("Frame"); svTrack.Size = UDim2.new(1,-20,0,10); svTrack.Position = UDim2.new(0,10,0,40); svTrack.BackgroundColor3 = Color3.new(1,1,1); svTrack.BorderSizePixel = 0; svTrack.Parent = colorCard; Corner(svTrack,3)
    local svGrad = Instance.new("UIGradient"); svGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(state_theme.themeHue,0.8,1)),
        ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
    }); svGrad.Parent = svTrack

    local initSVPct = 0.5
    local svKnob = Instance.new("Frame"); svKnob.Size = UDim2.new(0,12,0,14); svKnob.Position = UDim2.new(initSVPct,-6,0.5,-7); svKnob.BackgroundColor3 = THEME.text; svKnob.BorderSizePixel = 0; svKnob.ZIndex = 3; svKnob.Parent = svTrack; Corner(svKnob,3); Stroke(svKnob,Color3.new(0,0,0),1,0)

    local function updateColorPreview()
        local col = Color3.fromHSV(state_theme.themeHue, state_theme.themeSat, state_theme.themeVal)
        preview.BackgroundColor3 = col
        svGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV(state_theme.themeHue,0.8,1)),
            ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
        })
        updateThemeColors()
        SaveSettings()
    end

    local function applyHue(x)
        local aP, aS = hueTrack.AbsolutePosition.X, hueTrack.AbsoluteSize.X
        if aS > 0 then
            local pct = math.clamp((x-aP)/aS, 0, 0.999)
            state_theme.themeHue = pct
            hueKnob.Position = UDim2.new(pct,-6,0.5,-7)
            updateColorPreview()
        end
    end
    local function applySV(x)
        local aP, aS = svTrack.AbsolutePosition.X, svTrack.AbsoluteSize.X
        if aS > 0 then
            local pct = math.clamp((x-aP)/aS, 0, 1)
            svKnob.Position = UDim2.new(pct,-6,0.5,-7)
            local sat, val
            if pct <= 0.5 then sat = 0.8; val = pct*2 else sat = 1-(pct-0.5)*2; val = 1 end
            state_theme.themeSat = math.clamp(sat,0,1)
            state_theme.themeVal = math.clamp(val,0,1)
            updateColorPreview()
        end
    end

    local hueBtn = Instance.new("TextButton"); hueBtn.Size = UDim2.new(1,0,5,0); hueBtn.Position = UDim2.new(0,0,-2,0); hueBtn.BackgroundTransparency = 1; hueBtn.Text = ""; hueBtn.Parent = hueTrack; hueBtn.ZIndex = 5
    hueBtn.MouseButton1Down:Connect(function()
        Smooth(hueKnob, {Size=UDim2.new(0,14,0,14)}, 0.06)
        applyHue(UIS:GetMouseLocation().X)
        activeSliderDrag = {track=hueTrack, apply=applyHue, knob=hueKnob}
    end)

    local svBtn = Instance.new("TextButton"); svBtn.Size = UDim2.new(1,0,5,0); svBtn.Position = UDim2.new(0,0,-2,0); svBtn.BackgroundTransparency = 1; svBtn.Text = ""; svBtn.Parent = svTrack; svBtn.ZIndex = 5
    svBtn.MouseButton1Down:Connect(function()
        Smooth(svKnob, {Size=UDim2.new(0,14,0,14)}, 0.06)
        applySV(UIS:GetMouseLocation().X)
        activeSliderDrag = {track=svTrack, apply=applySV, knob=svKnob}
    end)

    SectionLabel(SP, "Unload")

    local unloadCard = Instance.new("Frame"); unloadCard.Size = UDim2.new(1,0,0,46); unloadCard.BackgroundColor3 = THEME.backgroundLighter; unloadCard.BackgroundTransparency = 0.5; unloadCard.BorderSizePixel = 0; unloadCard.Parent = SP; Corner(unloadCard,6); Stroke(unloadCard,THEME.danger,1,0.5)
    local unloadTitle = Instance.new("TextLabel"); unloadTitle.Size = UDim2.new(0.6,0,0,16); unloadTitle.Position = UDim2.new(0,10,0,6); unloadTitle.BackgroundTransparency = 1; unloadTitle.Font = Enum.Font.GothamBold; unloadTitle.Text = "Unload Script"; unloadTitle.TextColor3 = THEME.danger; unloadTitle.TextSize = 12; unloadTitle.TextXAlignment = Enum.TextXAlignment.Left; unloadTitle.Parent = unloadCard
    local unloadDesc = Instance.new("TextLabel"); unloadDesc.Size = UDim2.new(0.6,0,0,11); unloadDesc.Position = UDim2.new(0,10,0,26); unloadDesc.BackgroundTransparency = 1; unloadDesc.Font = Enum.Font.Gotham; unloadDesc.Text = "Remove script completely"; unloadDesc.TextColor3 = THEME.textMuted; unloadDesc.TextSize = 9; unloadDesc.TextXAlignment = Enum.TextXAlignment.Left; unloadDesc.Parent = unloadCard
    local unloadBtn = Instance.new("TextButton"); unloadBtn.Size = UDim2.new(0,72,0,26); unloadBtn.Position = UDim2.new(1,-82,0.5,-13); unloadBtn.BackgroundColor3 = THEME.danger; unloadBtn.BackgroundTransparency = 0.2; unloadBtn.Font = Enum.Font.GothamBold; unloadBtn.Text = "Unload"; unloadBtn.TextColor3 = THEME.text; unloadBtn.TextSize = 10; unloadBtn.AutoButtonColor = false; unloadBtn.Parent = unloadCard; Corner(unloadBtn,6); Stroke(unloadBtn,THEME.danger,1,0.3)
    unloadBtn.MouseEnter:Connect(function() Smooth(unloadBtn,{BackgroundTransparency=0},0.1) end)
    unloadBtn.MouseLeave:Connect(function() Smooth(unloadBtn,{BackgroundTransparency=0.2},0.1) end)
    unloadBtn.MouseButton1Click:Connect(function()
        Running=false; FlingActive=false; voidActive=false; StopNoclip(); StopFly(); ClearESP()
        if voidConnection then pcall(function() voidConnection:Disconnect() end) end
        if teleportLoopConnection then pcall(function() teleportLoopConnection:Disconnect() end) end
        for _, cn in pairs(allConnections) do pcall(function() cn:Disconnect() end) end
        local h = GetHum(); if h then h.WalkSpeed=16; h.JumpPower=50 end
        for _, item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end
        if LP.Character then for _, item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end
        pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end); RemoveBlur()
        Notify("QWEN","Unloaded",2,"error")
        task.delay(0.6, function()
            for _, g in pairs(game.CoreGui:GetChildren()) do
                if g.Name:find("QWEN") then pcall(function() g:Destroy() end) end
            end
        end)
    end)
end

-- FOOTER
do
    local footer = Instance.new("Frame")
    footer.Size = UDim2.new(1,-8,0,20); footer.Position = UDim2.new(0,4,1,-24)
    footer.BackgroundColor3 = THEME.backgroundLight; footer.BackgroundTransparency = 0.5
    footer.BorderSizePixel = 0; footer.ZIndex = 210; footer.Parent = menuFrame
    Corner(footer, 4)

    local ft = Instance.new("TextLabel")
    ft.Size = UDim2.new(1,-14,1,0); ft.Position = UDim2.new(0,7,0,0)
    ft.BackgroundTransparency = 1; ft.Font = Enum.Font.Gotham
    ft.Text = "QWEN  •  Press "..MenuToggleKey.." to toggle"
    ft.TextColor3 = THEME.textMuted; ft.TextSize = 8; ft.ZIndex = 211; ft.Parent = footer

    local sd = Instance.new("Frame")
    sd.Size = UDim2.new(0,6,0,6); sd.Position = UDim2.new(1,-14,0.5,-3)
    sd.BackgroundColor3 = THEME.success; sd.BorderSizePixel = 0; sd.ZIndex = 211; sd.Parent = footer
    Corner(sd, 3)
end

-- HUD
do
    local HUDSG = Instance.new("ScreenGui")
    HUDSG.Name = "QWENHUD"
    HUDSG.Parent = game.CoreGui
    HUDSG.ResetOnSpawn = false
    HUDSG.IgnoreGuiInset = true

    local HUD = Instance.new("Frame")
    HUD.Size = UDim2.new(0, 260, 0, 28)
    HUD.Position = LoadHUDPos()
    HUD.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    HUD.BackgroundTransparency = 0.25
    HUD.BorderSizePixel = 0
    HUD.Active = true
    HUD.Parent = HUDSG
    Corner(HUD, 14)

    local hudStroke = Instance.new("UIStroke")
    hudStroke.Thickness = 1
    hudStroke.Color = Color3.fromRGB(40, 40, 55)
    hudStroke.Transparency = 0.4
    hudStroke.Parent = HUD

    local hudDrag = false; local hudDragStart, hudStartPos
    HUD.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            hudDrag = true; hudDragStart = i.Position; hudStartPos = HUD.Position
        end
    end)
    HUD.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            hudDrag = false; SaveHUDPos(HUD.Position)
        end
    end)
    table.insert(allConnections, UIS.InputChanged:Connect(function(i)
        if hudDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - hudDragStart
            HUD.Position = UDim2.new(hudStartPos.X.Scale, hudStartPos.X.Offset+d.X, hudStartPos.Y.Scale, hudStartPos.Y.Offset+d.Y)
        end
    end))

    local hudInner = Instance.new("Frame")
    hudInner.Size = UDim2.new(1,-16,1,0)
    hudInner.Position = UDim2.new(0,8,0,0)
    hudInner.BackgroundTransparency = 1
    hudInner.Parent = HUD

    local hudLogo = Instance.new("TextLabel")
    hudLogo.Size = UDim2.new(0,32,1,0)
    hudLogo.Position = UDim2.new(0,0,0,0)
    hudLogo.BackgroundTransparency = 1
    hudLogo.Font = Enum.Font.GothamBlack
    hudLogo.Text = "Q"
    hudLogo.TextColor3 = Color3.fromRGB(180,180,200)
    hudLogo.TextSize = 13
    hudLogo.ZIndex = 2
    hudLogo.Parent = hudInner

    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(0,1,0.6,0); sep1.Position = UDim2.new(0,30,0.2,0)
    sep1.BackgroundColor3 = Color3.fromRGB(50,50,65); sep1.BackgroundTransparency = 0.3; sep1.BorderSizePixel = 0; sep1.Parent = hudInner

    local hFPSLabel = Instance.new("TextLabel")
    hFPSLabel.Size = UDim2.new(0,18,0,10); hFPSLabel.Position = UDim2.new(0,36,0,3)
    hFPSLabel.BackgroundTransparency = 1; hFPSLabel.Font = Enum.Font.GothamBold
    hFPSLabel.Text = "FPS"; hFPSLabel.TextColor3 = Color3.fromRGB(100,100,120); hFPSLabel.TextSize = 7; hFPSLabel.ZIndex = 2; hFPSLabel.Parent = hudInner

    local hFPS = Instance.new("TextLabel")
    hFPS.Size = UDim2.new(0,30,0,12); hFPS.Position = UDim2.new(0,36,0,13)
    hFPS.BackgroundTransparency = 1; hFPS.Font = Enum.Font.GothamBold
    hFPS.Text = "60"; hFPS.TextColor3 = Color3.fromRGB(34,197,94); hFPS.TextSize = 11; hFPS.ZIndex = 2; hFPS.Parent = hudInner

    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(0,1,0.6,0); sep2.Position = UDim2.new(0,72,0.2,0)
    sep2.BackgroundColor3 = Color3.fromRGB(50,50,65); sep2.BackgroundTransparency = 0.3; sep2.BorderSizePixel = 0; sep2.Parent = hudInner

    local hSessLabel = Instance.new("TextLabel")
    hSessLabel.Size = UDim2.new(0,40,0,10); hSessLabel.Position = UDim2.new(0,78,0,3)
    hSessLabel.BackgroundTransparency = 1; hSessLabel.Font = Enum.Font.GothamBold
    hSessLabel.Text = "SESSION"; hSessLabel.TextColor3 = Color3.fromRGB(100,100,120); hSessLabel.TextSize = 7; hSessLabel.ZIndex = 2; hSessLabel.Parent = hudInner

    local hSession = Instance.new("TextLabel")
    hSession.Size = UDim2.new(0,60,0,12); hSession.Position = UDim2.new(0,78,0,13)
    hSession.BackgroundTransparency = 1; hSession.Font = Enum.Font.GothamBold
    hSession.Text = "00:00:00"; hSession.TextColor3 = Color3.fromRGB(180,180,200); hSession.TextSize = 11; hSession.ZIndex = 2; hSession.Parent = hudInner

    local sep3 = Instance.new("Frame")
    sep3.Size = UDim2.new(0,1,0.6,0); sep3.Position = UDim2.new(0,144,0.2,0)
    sep3.BackgroundColor3 = Color3.fromRGB(50,50,65); sep3.BackgroundTransparency = 0.3; sep3.BorderSizePixel = 0; sep3.Parent = hudInner

    local hPingLabel = Instance.new("TextLabel")
    hPingLabel.Size = UDim2.new(0,30,0,10); hPingLabel.Position = UDim2.new(0,150,0,3)
    hPingLabel.BackgroundTransparency = 1; hPingLabel.Font = Enum.Font.GothamBold
    hPingLabel.Text = "PING"; hPingLabel.TextColor3 = Color3.fromRGB(100,100,120); hPingLabel.TextSize = 7; hPingLabel.ZIndex = 2; hPingLabel.Parent = hudInner

    local hPing = Instance.new("TextLabel")
    hPing.Size = UDim2.new(0,50,0,12); hPing.Position = UDim2.new(0,150,0,13)
    hPing.BackgroundTransparency = 1; hPing.Font = Enum.Font.GothamBold
    hPing.Text = "0ms"; hPing.TextColor3 = Color3.fromRGB(34,197,94); hPing.TextSize = 11; hPing.ZIndex = 2; hPing.Parent = hudInner

    task.spawn(function()
        while Running do
            hFPS.Text = tostring(fpsValue)
            if fpsValue >= 50 then hFPS.TextColor3 = Color3.fromRGB(34,197,94)
            elseif fpsValue >= 30 then hFPS.TextColor3 = Color3.fromRGB(185,148,55)
            else hFPS.TextColor3 = Color3.fromRGB(239,68,68) end

            local ping = 0
            pcall(function()
                ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            hPing.Text = ping.."ms"
            if ping < 80 then hPing.TextColor3 = Color3.fromRGB(34,197,94)
            elseif ping < 150 then hPing.TextColor3 = Color3.fromRGB(185,148,55)
            else hPing.TextColor3 = Color3.fromRGB(239,68,68) end

            hSession.Text = FormatTime(os.time()-StartTime)
            task.wait(0.5)
        end
    end)
end

RS.RenderStepped:Connect(function() updateSnow() end)

table.insert(allConnections, RS.Heartbeat:Connect(function()
    if not Running then return end
    local h = GetHum()
    if h then
        if h.WalkSpeed ~= State.Speed then h.WalkSpeed = State.Speed end
        if h.JumpPower ~= State.JumpPower then h.JumpPower = State.JumpPower end
    end
end))

table.insert(allConnections, LP.CharacterAdded:Connect(function(char)
    if not Running then return end
    local hum = char:WaitForChild("Humanoid"); task.wait(0.1)
    pcall(function() hum.WalkSpeed=State.Speed; hum.JumpPower=State.JumpPower end)
    if State.TpTool then
        task.wait(0.5)
        local exists = false
        for _, item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then exists=true; break end end
        if not exists then
            if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end) end
            local tool = Instance.new("Tool"); tool.Name="TP_Tool"; tool.RequiresHandle=false; tool.Parent=LP.Backpack
            tpToolConnection = tool.Activated:Connect(function()
                local c = LP.Character; if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end
            end)
        end
    end
    if State.Noclip then task.delay(0.3, StartNoclip) end
    if State.Fly then task.delay(0.5, StartFly) end
    if State.ESP then task.delay(0.5, function() pcall(UpdateESP) end) end
    if voidActive then voidActive=false; if voidConnection then pcall(function() voidConnection:Disconnect() end); voidConnection=nil end; pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end); UpdateVoidStatus() end
end))

table.insert(allConnections, UIS.InputBegan:Connect(function(input, gp)
    if gp or not Running or isWaitingForKey then return end
    local kn = tostring(input.KeyCode):gsub("Enum.KeyCode.","")

    if input.UserInputType == Enum.UserInputType.Keyboard then
        for fn, bk in pairs(Binds) do
            if bk == kn then
                local cb = toggleCallbacks[fn]
                if cb then cb() end
            end
        end
    end

    if kn == MenuToggleKey then
        if not MenuOpen then
            MenuOpen = true; SG.Enabled = true
            menuFrame.Visible = true
            if canvasGroupOK then
                menuFrame.GroupTransparency = 1
                Tween(menuFrame, {GroupTransparency=0}, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            end
            SetBlur(6)
        else
            if canvasGroupOK then
                Tween(menuFrame, {GroupTransparency=1}, 0.15)
                task.delay(0.17, function()
                    if not MenuOpen then menuFrame.Visible=false; SG.Enabled=false end
                end)
            else
                menuFrame.Visible = false; SG.Enabled = false
            end
            MenuOpen = false; RemoveBlur()
        end
        return
    end
end))

local function ShowAdminAlert(player)
    if not AdminAlertEnabled or not Running then return end
    local isAdmin = CheckIfAdmin(player); if not isAdmin then return end
    Notify("Admin Joined", player.DisplayName.." (@"..player.Name..") entered", 5, "admin")
    RefreshAdminList()
    RefreshAdminWindow()
end

table.insert(allConnections, Players.PlayerAdded:Connect(function(plr)
    if not Running then return end; task.wait(1); if Running then ShowAdminAlert(plr) end
end))
table.insert(allConnections, Players.PlayerRemoving:Connect(function(plr)
    if not Running then return end
    local wasAdmin = AdminCache[plr.UserId] and AdminCache[plr.UserId].IsAdmin
    if wasAdmin then
        Notify("Admin Left", plr.DisplayName.." left", 3, "info")
        AdminCache[plr.UserId]=nil
        RefreshAdminList()
        RefreshAdminWindow()
    end
    SelectedFlingTargets[plr.Name] = nil
    selectedTeleportPlayers[plr.Name] = nil
end))

task.wait(0.3)
updateThemeColors()
pcall(function() local h=GetHum(); if h then h.WalkSpeed=State.Speed; h.JumpPower=State.JumpPower end end)
if State.Noclip then StartNoclip(); ShowBindIndicator("Noclip") end
if State.Fly then StartFly(); ShowBindIndicator("Fly") end
if State.ESP then pcall(UpdateESP); ShowBindIndicator("ESP Players") end
if State.TpTool then
    local tool = Instance.new("Tool"); tool.Name="TP_Tool"; tool.RequiresHandle=false; tool.Parent=LP.Backpack
    tpToolConnection = tool.Activated:Connect(function()
        local c = LP.Character; if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end
    end)
    ShowBindIndicator("TP Tool")
end
RefreshAdminList()
RefreshAdminWindow()

task.spawn(function()
    task.wait(2); if not Running then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP then
            local isA=CheckIfAdmin(p)
            if isA then Notify("Admin Detected", p.DisplayName.." (@"..p.Name..") is here", 5, "admin") end
        end
    end
    RefreshAdminWindow()
end)

print("QWEN Loaded! ["..MenuToggleKey.."] to toggle")
menuFrame.Visible = true; SG.Enabled = true; MenuOpen = true
if canvasGroupOK then menuFrame.GroupTransparency = 0 end
SetBlur(6)
Notify("QWEN","["..MenuToggleKey.."] to toggle",4,"success")
print("[QWEN] Loaded | "..MenuToggleKey.." = toggle")