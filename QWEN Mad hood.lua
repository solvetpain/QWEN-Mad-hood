for _, gui in pairs(game.CoreGui:GetChildren()) do
    if gui.Name:find("QWEN") then pcall(function() gui:Destroy() end) end
end
if game:GetService("Lighting"):FindFirstChild("QWENBlur") then
    game:GetService("Lighting").QWENBlur:Destroy()
end

local Players,UIS,RS,TS,HttpService,Lighting = game:GetService("Players"),game:GetService("UserInputService"),game:GetService("RunService"),game:GetService("TweenService"),game:GetService("HttpService"),game:GetService("Lighting")
local LP,Mouse,Camera = Players.LocalPlayer,Players.LocalPlayer:GetMouse(),workspace.CurrentCamera
local Running,MenuOpen,StartTime,blurEffect,isWaitingForKey,MenuToggleKey = true,false,os.time(),nil,false,"Delete"

local State = {Speed=16,JumpPower=50,FlySpeed=50,TpTool=false,Noclip=false,Fly=false,ESP=false,FlingDuration=3,HitboxExpand=false,HitboxSize=8}
local ToggleStateMap = {["TP Tool"]="TpTool",["Noclip"]="Noclip",["Fly"]="Fly",["ESP Players"]="ESP",["Hitbox Expander"]="HitboxExpand"}
local SAVE_KEY = "QWEN"
local Binds,bindLabels,allConnections,toggleCallbacks,toggleSetters,activeBindIndicators = {},{},{},{},{},{}
local noclipConnection,flyBV,flyBG,flyConnection,tpToolConnection = nil,nil,nil,nil,nil
local espHighlights,espBillboards = {},{}
local hitboxOriginalSizes,hitboxConnection = {},nil
local fpsValue,fpsFrameCount,fpsLastTime,activeSliderDrag = 60,0,tick(),nil
local FlingActive,SelectedFlingTargets = false,{}
getgenv().OldPos,getgenv().FPDH = nil,workspace.FallenPartsDestroyHeight
local voidActive,voidConnection,voidYOffset,voidTargetY,voidSavedPos = false,nil,-150,nil,nil
local ADMIN_GROUP_ID,ADMIN_MIN_RANK,ADMIN_MAX_RANK = 367140785,249,255
local AdminCache,AdminAlertEnabled,AdminESPEnabled = {},true,true
local snowParticles,snowEnabled = {},true
local rainParticles,rainEnabled = {},false
local transparentBg = true
local selectedTeleportPlayers,teleportLoopEnabled,teleportLoopConnection = {},false,nil
local HUD_POS_KEY,BINDBOX_POS_KEY,ADMINWIN_POS_KEY = "QWENHUDPos","QWENBindBoxPos","QWENAdminWinPos"

local THEME = {
    primary=Color3.fromRGB(230,230,230),primaryDark=Color3.fromRGB(160,160,160),primaryLight=Color3.fromRGB(255,255,255),
    accent=Color3.fromRGB(200,200,200),text=Color3.fromRGB(255,255,255),textDim=Color3.fromRGB(195,195,195),
    textMuted=Color3.fromRGB(115,115,115),background=Color3.fromRGB(0,0,0),backgroundLight=Color3.fromRGB(8,8,8),
    backgroundLighter=Color3.fromRGB(18,18,18),border=Color3.fromRGB(255,255,255),success=Color3.fromRGB(200,200,200),
    danger=Color3.fromRGB(80,80,80),warning=Color3.fromRGB(170,170,170),graphFill=Color3.fromRGB(210,210,210),
}
local themedElements,state_theme = {},{themeHue=0,themeSat=0,themeVal=0}

local function trackTheme(o,p,k) table.insert(themedElements,{obj=o,prop=p,themeKey=k}) end
local function updateThemeColors()
    local h,s,v = state_theme.themeHue,state_theme.themeSat,state_theme.themeVal
    THEME.primary=Color3.fromHSV(h,s,v); THEME.primaryDark=Color3.fromHSV(h,math.min(s+.07,1),math.max(v-.16,0))
    THEME.primaryLight=Color3.fromHSV(h,math.max(s-.35,0),math.min(v+.03,1)); THEME.accent=Color3.fromHSV(h,math.max(s-.13,0),math.max(v-.01,0))
    THEME.graphFill=Color3.fromHSV(h,math.max(s-.01,0),math.max(v-.05,0))
    local alive={}; for _,e in ipairs(themedElements) do if e.obj and e.obj.Parent then pcall(function() e.obj[e.prop]=THEME[e.themeKey] end); table.insert(alive,e) end end; themedElements=alive
end

local function Corner(p,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=p; return c end
local function Stroke(p,col,t,tr) local s=Instance.new("UIStroke"); s.Color=col or THEME.border; s.Thickness=t or 1; s.Transparency=tr or 0.72; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=p; return s end
local function Tween(o,pr,d,style,dir) if not o or not o.Parent then return end pcall(function() TS:Create(o,TweenInfo.new(d or .2,style or Enum.EasingStyle.Quint,dir or Enum.EasingDirection.Out),pr):Play() end) end
local function Smooth(o,pr,d) Tween(o,pr,d or .2,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out) end
local function GetHRP() local c=LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function FormatTime(s) return string.format("%02d:%02d:%02d",math.floor(s/3600),math.floor((s%3600)/60),s%60) end

local function SetBlur(size)
    if not blurEffect then blurEffect=Instance.new("BlurEffect"); blurEffect.Name="QWENBlur"; blurEffect.Size=0; blurEffect.Parent=Lighting end
    Tween(blurEffect,{Size=size},.3)
end
local function RemoveBlur()
    if blurEffect then Tween(blurEffect,{Size=0},.25); task.delay(.3,function() if blurEffect then blurEffect:Destroy() end; blurEffect=nil end) end
end

local function SaveJSON(key,data) pcall(function() writefile(key..".json",HttpService:JSONEncode(data)) end) end
local function LoadJSON(key) local ok,r=pcall(function() if isfile and isfile(key..".json") then return HttpService:JSONDecode(readfile(key..".json")) end end); return ok and r or nil end

local function SaveSettings()
    local data={}; for k,v in pairs(State) do data[k]=v end
    data.Binds=Binds; data.AdminAlertEnabled=AdminAlertEnabled; data.AdminESPEnabled=AdminESPEnabled
    data.MenuToggleKey=MenuToggleKey; data.themeHue=state_theme.themeHue; data.themeSat=state_theme.themeSat
    data.themeVal=state_theme.themeVal; data.snowEnabled=snowEnabled; data.rainEnabled=rainEnabled; data.transparentBg=transparentBg; SaveJSON(SAVE_KEY,data)
end
local function LoadSettings()
    local r=LoadJSON(SAVE_KEY); if not r then return end
    for k,v in pairs(r) do
        if k=="Binds" then if type(v)=="table" then Binds=v end
        elseif k=="AdminAlertEnabled" then AdminAlertEnabled=v
        elseif k=="AdminESPEnabled" then AdminESPEnabled=v
        elseif k=="MenuToggleKey" then MenuToggleKey=v
        elseif k=="themeHue" then state_theme.themeHue=v
        elseif k=="themeSat" then state_theme.themeSat=v
        elseif k=="themeVal" then state_theme.themeVal=v
        elseif k=="snowEnabled" then snowEnabled=v
        elseif k=="rainEnabled" then rainEnabled=v
        elseif k=="transparentBg" then transparentBg=v
        elseif State[k]~=nil then State[k]=v end
    end
end
LoadSettings()

local function SavePos(key,pos) SaveJSON(key,{x=pos.X.Scale,xo=pos.X.Offset,y=pos.Y.Scale,yo=pos.Y.Offset}) end
local function LoadPos(key,dx,dy) local r=LoadJSON(key); if r then return UDim2.new(r.x or 0,r.xo or dx,r.y or 0,r.yo or dy) end; return UDim2.new(0,dx,0,dy) end

table.insert(allConnections,RS.RenderStepped:Connect(function()
    fpsFrameCount+=1; local now=tick()
    if now-fpsLastTime>=1 then fpsValue=math.floor(fpsFrameCount/(now-fpsLastTime)); fpsFrameCount=0; fpsLastTime=now end
end))

local function CheckIfAdmin(p)
    if AdminCache[p.UserId]~=nil then return AdminCache[p.UserId].IsAdmin,AdminCache[p.UserId].Rank end
    local s,r=pcall(function() return p:GetRankInGroup(ADMIN_GROUP_ID) end)
    local a=s and r>=ADMIN_MIN_RANK and r<=ADMIN_MAX_RANK; AdminCache[p.UserId]={IsAdmin=a,Rank=r or 0}; return a,r or 0
end

local NotifSG=Instance.new("ScreenGui"); NotifSG.Name="QWENNotif"; NotifSG.Parent=game.CoreGui; NotifSG.ResetOnSpawn=false; NotifSG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local NotifContainer=Instance.new("Frame"); NotifContainer.Size=UDim2.new(0,300,1,0); NotifContainer.Position=UDim2.new(1,-300,0,0); NotifContainer.BackgroundTransparency=1; NotifContainer.ZIndex=10000; NotifContainer.Parent=NotifSG
local notificationStack={}

local function repositionNotifications()
    for i,nd in ipairs(notificationStack) do
        if nd.frame and nd.frame.Parent then
            local targetY = -((72+i*62)/NotifContainer.AbsoluteSize.Y*NotifContainer.AbsoluteSize.Y)
            -- CHANGED: smoother reposition with Back easing
            TS:Create(nd.frame,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,1,targetY)}):Play()
        end
    end
end

local function removeNotification(nd)
    for i,v in ipairs(notificationStack) do if v==nd then table.remove(notificationStack,i) break end end
    if nd.frame and nd.frame.Parent then
        -- CHANGED: smoother exit animation
        local tw=TS:Create(nd.frame,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.In),{Position=UDim2.new(1,28,nd.frame.Position.Y.Scale,0),BackgroundTransparency=.95})
        tw:Play()
        tw.Completed:Connect(function() if nd.frame and nd.frame.Parent then nd.frame:Destroy() end end)
    end
    task.delay(.05,repositionNotifications)
end

local function Notify(title,message,duration,nType)
    duration=duration or 3; nType=nType or "info"
    local barColor=THEME.textDim
    if nType=="success" then barColor=THEME.success elseif nType=="error" then barColor=THEME.danger
    elseif nType=="warning" then barColor=THEME.warning elseif nType=="admin" then barColor=Color3.fromRGB(160,160,160)
    elseif nType=="info" then barColor=Color3.fromRGB(150,150,150) end
    if #notificationStack>=6 then removeNotification(notificationStack[#notificationStack]) end
    -- CHANGED: glass style notification with white border, rounded
    local notif=Instance.new("Frame")
    notif.Size=UDim2.new(1,-8,0,54)
    notif.Position=UDim2.new(1,24,1,-54)
    notif.BackgroundColor3=Color3.fromRGB(10,10,10)
    notif.BackgroundTransparency=.3
    notif.BorderSizePixel=0; notif.ZIndex=10001; notif.Parent=NotifContainer
    Corner(notif,16)
    local ns=Instance.new("UIStroke"); ns.Thickness=1; ns.Color=Color3.fromRGB(255,255,255); ns.Transparency=.72; ns.Parent=notif
    local ab=Instance.new("Frame"); ab.Size=UDim2.new(0,3,.6,0); ab.Position=UDim2.new(0,0,.2,0); ab.BackgroundColor3=barColor; ab.BorderSizePixel=0; ab.ZIndex=10002; ab.Parent=notif; Corner(ab,3)
    local ic=Instance.new("Frame"); ic.Size=UDim2.new(0,20,0,20); ic.Position=UDim2.new(0,12,.5,-10); ic.BackgroundColor3=barColor; ic.BackgroundTransparency=.25; ic.BorderSizePixel=0; ic.ZIndex=10003; ic.Parent=notif; Corner(ic,10)
    local function NL(sz,pos,bold,txt,col,sz2) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham; l.Text=txt; l.TextColor3=col; l.TextSize=sz2; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=10003; l.Parent=notif; return l end
    NL(UDim2.new(1,-46,0,16),UDim2.new(0,42,0,9),true,title or "Notification",Color3.new(1,1,1),12)
    NL(UDim2.new(1,-46,0,14),UDim2.new(0,42,0,27),false,message or "",Color3.fromRGB(160,160,160),10).TextTruncate=Enum.TextTruncate.AtEnd
    local nd={frame=notif,time=tick()}; table.insert(notificationStack,1,nd); repositionNotifications()
    -- CHANGED: smoother spring entrance with Back easing
    task.delay(.05,function()
        if notif and notif.Parent then
            TS:Create(notif,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,notif.Position.Y.Scale,0)}):Play()
        end
    end)
    task.delay(duration,function() removeNotification(nd) end)
end

local function StartNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection=RS.Stepped:Connect(function()
        local c=LP.Character
        if c then for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    end)
    table.insert(allConnections,noclipConnection)
end
local function StopNoclip() if noclipConnection then noclipConnection:Disconnect(); noclipConnection=nil end end

local function StartFly()
    local c=LP.Character; if not c then return end
    local hrp=c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if not State.Noclip then StartNoclip() end
    if flyBV then pcall(function() flyBV:Destroy() end) end
    if flyBG then pcall(function() flyBG:Destroy() end) end
    if flyConnection then pcall(function() flyConnection:Disconnect() end) end
    flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(math.huge,math.huge,math.huge); flyBV.Velocity=Vector3.zero; flyBV.Parent=hrp
    flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=Vector3.new(math.huge,math.huge,math.huge); flyBG.D=200; flyBG.P=10000; flyBG.Parent=hrp
    flyConnection=RS.RenderStepped:Connect(function()
        if not State.Fly or not hrp or not hrp.Parent then if flyConnection then flyConnection:Disconnect(); flyConnection=nil end; return end
        flyBG.CFrame=Camera.CFrame; local dir=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir-=Vector3.new(0,1,0) end
        if dir.Magnitude>0 then dir=dir.Unit end; flyBV.Velocity=dir*State.FlySpeed
    end)
    table.insert(allConnections,flyConnection)
end
local function StopFly()
    if flyBV then pcall(function() flyBV:Destroy() end); flyBV=nil end
    if flyBG then pcall(function() flyBG:Destroy() end); flyBG=nil end
    if flyConnection then pcall(function() flyConnection:Disconnect() end); flyConnection=nil end
    if not State.Noclip then StopNoclip() end
end

local function ApplyHitbox(player)
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not hitboxOriginalSizes[player.UserId] then
        hitboxOriginalSizes[player.UserId] = hrp.Size
    end
    hrp.Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
    hrp.LocalTransparencyModifier = 0
end

local function RestoreHitbox(player)
    if not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if hrp and hitboxOriginalSizes[player.UserId] then
        pcall(function() hrp.Size = hitboxOriginalSizes[player.UserId] end)
    end
    hitboxOriginalSizes[player.UserId] = nil
end

local function StartHitboxExpander()
    if hitboxConnection then pcall(function() hitboxConnection:Disconnect() end) end
    for _,player in pairs(Players:GetPlayers()) do
        if player ~= LP then pcall(function() ApplyHitbox(player) end) end
    end
    hitboxConnection = RS.Heartbeat:Connect(function()
        if not State.HitboxExpand then return end
        for _,player in pairs(Players:GetPlayers()) do
            if player ~= LP and player.Character then
                pcall(function() ApplyHitbox(player) end)
            end
        end
    end)
    table.insert(allConnections, hitboxConnection)
end

local function StopHitboxExpander()
    if hitboxConnection then pcall(function() hitboxConnection:Disconnect() end); hitboxConnection = nil end
    for _,player in pairs(Players:GetPlayers()) do
        if player ~= LP then pcall(function() RestoreHitbox(player) end) end
    end
    hitboxOriginalSizes = {}
end

local function ClearESP() for _,h in pairs(espHighlights) do pcall(function() h:Destroy() end) end; espHighlights={}; for _,b in pairs(espBillboards) do pcall(function() b:Destroy() end) end; espBillboards={} end
local function UpdateESP()
    ClearESP(); if not State.ESP then return end
    for _,player in pairs(Players:GetPlayers()) do
        if player~=LP and player.Character then
            local char=player.Character; local head=char:FindFirstChild("Head"); local isAdmin=CheckIfAdmin(player)
            local espColor=(isAdmin and AdminESPEnabled) and Color3.fromRGB(180,180,180) or THEME.accent
            local hl=Instance.new("Highlight"); hl.Adornee=char; hl.FillColor=espColor; hl.FillTransparency=.82; hl.OutlineColor=espColor; hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char; table.insert(espHighlights,hl)
            if head then
                local bb=Instance.new("BillboardGui"); bb.Name="QWEN_ESP"; bb.Adornee=head; bb.Size=UDim2.new(0,160,0,36); bb.StudsOffset=Vector3.new(0,2.5,0); bb.AlwaysOnTop=true; bb.MaxDistance=1000; bb.Parent=head
                local function BL(sz,pos,font,txt,col,tsz) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=font; l.Text=txt; l.TextColor3=col; l.TextSize=tsz; l.TextStrokeTransparency=1; l.Parent=bb end
                BL(UDim2.new(1,0,.55,0),UDim2.new(0,0,0,0),Enum.Font.GothamBold,player.DisplayName,espColor,13)
                BL(UDim2.new(1,0,.35,0),UDim2.new(0,0,.55,0),Enum.Font.Gotham,"@"..player.Name,THEME.textDim,10)
                table.insert(espBillboards,bb)
            end
        end
    end
end
task.spawn(function() while Running do if State.ESP then pcall(UpdateESP) end; task.wait(3) end end)

local UpdateVoidStatus=function() end
local cachedLowestY=nil
task.spawn(function()
    while Running do
        local lowestY=math.huge
        pcall(function()
            for _,obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj:IsDescendantOf(LP.Character or Instance.new("Folder")) then
                    local y=obj.Position.Y-obj.Size.Y/2
                    if y<lowestY then lowestY=y end
                end
            end
        end)
        cachedLowestY=lowestY==math.huge and 0 or lowestY
        task.wait(10)
    end
end)
local function FindLowestY() return cachedLowestY or 0 end

local function StartVoid()
    if voidActive then return end
    local hrp=GetHRP(); if not hrp then Notify("Void","No character",2,"error"); return end
    voidSavedPos=hrp.CFrame
    voidTargetY=FindLowestY()+voidYOffset
    pcall(function() workspace.FallenPartsDestroyHeight=-1e9 end)
    hrp.CFrame=CFrame.new(hrp.Position.X,voidTargetY,hrp.Position.Z)
    hrp.Velocity=Vector3.zero
    voidActive=true
    if voidConnection then pcall(function() voidConnection:Disconnect() end) end
    voidConnection=RS.Heartbeat:Connect(function()
        if not voidActive or not Running then if voidConnection then voidConnection:Disconnect(); voidConnection=nil end; return end
        local h=GetHRP()
        if h then
            h.CFrame=CFrame.new(h.Position.X,voidTargetY,h.Position.Z)*CFrame.Angles(0,math.rad(h.Orientation.Y),0)
            h.Velocity=Vector3.new(h.Velocity.X*.5,0,h.Velocity.Z*.5)
            h.RotVelocity=Vector3.zero
            local ch=LP.Character
            if ch then for _,p in pairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
        end
    end)
    table.insert(allConnections,voidConnection)
    Notify("Void","Under map",2,"info")
    UpdateVoidStatus()
end

local function StopVoid()
    if not voidActive then return end; voidActive=false
    if voidConnection then pcall(function() voidConnection:Disconnect() end); voidConnection=nil end
    pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end)
    local hrp=GetHRP()
    if hrp then
        if voidSavedPos then hrp.CFrame=voidSavedPos; hrp.Velocity=Vector3.zero
        else local safeY=50; pcall(function() local ray=workspace:Raycast(Vector3.new(hrp.Position.X,5000,hrp.Position.Z),Vector3.new(0,-10000,0)); if ray then safeY=ray.Position.Y+5 end end); hrp.CFrame=CFrame.new(hrp.Position.X,safeY,hrp.Position.Z); hrp.Velocity=Vector3.zero end
    end
    voidSavedPos=nil
    Notify("Void","Returned",2,"success")
    UpdateVoidStatus()
end

local function SkidFling(TargetPlayer,duration)
    if not Running or not FlingActive then return end; duration=duration or State.FlingDuration or 3
    local Character=LP.Character; if not Character then return end
    local Humanoid=Character:FindFirstChildOfClass("Humanoid"); if not Humanoid then return end
    local RootPart=Humanoid.RootPart; if not RootPart then return end
    local TCharacter=TargetPlayer.Character; if not TCharacter then return end
    local THumanoid=TCharacter:FindFirstChildOfClass("Humanoid"); local TRootPart=THumanoid and THumanoid.RootPart
    local THead=TCharacter:FindFirstChild("Head"); local Accessory=TCharacter:FindFirstChildOfClass("Accessory"); local Handle=Accessory and Accessory:FindFirstChild("Handle")
    if not TRootPart and not THead and not Handle then return end
    if THumanoid and THumanoid.Health<=0 then return end; if Humanoid.Health<=0 then return end; if THumanoid and THumanoid.Sit then return end
    local wasVoid=voidActive; local savedCF=RootPart.CFrame
    if RootPart.Velocity.Magnitude<50 then getgenv().OldPos=RootPart.CFrame end
    if wasVoid and voidConnection then pcall(function() voidConnection:Disconnect() end); voidConnection=nil end
    if THead then workspace.CurrentCamera.CameraSubject=THead elseif Handle then workspace.CurrentCamera.CameraSubject=Handle elseif THumanoid then workspace.CurrentCamera.CameraSubject=THumanoid end
    local function GetTP() if TRootPart and TRootPart.Parent then return TRootPart end; if THead and THead.Parent then return THead end; if Handle and Handle.Parent then return Handle end end
    local function FPos(BP,Pos,Ang) if not RootPart or not RootPart.Parent then return end; local cf=CFrame.new(BP.Position)*Pos*Ang; RootPart.CFrame=cf; pcall(function() Character:PivotTo(cf) end); RootPart.Velocity=Vector3.new(9e7,9e7*10,9e7); RootPart.RotVelocity=Vector3.new(9e8,9e8,9e8) end
    local function SFBasePart(BP)
        if not BP or not BP.Parent then return end; local startT=tick(); local A=0
        repeat
            if not Running or not FlingActive then break end; if not RootPart or not RootPart.Parent then break end
            if not THumanoid or not THumanoid.Parent then break end; if THumanoid.Health<=0 then break end
            local curBP=GetTP(); if not curBP or not curBP.Parent then break end
            local targetVel=curBP.Velocity.Magnitude; local predictOffset=Vector3.zero
            if targetVel>5 then predictOffset=curBP.Velocity.Unit*math.min(targetVel*.08,10) end
            if targetVel<50 then
                A=A+100; local md=THumanoid.MoveDirection*targetVel/1.25
                FPos(curBP,CFrame.new(predictOffset+Vector3.new(0,1.5,0)+md),CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP,CFrame.new(predictOffset+Vector3.new(0,-1.5,0)+md),CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP,CFrame.new(predictOffset+Vector3.new(0,1.5,0)+THumanoid.MoveDirection),CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP,CFrame.new(predictOffset+Vector3.new(0,-1.5,0)+THumanoid.MoveDirection),CFrame.Angles(math.rad(A),0,0)); task.wait()
            else
                A=A+150; local chaseDir=(curBP.Position-RootPart.Position); if chaseDir.Magnitude>.1 then chaseDir=chaseDir.Unit else chaseDir=THumanoid.MoveDirection end
                local speedBoost=math.max(THumanoid.WalkSpeed,targetVel*.5)
                FPos(curBP,CFrame.new(predictOffset+Vector3.new(0,1.5,0)+chaseDir*speedBoost*.03),CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP,CFrame.new(predictOffset+Vector3.new(0,-1.5,0)-chaseDir*speedBoost*.03),CFrame.Angles(math.rad(-A),0,0)); task.wait()
                FPos(curBP,CFrame.new(predictOffset+Vector3.new(0,.5,0)),CFrame.Angles(math.rad(A),math.rad(A),0)); task.wait()
                FPos(curBP,CFrame.new(predictOffset+Vector3.new(0,-.5,0)),CFrame.Angles(0,0,math.rad(A))); task.wait()
                if targetVel>100 then FPos(curBP,CFrame.new(predictOffset+Vector3.new(1.5,0,0)),CFrame.Angles(math.rad(A*2),0,0)); task.wait(); FPos(curBP,CFrame.new(predictOffset+Vector3.new(-1.5,0,0)),CFrame.Angles(math.rad(-A*2),0,0)); task.wait() end
            end
        until tick()-startT>=duration or not FlingActive or not Running
    end
    pcall(function() workspace.FallenPartsDestroyHeight=0/0 end)
    local BV=Instance.new("BodyVelocity"); BV.Parent=RootPart; BV.Velocity=Vector3.zero; BV.MaxForce=Vector3.new(9e9,9e9,9e9)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,false)
    local mainBP=GetTP(); if mainBP then SFBasePart(mainBP) end
    pcall(function() BV:Destroy() end); pcall(function() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,true) end); pcall(function() workspace.CurrentCamera.CameraSubject=Humanoid end)
    local returnCF=wasVoid and savedCF or getgenv().OldPos
    if returnCF and RootPart and RootPart.Parent then
        local att=0
        repeat att+=1; pcall(function() RootPart.CFrame=returnCF*CFrame.new(0,.5,0); Character:PivotTo(returnCF*CFrame.new(0,.5,0)); Humanoid:ChangeState("GettingUp"); for _,p in pairs(Character:GetChildren()) do if p:IsA("BasePart") then p.Velocity=Vector3.zero; p.RotVelocity=Vector3.zero end end end); task.wait()
        until (RootPart.Position-returnCF.Position).Magnitude<25 or att>150
    end
    if wasVoid and voidActive then
        pcall(function() workspace.FallenPartsDestroyHeight=-1e9 end)
        voidConnection=RS.Heartbeat:Connect(function()
            if not voidActive or not Running then if voidConnection then voidConnection:Disconnect(); voidConnection=nil end; return end
            local h=GetHRP(); if h then h.CFrame=CFrame.new(h.Position.X,voidTargetY,h.Position.Z)*CFrame.Angles(0,math.rad(h.Orientation.Y),0); h.Velocity=Vector3.new(h.Velocity.X*.5,0,h.Velocity.Z*.5); h.RotVelocity=Vector3.zero; local ch=LP.Character; if ch then for _,p in pairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end end
        end); table.insert(allConnections,voidConnection)
    else pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end) end
end

local WIN_W,WIN_H,SIDEBAR_W,HEADER_H = 560,440,110,48
local SG=Instance.new("ScreenGui"); SG.Name="QWENGui"; SG.Parent=game.CoreGui; SG.ResetOnSpawn=false; SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SG.IgnoreGuiInset=true; SG.Enabled=false
local canvasGroupOK=pcall(function() local t=Instance.new("CanvasGroup"); t:Destroy() end)
local menuFrame=Instance.new(canvasGroupOK and "CanvasGroup" or "Frame")
if canvasGroupOK then menuFrame.GroupTransparency=1 end
menuFrame.Name="Main"; menuFrame.Size=UDim2.new(0,WIN_W,0,WIN_H); menuFrame.Position=UDim2.new(.5,-WIN_W/2,.5,-WIN_H/2); menuFrame.BackgroundColor3=Color3.fromRGB(0,0,0); menuFrame.BackgroundTransparency=transparentBg and .55 or .9; menuFrame.BorderSizePixel=0; menuFrame.Visible=false; menuFrame.ZIndex=200; menuFrame.Parent=SG; Corner(menuFrame,20)
local menuStroke=Stroke(menuFrame,Color3.fromRGB(255,255,255),1,.78)
task.spawn(function()
    local t=0
    while menuFrame and menuFrame.Parent do
        t+=.04; pcall(function() menuStroke.Transparency=math.sin(t)*0.15+0.72 end); task.wait(.04)
    end
end)

local snowContainer
local function createSnowContainer(parent)
    if snowContainer and snowContainer.Parent then snowContainer:Destroy() end
    snowContainer=Instance.new("Frame"); snowContainer.Size=UDim2.new(1,0,1,0); snowContainer.BackgroundTransparency=1; snowContainer.ClipsDescendants=true; snowContainer.ZIndex=203; snowContainer.Name="SnowContainer"; snowContainer.Parent=parent
end
local function updateSnow()
    if not snowEnabled then if snowContainer and snowContainer.Parent then for _,c in pairs(snowContainer:GetChildren()) do c:Destroy() end end; snowParticles={}; return end
    if not snowContainer or not snowContainer.Parent then return end
    if math.random()<.25 then
        local size=math.random(2,4); local flake=Instance.new("Frame"); flake.Size=UDim2.new(0,size,0,size); flake.Position=UDim2.new(math.random()*1.2-.1,0,-.02,0); flake.BackgroundColor3=Color3.new(1,1,1); flake.BackgroundTransparency=math.random()*.3+.4; flake.BorderSizePixel=0; flake.ZIndex=204; flake.Parent=snowContainer; Corner(flake,10)
        table.insert(snowParticles,{frame=flake,speed=math.random(40,100)/100,drift=(math.random()-.5)*.25,startX=flake.Position.X.Scale,time=0})
    end
    for i=#snowParticles,1,-1 do
        local p=snowParticles[i]
        if p.frame and p.frame.Parent then p.time+=.016; local newY=p.frame.Position.Y.Scale+p.speed*.004; p.frame.Position=UDim2.new(p.startX+math.sin(p.time*2)*p.drift,0,newY,0); if newY>1.05 then p.frame:Destroy(); table.remove(snowParticles,i) end
        else table.remove(snowParticles,i) end
    end
end
createSnowContainer(menuFrame)
RS.RenderStepped:Connect(function() updateSnow() end)

local rainContainer
local function createRainContainer(parent)
    if rainContainer and rainContainer.Parent then rainContainer:Destroy() end
    rainContainer=Instance.new("Frame"); rainContainer.Size=UDim2.new(1,0,1,0); rainContainer.BackgroundTransparency=1; rainContainer.ClipsDescendants=true; rainContainer.ZIndex=203; rainContainer.Name="RainContainer"; rainContainer.Parent=parent
end
local function updateRain()
    if not rainEnabled then if rainContainer and rainContainer.Parent then for _,c in pairs(rainContainer:GetChildren()) do c:Destroy() end end; rainParticles={}; return end
    if not rainContainer or not rainContainer.Parent then return end
    if math.random()<.32 then
        local h=math.random(10,20); local w=math.random(1,2)
        local drop=Instance.new("Frame"); drop.Size=UDim2.new(0,w,0,h); drop.Position=UDim2.new(math.random()*1.1-.05,0,-.03,0); drop.BackgroundColor3=Color3.fromRGB(160,200,255); drop.BackgroundTransparency=math.random()*.35+.45; drop.BorderSizePixel=0; drop.ZIndex=204; drop.Rotation=math.random(-8,8); drop.Parent=rainContainer; Corner(drop,1)
        table.insert(rainParticles,{frame=drop,speed=math.random(70,130)/100,drift=math.random(-3,3)/100,startX=drop.Position.X.Scale,time=0})
    end
    for i=#rainParticles,1,-1 do
        local p=rainParticles[i]
        if p.frame and p.frame.Parent then p.time+=.016; local newY=p.frame.Position.Y.Scale+p.speed*.010; p.frame.Position=UDim2.new(p.startX+p.drift*p.time,0,newY,0); if newY>1.05 then p.frame:Destroy(); table.remove(rainParticles,i) end
        else table.remove(rainParticles,i) end
    end
end
createRainContainer(menuFrame)
RS.RenderStepped:Connect(function() updateRain() end)

do -- Header block
local header=Instance.new("Frame"); header.Size=UDim2.new(1,0,0,HEADER_H); header.BackgroundColor3=Color3.fromRGB(255,255,255); header.BackgroundTransparency=.88; header.BorderSizePixel=0; header.ZIndex=210; header.Parent=menuFrame; Corner(header,20)
local mainDrag,mainDragStart,mainStartPos=false,nil,nil
header.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then mainDrag=true; mainDragStart=i.Position; mainStartPos=menuFrame.Position end end)
header.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then mainDrag=false end end)
table.insert(allConnections,UIS.InputChanged:Connect(function(i) if mainDrag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-mainDragStart; menuFrame.Position=UDim2.new(mainStartPos.X.Scale,mainStartPos.X.Offset+d.X,mainStartPos.Y.Scale,mainStartPos.Y.Offset+d.Y) end end))
local lc=Instance.new("Frame"); lc.Size=UDim2.new(0,32,0,32); lc.Position=UDim2.new(0,12,0,10); lc.BackgroundColor3=Color3.fromRGB(255,255,255); lc.BackgroundTransparency=.82; lc.BorderSizePixel=0; lc.ZIndex=213; lc.Parent=header; Corner(lc,12); Stroke(lc,Color3.fromRGB(255,255,255),1,.7)
local lt=Instance.new("TextLabel"); lt.Size=UDim2.new(1,0,1,0); lt.BackgroundTransparency=1; lt.Font=Enum.Font.GothamBlack; lt.Text="Q"; lt.TextColor3=Color3.new(1,1,1); lt.TextSize=18; lt.ZIndex=214; lt.Parent=lc
local glowRing=Instance.new("Frame"); glowRing.Size=UDim2.new(0,40,0,40); glowRing.Position=UDim2.new(0,8,0,6); glowRing.BackgroundColor3=Color3.fromRGB(200,200,200); glowRing.BackgroundTransparency=.85; glowRing.BorderSizePixel=0; glowRing.ZIndex=212; glowRing.Parent=header; Corner(glowRing,20)
task.spawn(function()
    local t=0
    while lc and lc.Parent do
        t+=.05; local pulse=math.sin(t)*0.07+0.88; Smooth(glowRing,{BackgroundTransparency=pulse},.08); task.wait(.05)
    end
end)
local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(0,160,0,28); tl.Position=UDim2.new(0,52,.5,-14); tl.BackgroundTransparency=1; tl.Font=Enum.Font.GothamBlack; tl.Text="QWEN"; tl.TextColor3=THEME.text; tl.TextSize=17; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.ZIndex=212; tl.Parent=header
local tg=Instance.new("UIGradient"); tg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,200,200)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(200,200,200))}); tg.Parent=tl
task.spawn(function() local o=0; while tl and tl.Parent do o=(o+.02)%2; tg.Offset=Vector2.new(o-.5,0); tg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(200,200,200)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(200,200,200))}); task.wait(.03) end end)
task.spawn(function()
    local t=0
    while menuFrame and menuFrame.Parent do
        t+=.04; local alpha=math.sin(t)*0.18+0.75; pcall(function() menuStroke.Transparency=alpha end); task.wait(.04)
    end
end)
do
    local scanlineFrame=Instance.new("Frame"); scanlineFrame.Size=UDim2.new(1,0,1,0); scanlineFrame.BackgroundTransparency=1; scanlineFrame.BorderSizePixel=0; scanlineFrame.ZIndex=205; scanlineFrame.ClipsDescendants=true; scanlineFrame.Name="Scanlines"; scanlineFrame.Parent=menuFrame
    local scanGrad=Instance.new("UIGradient"); scanGrad.Rotation=90; scanGrad.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.48,1),NumberSequenceKeypoint.new(.49,.92),NumberSequenceKeypoint.new(.5,1),NumberSequenceKeypoint.new(.98,1),NumberSequenceKeypoint.new(.99,.92),NumberSequenceKeypoint.new(1,1)}); scanGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}); scanGrad.Parent=scanlineFrame
    task.spawn(function()
        local o=0
        while scanlineFrame and scanlineFrame.Parent do
            o=(o+.004)%1; scanGrad.Offset=Vector2.new(0,o); task.wait(.02)
        end
    end)
end
end

local sidebar=Instance.new("Frame"); sidebar.Size=UDim2.new(0,SIDEBAR_W,1,-HEADER_H-8); sidebar.Position=UDim2.new(0,8,0,HEADER_H+4); sidebar.BackgroundColor3=Color3.fromRGB(28,28,28); sidebar.BackgroundTransparency=.15; sidebar.BorderSizePixel=0; sidebar.ZIndex=210; sidebar.Parent=menuFrame; Corner(sidebar,12); Stroke(sidebar,Color3.fromRGB(80,80,80),1,.55)
local contentArea=Instance.new("Frame"); contentArea.Size=UDim2.new(1,-(SIDEBAR_W+24),1,-HEADER_H-8); contentArea.Position=UDim2.new(0,SIDEBAR_W+16,0,HEADER_H+4); contentArea.BackgroundTransparency=1; contentArea.ClipsDescendants=true; contentArea.ZIndex=210; contentArea.Parent=menuFrame
local tabPad=Instance.new("UIPadding",sidebar); tabPad.PaddingTop=UDim.new(0,6); tabPad.PaddingLeft=UDim.new(0,4); tabPad.PaddingRight=UDim.new(0,4)
local tabLayout=Instance.new("UIListLayout",sidebar); tabLayout.Padding=UDim.new(0,2); tabLayout.SortOrder=Enum.SortOrder.LayoutOrder

local tabButtons,tabContents,currentTab={},{},"Player"
local tabs={"Player","ESP","Fling","Teleport","Elimination","Void","Admin","Settings"}

local function SetTab(name)
    if currentTab==name then return end
    for n,content in pairs(tabContents) do content.Visible=(n==name) end
    for n,btn in pairs(tabButtons) do
        local active=(n==name)
        Smooth(btn,{BackgroundTransparency=active and .1 or .6,TextColor3=active and THEME.text or THEME.textMuted},.2)
        local ind=btn:FindFirstChild("Indicator"); if ind then Smooth(ind,{BackgroundTransparency=active and 0 or 1},.2) end
    end
    currentTab=name
end

for i,name in ipairs(tabs) do
    local isFirst=(i==1)
    local tb=Instance.new("TextButton"); tb.Name=name; tb.Size=UDim2.new(1,0,0,30); tb.BackgroundColor3=Color3.fromRGB(60,60,60); tb.BackgroundTransparency=isFirst and .1 or .6; tb.Font=Enum.Font.GothamBold; tb.Text=name; tb.TextColor3=isFirst and THEME.text or THEME.textMuted; tb.TextSize=10; tb.BorderSizePixel=0; tb.ZIndex=211; tb.LayoutOrder=i; tb.AutoButtonColor=false; tb.TextWrapped=true; tb.Parent=sidebar; Corner(tb,10)
    tb.MouseButton1Click:Connect(function()
        local ripple=Instance.new("Frame"); ripple.Size=UDim2.new(0,0,0,0); ripple.Position=UDim2.new(.5,0,.5,0); ripple.AnchorPoint=Vector2.new(.5,.5); ripple.BackgroundColor3=Color3.fromRGB(255,255,255); ripple.BackgroundTransparency=.7; ripple.BorderSizePixel=0; ripple.ZIndex=220; ripple.Parent=tb; Corner(ripple,50)
        TS:Create(ripple,TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(1.4,0,1.4,0),BackgroundTransparency=1}):Play()
        task.delay(.45,function() if ripple and ripple.Parent then ripple:Destroy() end end)
    end)
    local ind=Instance.new("Frame"); ind.Name="Indicator"; ind.Size=UDim2.new(0,3,.6,0); ind.Position=UDim2.new(0,0,.2,0); ind.BackgroundColor3=THEME.primary; ind.BackgroundTransparency=isFirst and 0 or 1; ind.BorderSizePixel=0; ind.ZIndex=212; ind.Parent=tb; Corner(ind,2); trackTheme(ind,"BackgroundColor3","primary")
    tabButtons[name]=tb
    tb.MouseEnter:Connect(function() if currentTab~=name then Smooth(tb,{BackgroundTransparency=.3,TextColor3=THEME.textDim},.15) end end)
    tb.MouseLeave:Connect(function() if currentTab~=name then Smooth(tb,{BackgroundTransparency=.6,TextColor3=THEME.textMuted},.15) end end)
    tb.MouseButton1Click:Connect(function() SetTab(name) end)
end

local function MakePage(visible)
    local page=Instance.new("ScrollingFrame"); page.Size=UDim2.new(1,0,1,0); page.BackgroundTransparency=1; page.BorderSizePixel=0; page.ScrollBarThickness=3; page.ScrollBarImageColor3=THEME.primary; page.CanvasSize=UDim2.new(0,0,0,0); page.AutomaticCanvasSize=Enum.AutomaticSize.Y; page.Visible=visible or false; page.ZIndex=211; page.Parent=contentArea; trackTheme(page,"ScrollBarImageColor3","primary")
    local pad=Instance.new("UIPadding",page); pad.PaddingTop=UDim.new(0,4); pad.PaddingBottom=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,2); pad.PaddingRight=UDim.new(0,4)
    local lay=Instance.new("UIListLayout",page); lay.Padding=UDim.new(0,4); lay.SortOrder=Enum.SortOrder.LayoutOrder
    return page
end
for i,name in ipairs(tabs) do tabContents[name]=MakePage(i==1) end

local function SectionLabel(parent,text)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,0,18); lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.GothamBold; lbl.Text=text:upper(); lbl.TextColor3=THEME.textMuted; lbl.TextSize=9; lbl.ZIndex=212; lbl.Parent=parent
end

-- CHANGED: Glass style search bar
local function MakeSearchBar(parent,onSearch)
    local sf=Instance.new("Frame"); sf.Size=UDim2.new(1,0,0,28); sf.BackgroundColor3=Color3.fromRGB(255,255,255); sf.BackgroundTransparency=.92; sf.BorderSizePixel=0; sf.Parent=parent; Corner(sf,12); Stroke(sf,Color3.fromRGB(255,255,255),1,.82)
    local tb=Instance.new("TextBox"); tb.Size=UDim2.new(1,-12,1,-4); tb.Position=UDim2.new(0,6,0,2); tb.BackgroundTransparency=1; tb.Font=Enum.Font.Gotham; tb.PlaceholderText="Search players..."; tb.PlaceholderColor3=THEME.textMuted; tb.Text=""; tb.TextColor3=THEME.text; tb.TextSize=11; tb.TextXAlignment=Enum.TextXAlignment.Left; tb.ClearTextOnFocus=false; tb.Parent=sf
    tb:GetPropertyChangedSignal("Text"):Connect(function() onSearch(tb.Text:lower()) end)
    return tb
end

-- CHANGED: Toggle with improved bind button - smaller font, Gotham (not Bold)
local function Toggle(parent,name,desc,callback)
    local container=Instance.new("Frame"); container.Size=UDim2.new(1,0,0,42); container.BackgroundColor3=Color3.fromRGB(255,255,255); container.BackgroundTransparency=.92; container.BorderSizePixel=0; container.ZIndex=211; container.Parent=parent; Corner(container,10)
    local cS=Instance.new("UIStroke"); cS.Thickness=1; cS.Color=THEME.border; cS.Transparency=.78; cS.Parent=container
    container.MouseEnter:Connect(function() Smooth(container,{BackgroundTransparency=.85},.15); Smooth(cS,{Color=THEME.primary,Transparency=.55},.15) end)
    container.MouseLeave:Connect(function() Smooth(container,{BackgroundTransparency=.92},.15); Smooth(cS,{Color=THEME.border,Transparency=.78},.15) end)
    local function TL(sz,pos,font,txt,col,tsz) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=font; l.Text=txt; l.TextColor3=col; l.TextSize=tsz; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=212; l.Parent=container; return l end
    TL(UDim2.new(1,-130,0,16),UDim2.new(0,10,0,4),Enum.Font.GothamSemibold,name,THEME.text,11)
    TL(UDim2.new(1,-130,0,12),UDim2.new(0,10,0,23),Enum.Font.Gotham,desc or "",THEME.textMuted,8)
    -- CHANGED: bind button — smaller, lighter font, glass look
    local kbBtn=Instance.new("TextButton")
    kbBtn.Size=UDim2.new(0,44,0,19)
    kbBtn.Position=UDim2.new(1,-130,.5,-9)
    kbBtn.BackgroundColor3=Color3.fromRGB(255,255,255)
    kbBtn.BackgroundTransparency=.90
    kbBtn.BorderSizePixel=0
    kbBtn.Font=Enum.Font.Gotham  -- CHANGED: not Bold
    kbBtn.Text=Binds[name] and ("["..Binds[name].."]") or "BIND"
    kbBtn.TextColor3=Color3.fromRGB(160,160,160)  -- CHANGED: dimmer
    kbBtn.TextSize=9  -- CHANGED: smaller
    kbBtn.AutoButtonColor=false
    kbBtn.ZIndex=215
    kbBtn.Parent=container
    Corner(kbBtn,6)
    local kbStroke=Instance.new("UIStroke"); kbStroke.Thickness=1; kbStroke.Color=Color3.fromRGB(255,255,255); kbStroke.Transparency=.75; kbStroke.Parent=kbBtn
    bindLabels[name]=kbBtn
    local isWaitingBind=false
    kbBtn.MouseEnter:Connect(function() if not isWaitingBind then Smooth(kbBtn,{BackgroundTransparency=.75,TextColor3=THEME.text},.1) end end)
    kbBtn.MouseLeave:Connect(function() if not isWaitingBind then Smooth(kbBtn,{BackgroundTransparency=.90,TextColor3=Color3.fromRGB(160,160,160)},.1) end end)
    kbBtn.MouseButton1Click:Connect(function()
        if isWaitingBind then return end; isWaitingBind=true; kbBtn.Text="..."; kbBtn.TextColor3=THEME.primary; Smooth(kbBtn,{BackgroundTransparency=.70},.1); Smooth(kbStroke,{Transparency=.45},.1)
        local conn; conn=UIS.InputBegan:Connect(function(i2,gp2)
            if gp2 then return end
            if i2.UserInputType==Enum.UserInputType.Keyboard then
                isWaitingBind=false; conn:Disconnect()
                if i2.KeyCode==Enum.KeyCode.Escape then kbBtn.Text=Binds[name] and ("["..Binds[name].."]") or "BIND"; kbBtn.TextColor3=Color3.fromRGB(160,160,160); Smooth(kbBtn,{BackgroundTransparency=.90},.1); Smooth(kbStroke,{Transparency=.75},.1); return end
                if i2.KeyCode==Enum.KeyCode.Backspace then Binds[name]=nil; kbBtn.Text="BIND"; kbBtn.TextColor3=Color3.fromRGB(160,160,160); Smooth(kbBtn,{BackgroundTransparency=.90},.1); Smooth(kbStroke,{Transparency=.75},.1); SaveSettings(); Notify("Keybind",name.." unbound",2,"info"); return end
                local kn2=tostring(i2.KeyCode):gsub("Enum.KeyCode.",""); Binds[name]=kn2; kbBtn.Text="["..kn2.."]"; kbBtn.TextColor3=Color3.fromRGB(160,160,160); Smooth(kbBtn,{BackgroundTransparency=.90},.1); Smooth(kbStroke,{Transparency=.75},.1); SaveSettings(); Notify("Keybind",name.." → ["..kn2.."]",2,"success")
            end
        end)
    end)
    local stateKey=ToggleStateMap[name]; local enabled=stateKey and State[stateKey] or false
    local tBg=Instance.new("Frame"); tBg.Size=UDim2.new(0,36,0,20); tBg.Position=UDim2.new(1,-44,.5,-10); tBg.BackgroundColor3=enabled and Color3.fromRGB(220,220,220) or Color3.fromRGB(50,50,50); tBg.BackgroundTransparency=.25; tBg.BorderSizePixel=0; tBg.ZIndex=212; tBg.Parent=container; Corner(tBg,10)
    local tSt=Instance.new("UIStroke"); tSt.Thickness=1; tSt.Color=enabled and Color3.fromRGB(220,220,220) or Color3.fromRGB(80,80,80); tSt.Parent=tBg
    local tK=Instance.new("Frame"); tK.Size=UDim2.new(0,16,0,16); tK.Position=enabled and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2); tK.BackgroundColor3=Color3.new(1,1,1); tK.BorderSizePixel=0; tK.ZIndex=213; tK.Parent=tBg; Corner(tK,8)
    local tBtn=Instance.new("TextButton"); tBtn.Size=UDim2.new(0,36,0,20); tBtn.Position=UDim2.new(1,-44,.5,-10); tBtn.BackgroundTransparency=1; tBtn.Text=""; tBtn.ZIndex=215; tBtn.Parent=container
    local function updateVisual()
        Smooth(tBg,{BackgroundColor3=enabled and Color3.fromRGB(220,220,220) or Color3.fromRGB(50,50,50),BackgroundTransparency=.25},.2)
        Smooth(tSt,{Color=enabled and Color3.fromRGB(220,220,220) or Color3.fromRGB(80,80,80)},.2)
        Tween(tK,{Position=enabled and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)},.2,Enum.EasingStyle.Back)
    end
    local function setEnabled(val) enabled=val; if stateKey then State[stateKey]=val end; updateVisual(); callback(enabled); SaveSettings() end
    toggleSetters[name]=setEnabled
    tBtn.MouseButton1Click:Connect(function() if isWaitingBind then return end; setEnabled(not enabled); Notify(name,enabled and "Enabled" or "Disabled",2,enabled and "success" or "info") end)
    return setEnabled
end

local function Slider(parent,name,minV,maxV,def,callback)
    local container=Instance.new("Frame"); container.Size=UDim2.new(1,0,0,46); container.BackgroundColor3=Color3.fromRGB(255,255,255); container.BackgroundTransparency=.92; container.BorderSizePixel=0; container.ZIndex=211; container.Parent=parent; Corner(container,10); Stroke(container,THEME.border,1,.78)
    local nameL=Instance.new("TextLabel"); nameL.Size=UDim2.new(1,-60,0,16); nameL.Position=UDim2.new(0,10,0,4); nameL.BackgroundTransparency=1; nameL.Font=Enum.Font.GothamSemibold; nameL.Text=name; nameL.TextColor3=THEME.text; nameL.TextSize=10; nameL.TextXAlignment=Enum.TextXAlignment.Left; nameL.ZIndex=212; nameL.Parent=container
    local vl=Instance.new("TextLabel"); vl.Size=UDim2.new(0,50,0,16); vl.Position=UDim2.new(1,-58,0,4); vl.BackgroundTransparency=1; vl.Font=Enum.Font.GothamBold; vl.Text=tostring(def); vl.TextColor3=THEME.primary; vl.TextSize=10; vl.TextXAlignment=Enum.TextXAlignment.Right; vl.ZIndex=212; vl.Parent=container; trackTheme(vl,"TextColor3","primary")
    local track=Instance.new("Frame"); track.Size=UDim2.new(1,-20,0,6); track.Position=UDim2.new(0,10,0,30); track.BackgroundColor3=Color3.fromRGB(15,15,15); track.BorderSizePixel=0; track.ZIndex=212; track.Parent=container; Corner(track,3)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new(math.clamp((def-minV)/(maxV-minV),0,1),0,1,0); fill.BackgroundColor3=THEME.primary; fill.BorderSizePixel=0; fill.ZIndex=213; fill.Parent=track; Corner(fill,3); trackTheme(fill,"BackgroundColor3","primary")
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,14,0,14); knob.Position=UDim2.new(math.clamp((def-minV)/(maxV-minV),0,1),-7,.5,-7); knob.BackgroundColor3=THEME.text; knob.BorderSizePixel=0; knob.ZIndex=214; knob.Parent=track; Corner(knob,7)
    local ks=Instance.new("UIStroke"); ks.Thickness=1; ks.Color=THEME.primary; ks.Parent=knob; trackTheme(ks,"Color","primary")
    local curVal=def
    local function apply(v)
        v=math.clamp(math.floor(v+.5),minV,maxV); if curVal==v then return end; curVal=v; local pct=(v-minV)/(maxV-minV)
        fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,-7,.5,-7); vl.Text=tostring(v); callback(v)
    end
    local function applyFromMouse(inputX) local aP,aS=track.AbsolutePosition.X,track.AbsoluteSize.X; if aS>0 then apply(minV+(maxV-minV)*math.clamp((inputX-aP)/aS,0,1)) end end
    local dragBtn=Instance.new("TextButton"); dragBtn.Size=UDim2.new(1,0,5,0); dragBtn.Position=UDim2.new(0,0,-2,0); dragBtn.BackgroundTransparency=1; dragBtn.Text=""; dragBtn.Parent=track; dragBtn.ZIndex=216
    dragBtn.MouseButton1Down:Connect(function(x) Smooth(knob,{Size=UDim2.new(0,16,0,16)},.06); applyFromMouse(x); activeSliderDrag={track=track,apply=applyFromMouse,knob=knob} end)
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then Smooth(knob,{Size=UDim2.new(0,16,0,16)},.06); applyFromMouse(i.Position.X); activeSliderDrag={track=track,apply=applyFromMouse,knob=knob} end end)
end

table.insert(allConnections,UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 and activeSliderDrag then Smooth(activeSliderDrag.knob,{Size=UDim2.new(0,14,0,14)},.1); activeSliderDrag=nil end end))
table.insert(allConnections,UIS.InputChanged:Connect(function(i) if activeSliderDrag and i.UserInputType==Enum.UserInputType.MouseMovement then activeSliderDrag.apply(i.Position.X) end end))

table.insert(allConnections,RS.Heartbeat:Connect(function()
    if not Running then return end
    local h=GetHum()
    if h then h.WalkSpeed=State.Speed; h.JumpPower=State.JumpPower end
end))

-- CHANGED: BindBox with glass style
local BindGui=Instance.new("ScreenGui"); BindGui.Name="QWENBind"; BindGui.ResetOnSpawn=false; BindGui.IgnoreGuiInset=true; BindGui.Parent=game.CoreGui
local BindBox=Instance.new("Frame"); BindBox.Size=UDim2.new(0,160,0,32); BindBox.Position=LoadPos(BINDBOX_POS_KEY,12,200); BindBox.BackgroundColor3=Color3.fromRGB(10,10,10); BindBox.BackgroundTransparency=.45; BindBox.BorderSizePixel=0; BindBox.AutomaticSize=Enum.AutomaticSize.Y; BindBox.Active=true; BindBox.Visible=true; BindBox.Parent=BindGui; Corner(BindBox,14)
local bindBoxStroke=Instance.new("UIStroke"); bindBoxStroke.Thickness=1; bindBoxStroke.Color=Color3.fromRGB(255,255,255); bindBoxStroke.Transparency=.75; bindBoxStroke.Parent=BindBox
local bbHF=Instance.new("Frame"); bbHF.Size=UDim2.new(1,0,0,26); bbHF.BackgroundTransparency=1; bbHF.Parent=BindBox
local bbDot=Instance.new("Frame"); bbDot.Size=UDim2.new(0,5,0,5); bbDot.Position=UDim2.new(0,10,.5,-2.5); bbDot.BackgroundColor3=THEME.success; bbDot.BorderSizePixel=0; bbDot.ZIndex=3; bbDot.Parent=bbHF; Corner(bbDot,3)
-- CHANGED: bind box title smaller font
local bbTitle=Instance.new("TextLabel"); bbTitle.Size=UDim2.new(1,-24,1,0); bbTitle.Position=UDim2.new(0,20,0,0); bbTitle.BackgroundTransparency=1; bbTitle.Font=Enum.Font.Gotham; bbTitle.Text="ACTIVE"; bbTitle.TextColor3=Color3.fromRGB(110,110,110); bbTitle.TextSize=8; bbTitle.TextXAlignment=Enum.TextXAlignment.Left; bbTitle.ZIndex=3; bbTitle.Parent=bbHF
local bbDiv=Instance.new("Frame"); bbDiv.Size=UDim2.new(1,-16,0,1); bbDiv.Position=UDim2.new(0,8,0,26); bbDiv.BackgroundColor3=Color3.fromRGB(60,60,60); bbDiv.BackgroundTransparency=.3; bbDiv.BorderSizePixel=0; bbDiv.Parent=BindBox
local BindI=Instance.new("Frame"); BindI.Size=UDim2.new(1,0,0,0); BindI.Position=UDim2.new(0,0,0,30); BindI.BackgroundTransparency=1; BindI.AutomaticSize=Enum.AutomaticSize.Y; BindI.Parent=BindBox
local bLay=Instance.new("UIListLayout",BindI); bLay.Padding=UDim.new(0,2)
local bPa=Instance.new("UIPadding",BindI); bPa.PaddingLeft=UDim.new(0,6); bPa.PaddingRight=UDim.new(0,6); bPa.PaddingBottom=UDim.new(0,8); bPa.PaddingTop=UDim.new(0,4)
local bD,bDS,bSP=false,nil,nil
BindBox.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then bD=true; bDS=i.Position; bSP=BindBox.Position end end)
BindBox.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then bD=false; SavePos(BINDBOX_POS_KEY,BindBox.Position) end end)
table.insert(allConnections,UIS.InputChanged:Connect(function(i) if bD and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-bDS; BindBox.Position=UDim2.new(bSP.X.Scale,bSP.X.Offset+d.X,bSP.Y.Scale,bSP.Y.Offset+d.Y) end end))

local function UpdateBindVis()
    local ct=0; for _ in pairs(activeBindIndicators) do ct+=1 end
    BindBox.Visible=true
    if ct>0 then Smooth(BindBox,{BackgroundTransparency=.45},.2)
    else Smooth(BindBox,{BackgroundTransparency=1},.2) end
end

function ShowBindIndicator(name)
    if activeBindIndicators[name] then return end
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,22); f.BackgroundColor3=Color3.fromRGB(255,255,255); f.BackgroundTransparency=1; f.BorderSizePixel=0; f.Parent=BindI; Corner(f,8)
    local accent=Instance.new("Frame"); accent.Size=UDim2.new(0,2,.65,0); accent.Position=UDim2.new(0,0,.175,0); accent.BackgroundColor3=THEME.primary; accent.BorderSizePixel=0; accent.ZIndex=3; accent.Parent=f; Corner(accent,1); trackTheme(accent,"BackgroundColor3","primary")
    -- CHANGED: bind indicator label smaller font
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-10,1,0); lbl.Position=UDim2.new(0,8,0,0); lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.Gotham; lbl.Text=name; lbl.TextColor3=Color3.fromRGB(210,210,210); lbl.TextSize=10; lbl.TextTransparency=1; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=3; lbl.Parent=f
    activeBindIndicators[name]=f; Smooth(f,{BackgroundTransparency=.88},.2); Smooth(lbl,{TextTransparency=0},.2); UpdateBindVis()
end

function HideBindIndicator(name)
    local f=activeBindIndicators[name]; if not f then return end; activeBindIndicators[name]=nil
    local function findLbl(p) for _,ch in pairs(p:GetChildren()) do if ch:IsA("TextLabel") then return ch end; local fd=findLbl(ch); if fd then return fd end end end
    local rl=findLbl(f); if rl then Smooth(rl,{TextTransparency=1},.18) end
    Smooth(f,{BackgroundTransparency=1},.18); task.delay(.22,function() pcall(function() f:Destroy() end) end); UpdateBindVis()
end

local AdminWinGui=Instance.new("ScreenGui"); AdminWinGui.Name="QWENAdminWin"; AdminWinGui.ResetOnSpawn=false; AdminWinGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; AdminWinGui.Parent=game.CoreGui
local AdminWin=Instance.new("Frame"); AdminWin.Name="AdminWindow"; AdminWin.Size=UDim2.new(0,180,0,32); AdminWin.Position=LoadPos(ADMINWIN_POS_KEY,12,120); AdminWin.BackgroundColor3=Color3.fromRGB(0,0,0); AdminWin.BackgroundTransparency=.25; AdminWin.BorderSizePixel=0; AdminWin.AutomaticSize=Enum.AutomaticSize.Y; AdminWin.Active=true; AdminWin.Visible=false; AdminWin.Parent=AdminWinGui; Corner(AdminWin,12)
local adminWinStroke=Instance.new("UIStroke"); adminWinStroke.Thickness=1; adminWinStroke.Color=Color3.fromRGB(150,150,150); adminWinStroke.Transparency=.5; adminWinStroke.Parent=AdminWin
local awH=Instance.new("Frame"); awH.Size=UDim2.new(1,0,0,26); awH.BackgroundTransparency=1; awH.Parent=AdminWin
local awDot=Instance.new("Frame"); awDot.Size=UDim2.new(0,5,0,5); awDot.Position=UDim2.new(0,10,.5,-2.5); awDot.BackgroundColor3=Color3.fromRGB(150,150,150); awDot.BorderSizePixel=0; awDot.ZIndex=3; awDot.Parent=awH; Corner(awDot,3)
local awTitle=Instance.new("TextLabel"); awTitle.Size=UDim2.new(1,-24,1,0); awTitle.Position=UDim2.new(0,20,0,0); awTitle.BackgroundTransparency=1; awTitle.Font=Enum.Font.GothamBold; awTitle.Text="ADMINS"; awTitle.TextColor3=Color3.fromRGB(200,200,200); awTitle.TextSize=9; awTitle.TextXAlignment=Enum.TextXAlignment.Left; awTitle.ZIndex=3; awTitle.Parent=awH
local awDiv=Instance.new("Frame"); awDiv.Size=UDim2.new(1,-16,0,1); awDiv.Position=UDim2.new(0,8,0,26); awDiv.BackgroundColor3=Color3.fromRGB(100,100,100); awDiv.BackgroundTransparency=.7; awDiv.BorderSizePixel=0; awDiv.Parent=AdminWin
local awList=Instance.new("Frame"); awList.Size=UDim2.new(1,0,0,0); awList.Position=UDim2.new(0,0,0,30); awList.BackgroundTransparency=1; awList.AutomaticSize=Enum.AutomaticSize.Y; awList.Parent=AdminWin
local awLL=Instance.new("UIListLayout",awList); awLL.Padding=UDim.new(0,2)
local awPad=Instance.new("UIPadding",awList); awPad.PaddingLeft=UDim.new(0,6); awPad.PaddingRight=UDim.new(0,6); awPad.PaddingBottom=UDim.new(0,8); awPad.PaddingTop=UDim.new(0,4)
local awDrag,awDragStart,awStartPos=false,nil,nil
AdminWin.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then awDrag=true; awDragStart=i.Position; awStartPos=AdminWin.Position end end)
AdminWin.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then awDrag=false; SavePos(ADMINWIN_POS_KEY,AdminWin.Position) end end)
table.insert(allConnections,UIS.InputChanged:Connect(function(i) if awDrag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-awDragStart; AdminWin.Position=UDim2.new(awStartPos.X.Scale,awStartPos.X.Offset+d.X,awStartPos.Y.Scale,awStartPos.Y.Offset+d.Y) end end))

local adminWinEntries={}
local function RefreshAdminWindow()
    for _,f in pairs(adminWinEntries) do pcall(function() f:Destroy() end) end; adminWinEntries={}
    local found=false
    for _,plr in pairs(Players:GetPlayers()) do
        if plr~=LP then
            local isAdmin,rank=CheckIfAdmin(plr)
            if isAdmin then
                found=true
                local ef=Instance.new("Frame"); ef.Size=UDim2.new(1,0,0,44); ef.BackgroundColor3=Color3.fromRGB(255,255,255); ef.BackgroundTransparency=.90; ef.BorderSizePixel=0; ef.Parent=awList; Corner(ef,10); Stroke(ef,Color3.fromRGB(255,255,255),1,.78)
                local eA=Instance.new("Frame"); eA.Size=UDim2.new(0,2,.65,0); eA.Position=UDim2.new(0,0,.175,0); eA.BackgroundColor3=Color3.fromRGB(150,150,150); eA.BorderSizePixel=0; eA.ZIndex=3; eA.Parent=ef; Corner(eA,1)
                local function AWL(sz,pos,font,txt,col,tsz) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=font; l.Text=txt; l.TextColor3=col; l.TextSize=tsz; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=3; l.Parent=ef end
                AWL(UDim2.new(1,-8,0,14),UDim2.new(0,7,0,4),Enum.Font.GothamBold,plr.DisplayName,Color3.fromRGB(220,220,220),10)
                AWL(UDim2.new(1,-8,0,10),UDim2.new(0,7,0,20),Enum.Font.Gotham,"@"..plr.Name,Color3.fromRGB(130,130,130),8)
                AWL(UDim2.new(1,-8,0,10),UDim2.new(0,7,0,32),Enum.Font.GothamBold,"Rank: "..tostring(rank),Color3.fromRGB(180,180,180),8)
                table.insert(adminWinEntries,ef)
            end
        end
    end
    if found then AdminWin.Visible=true; Smooth(AdminWin,{BackgroundTransparency=.25},.3)
    else Smooth(AdminWin,{BackgroundTransparency=1},.3); task.delay(.35,function() if #adminWinEntries==0 then AdminWin.Visible=false end end) end
end

-- PLAYER TAB
do
    local PP=tabContents["Player"]
    SectionLabel(PP,"Movement")
    Slider(PP,"Walk Speed",16,200,State.Speed,function(v) State.Speed=v end)
    Slider(PP,"Jump Power",50,350,State.JumpPower,function(v) State.JumpPower=v end)
    SectionLabel(PP,"Options")
    Toggle(PP,"Noclip","Walk through walls",function(s) State.Noclip=s; if s then StartNoclip(); ShowBindIndicator("Noclip") else if not State.Fly then StopNoclip() end; HideBindIndicator("Noclip") end end)
    toggleCallbacks["Noclip"]=function() if toggleSetters["Noclip"] then toggleSetters["Noclip"](not State.Noclip) end end
    Toggle(PP,"Fly","WASD + Space / Shift",function(s) State.Fly=s; if s then StartFly(); ShowBindIndicator("Fly") else StopFly(); HideBindIndicator("Fly") end end)
    toggleCallbacks["Fly"]=function() if toggleSetters["Fly"] then toggleSetters["Fly"](not State.Fly) end end
    Slider(PP,"Fly Speed",10,200,State.FlySpeed,function(v) State.FlySpeed=v end)
    Toggle(PP,"TP Tool","Click to teleport",function(s)
        State.TpTool=s
        if s then
            if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end) end
            for _,item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end
            if LP.Character then for _,item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end
            local tool=Instance.new("Tool"); tool.Name="TP_Tool"; tool.RequiresHandle=false; tool.Parent=LP.Backpack
            tpToolConnection=tool.Activated:Connect(function() local c=LP.Character; if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame=CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end end)
            ShowBindIndicator("TP Tool")
        else
            if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end); tpToolConnection=nil end
            for _,item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end
            if LP.Character then for _,item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end
            HideBindIndicator("TP Tool")
        end
    end)
    toggleCallbacks["TP Tool"]=function() if toggleSetters["TP Tool"] then toggleSetters["TP Tool"](not State.TpTool) end end
    SectionLabel(PP,"Combat")
    Toggle(PP,"Hitbox Expander","Expand enemy hitboxes",function(s) State.HitboxExpand=s; if s then StartHitboxExpander(); ShowBindIndicator("Hitbox Expander") else StopHitboxExpander(); HideBindIndicator("Hitbox Expander") end end)
    toggleCallbacks["Hitbox Expander"]=function() if toggleSetters["Hitbox Expander"] then toggleSetters["Hitbox Expander"](not State.HitboxExpand) end end
    Slider(PP,"Hitbox Size",4,50,State.HitboxSize,function(v) State.HitboxSize=v end)
end

-- ESP TAB
do
    local EP=tabContents["ESP"]
    SectionLabel(EP,"Players")
    Toggle(EP,"ESP Players","Show players through walls",function(s) State.ESP=s; if s then pcall(UpdateESP); ShowBindIndicator("ESP Players") else ClearESP(); HideBindIndicator("ESP Players") end end)
    toggleCallbacks["ESP Players"]=function() if toggleSetters["ESP Players"] then toggleSetters["ESP Players"](not State.ESP) end end
    SectionLabel(EP,"Admin ESP")
    local function AdminTogESP(parent,name,defVal,cb)
        -- CHANGED: glass style
        local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,38); f.BackgroundColor3=Color3.fromRGB(255,255,255); f.BackgroundTransparency=.92; f.BorderSizePixel=0; f.Parent=parent; Corner(f,10); Stroke(f,Color3.fromRGB(255,255,255),1,.78)
        local nL=Instance.new("TextLabel"); nL.Size=UDim2.new(1,-60,0,16); nL.Position=UDim2.new(0,10,.5,-8); nL.BackgroundTransparency=1; nL.Font=Enum.Font.GothamSemibold; nL.Text=name; nL.TextColor3=THEME.text; nL.TextSize=11; nL.TextXAlignment=Enum.TextXAlignment.Left; nL.Parent=f
        local tBg=Instance.new("Frame"); tBg.Size=UDim2.new(0,36,0,20); tBg.Position=UDim2.new(1,-44,.5,-10); tBg.BackgroundColor3=defVal and Color3.fromRGB(200,200,200) or Color3.fromRGB(50,50,50); tBg.BackgroundTransparency=.25; tBg.BorderSizePixel=0; tBg.Parent=f; Corner(tBg,10)
        local tSt=Instance.new("UIStroke"); tSt.Thickness=1; tSt.Color=defVal and Color3.fromRGB(200,200,200) or Color3.fromRGB(80,80,80); tSt.Parent=tBg
        local tK=Instance.new("Frame"); tK.Size=UDim2.new(0,16,0,16); tK.Position=defVal and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2); tK.BackgroundColor3=Color3.new(1,1,1); tK.BorderSizePixel=0; tK.Parent=tBg; Corner(tK,8)
        local en=defVal; local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=f
        btn.MouseButton1Click:Connect(function()
            en=not en
            Smooth(tBg,{BackgroundColor3=en and Color3.fromRGB(200,200,200) or Color3.fromRGB(50,50,50),BackgroundTransparency=.25},.18)
            Smooth(tSt,{Color=en and Color3.fromRGB(200,200,200) or Color3.fromRGB(80,80,80)},.18)
            Tween(tK,{Position=en and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)},.2,Enum.EasingStyle.Back)
            cb(en); SaveSettings()
        end)
        f.MouseEnter:Connect(function() Smooth(f,{BackgroundTransparency=.85},.1) end)
        f.MouseLeave:Connect(function() Smooth(f,{BackgroundTransparency=.92},.1) end)
    end
    AdminTogESP(EP,"Highlight Admins",AdminESPEnabled,function(v) AdminESPEnabled=v; if State.ESP then pcall(UpdateESP) end end)
end

-- FLING TAB
local flingStatusL,flingDot,flingPlrCont,flingPlayerBtns,flingAllFrames
do
    local FP=tabContents["Fling"]
    -- CHANGED: glass style status frame
    local fSF=Instance.new("Frame"); fSF.Size=UDim2.new(1,0,0,36); fSF.BackgroundColor3=Color3.fromRGB(255,255,255); fSF.BackgroundTransparency=.92; fSF.BorderSizePixel=0; fSF.Parent=FP; Corner(fSF,12); Stroke(fSF,Color3.fromRGB(255,255,255),1,.82)
    flingDot=Instance.new("Frame"); flingDot.Size=UDim2.new(0,5,0,5); flingDot.Position=UDim2.new(0,12,.5,-2); flingDot.BackgroundColor3=THEME.textMuted; flingDot.BorderSizePixel=0; flingDot.Parent=fSF; Corner(flingDot,3)
    flingStatusL=Instance.new("TextLabel"); flingStatusL.Size=UDim2.new(1,-26,1,0); flingStatusL.Position=UDim2.new(0,24,0,0); flingStatusL.BackgroundTransparency=1; flingStatusL.Font=Enum.Font.GothamMedium; flingStatusL.Text="Select targets"; flingStatusL.TextColor3=THEME.textMuted; flingStatusL.TextSize=11; flingStatusL.TextXAlignment=Enum.TextXAlignment.Left; flingStatusL.Parent=fSF
    SectionLabel(FP,"Duration")
    Slider(FP,"Duration (sec)",1,10,State.FlingDuration,function(v) State.FlingDuration=v end)
    SectionLabel(FP,"Controls")
    local btnRow=Instance.new("Frame"); btnRow.Size=UDim2.new(1,0,0,32); btnRow.BackgroundTransparency=1; btnRow.Parent=FP
    local bRL=Instance.new("UIListLayout"); bRL.FillDirection=Enum.FillDirection.Horizontal; bRL.Padding=UDim.new(0,6); bRL.Parent=btnRow
    local function FBtn(txt,isGreen)
        -- CHANGED: glass style buttons
        local col=isGreen and Color3.fromRGB(200,200,200) or Color3.fromRGB(70,70,70)
        local b=Instance.new("TextButton"); b.Size=UDim2.new(0.5,-3,1,0); b.BackgroundColor3=Color3.fromRGB(255,255,255); b.BackgroundTransparency=.88; b.Font=Enum.Font.GothamBold; b.Text=txt; b.TextColor3=isGreen and Color3.fromRGB(220,220,220) or Color3.fromRGB(150,150,150); b.TextSize=11; b.AutoButtonColor=false; b.BorderSizePixel=0; b.Parent=btnRow; Corner(b,10); Stroke(b,col,1,.55)
        b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=.75},.1) end)
        b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=.88},.1) end)
        return b
    end
    local StartFBtn=FBtn("▶ Start",true); local StopFBtn=FBtn("■ Stop",false)
    local selRow=Instance.new("Frame"); selRow.Size=UDim2.new(1,0,0,28); selRow.BackgroundTransparency=1; selRow.Parent=FP
    local sRL=Instance.new("UIListLayout"); sRL.FillDirection=Enum.FillDirection.Horizontal; sRL.Padding=UDim.new(0,6); sRL.Parent=selRow
    local function SBtn(txt)
        local b=Instance.new("TextButton"); b.Size=UDim2.new(0.5,-3,1,0); b.BackgroundColor3=Color3.fromRGB(255,255,255); b.BackgroundTransparency=.92; b.Font=Enum.Font.GothamBold; b.Text=txt; b.TextColor3=THEME.textDim; b.TextSize=10; b.AutoButtonColor=false; b.BorderSizePixel=0; b.Parent=selRow; Corner(b,8); Stroke(b,Color3.fromRGB(255,255,255),1,.82)
        b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=.80},.1) end)
        b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=.92},.1) end)
        return b
    end
    local selAllBtn=SBtn("Select All"); local deselAllBtn=SBtn("Unselect All")
    SectionLabel(FP,"Players")
    MakeSearchBar(FP,function(q)
        if not flingAllFrames then return end
        for _,fd in pairs(flingAllFrames) do
            if fd.frame and fd.frame.Parent then
                fd.frame.Visible=(q=="" or fd.name:lower():find(q,1,true)~=nil)
            end
        end
    end)
    flingPlrCont=Instance.new("Frame"); flingPlrCont.Size=UDim2.new(1,0,0,0); flingPlrCont.AutomaticSize=Enum.AutomaticSize.Y; flingPlrCont.BackgroundTransparency=1; flingPlrCont.Parent=FP
    Instance.new("UIListLayout",flingPlrCont).Padding=UDim.new(0,3)
    flingPlayerBtns={}; flingAllFrames={}
    local function UpdateFlingStatus()
        local cnt=0; for _ in pairs(SelectedFlingTargets) do cnt+=1 end
        if FlingActive then flingStatusL.Text="Flinging "..cnt.."..."; flingStatusL.TextColor3=THEME.text; Smooth(flingDot,{BackgroundColor3=THEME.success},.2)
        elseif cnt>0 then flingStatusL.Text="Selected: "..cnt; flingStatusL.TextColor3=THEME.textDim; Smooth(flingDot,{BackgroundColor3=THEME.textDim},.2)
        else flingStatusL.Text="Select targets"; flingStatusL.TextColor3=THEME.textMuted; Smooth(flingDot,{BackgroundColor3=THEME.textMuted},.2) end
    end
    local playerFrameData={}
    local function RefreshFlingList()
        for _,b in pairs(flingPlayerBtns) do pcall(function() b:Destroy() end) end
        flingPlayerBtns={}; playerFrameData={}; flingAllFrames={}
        local plrs=Players:GetPlayers(); table.sort(plrs,function(a,b2) return a.Name:lower()<b2.Name:lower() end)
        for _,plr in ipairs(plrs) do
            if plr~=LP then
                local isSel=SelectedFlingTargets[plr.Name]~=nil
                -- CHANGED: glass style player frame
                local pF=Instance.new("Frame"); pF.Size=UDim2.new(1,0,0,44); pF.BackgroundColor3=Color3.fromRGB(255,255,255); pF.BackgroundTransparency=isSel and .82 or .92; pF.BorderSizePixel=0; pF.Parent=flingPlrCont; Corner(pF,12)
                local pStroke=Stroke(pF,isSel and THEME.primary or Color3.fromRGB(255,255,255),1,isSel and .5 or .82)
                local function PL(sz,pos,font,txt,col,tsz) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=font; l.Text=txt; l.TextColor3=col; l.TextSize=tsz; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=pF end
                PL(UDim2.new(1,-50,0,16),UDim2.new(0,10,0,6),Enum.Font.GothamSemibold,plr.DisplayName,THEME.text,12)
                PL(UDim2.new(1,-50,0,12),UDim2.new(0,10,0,24),Enum.Font.Gotham,"@"..plr.Name,THEME.textMuted,9)
                local chk=Instance.new("Frame"); chk.Size=UDim2.new(0,22,0,22); chk.Position=UDim2.new(1,-32,.5,-11); chk.BackgroundColor3=isSel and THEME.primary or Color3.fromRGB(255,255,255); chk.BackgroundTransparency=isSel and .3 or .90; chk.BorderSizePixel=0; chk.ZIndex=213; chk.Parent=pF; Corner(chk,8); Stroke(chk,Color3.fromRGB(255,255,255),1,.72)
                local chkL=Instance.new("TextLabel"); chkL.Size=UDim2.new(1,0,1,0); chkL.BackgroundTransparency=1; chkL.Font=Enum.Font.GothamBold; chkL.Text=isSel and "✓" or ""; chkL.TextColor3=THEME.text; chkL.TextSize=13; chkL.ZIndex=214; chkL.Parent=chk
                local clickArea=Instance.new("TextButton"); clickArea.Size=UDim2.new(1,0,1,0); clickArea.BackgroundTransparency=1; clickArea.Text=""; clickArea.ZIndex=215; clickArea.Parent=pF
                local cp,cpName=plr,plr.Name
                local function setSelected(sel)
                    if sel then SelectedFlingTargets[cpName]=cp; Smooth(pF,{BackgroundTransparency=.82},.12); Smooth(chk,{BackgroundTransparency=.3},.12); Smooth(pStroke,{Color=THEME.primary,Transparency=.5},.12); chkL.Text="✓"
                    else SelectedFlingTargets[cpName]=nil; Smooth(pF,{BackgroundTransparency=.92},.12); Smooth(chk,{BackgroundTransparency=.90},.12); Smooth(pStroke,{Color=Color3.fromRGB(255,255,255),Transparency=.82},.12); chkL.Text="" end
                    UpdateFlingStatus()
                end
                playerFrameData[cpName]=setSelected
                clickArea.MouseButton1Click:Connect(function() setSelected(SelectedFlingTargets[cpName]==nil) end)
                clickArea.MouseEnter:Connect(function() if not SelectedFlingTargets[cpName] then Smooth(pF,{BackgroundTransparency=.86},.08) end end)
                clickArea.MouseLeave:Connect(function() if not SelectedFlingTargets[cpName] then Smooth(pF,{BackgroundTransparency=.92},.08) end end)
                table.insert(flingPlayerBtns,pF)
                table.insert(flingAllFrames,{frame=pF,name=plr.Name..plr.DisplayName})
            end
        end
        if #flingPlayerBtns==0 then local eL=Instance.new("TextLabel"); eL.Size=UDim2.new(1,0,0,28); eL.BackgroundTransparency=1; eL.Font=Enum.Font.Gotham; eL.Text="No other players"; eL.TextColor3=THEME.textMuted; eL.TextSize=10; eL.Parent=flingPlrCont; table.insert(flingPlayerBtns,eL) end
    end
    StartFBtn.MouseButton1Click:Connect(function()
        local cnt=0; for _ in pairs(SelectedFlingTargets) do cnt+=1 end
        if cnt==0 then Notify("Fling","Select targets first",2,"warning"); return end
        FlingActive=true; UpdateFlingStatus(); ShowBindIndicator("Fling"); Notify("Fling","Flinging "..cnt,2,"info")
        task.spawn(function()
            while FlingActive and Running do
                for n2,pl in pairs(SelectedFlingTargets) do if not pl or not pl.Parent then SelectedFlingTargets[n2]=nil end end
                local c2=0; for _ in pairs(SelectedFlingTargets) do c2+=1 end
                if c2==0 then FlingActive=false; break end; UpdateFlingStatus()
                for _,pl in pairs(SelectedFlingTargets) do if FlingActive and Running and pl and pl.Parent then pcall(function() SkidFling(pl,State.FlingDuration) end); task.wait(.15) end end; task.wait(.2)
            end
            FlingActive=false; UpdateFlingStatus(); HideBindIndicator("Fling")
        end)
    end)
    StopFBtn.MouseButton1Click:Connect(function() FlingActive=false; UpdateFlingStatus(); HideBindIndicator("Fling"); Notify("Fling","Stopped",2,"info") end)
    selAllBtn.MouseButton1Click:Connect(function() for _,p in ipairs(Players:GetPlayers()) do if p~=LP then SelectedFlingTargets[p.Name]=p; if playerFrameData[p.Name] then playerFrameData[p.Name](true) end end end; UpdateFlingStatus() end)
    deselAllBtn.MouseButton1Click:Connect(function() SelectedFlingTargets={}; for name,fn in pairs(playerFrameData) do fn(false) end; UpdateFlingStatus() end)
    Players.PlayerAdded:Connect(function() task.wait(1); RefreshFlingList() end)
    Players.PlayerRemoving:Connect(function(p) task.wait(.1); SelectedFlingTargets[p.Name]=nil; RefreshFlingList(); UpdateFlingStatus() end)
    task.spawn(RefreshFlingList)
end

-- TELEPORT TAB
local tpToPlrCont,tpToPlayerBtns,tpToAllFrames
do
    local TP=tabContents["Teleport"]
    -- CHANGED: glass style status bar
    local tSF=Instance.new("Frame"); tSF.Size=UDim2.new(1,0,0,32); tSF.BackgroundColor3=Color3.fromRGB(255,255,255); tSF.BackgroundTransparency=.92; tSF.BorderSizePixel=0; tSF.Parent=TP; Corner(TP,12); Stroke(tSF,Color3.fromRGB(255,255,255),1,.82)
    local tDot=Instance.new("Frame"); tDot.Size=UDim2.new(0,5,0,5); tDot.Position=UDim2.new(0,12,.5,-2); tDot.BackgroundColor3=THEME.textMuted; tDot.BorderSizePixel=0; tDot.Parent=tSF; Corner(tDot,3)
    local tStatL=Instance.new("TextLabel"); tStatL.Size=UDim2.new(1,-26,1,0); tStatL.Position=UDim2.new(0,24,0,0); tStatL.BackgroundTransparency=1; tStatL.Font=Enum.Font.GothamMedium; tStatL.Text="Select player"; tStatL.TextColor3=THEME.textMuted; tStatL.TextSize=11; tStatL.TextXAlignment=Enum.TextXAlignment.Left; tStatL.Parent=tSF
    SectionLabel(TP,"Players")
    MakeSearchBar(TP,function(q)
        if not tpToAllFrames then return end
        for _,fd in pairs(tpToAllFrames) do
            if fd.frame and fd.frame.Parent then
                fd.frame.Visible=(q=="" or fd.name:lower():find(q,1,true)~=nil)
            end
        end
    end)
    tpToPlrCont=Instance.new("Frame"); tpToPlrCont.Size=UDim2.new(1,0,0,0); tpToPlrCont.AutomaticSize=Enum.AutomaticSize.Y; tpToPlrCont.BackgroundTransparency=1; tpToPlrCont.Parent=TP
    Instance.new("UIListLayout",tpToPlrCont).Padding=UDim.new(0,3)
    tpToPlayerBtns={}; tpToAllFrames={}
    local function RefreshTpToList()
        for _,b in pairs(tpToPlayerBtns) do pcall(function() b:Destroy() end) end
        tpToPlayerBtns={}; tpToAllFrames={}
        local plrs=Players:GetPlayers(); table.sort(plrs,function(a,b2) return a.Name:lower()<b2.Name:lower() end)
        for _,plr in ipairs(plrs) do
            if plr~=LP then
                -- CHANGED: glass style matching screenshot 1
                local pF=Instance.new("Frame"); pF.Size=UDim2.new(1,0,0,44); pF.BackgroundColor3=Color3.fromRGB(255,255,255); pF.BackgroundTransparency=.92; pF.BorderSizePixel=0; pF.Parent=tpToPlrCont; Corner(pF,12)
                local pStroke=Stroke(pF,Color3.fromRGB(255,255,255),1,.82)
                local function PL(sz,pos,font,txt,col,tsz) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=font; l.Text=txt; l.TextColor3=col; l.TextSize=tsz; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=pF end
                PL(UDim2.new(1,-80,0,16),UDim2.new(0,12,0,6),Enum.Font.GothamSemibold,plr.DisplayName,THEME.text,12)
                PL(UDim2.new(1,-80,0,12),UDim2.new(0,12,0,24),Enum.Font.Gotham,"@"..plr.Name,THEME.textMuted,9)
                local tpBtn=Instance.new("TextButton"); tpBtn.Size=UDim2.new(0,44,0,24); tpBtn.Position=UDim2.new(1,-52,.5,-12); tpBtn.BackgroundColor3=Color3.fromRGB(255,255,255); tpBtn.BackgroundTransparency=.88; tpBtn.Font=Enum.Font.GothamBold; tpBtn.Text="TP"; tpBtn.TextColor3=THEME.primary; tpBtn.TextSize=11; tpBtn.AutoButtonColor=false; tpBtn.ZIndex=215; tpBtn.Parent=pF; Corner(tpBtn,8); Stroke(tpBtn,THEME.primary,1,.5)
                tpBtn.MouseEnter:Connect(function() Smooth(tpBtn,{BackgroundTransparency=.6,TextColor3=Color3.new(1,1,1)},.12) end)
                tpBtn.MouseLeave:Connect(function() Smooth(tpBtn,{BackgroundTransparency=.88,TextColor3=THEME.primary},.12) end)
                pF.MouseEnter:Connect(function() Smooth(pF,{BackgroundTransparency=.84},.1); Smooth(pStroke,{Transparency=.55},.1) end)
                pF.MouseLeave:Connect(function() Smooth(pF,{BackgroundTransparency=.92},.1); Smooth(pStroke,{Transparency=.82},.1) end)
                local cp=plr
                tpBtn.MouseButton1Click:Connect(function()
                    local myHRP=GetHRP(); if not myHRP then Notify("Teleport","No character",2,"error"); return end
                    if not cp or not cp.Character or not cp.Character:FindFirstChild("HumanoidRootPart") then Notify("Teleport","Player unavailable",2,"error"); return end
                    myHRP.CFrame=cp.Character.HumanoidRootPart.CFrame*CFrame.new(0,0,-3)
                    tStatL.Text="→ "..cp.DisplayName; tStatL.TextColor3=THEME.success; Smooth(tDot,{BackgroundColor3=THEME.success},.2)
                    Notify("Teleport","→ "..cp.DisplayName,2,"success")
                    task.delay(2,function() tStatL.Text="Select player"; tStatL.TextColor3=THEME.textMuted; Smooth(tDot,{BackgroundColor3=THEME.textMuted},.2) end)
                end)
                table.insert(tpToPlayerBtns,pF)
                table.insert(tpToAllFrames,{frame=pF,name=plr.Name..plr.DisplayName})
            end
        end
        if #tpToPlayerBtns==0 then local eL=Instance.new("TextLabel"); eL.Size=UDim2.new(1,0,0,28); eL.BackgroundTransparency=1; eL.Font=Enum.Font.Gotham; eL.Text="No other players"; eL.TextColor3=THEME.textMuted; eL.TextSize=10; eL.Parent=tpToPlrCont; table.insert(tpToPlayerBtns,eL) end
    end
    Players.PlayerAdded:Connect(function() task.wait(1); RefreshTpToList() end)
    Players.PlayerRemoving:Connect(function() task.wait(.1); RefreshTpToList() end)
    task.spawn(RefreshTpToList)
end

-- ELIMINATION TAB
local teleportStatusL,teleportStatusDot,teleportPlrCont,teleportPlayerBtns,elimAllFrames
do
    local TP=tabContents["Elimination"]
    -- CHANGED: glass style status frame
    local tSF=Instance.new("Frame"); tSF.Size=UDim2.new(1,0,0,36); tSF.BackgroundColor3=Color3.fromRGB(255,255,255); tSF.BackgroundTransparency=.92; tSF.BorderSizePixel=0; tSF.Parent=TP; Corner(tSF,12); Stroke(tSF,Color3.fromRGB(255,255,255),1,.82)
    teleportStatusDot=Instance.new("Frame"); teleportStatusDot.Size=UDim2.new(0,5,0,5); teleportStatusDot.Position=UDim2.new(0,12,.5,-2); teleportStatusDot.BackgroundColor3=THEME.textMuted; teleportStatusDot.BorderSizePixel=0; teleportStatusDot.Parent=tSF; Corner(teleportStatusDot,3)
    teleportStatusL=Instance.new("TextLabel"); teleportStatusL.Size=UDim2.new(1,-26,1,0); teleportStatusL.Position=UDim2.new(0,24,0,0); teleportStatusL.BackgroundTransparency=1; teleportStatusL.Font=Enum.Font.GothamMedium; teleportStatusL.Text="Select players"; teleportStatusL.TextColor3=THEME.textMuted; teleportStatusL.TextSize=11; teleportStatusL.TextXAlignment=Enum.TextXAlignment.Left; teleportStatusL.Parent=tSF
    SectionLabel(TP,"Controls")
    local loopRow=Instance.new("Frame"); loopRow.Size=UDim2.new(1,0,0,36); loopRow.BackgroundTransparency=1; loopRow.Parent=TP
    -- CHANGED: glass toggle button
    local LoopToggle=Instance.new("TextButton"); LoopToggle.Size=UDim2.new(1,0,1,0); LoopToggle.BackgroundColor3=Color3.fromRGB(255,255,255); LoopToggle.BackgroundTransparency=.88; LoopToggle.Font=Enum.Font.GothamBold; LoopToggle.Text="● Auto: OFF"; LoopToggle.TextColor3=Color3.fromRGB(130,130,130); LoopToggle.TextSize=12; LoopToggle.AutoButtonColor=false; LoopToggle.BorderSizePixel=0; LoopToggle.Parent=loopRow; Corner(LoopToggle,10); Stroke(LoopToggle,Color3.fromRGB(255,255,255),1,.78)
    LoopToggle.MouseEnter:Connect(function() Smooth(LoopToggle,{BackgroundTransparency=.78},.1) end)
    LoopToggle.MouseLeave:Connect(function() Smooth(LoopToggle,{BackgroundTransparency=teleportLoopEnabled and .75 or .88},.1) end)
    local selRow=Instance.new("Frame"); selRow.Size=UDim2.new(1,0,0,28); selRow.BackgroundTransparency=1; selRow.Parent=TP
    local sLayout=Instance.new("UIListLayout"); sLayout.FillDirection=Enum.FillDirection.Horizontal; sLayout.Padding=UDim.new(0,6); sLayout.Parent=selRow
    local function SBtn(txt)
        local b=Instance.new("TextButton"); b.Size=UDim2.new(0.5,-3,1,0); b.BackgroundColor3=Color3.fromRGB(255,255,255); b.BackgroundTransparency=.92; b.Font=Enum.Font.GothamBold; b.Text=txt; b.TextColor3=THEME.textDim; b.TextSize=10; b.AutoButtonColor=false; b.BorderSizePixel=0; b.Parent=selRow; Corner(b,8); Stroke(b,Color3.fromRGB(255,255,255),1,.82)
        b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=.80},.1) end)
        b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=.92},.1) end)
        return b
    end
    local selAllBtn=SBtn("Select All"); local deselAllBtn=SBtn("Unselect All")
    SectionLabel(TP,"Players")
    MakeSearchBar(TP,function(q)
        if not elimAllFrames then return end
        for _,fd in pairs(elimAllFrames) do
            if fd.frame and fd.frame.Parent then
                fd.frame.Visible=(q=="" or fd.name:lower():find(q,1,true)~=nil)
            end
        end
    end)
    teleportPlrCont=Instance.new("Frame"); teleportPlrCont.Size=UDim2.new(1,0,0,0); teleportPlrCont.AutomaticSize=Enum.AutomaticSize.Y; teleportPlrCont.BackgroundTransparency=1; teleportPlrCont.Parent=TP
    Instance.new("UIListLayout",teleportPlrCont).Padding=UDim.new(0,3)
    teleportPlayerBtns={}; elimAllFrames={}
    local function UpdateTeleportStatus()
        local cnt=0; for _ in pairs(selectedTeleportPlayers) do cnt+=1 end
        if teleportLoopEnabled then
            teleportStatusL.Text="Auto: "..cnt.." players"; teleportStatusL.TextColor3=THEME.success; Smooth(teleportStatusDot,{BackgroundColor3=THEME.success},.2)
            LoopToggle.Text="● Auto: ON"; LoopToggle.TextColor3=Color3.fromRGB(200,200,200); Smooth(LoopToggle,{BackgroundTransparency=.75},.15)
        else
            teleportStatusL.Text=cnt>0 and ("Selected: "..cnt) or "Select players"
            teleportStatusL.TextColor3=cnt>0 and THEME.textDim or THEME.textMuted
            Smooth(teleportStatusDot,{BackgroundColor3=cnt>0 and THEME.textDim or THEME.textMuted},.2)
            LoopToggle.Text="● Auto: OFF"; LoopToggle.TextColor3=Color3.fromRGB(130,130,130); Smooth(LoopToggle,{BackgroundTransparency=.88},.15)
        end
    end
    local teleportFrameData={}
    local function TeleportPlayersToMe()
        if not LP.Character or not LP.Character:FindFirstChild("HumanoidRootPart") then return end
        local hrp=LP.Character.HumanoidRootPart
        for _,player in pairs(selectedTeleportPlayers) do
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame=hrp.CFrame*CFrame.new(0,0,-3)
            end
        end
    end
    local function RefreshTeleportList()
        for _,b in pairs(teleportPlayerBtns) do pcall(function() b:Destroy() end) end
        teleportPlayerBtns={}; teleportFrameData={}; elimAllFrames={}
        local plrs=Players:GetPlayers(); table.sort(plrs,function(a,b2) return a.Name:lower()<b2.Name:lower() end)
        for _,plr in ipairs(plrs) do
            if plr~=LP then
                local isSel=selectedTeleportPlayers[plr.Name]~=nil
                -- CHANGED: glass style player frames
                local pF=Instance.new("Frame"); pF.Size=UDim2.new(1,0,0,44); pF.BackgroundColor3=Color3.fromRGB(255,255,255); pF.BackgroundTransparency=isSel and .82 or .92; pF.BorderSizePixel=0; pF.Parent=teleportPlrCont; Corner(pF,12)
                local pStroke=Stroke(pF,isSel and THEME.primary or Color3.fromRGB(255,255,255),1,isSel and .5 or .82)
                local function PL(sz,pos,font,txt,col,tsz) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=font; l.Text=txt; l.TextColor3=col; l.TextSize=tsz; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=pF end
                PL(UDim2.new(1,-50,0,16),UDim2.new(0,10,0,6),Enum.Font.GothamSemibold,plr.DisplayName,THEME.text,12)
                PL(UDim2.new(1,-50,0,12),UDim2.new(0,10,0,24),Enum.Font.Gotham,"@"..plr.Name,THEME.textMuted,9)
                local chk=Instance.new("Frame"); chk.Size=UDim2.new(0,22,0,22); chk.Position=UDim2.new(1,-32,.5,-11); chk.BackgroundColor3=isSel and THEME.primary or Color3.fromRGB(255,255,255); chk.BackgroundTransparency=isSel and .3 or .90; chk.BorderSizePixel=0; chk.ZIndex=213; chk.Parent=pF; Corner(chk,8); Stroke(chk,Color3.fromRGB(255,255,255),1,.72)
                local chkL=Instance.new("TextLabel"); chkL.Size=UDim2.new(1,0,1,0); chkL.BackgroundTransparency=1; chkL.Font=Enum.Font.GothamBold; chkL.Text=isSel and "✓" or ""; chkL.TextColor3=THEME.text; chkL.TextSize=13; chkL.ZIndex=214; chkL.Parent=chk
                local clickArea=Instance.new("TextButton"); clickArea.Size=UDim2.new(1,0,1,0); clickArea.BackgroundTransparency=1; clickArea.Text=""; clickArea.ZIndex=215; clickArea.Parent=pF
                local cp,cpName=plr,plr.Name
                local function setSelected(sel)
                    if sel then selectedTeleportPlayers[cpName]=cp; Smooth(pF,{BackgroundTransparency=.82},.12); Smooth(chk,{BackgroundTransparency=.3},.12); Smooth(pStroke,{Color=THEME.primary,Transparency=.5},.12); chkL.Text="✓"
                    else selectedTeleportPlayers[cpName]=nil; Smooth(pF,{BackgroundTransparency=.92},.12); Smooth(chk,{BackgroundTransparency=.90},.12); Smooth(pStroke,{Color=Color3.fromRGB(255,255,255),Transparency=.82},.12); chkL.Text="" end
                    UpdateTeleportStatus()
                end
                teleportFrameData[cpName]=setSelected
                clickArea.MouseButton1Click:Connect(function() setSelected(selectedTeleportPlayers[cpName]==nil) end)
                clickArea.MouseEnter:Connect(function() if not selectedTeleportPlayers[cpName] then Smooth(pF,{BackgroundTransparency=.86},.08) end end)
                clickArea.MouseLeave:Connect(function() if not selectedTeleportPlayers[cpName] then Smooth(pF,{BackgroundTransparency=.92},.08) end end)
                table.insert(teleportPlayerBtns,pF)
                table.insert(elimAllFrames,{frame=pF,name=plr.Name..plr.DisplayName})
            end
        end
        if #teleportPlayerBtns==0 then local eL=Instance.new("TextLabel"); eL.Size=UDim2.new(1,0,0,28); eL.BackgroundTransparency=1; eL.Font=Enum.Font.Gotham; eL.Text="No other players"; eL.TextColor3=THEME.textMuted; eL.TextSize=10; eL.Parent=teleportPlrCont; table.insert(teleportPlayerBtns,eL) end
    end
    LoopToggle.MouseButton1Click:Connect(function()
        local cnt=0; for _ in pairs(selectedTeleportPlayers) do cnt+=1 end
        if not teleportLoopEnabled and cnt==0 then Notify("Elimination","Select players first",2,"warning"); return end
        teleportLoopEnabled=not teleportLoopEnabled
        if teleportLoopEnabled then
            if teleportLoopConnection then pcall(function() teleportLoopConnection:Disconnect() end) end
            teleportLoopConnection=RS.Heartbeat:Connect(function() if teleportLoopEnabled and Running then TeleportPlayersToMe() end end)
            table.insert(allConnections,teleportLoopConnection)
            Notify("Elimination","Auto enabled",2,"success")
        else
            if teleportLoopConnection then pcall(function() teleportLoopConnection:Disconnect() end); teleportLoopConnection=nil end
            Notify("Elimination","Auto disabled",2,"info")
        end
        UpdateTeleportStatus()
    end)
    selAllBtn.MouseButton1Click:Connect(function() for _,p in ipairs(Players:GetPlayers()) do if p~=LP then selectedTeleportPlayers[p.Name]=p; if teleportFrameData[p.Name] then teleportFrameData[p.Name](true) end end end; UpdateTeleportStatus() end)
    deselAllBtn.MouseButton1Click:Connect(function() selectedTeleportPlayers={}; for _,fn in pairs(teleportFrameData) do fn(false) end; UpdateTeleportStatus() end)
    Players.PlayerAdded:Connect(function() task.wait(1); RefreshTeleportList() end)
    Players.PlayerRemoving:Connect(function(p) task.wait(.1); selectedTeleportPlayers[p.Name]=nil; RefreshTeleportList(); UpdateTeleportStatus() end)
    task.spawn(RefreshTeleportList)
end

-- VOID TAB
local voidStatusL2,voidStatusDot2
do
    local VP=tabContents["Void"]
    -- CHANGED: glass style
    local vSF=Instance.new("Frame"); vSF.Size=UDim2.new(1,0,0,36); vSF.BackgroundColor3=Color3.fromRGB(255,255,255); vSF.BackgroundTransparency=.92; vSF.BorderSizePixel=0; vSF.Parent=VP; Corner(vSF,12); Stroke(vSF,Color3.fromRGB(255,255,255),1,.82)
    voidStatusDot2=Instance.new("Frame"); voidStatusDot2.Size=UDim2.new(0,5,0,5); voidStatusDot2.Position=UDim2.new(0,12,.5,-2); voidStatusDot2.BackgroundColor3=THEME.textMuted; voidStatusDot2.BorderSizePixel=0; voidStatusDot2.Parent=vSF; Corner(voidStatusDot2,3)
    voidStatusL2=Instance.new("TextLabel"); voidStatusL2.Size=UDim2.new(1,-26,1,0); voidStatusL2.Position=UDim2.new(0,24,0,0); voidStatusL2.BackgroundTransparency=1; voidStatusL2.Font=Enum.Font.GothamMedium; voidStatusL2.Text="Above ground"; voidStatusL2.TextColor3=THEME.textMuted; voidStatusL2.TextSize=11; voidStatusL2.TextXAlignment=Enum.TextXAlignment.Left; voidStatusL2.Parent=vSF
    SectionLabel(VP,"Depth")
    Slider(VP,"Y Offset",-500,-10,voidYOffset,function(v) voidYOffset=v; if voidActive then voidTargetY=(cachedLowestY or 0)+voidYOffset end end)
    SectionLabel(VP,"Controls")
    local vBR=Instance.new("Frame"); vBR.Size=UDim2.new(1,0,0,32); vBR.BackgroundTransparency=1; vBR.Parent=VP
    local vBL=Instance.new("UIListLayout"); vBL.FillDirection=Enum.FillDirection.Horizontal; vBL.Padding=UDim.new(0,6); vBL.Parent=vBR
    -- CHANGED: glass style void buttons
    local function VBtn(txt,isGreen)
        local col=isGreen and Color3.fromRGB(180,180,180) or Color3.fromRGB(110,110,110)
        local b=Instance.new("TextButton"); b.Size=UDim2.new(0.5,-3,1,0); b.BackgroundColor3=Color3.fromRGB(255,255,255); b.BackgroundTransparency=.88; b.Font=Enum.Font.GothamBold; b.Text=txt; b.TextColor3=isGreen and Color3.fromRGB(210,210,210) or Color3.fromRGB(150,150,150); b.TextSize=11; b.AutoButtonColor=false; b.BorderSizePixel=0; b.Parent=vBR; Corner(b,10); Stroke(b,col,1,.55)
        b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=.75},.1) end)
        b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=.88},.1) end)
        return b
    end
    local vGo=VBtn("Go Under",false); local vBack=VBtn("Return",true)
    vGo.MouseButton1Click:Connect(function() if voidActive then Notify("Void","Already under",2,"warning"); return end; StartVoid() end)
    vBack.MouseButton1Click:Connect(function() if not voidActive then Notify("Void","Not under map",2,"info"); return end; StopVoid() end)
end
UpdateVoidStatus=function()
    if not voidStatusL2 or not voidStatusDot2 then return end
    if voidActive then voidStatusL2.Text="Under map"; voidStatusL2.TextColor3=THEME.success; Smooth(voidStatusDot2,{BackgroundColor3=THEME.success},.2)
    else voidStatusL2.Text="Above ground"; voidStatusL2.TextColor3=THEME.textMuted; Smooth(voidStatusDot2,{BackgroundColor3=THEME.textMuted},.2) end
end

-- ADMIN TAB
local adminListCont,adminListItems,adminStatusL2
do
    local AP=tabContents["Admin"]
    -- CHANGED: glass style
    local aSF=Instance.new("Frame"); aSF.Size=UDim2.new(1,0,0,36); aSF.BackgroundColor3=Color3.fromRGB(255,255,255); aSF.BackgroundTransparency=.92; aSF.BorderSizePixel=0; aSF.Parent=AP; Corner(aSF,12); Stroke(aSF,Color3.fromRGB(255,255,255),1,.82)
    adminStatusL2=Instance.new("TextLabel"); adminStatusL2.Size=UDim2.new(1,-16,1,0); adminStatusL2.Position=UDim2.new(0,12,0,0); adminStatusL2.BackgroundTransparency=1; adminStatusL2.Font=Enum.Font.GothamMedium; adminStatusL2.Text="Scanning..."; adminStatusL2.TextColor3=THEME.textMuted; adminStatusL2.TextSize=11; adminStatusL2.TextXAlignment=Enum.TextXAlignment.Left; adminStatusL2.Parent=aSF
    SectionLabel(AP,"Settings")
    local function AdminTog(parent,name,defVal,cb)
        -- CHANGED: glass style
        local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,38); f.BackgroundColor3=Color3.fromRGB(255,255,255); f.BackgroundTransparency=.92; f.BorderSizePixel=0; f.Parent=parent; Corner(f,10); Stroke(f,Color3.fromRGB(255,255,255),1,.78)
        local nL=Instance.new("TextLabel"); nL.Size=UDim2.new(1,-60,0,16); nL.Position=UDim2.new(0,10,.5,-8); nL.BackgroundTransparency=1; nL.Font=Enum.Font.GothamSemibold; nL.Text=name; nL.TextColor3=THEME.text; nL.TextSize=11; nL.TextXAlignment=Enum.TextXAlignment.Left; nL.Parent=f
        local tBg=Instance.new("Frame"); tBg.Size=UDim2.new(0,36,0,20); tBg.Position=UDim2.new(1,-44,.5,-10); tBg.BackgroundColor3=defVal and Color3.fromRGB(200,200,200) or Color3.fromRGB(50,50,50); tBg.BackgroundTransparency=.25; tBg.BorderSizePixel=0; tBg.Parent=f; Corner(tBg,10)
        local tSt=Instance.new("UIStroke"); tSt.Thickness=1; tSt.Color=defVal and Color3.fromRGB(200,200,200) or Color3.fromRGB(80,80,80); tSt.Parent=tBg
        local tK=Instance.new("Frame"); tK.Size=UDim2.new(0,16,0,16); tK.Position=defVal and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2); tK.BackgroundColor3=Color3.new(1,1,1); tK.BorderSizePixel=0; tK.Parent=tBg; Corner(tK,8)
        local en=defVal; local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=f
        btn.MouseButton1Click:Connect(function()
            en=not en
            Smooth(tBg,{BackgroundColor3=en and Color3.fromRGB(200,200,200) or Color3.fromRGB(50,50,50),BackgroundTransparency=.25},.18)
            Smooth(tSt,{Color=en and Color3.fromRGB(200,200,200) or Color3.fromRGB(80,80,80)},.18)
            Tween(tK,{Position=en and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)},.2,Enum.EasingStyle.Back)
            cb(en); SaveSettings()
        end)
        f.MouseEnter:Connect(function() Smooth(f,{BackgroundTransparency=.84},.1) end)
        f.MouseLeave:Connect(function() Smooth(f,{BackgroundTransparency=.92},.1) end)
    end
    AdminTog(AP,"Join Alerts",AdminAlertEnabled,function(v) AdminAlertEnabled=v end)
    SectionLabel(AP,"Admins In Server")
    adminListCont=Instance.new("Frame"); adminListCont.Size=UDim2.new(1,0,0,0); adminListCont.AutomaticSize=Enum.AutomaticSize.Y; adminListCont.BackgroundTransparency=1; adminListCont.Parent=AP; Instance.new("UIListLayout",adminListCont).Padding=UDim.new(0,4); adminListItems={}
end

local function RefreshAdminList()
    for _,item in pairs(adminListItems) do pcall(function() item:Destroy() end) end; adminListItems={}
    local adminCount=0
    for _,plr in pairs(Players:GetPlayers()) do
        if plr~=LP then
            local isAdmin,rank=CheckIfAdmin(plr)
            if isAdmin then
                adminCount+=1
                -- CHANGED: glass style admin card
                local aF=Instance.new("Frame"); aF.Size=UDim2.new(1,0,0,56); aF.BackgroundColor3=Color3.fromRGB(255,255,255); aF.BackgroundTransparency=.90; aF.BorderSizePixel=0; aF.Parent=adminListCont; Corner(aF,12); Stroke(aF,Color3.fromRGB(255,255,255),1,.78)
                local strip=Instance.new("Frame"); strip.Size=UDim2.new(0,3,.7,0); strip.Position=UDim2.new(0,0,.15,0); strip.BackgroundColor3=Color3.fromRGB(185,148,55); strip.BorderSizePixel=0; strip.Parent=aF; Corner(strip,2)
                local function AL(sz,pos,font,txt,col,tsz) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=font; l.Text=txt; l.TextColor3=col; l.TextSize=tsz; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=aF end
                AL(UDim2.new(1,-16,0,16),UDim2.new(0,14,0,6),Enum.Font.GothamBold,plr.DisplayName,THEME.text,11)
                AL(UDim2.new(1,-16,0,11),UDim2.new(0,14,0,24),Enum.Font.Gotham,"@"..plr.Name,THEME.textMuted,9)
                AL(UDim2.new(1,-16,0,11),UDim2.new(0,14,0,37),Enum.Font.GothamBold,"Rank: "..tostring(rank),Color3.fromRGB(180,180,180),9)
                table.insert(adminListItems,aF)
            end
        end
    end
    if adminCount==0 then
        local eL=Instance.new("Frame"); eL.Size=UDim2.new(1,0,0,36); eL.BackgroundColor3=Color3.fromRGB(255,255,255); eL.BackgroundTransparency=.92; eL.BorderSizePixel=0; eL.Parent=adminListCont; Corner(eL,10); Stroke(eL,Color3.fromRGB(255,255,255),1,.82)
        local eLT=Instance.new("TextLabel"); eLT.Size=UDim2.new(1,0,1,0); eLT.BackgroundTransparency=1; eLT.Font=Enum.Font.GothamMedium; eLT.Text="No admins detected"; eLT.TextColor3=THEME.textMuted; eLT.TextSize=10; eLT.Parent=eL; table.insert(adminListItems,eL)
        if adminStatusL2 then adminStatusL2.Text="No admins detected"; adminStatusL2.TextColor3=THEME.textMuted end
    else if adminStatusL2 then adminStatusL2.Text=adminCount.." admin(s) in server"; adminStatusL2.TextColor3=THEME.textDim end end
    RefreshAdminWindow()
end

-- SETTINGS TAB
do
    local SP=tabContents["Settings"]
    SectionLabel(SP,"Menu")
    local function SettCard(parent,title,desc,h)
        -- CHANGED: glass style
        local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,h or 46); f.BackgroundColor3=Color3.fromRGB(255,255,255); f.BackgroundTransparency=.92; f.BorderSizePixel=0; f.Parent=parent; Corner(f,10); Stroke(f,Color3.fromRGB(255,255,255),1,.78)
        f.MouseEnter:Connect(function() Smooth(f,{BackgroundTransparency=.85},.1) end); f.MouseLeave:Connect(function() Smooth(f,{BackgroundTransparency=.92},.1) end)
        local t=Instance.new("TextLabel"); t.Size=UDim2.new(.6,0,0,16); t.Position=UDim2.new(0,10,0,6); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamSemibold; t.Text=title; t.TextColor3=THEME.text; t.TextSize=11; t.TextXAlignment=Enum.TextXAlignment.Left; t.Parent=f
        local d=Instance.new("TextLabel"); d.Size=UDim2.new(.6,0,0,11); d.Position=UDim2.new(0,10,0,26); d.BackgroundTransparency=1; d.Font=Enum.Font.Gotham; d.Text=desc; d.TextColor3=THEME.textMuted; d.TextSize=9; d.TextXAlignment=Enum.TextXAlignment.Left; d.Parent=f; return f
    end
    local function MiniToggle(parent,defVal,cb)
        local tBg=Instance.new("Frame"); tBg.Size=UDim2.new(0,36,0,20); tBg.Position=UDim2.new(1,-44,.5,-10); tBg.BackgroundColor3=defVal and Color3.fromRGB(200,200,200) or Color3.fromRGB(50,50,50); tBg.BackgroundTransparency=.25; tBg.BorderSizePixel=0; tBg.Parent=parent; Corner(tBg,10)
        local tSt=Instance.new("UIStroke"); tSt.Thickness=1; tSt.Color=defVal and Color3.fromRGB(200,200,200) or Color3.fromRGB(80,80,80); tSt.Parent=tBg
        local tK=Instance.new("Frame"); tK.Size=UDim2.new(0,16,0,16); tK.Position=defVal and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2); tK.BackgroundColor3=Color3.new(1,1,1); tK.BorderSizePixel=0; tK.ZIndex=213; tK.Parent=tBg; Corner(tK,8)
        local en=defVal; local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,36,0,20); btn.Position=UDim2.new(1,-44,.5,-10); btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=215; btn.Parent=parent
        btn.MouseButton1Click:Connect(function()
            en=not en
            Smooth(tBg,{BackgroundColor3=en and Color3.fromRGB(200,200,200) or Color3.fromRGB(50,50,50),BackgroundTransparency=.25},.18)
            Smooth(tSt,{Color=en and Color3.fromRGB(200,200,200) or Color3.fromRGB(80,80,80)},.18)
            Tween(tK,{Position=en and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)},.2,Enum.EasingStyle.Back)
            cb(en); SaveSettings()
        end)
    end
    local keyCard=SettCard(SP,"Menu Toggle Key","Click to change")
    local keyBadge=Instance.new("TextButton"); keyBadge.Size=UDim2.new(0,80,0,24); keyBadge.Position=UDim2.new(1,-90,.5,-12); keyBadge.BackgroundColor3=Color3.fromRGB(255,255,255); keyBadge.BackgroundTransparency=.88; keyBadge.Font=Enum.Font.Gotham; keyBadge.Text=MenuToggleKey; keyBadge.TextColor3=THEME.textDim; keyBadge.TextSize=10; keyBadge.AutoButtonColor=false; keyBadge.Parent=keyCard; Corner(keyBadge,8); Stroke(keyBadge,Color3.fromRGB(255,255,255),1,.78)
    keyBadge.MouseEnter:Connect(function() if not isWaitingForKey then Smooth(keyBadge,{BackgroundTransparency=.75,TextColor3=THEME.text},.1) end end)
    keyBadge.MouseLeave:Connect(function() if not isWaitingForKey then Smooth(keyBadge,{BackgroundTransparency=.88,TextColor3=THEME.textDim},.1) end end)
    keyBadge.MouseButton1Click:Connect(function()
        if isWaitingForKey then return end; isWaitingForKey=true; keyBadge.Text="..."; keyBadge.TextColor3=THEME.primary; Smooth(keyBadge,{BackgroundTransparency=.70},.1)
        local kconn; kconn=UIS.InputBegan:Connect(function(i2,gp2)
            if gp2 then return end
            if i2.UserInputType==Enum.UserInputType.Keyboard then
                if i2.KeyCode==Enum.KeyCode.Escape then isWaitingForKey=false; keyBadge.Text=MenuToggleKey; keyBadge.TextColor3=THEME.textDim; Smooth(keyBadge,{BackgroundTransparency=.88},.1); kconn:Disconnect(); return end
                local kn2=tostring(i2.KeyCode):gsub("Enum.KeyCode.",""); MenuToggleKey=kn2; keyBadge.Text=kn2; keyBadge.TextColor3=THEME.textDim; Smooth(keyBadge,{BackgroundTransparency=.88},.1); isWaitingForKey=false; kconn:Disconnect(); SaveSettings(); Notify("Settings","Menu key → ["..kn2.."]",2,"success")
            end
        end)
    end)
    local snowCard=SettCard(SP,"Snow Effect","Falling snow in menu")
    MiniToggle(snowCard,snowEnabled,function(v)
        snowEnabled=v
        if snowEnabled then createSnowContainer(menuFrame)
        else if snowContainer and snowContainer.Parent then for _,c in pairs(snowContainer:GetChildren()) do c:Destroy() end end; snowParticles={} end
        Notify("Snow",snowEnabled and "Enabled" or "Disabled",2,snowEnabled and "success" or "info")
    end)
    local rainCard=SettCard(SP,"Rain Effect","Falling rain in menu")
    MiniToggle(rainCard,rainEnabled,function(v)
        rainEnabled=v
        if rainEnabled then createRainContainer(menuFrame)
        else if rainContainer and rainContainer.Parent then for _,c in pairs(rainContainer:GetChildren()) do c:Destroy() end end; rainParticles={} end
        Notify("Rain",rainEnabled and "Enabled" or "Disabled",2,rainEnabled and "success" or "info")
    end)
    local bgCard=SettCard(SP,"Transparent Background","Toggle UI background transparency")
    MiniToggle(bgCard,transparentBg,function(v)
        transparentBg=v
        Smooth(menuFrame,{BackgroundTransparency=v and .55 or .9},.25)
        Notify("UI",v and "Transparent background" or "Solid background",2,"info")
    end)
    SectionLabel(SP,"Accent Color")
    local colorCard=Instance.new("Frame"); colorCard.Size=UDim2.new(1,0,0,56); colorCard.BackgroundColor3=Color3.fromRGB(255,255,255); colorCard.BackgroundTransparency=.92; colorCard.BorderSizePixel=0; colorCard.Parent=SP; Corner(colorCard,10); Stroke(colorCard,Color3.fromRGB(255,255,255),1,.78)
    local cLabel=Instance.new("TextLabel"); cLabel.Size=UDim2.new(1,-60,0,16); cLabel.Position=UDim2.new(0,10,0,4); cLabel.BackgroundTransparency=1; cLabel.Font=Enum.Font.GothamSemibold; cLabel.Text="Hue"; cLabel.TextColor3=THEME.text; cLabel.TextSize=10; cLabel.TextXAlignment=Enum.TextXAlignment.Left; cLabel.Parent=colorCard
    local preview=Instance.new("Frame"); preview.Size=UDim2.new(0,16,0,16); preview.Position=UDim2.new(1,-26,0,4); preview.BackgroundColor3=THEME.primary; preview.BorderSizePixel=0; preview.Parent=colorCard; Corner(preview,4); Stroke(preview,Color3.fromRGB(255,255,255),1,.6)
    local hueTrack=Instance.new("Frame"); hueTrack.Size=UDim2.new(1,-20,0,10); hueTrack.Position=UDim2.new(0,10,0,24); hueTrack.BackgroundColor3=Color3.new(1,1,1); hueTrack.BorderSizePixel=0; hueTrack.Parent=colorCard; Corner(hueTrack,3)
    local hueGrad=Instance.new("UIGradient"); hueGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(.16,Color3.fromHSV(.16,1,1)),ColorSequenceKeypoint.new(.33,Color3.fromHSV(.33,1,1)),ColorSequenceKeypoint.new(.5,Color3.fromHSV(.5,1,1)),ColorSequenceKeypoint.new(.66,Color3.fromHSV(.66,1,1)),ColorSequenceKeypoint.new(.83,Color3.fromHSV(.83,1,1)),ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))}); hueGrad.Parent=hueTrack
    local hueKnob=Instance.new("Frame"); hueKnob.Size=UDim2.new(0,12,0,14); hueKnob.Position=UDim2.new(state_theme.themeHue,-6,.5,-7); hueKnob.BackgroundColor3=THEME.text; hueKnob.BorderSizePixel=0; hueKnob.ZIndex=3; hueKnob.Parent=hueTrack; Corner(hueKnob,3); Stroke(hueKnob,Color3.new(0,0,0),1,0)
    local svTrack=Instance.new("Frame"); svTrack.Size=UDim2.new(1,-20,0,10); svTrack.Position=UDim2.new(0,10,0,40); svTrack.BackgroundColor3=Color3.new(1,1,1); svTrack.BorderSizePixel=0; svTrack.Parent=colorCard; Corner(svTrack,3)
    local svGrad=Instance.new("UIGradient"); svGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),ColorSequenceKeypoint.new(.5,Color3.fromHSV(state_theme.themeHue,.8,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}); svGrad.Parent=svTrack
    local svKnob=Instance.new("Frame"); svKnob.Size=UDim2.new(0,12,0,14); svKnob.Position=UDim2.new(.5,-6,.5,-7); svKnob.BackgroundColor3=THEME.text; svKnob.BorderSizePixel=0; svKnob.ZIndex=3; svKnob.Parent=svTrack; Corner(svKnob,3); Stroke(svKnob,Color3.new(0,0,0),1,0)
    local function updateColorPreview() preview.BackgroundColor3=Color3.fromHSV(state_theme.themeHue,state_theme.themeSat,state_theme.themeVal); svGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0,0,0)),ColorSequenceKeypoint.new(.5,Color3.fromHSV(state_theme.themeHue,.8,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}); updateThemeColors(); SaveSettings() end
    local function applyHue(x) local aP,aS=hueTrack.AbsolutePosition.X,hueTrack.AbsoluteSize.X; if aS>0 then local pct=math.clamp((x-aP)/aS,0,.999); state_theme.themeHue=pct; hueKnob.Position=UDim2.new(pct,-6,.5,-7); updateColorPreview() end end
    local function applySV(x) local aP,aS=svTrack.AbsolutePosition.X,svTrack.AbsoluteSize.X; if aS>0 then local pct=math.clamp((x-aP)/aS,0,1); svKnob.Position=UDim2.new(pct,-6,.5,-7); local sat,val; if pct<=.5 then sat=.8; val=pct*2 else sat=1-(pct-.5)*2; val=1 end; state_theme.themeSat=math.clamp(sat,0,1); state_theme.themeVal=math.clamp(val,0,1); updateColorPreview() end end
    local hBtn=Instance.new("TextButton"); hBtn.Size=UDim2.new(1,0,5,0); hBtn.Position=UDim2.new(0,0,-2,0); hBtn.BackgroundTransparency=1; hBtn.Text=""; hBtn.Parent=hueTrack; hBtn.ZIndex=5
    hBtn.MouseButton1Down:Connect(function() Smooth(hueKnob,{Size=UDim2.new(0,14,0,14)},.06); applyHue(UIS:GetMouseLocation().X); activeSliderDrag={track=hueTrack,apply=applyHue,knob=hueKnob} end)
    local sBtn2=Instance.new("TextButton"); sBtn2.Size=UDim2.new(1,0,5,0); sBtn2.Position=UDim2.new(0,0,-2,0); sBtn2.BackgroundTransparency=1; sBtn2.Text=""; sBtn2.Parent=svTrack; sBtn2.ZIndex=5
    sBtn2.MouseButton1Down:Connect(function() Smooth(svKnob,{Size=UDim2.new(0,14,0,14)},.06); applySV(UIS:GetMouseLocation().X); activeSliderDrag={track=svTrack,apply=applySV,knob=svKnob} end)
    SectionLabel(SP,"Unload")
    local uCard=Instance.new("Frame"); uCard.Size=UDim2.new(1,0,0,46); uCard.BackgroundColor3=Color3.fromRGB(255,255,255); uCard.BackgroundTransparency=.92; uCard.BorderSizePixel=0; uCard.Parent=SP; Corner(uCard,10); Stroke(uCard,Color3.fromRGB(100,60,60),1,.5)
    local uT=Instance.new("TextLabel"); uT.Size=UDim2.new(.6,0,0,16); uT.Position=UDim2.new(0,10,0,6); uT.BackgroundTransparency=1; uT.Font=Enum.Font.GothamBold; uT.Text="Unload Script"; uT.TextColor3=Color3.fromRGB(180,100,100); uT.TextSize=12; uT.TextXAlignment=Enum.TextXAlignment.Left; uT.Parent=uCard
    local uD=Instance.new("TextLabel"); uD.Size=UDim2.new(.6,0,0,11); uD.Position=UDim2.new(0,10,0,26); uD.BackgroundTransparency=1; uD.Font=Enum.Font.Gotham; uD.Text="Remove script completely"; uD.TextColor3=THEME.textMuted; uD.TextSize=9; uD.TextXAlignment=Enum.TextXAlignment.Left; uD.Parent=uCard
    local uBtn=Instance.new("TextButton"); uBtn.Size=UDim2.new(0,72,0,26); uBtn.Position=UDim2.new(1,-82,.5,-13); uBtn.BackgroundColor3=Color3.fromRGB(255,255,255); uBtn.BackgroundTransparency=.88; uBtn.Font=Enum.Font.GothamBold; uBtn.Text="Unload"; uBtn.TextColor3=Color3.fromRGB(180,100,100); uBtn.TextSize=10; uBtn.AutoButtonColor=false; uBtn.Parent=uCard; Corner(uBtn,8); Stroke(uBtn,Color3.fromRGB(150,70,70),1,.5)
    uBtn.MouseEnter:Connect(function() Smooth(uBtn,{BackgroundTransparency=.75},.1) end); uBtn.MouseLeave:Connect(function() Smooth(uBtn,{BackgroundTransparency=.88},.1) end)
    uBtn.MouseButton1Click:Connect(function()
        Running=false; FlingActive=false; voidActive=false
        StopNoclip(); StopFly(); ClearESP()
        if voidConnection then pcall(function() voidConnection:Disconnect() end) end
        if teleportLoopConnection then pcall(function() teleportLoopConnection:Disconnect() end) end
        for _,cn in pairs(allConnections) do pcall(function() cn:Disconnect() end) end
        local h=GetHum(); if h then h.WalkSpeed=16; h.JumpPower=50 end
        for _,item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end
        if LP.Character then for _,item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end
        pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end); RemoveBlur()
        Notify("QWEN","Unloaded",2,"error")
        task.delay(.6,function() for _,g in pairs(game.CoreGui:GetChildren()) do if g.Name:find("QWEN") then pcall(function() g:Destroy() end) end end end)
    end)
end

local HUDSG=Instance.new("ScreenGui"); HUDSG.Name="QWENHUD"; HUDSG.Parent=game.CoreGui; HUDSG.ResetOnSpawn=false; HUDSG.IgnoreGuiInset=true
local HUD=Instance.new("Frame"); HUD.Size=UDim2.new(0,260,0,28); HUD.Position=LoadPos(HUD_POS_KEY,12,12); HUD.BackgroundColor3=Color3.fromRGB(0,0,0); HUD.BackgroundTransparency=.45; HUD.BorderSizePixel=0; HUD.Active=true; HUD.Parent=HUDSG; Corner(HUD,14)
local hudStroke=Instance.new("UIStroke"); hudStroke.Thickness=1; hudStroke.Color=Color3.fromRGB(255,255,255); hudStroke.Transparency=.75; hudStroke.Parent=HUD
local hudDrag,hudDragStart,hudStartPos=false,nil,nil
HUD.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then hudDrag=true; hudDragStart=i.Position; hudStartPos=HUD.Position end end)
HUD.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then hudDrag=false; SavePos(HUD_POS_KEY,HUD.Position) end end)
table.insert(allConnections,UIS.InputChanged:Connect(function(i) if hudDrag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-hudDragStart; HUD.Position=UDim2.new(hudStartPos.X.Scale,hudStartPos.X.Offset+d.X,hudStartPos.Y.Scale,hudStartPos.Y.Offset+d.Y) end end))
local hudInner=Instance.new("Frame"); hudInner.Size=UDim2.new(1,-16,1,0); hudInner.Position=UDim2.new(0,8,0,0); hudInner.BackgroundTransparency=1; hudInner.Parent=HUD
local function HLabel(sz,pos,txt,col,tsz) local l=Instance.new("TextLabel"); l.Size=sz; l.Position=pos; l.BackgroundTransparency=1; l.Font=Enum.Font.GothamBold; l.Text=txt; l.TextColor3=col; l.TextSize=tsz; l.ZIndex=2; l.Parent=hudInner; return l end
local function HSep(x) local s=Instance.new("Frame"); s.Size=UDim2.new(0,1,.6,0); s.Position=UDim2.new(0,x,.2,0); s.BackgroundColor3=Color3.fromRGB(255,255,255); s.BackgroundTransparency=.75; s.BorderSizePixel=0; s.Parent=hudInner end
HLabel(UDim2.new(0,32,1,0),UDim2.new(0,0,0,0),"Q",Color3.fromRGB(200,200,200),13); HSep(30)
HLabel(UDim2.new(0,18,0,10),UDim2.new(0,36,0,3),"FPS",Color3.fromRGB(100,100,100),7)
local hFPS=HLabel(UDim2.new(0,30,0,12),UDim2.new(0,36,0,13),"60",Color3.fromRGB(220,220,220),11); HSep(72)
HLabel(UDim2.new(0,40,0,10),UDim2.new(0,78,0,3),"SESSION",Color3.fromRGB(100,100,100),7)
local hSession=HLabel(UDim2.new(0,60,0,12),UDim2.new(0,78,0,13),"00:00:00",Color3.fromRGB(200,200,200),11); HSep(144)
HLabel(UDim2.new(0,30,0,10),UDim2.new(0,150,0,3),"PING",Color3.fromRGB(100,100,100),7)
local hPing=HLabel(UDim2.new(0,50,0,12),UDim2.new(0,150,0,13),"0ms",Color3.fromRGB(220,220,220),11)
task.spawn(function()
    while Running do
        hFPS.Text=tostring(fpsValue)
        if fpsValue>=50 then hFPS.TextColor3=Color3.fromRGB(220,220,220) elseif fpsValue>=30 then hFPS.TextColor3=Color3.fromRGB(150,150,150) else hFPS.TextColor3=Color3.fromRGB(90,90,90) end
        local ping=0; pcall(function() ping=math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        hPing.Text=ping.."ms"
        if ping<80 then hPing.TextColor3=Color3.fromRGB(220,220,220) elseif ping<150 then hPing.TextColor3=Color3.fromRGB(150,150,150) else hPing.TextColor3=Color3.fromRGB(90,90,90) end
        hSession.Text=FormatTime(os.time()-StartTime); task.wait(.5)
    end
end)

table.insert(allConnections,LP.CharacterAdded:Connect(function(char)
    if not Running then return end
    local hum=char:WaitForChild("Humanoid"); task.wait(.1)
    if State.TpTool then
        task.wait(.5)
        local exists=false
        for _,item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then exists=true; break end end
        if not exists then
            if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end) end
            local tool=Instance.new("Tool"); tool.Name="TP_Tool"; tool.RequiresHandle=false; tool.Parent=LP.Backpack
            tpToolConnection=tool.Activated:Connect(function() local c=LP.Character; if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame=CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end end)
        end
    end
    if State.Noclip then task.delay(.3,StartNoclip) end
    if State.Fly then task.delay(.5,StartFly) end
    if State.ESP then task.delay(.5,function() pcall(UpdateESP) end) end
    if State.HitboxExpand then task.delay(.5,StartHitboxExpander) end
    if voidActive then voidActive=false; if voidConnection then pcall(function() voidConnection:Disconnect() end); voidConnection=nil end; pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end); UpdateVoidStatus() end
end))

table.insert(allConnections,UIS.InputBegan:Connect(function(input,gp)
    if gp or not Running or isWaitingForKey then return end
    local kn=tostring(input.KeyCode):gsub("Enum.KeyCode.","")
    if input.UserInputType==Enum.UserInputType.Keyboard then
        for fn,bk in pairs(Binds) do if bk==kn then local cb=toggleCallbacks[fn]; if cb then cb() end end end
    end
    if kn==MenuToggleKey then
        if not MenuOpen then
            MenuOpen=true; SG.Enabled=true; menuFrame.Visible=true
            if canvasGroupOK then menuFrame.GroupTransparency=1; Tween(menuFrame,{GroupTransparency=0},.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out) end
            SetBlur(6)
        else
            if canvasGroupOK then Tween(menuFrame,{GroupTransparency=1},.15); task.delay(.17,function() if not MenuOpen then menuFrame.Visible=false; SG.Enabled=false end end) else menuFrame.Visible=false; SG.Enabled=false end
            MenuOpen=false; RemoveBlur()
        end
    end
end))

local function ShowAdminAlert(player)
    if not AdminAlertEnabled or not Running then return end
    local isAdmin=CheckIfAdmin(player); if not isAdmin then return end
    Notify("Admin Joined",player.DisplayName.." (@"..player.Name..") entered",5,"admin"); RefreshAdminList(); RefreshAdminWindow()
end
table.insert(allConnections,Players.PlayerAdded:Connect(function(plr) if not Running then return end; task.wait(1); if Running then ShowAdminAlert(plr) end end))
table.insert(allConnections,Players.PlayerRemoving:Connect(function(plr)
    if not Running then return end
    local wasAdmin=AdminCache[plr.UserId] and AdminCache[plr.UserId].IsAdmin
    if wasAdmin then Notify("Admin Left",plr.DisplayName.." left",3,"info"); AdminCache[plr.UserId]=nil; RefreshAdminList(); RefreshAdminWindow() end
    SelectedFlingTargets[plr.Name]=nil; selectedTeleportPlayers[plr.Name]=nil
end))

task.wait(.3); updateThemeColors()
if State.Noclip then StartNoclip(); ShowBindIndicator("Noclip") end
if State.Fly then StartFly(); ShowBindIndicator("Fly") end
if State.ESP then pcall(UpdateESP); ShowBindIndicator("ESP Players") end
if State.TpTool then
    local tool=Instance.new("Tool"); tool.Name="TP_Tool"; tool.RequiresHandle=false; tool.Parent=LP.Backpack
    tpToolConnection=tool.Activated:Connect(function() local c=LP.Character; if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame=CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end end)
    ShowBindIndicator("TP Tool")
end
RefreshAdminList(); RefreshAdminWindow()
task.spawn(function()
    task.wait(2); if not Running then return end
    for _,p in pairs(Players:GetPlayers()) do if p~=LP then local isA=CheckIfAdmin(p); if isA then Notify("Admin Detected",p.DisplayName.." (@"..p.Name..") is here",5,"admin") end end end
    RefreshAdminWindow()
end)
menuFrame.Visible=true; SG.Enabled=true; MenuOpen=true
if canvasGroupOK then menuFrame.GroupTransparency=0 end
SetBlur(6); Notify("QWEN","["..MenuToggleKey.."] to toggle",4,"success")
print("[QWEN] Loaded | "..MenuToggleKey.." = toggle")
