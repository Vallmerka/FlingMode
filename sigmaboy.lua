local UIS = game:GetService("UserInputService")
if UIS.TouchEnabled and not UIS.MouseEnabled and not UIS.KeyboardEnabled then
    getgenv().bypass_adonis = true
    loadstring(game:HttpGet('https://raw.githubusercontent.com/Vallmerka/FlingMode/refs/heads/main/FlingModeMobile.lua'))() return
end

if not game:IsLoaded() then 
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

if bypass_adonis then
    task.spawn(function()
        local g = getinfo or debug.getinfo
        local d = false
        local h = {}

        local x, y

        setthreadidentity(2)

        for i, v in getgc(true) do
            if typeof(v) == "table" then
                local a = rawget(v, "Detected")
                local b = rawget(v, "Kill")
            
                if typeof(a) == "function" and not x then
                    x = a
                    local o; o = hookfunction(x, function(c, f, n)
                        if c ~= "_" then
                            if d then
                                warn(`Adonis AntiCheat flagged\nMethod: {c}\nInfo: {f}`)
                            end
                        end
                        
                        return true
                    end)
                    table.insert(h, x)
                end

                if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
                    y = b
                    local o; o = hookfunction(y, function(f)
                        if d then
                            warn(`Adonis AntiCheat tried to kill (fallback): {f}`)
                        end
                    end)
                    table.insert(h, y)
                end
            end
        end

        local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
            local a, f = ...

            if x and a == x then
                if d then
                    warn(`zins | adonis bypassed`)
                end

                return coroutine.yield(coroutine.running())
            end
            
            return o(...)
        end))

        setthreadidentity(7)
    end)
end
local SilentAimSettings = {
    Enabled = false,
    
    ClassName = "FlingMode | alpha-1.0",
    ToggleKey = "U",
    
    TeamCheck = false,
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false, 
    
    HitChance = 100
}

getgenv().SilentAimSettings = Settings

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume 
local create = coroutine.create

local ValidTargetParts = {"Head", "HumanoidRootPart"}
local PredictionAmount = 0.165

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local ExpectedArguments = {
    ViewportPointToRay = {
        ArgCountRequired = 2,
        Args = { "number", "number" }
    },
    ScreenPointToRay = {
        ArgCountRequired = 2,
        Args = { "number", "number" }
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = { "Instance", "Vector3", "Vector3", "RaycastParams" }
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = { "Ray", "Instance", "boolean", "boolean" }
    },
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 3,
        Args = { "Ray", "table", "boolean", "boolean" }
    },
    FindPartOnRayWithWhitelist = { 
        ArgCountRequired = 3,
        Args = { "Ray", "table", "boolean", "boolean" }
    }
}


function CalculateChance(Percentage)

    Percentage = math.floor(Percentage)


    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100


    return chance <= Percentage / 100
end


local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    
    if not (PlayerCharacter or LocalPlayerCharacter) then return end 
    
    local PlayerRoot = FindFirstChild(PlayerCharacter, Options.TargetPart.Value) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    
    if not PlayerRoot then return end 
    
    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    
    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function getClosestPlayer()
    if not Options.TargetPart.Value then return end
    local Closest
    local DistanceToMouse
    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character
        if not Character then continue end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end

        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or Options.Radius.Value or 2000) then
            Closest = ((Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[Options.TargetPart.Value])
            DistanceToMouse = Distance
        end
    end
    return Closest
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local isLockedOn = false
local targetPlayer = nil
local lockEnabled = false
local smoothingFactor = 0.1
local predictionFactor = 0.0
local bodyPartSelected = "Head"
local aimLockEnabled = false 


local function getBodyPart(character, part)
    return character:FindFirstChild(part) and part or "Head"
end

local function getNearestPlayerToMouse()
    if not aimLockEnabled then return nil end 
    local nearestPlayer = nil
    local shortestDistance = math.huge
    local mousePosition = Camera:ViewportPointToRay(Mouse.X, Mouse.Y).Origin

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(bodyPartSelected) then
            local part = player.Character[bodyPartSelected]
            local screenPosition, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local distance = (Vector2.new(screenPosition.X, screenPosition.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                if distance < shortestDistance then
                    nearestPlayer = player
                    shortestDistance = distance
                end
            end
        end
    end
    return nearestPlayer
end

local function toggleLockOnPlayer()
    if not lockEnabled or not aimLockEnabled then return end

    if isLockedOn then
        isLockedOn = false
        targetPlayer = nil
    else
        targetPlayer = getNearestPlayerToMouse()
        if targetPlayer and targetPlayer.Character then
            local part = getBodyPart(targetPlayer.Character, bodyPartSelected)
            if targetPlayer.Character:FindFirstChild(part) then
                isLockedOn = true
            end
        end
    end
end


RunService.RenderStepped:Connect(function()
    if aimLockEnabled and lockEnabled and isLockedOn and targetPlayer and targetPlayer.Character then
        local partName = getBodyPart(targetPlayer.Character, bodyPartSelected)
        local part = targetPlayer.Character:FindFirstChild(partName)

        if part and targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * predictionFactor)
            local currentCameraPosition = Camera.CFrame.Position

            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, smoothingFactor)
        else
            isLockedOn = false
            targetPlayer = nil
        end
    end
end)



local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Vallmerka/FlingMode/refs/heads/main/linoralib.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/Vallmerka/FlingMode/refs/heads/main/manage2.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/Vallmerka/FlingMode/refs/heads/main/manager.lua"))()

Library.KeybindFrame.Visible = true;

local Window = Library:CreateWindow({
    Title = 'FlingMode | alpha-1.0',
    Center = true,
    AutoShow = true,  
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local GeneralTab = Window:AddTab("Main")
local aimbox = GeneralTab:AddRightGroupbox("AimLock settings")
local velbox = GeneralTab:AddRightGroupbox("Anti Lock")
local frabox = GeneralTab:AddRightGroupbox("Movement")
local ExploitTab = Window:AddTab("Exploits")
local WarTycoonBox = ExploitTab:AddLeftGroupbox("War Tycoon")
local ACSEngineBox = ExploitTab:AddRightGroupbox("weapon settings")
local VisualsTab = Window:AddTab("Visuals")
local settingsTab = Window:AddTab("Settings")


ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:ApplyToTab(settingsTab)
SaveManager:BuildConfigSection(settingsTab)

aimbox:AddToggle("aimLock_Enabled", {
    Text = "enable/disable AimLock",
    Default = false,
    Tooltip = "Toggle the AimLock feature on or off.",
    Callback = function(value)
        aimLockEnabled = value
        if not aimLockEnabled then
            lockEnabled = false
            isLockedOn = false
            targetPlayer = nil
        end
    end
})

aimbox:AddToggle("aim_Enabled", {
    Text = "aimlock keybind",
    Default = false,
    Tooltip = "Toggle AimLock on or off.",
    Callback = function(value)
        lockEnabled = value
        if not lockEnabled then
            isLockedOn = false
            targetPlayer = nil
        end
    end,
}):AddKeyPicker("aim_Enabled_KeyPicker", {
    Default = "G", 
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "AimLock Key",
    Tooltip = "Key to toggle AimLock",
    Callback = function()
        toggleLockOnPlayer()
    end,
})

aimbox:AddSlider("Smoothing", {
    Text = "Camera Smoothing",
    Default = 0.1,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Tooltip = "Adjust camera smoothing factor.",
    Callback = function(value)
        smoothingFactor = value
    end,
})


aimbox:AddSlider("Prediction", {
    Text = "Prediction Factor",
    Default = 0.0,
    Min = 0,
    Max = 2,
    Rounding = 2,
    Tooltip = "Adjust prediction for target movement.",
    Callback = function(value)
        predictionFactor = value
    end,
})

aimbox:AddDropdown("BodyParts", {
    Values = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm"},
    Default = "Head",
    Multi = false,
    Text = "Target Body Part",
    Tooltip = "Select which body part to lock onto.",
    Callback = function(value)
        bodyPartSelected = value
    end,
})


local reverseResolveIntensity = 5
getgenv().Desync = false
getgenv().DesyncEnabled = false  


game:GetService("RunService").Heartbeat:Connect(function()
    if getgenv().DesyncEnabled then  
        if getgenv().Desync then
            local player = game.Players.LocalPlayer
            local character = player.Character
            if not character then return end 

            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then return end

            local originalVelocity = humanoidRootPart.Velocity

            local randomOffset = Vector3.new(
                math.random(-1, 1) * reverseResolveIntensity * 1000,
                math.random(-1, 1) * reverseResolveIntensity * 1000,
                math.random(-1, 1) * reverseResolveIntensity * 1000
            )

            humanoidRootPart.Velocity = randomOffset
            humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(
                0,
                math.random(-1, 1) * reverseResolveIntensity * 0.001,
                0
            )

            game:GetService("RunService").RenderStepped:Wait()

            humanoidRootPart.Velocity = originalVelocity
        end
    end
end)

velbox:AddToggle("desyncMasterEnabled", {
    Text = "Enable Desync",
    Default = false,
    Tooltip = "Enable or disable the entire desync system.",
    Callback = function(value)
        getgenv().DesyncEnabled = value  
    end
})


velbox:AddToggle("desyncEnabled", {
    Text = "Desync keybind",
    Default = false,
    Tooltip = "Enable or disable reverse resolve desync.",
    Callback = function(value)
        getgenv().Desync = value
    end
}):AddKeyPicker("desyncToggleKey", {
    Default = "V", 
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Desync Toggle Key",
    Tooltip = "Toggle to enable/disable velocity desync.",
    Callback = function(value)
        getgenv().Desync = value
    end
})


velbox:AddSlider("ReverseResolveIntensity", {
    Text = "velocity intensity",
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Tooltip = "Adjust the intensity of the reverse resolve effect.",
    Callback = function(value)
        reverseResolveIntensity = value
    end
})



local antiLockEnabled = false
local resolverIntensity = 1.0
local resolverMethod = "Recalculate"


RunService.RenderStepped:Connect(function()
    if aimLockEnabled and isLockedOn and targetPlayer and targetPlayer.Character then
        local partName = getBodyPart(targetPlayer.Character, bodyPartSelected)
        local part = targetPlayer.Character:FindFirstChild(partName)

        if part and targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * predictionFactor)

            if antiLockEnabled then
                if resolverMethod == "Recalculate" then

                    predictedPosition = predictedPosition + (part.AssemblyLinearVelocity * resolverIntensity)
                elseif resolverMethod == "Randomize" then

                    predictedPosition = predictedPosition + Vector3.new(
                        math.random() * resolverIntensity - (resolverIntensity / 2),
                        math.random() * resolverIntensity - (resolverIntensity / 2),
                        math.random() * resolverIntensity - (resolverIntensity / 2)
                    )
                elseif resolverMethod == "Invert" then

                    predictedPosition = predictedPosition - (part.AssemblyLinearVelocity * resolverIntensity * 2)
                end
            end

            local currentCameraPosition = Camera.CFrame.Position
            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, smoothingFactor)
        else
            isLockedOn = false
            targetPlayer = nil
        end
    end
end)

aimbox:AddToggle("antiLock_Enabled", {
    Text = "Enable Anti Lock Resolver",
    Default = false,
    Tooltip = "Toggle the Anti Lock Resolver on or off.",
    Callback = function(value)
        antiLockEnabled = value
    end,
})

aimbox:AddSlider("ResolverIntensity", {
    Text = "Resolver Intensity",
    Default = 1.0,
    Min = 0,
    Max = 5,
    Rounding = 2,
    Tooltip = "Adjust the intensity of the Anti Lock Resolver.",
    Callback = function(value)
        resolverIntensity = value
    end,
})

aimbox:AddDropdown("ResolverMethods", {
    Values = {"Recalculate", "Randomize", "Invert"},
    Default = "Recalculate", 
    Multi = false,
    Text = "Resolver Method",
    Tooltip = "Select the method used by the Anti Lock Resolver.",
    Callback = function(value)
        resolverMethod = value
    end,
})


local MainBOX = GeneralTab:AddLeftTabbox("silent aim")
local Main = MainBOX:AddTab("silent aim")

SilentAimSettings.BulletTP = false


Main:AddToggle("aim_Enabled", {Text = "Enabled"})
    :AddKeyPicker("aim_Enabled_KeyPicker", {
        Default = "U", 
        SyncToggleState = true, 
        Mode = "Toggle", 
        Text = "Enabled", 
        NoUI = false
    })

Options.aim_Enabled_KeyPicker:OnClick(function()
    SilentAimSettings.Enabled = not SilentAimSettings.Enabled
    Toggles.aim_Enabled.Value = SilentAimSettings.Enabled
    Toggles.aim_Enabled:SetValue(SilentAimSettings.Enabled)
end)

Main:AddToggle("TeamCheck", {
    Text = "Team Check", 
    Default = SilentAimSettings.TeamCheck
}):OnChanged(function()
    SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value
end)

Main:AddToggle("BulletTP", {
    Text = "Bullet Teleport",
    Default = SilentAimSettings.BulletTP,
    Tooltip = "Teleports bullet origin to target"
}):OnChanged(function()
    SilentAimSettings.BulletTP = Toggles.BulletTP.Value
end)

Main:AddToggle("CheckForFireFunc", {
    Text = "Check For Fire Function",
    Default = SilentAimSettings.CheckForFireFunc,
    Tooltip = "Checks if the method is called from a fire function"
}):OnChanged(function()
    SilentAimSettings.CheckForFireFunc = Toggles.CheckForFireFunc.Value
end)

Main:AddDropdown("TargetPart", {
    AllowNull = true, 
    Text = "Target Part", 
    Default = SilentAimSettings.TargetPart, 
    Values = {"Head", "HumanoidRootPart", "Random"}
}):OnChanged(function()
    SilentAimSettings.TargetPart = Options.TargetPart.Value
end)

Main:AddDropdown("Method", {
    AllowNull = true,
    Text = "Silent Aim Method",
    Default = SilentAimSettings.SilentAimMethod,
    Values = {
        "ViewportPointToRay",
        "ScreenPointToRay",
        "Raycast",
        "FindPartOnRay",
        "FindPartOnRayWithIgnoreList"
    }
}):OnChanged(function() 
    SilentAimSettings.SilentAimMethod = Options.Method.Value 
end)

if not SilentAimSettings.BlockedMethods then
    SilentAimSettings.BlockedMethods = {}
end

Main:AddDropdown("Blocked Methods", {
    AllowNull = true,
    Multi = true,
    Text = "Blocked Methods",
    Default = SilentAimSettings.BlockedMethods,
    Values = {
        "Destroy",
        "BulkMoveTo",
        "PivotTo",
        "TranslateBy",
        "SetPrimaryPartCFrame"
    }
}):OnChanged(function()
    SilentAimSettings.BlockedMethods = Options["Blocked Methods"].Value
end)

Main:AddDropdown("Include", {
    AllowNull = true,
    Multi = true,
    Text = "Include",
    Default = SilentAimSettings.Include or {},
    Values = {"Camera", "Character"},
    Tooltip = "Includes these objects in the ignore list"
}):OnChanged(function()
    SilentAimSettings.Include = Options.Include.Value
end)

Main:AddDropdown("Origin", {
    AllowNull = true,
    Multi = true,
    Text = "Origin",
    Default = SilentAimSettings.Origin or "Camera",
    Values = {"Camera", "Custom"},
    Tooltip = "Sets the origin of the bullet"
}):OnChanged(function()
    SilentAimSettings.Origin = Options.Origin.Value
end)

Main:AddSlider("MultiplyUnitBy", {
    Text = "Multiply Unit By",
    Default = 1,
    Min = 0.1,
    Max = 10,
    Rounding = 1,
    Compact = false,
    Tooltip = "Multiplies the direction vector by this value"
}):OnChanged(function()
    SilentAimSettings.MultiplyUnitBy = Options.MultiplyUnitBy.Value
end)

Main:AddSlider("HitChance", {
    Text = "Hit Chance",
    Default = 100,
    Min = 0,
    Max = 100,
    Rounding = 1,
    Compact = false,
}):OnChanged(function()
    SilentAimSettings.HitChance = Options.HitChance.Value
end)

local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View") do
    local Main = FieldOfViewBOX:AddTab("Visuals")

    Main:AddToggle("Visible", {Text = "Show FOV Circle"})
        :AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)})
        :OnChanged(function()
            fov_circle.Visible = Toggles.Visible.Value
            SilentAimSettings.FOVVisible = Toggles.Visible.Value
        end)

    Main:AddSlider("Radius", {
        Text = "FOV Circle Radius", 
        Min = 0, 
        Max = 360, 
        Default = 130, 
        Rounding = 0
    }):OnChanged(function()
        fov_circle.Radius = Options.Radius.Value
        SilentAimSettings.FOVRadius = Options.Radius.Value
    end)

    Main:AddToggle("MousePosition", {Text = "Show Silent Aim Target"})
        :AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)})
        :OnChanged(function()
            SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value
        end)
end

local previousHighlight = nil
local function removeOldHighlight()
    if previousHighlight then
        previousHighlight:Destroy()
        previousHighlight = nil
    end
end

resume(create(function()
    RenderStepped:Connect(function()
        if Toggles.aim_Enabled.Value then
            local closestPlayer = getClosestPlayer()
            
            if closestPlayer then 
                local Root = closestPlayer.Parent.PrimaryPart or closestPlayer
                local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position)

                removeOldHighlight()

                if IsOnScreen then
                    local highlight = closestPlayer.Parent:FindFirstChildOfClass("Highlight")
                    if not highlight then
                        highlight = Instance.new("Highlight")
                        highlight.Parent = closestPlayer.Parent
                        highlight.Adornee = closestPlayer.Parent
                    end

                    highlight.FillColor = Options.MouseVisualizeColor.Value
                    highlight.FillTransparency = 0.5
                    highlight.OutlineColor = Options.MouseVisualizeColor.Value
                    highlight.OutlineTransparency = 0

                    previousHighlight = highlight
                end
            else 
                removeOldHighlight()
            end
        end
        
        if Toggles.Visible.Value then 
            fov_circle.Visible = Toggles.Visible.Value
            fov_circle.Color = Options.Color.Value
            fov_circle.Position = getMousePosition()
        end
    end)
end))


local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method, Arguments = getnamecallmethod(), {...}
    local self, chance = Arguments[1], CalculateChance(SilentAimSettings.HitChance)

    local BlockedMethods = SilentAimSettings.BlockedMethods or {}
    if Method == "Destroy" and self == Client then
        return
    end
    if table.find(BlockedMethods, Method) then
        return
    end

    local CanContinue = false
    if SilentAimSettings.CheckForFireFunc and (Method == "FindPartOnRay" or Method == "FindPartOnRayWithWhitelist" or Method == "FindPartOnRayWithIgnoreList" or Method == "Raycast" or Method == "ViewportPointToRay" or Method == "ScreenPointToRay") then
        local Traceback = tostring(debug.traceback()):lower()
        if Traceback:find("bullet") or Traceback:find("gun") or Traceback:find("fire") then
            CanContinue = true
        else
            return oldNamecall(...)
        end
    end

    if Toggles.aim_Enabled and Toggles.aim_Enabled.Value and self == workspace and not checkcaller() and chance then
        local HitPart = getClosestPlayer()
        if HitPart then
            local function modifyRay(Origin)
                if SilentAimSettings.BulletTP then
                    Origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
                end
                return Origin, getDirection(Origin, HitPart.Position)
            end

            if Method == "FindPartOnRayWithIgnoreList" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                    local Origin, Direction = modifyRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction * SilentAimSettings.MultiplyUnitBy)
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "FindPartOnRayWithWhitelist" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                    local Origin, Direction = modifyRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction * SilentAimSettings.MultiplyUnitBy)
                    return oldNamecall(unpack(Arguments))
                end
            elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and Options.Method.Value:lower() == Method:lower() then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                    local Origin, Direction = modifyRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction * SilentAimSettings.MultiplyUnitBy)
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "Raycast" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                    local Origin, Direction = modifyRay(Arguments[2])
                    Arguments[2], Arguments[3] = Origin, Direction * SilentAimSettings.MultiplyUnitBy
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "ViewportPointToRay" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.ViewportPointToRay) then
                    local Origin = Camera.CFrame.p
                    if SilentAimSettings.BulletTP then
                        Origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
                    end
                    Arguments[2] = Camera:WorldToScreenPoint(HitPart.Position)
                    return Ray.new(Origin, (HitPart.Position - Origin).Unit * SilentAimSettings.MultiplyUnitBy)
                end
            elseif Method == "ScreenPointToRay" and Options.Method.Value == Method then
                if ValidateArguments(Arguments, ExpectedArguments.ScreenPointToRay) then
                    local Origin = Camera.CFrame.p
                    if SilentAimSettings.BulletTP then
                        Origin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
                    end
                    Arguments[2] = Camera:WorldToScreenPoint(HitPart.Position)
                    return Ray.new(Origin, (HitPart.Position - Origin).Unit * SilentAimSettings.MultiplyUnitBy)
                end
            end
        end
    end

    return oldNamecall(...)
end))

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local BOXEnabled, TRAEnabled, NameTagsEnabled, teamCheckEnabled = false, false, false, false
local espBoxes, espTracers, espNameTags = {}, {}, {}
local boxColor, tracerColor, nameTagColor = Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)

local function createESPBox(color)
    local box = Drawing.new("Square")
    box.Color, box.Thickness, box.Filled, box.Visible = color, 1, false, false
    return box
end

local function createTracer(color)
    local tracer = Drawing.new("Line")
    tracer.Color, tracer.Thickness, tracer.Visible = color, 2, false
    return tracer
end

local function createNameTag(color, text)
    local nameTag = Drawing.new("Text")
    nameTag.Color, nameTag.Text, nameTag.Size, nameTag.Center, nameTag.Outline, nameTag.OutlineColor, nameTag.Visible = color, text, 15, true, true, Color3.fromRGB(0, 0, 0), false
    return nameTag
end

local function smoothInterpolation(from, to, factor)
    return from + (to - from) * factor
end

local function updateESPBoxes()
    if BOXEnabled then
        for player, box in pairs(espBoxes) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                if teamCheckEnabled and player.Team == Players.LocalPlayer.Team then
                    box.Visible = false
                else
                    local rootPart = player.Character.HumanoidRootPart
                    local screenPosition, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    if onScreen then
                        local distance = screenPosition.Z
                        local scaleFactor = 70 / distance
                        local boxWidth = 30 * scaleFactor
                        local boxHeight = 50 * scaleFactor
                        box.Size = Vector2.new(boxWidth, boxHeight)
                        box.Position = Vector2.new(screenPosition.X - boxWidth / 2, screenPosition.Y - boxHeight / 2)
                        box.Visible = true
                    else
                        box.Visible = false
                    end
                end
            else
                box.Visible = false
            end
        end
    end
end

local function updateTracers()
    if TRAEnabled then
        for player, tracer in pairs(espTracers) do
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                if teamCheckEnabled and player.Team == Players.LocalPlayer.Team then
                    tracer.Visible = false
                else
                    local rootPart = player.Character.HumanoidRootPart
                    local screenPosition, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
                    if onScreen then
                        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        local targetPosition = Vector2.new(screenPosition.X, screenPosition.Y)
                        tracer.From = smoothInterpolation(tracer.From, screenCenter, 0.1)
                        tracer.To = smoothInterpolation(tracer.To, targetPosition, 0.1)
                        tracer.Visible = true
                    else
                        tracer.Visible = false
                    end
                end
            else
                tracer.Visible = false
            end
        end
    end
end

local function updateNameTags()
    if NameTagsEnabled then
        for player, nameTag in pairs(espNameTags) do
            if player.Character and player.Character:FindFirstChild("Head") then
                if teamCheckEnabled and player.Team == Players.LocalPlayer.Team then
                    nameTag.Visible = false
                else
                    local headPosition, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
                    if onScreen then
                        nameTag.Position = Vector2.new(headPosition.X, headPosition.Y - 30)
                        nameTag.Visible = true
                    else
                        nameTag.Visible = false
                    end
                end
            else
                nameTag.Visible = false
            end
        end
    end
end

local function addESP(player)
    if player ~= Players.LocalPlayer then
        local box = createESPBox(boxColor)
        espBoxes[player] = box
        player.CharacterAdded:Connect(function()
            espBoxes[player] = box
        end)
    end
end

local function addTracer(player)
    if player ~= Players.LocalPlayer then
        local tracer = createTracer(tracerColor)
        espTracers[player] = tracer
        player.CharacterAdded:Connect(function()
            espTracers[player] = tracer
        end)
    end
end

local function addNameTag(player)
    if player ~= Players.LocalPlayer then
        local nameTag = createNameTag(nameTagColor, player.Name)
        espNameTags[player] = nameTag
        player.CharacterAdded:Connect(function()
            espNameTags[player] = nameTag
        end)
    end
end

local function removeESP(player)
    if espBoxes[player] then
        espBoxes[player].Visible = false
        espBoxes[player] = nil
    end
end

local function removeTracer(player)
    if espTracers[player] then
        espTracers[player].Visible = false
        espTracers[player] = nil
    end
end

local function removeNameTag(player)
    if espNameTags[player] then
        espNameTags[player].Visible = false
        espNameTags[player] = nil
    end
end

local function updateTeamColor(player)
    local teamColor = player.Team and player.Team.TeamColor.Color
    if EspTeamColor then
        if espBoxes[player] then espBoxes[player].Color = teamColor end
        if espTracers[player] then espTracers[player].Color = teamColor end
        if espNameTags[player] then espNameTags[player].Color = teamColor end
    else
        if espBoxes[player] then espBoxes[player].Color = boxColor end
        if espTracers[player] then espTracers[player].Color = tracerColor end
        if espNameTags[player] then espNameTags[player].Color = nameTagColor end
    end
end

Players.PlayerAdded:Connect(function(player)
    addESP(player) addTracer(player) addNameTag(player)
    player:GetPropertyChangedSignal("Team"):Connect(function() updateTeamColor(player) end)
    updateTeamColor(player)
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    removeTracer(player)
    removeNameTag(player)
end)

for _, player in pairs(Players:GetPlayers()) do
    addESP(player)
    addTracer(player)
    addNameTag(player)
end

RunService.RenderStepped:Connect(updateESPBoxes)
RunService.RenderStepped:Connect(updateTracers)
RunService.RenderStepped:Connect(updateNameTags)

local espbox = VisualsTab:AddLeftGroupbox("esp")

espbox:AddToggle("TeamCheck", {
    Text = "Enable Team Check",
    Default = false,
    Callback = function(state)
        teamCheckEnabled = state
        for player, box in pairs(espBoxes) do
            if player.Team == Players.LocalPlayer.Team then
                box.Visible = false
            end
        end
        for player, tracer in pairs(espTracers) do
            if player.Team == Players.LocalPlayer.Team then
                tracer.Visible = false
            end
        end
        for player, nameTag in pairs(espNameTags) do
            if player.Team == Players.LocalPlayer.Team then
                nameTag.Visible = false
            end
        end
    end,
})

espbox:AddToggle("EspTeamColor", {
    Text = "ESP Team Color",
    Default = false,
    Callback = function(state)
        EspTeamColor = state
        for player, box in pairs(espBoxes) do
            updateTeamColor(player)
        end
        for player, tracer in pairs(espTracers) do
            updateTeamColor(player)
        end
        for player, nameTag in pairs(espNameTags) do
            updateTeamColor(player)
        end
    end,
})

espbox:AddToggle("EnableESP", {
    Text = "Box ESP",
    Default = false,
    Callback = function(state)
        BOXEnabled = state
        for player, box in pairs(espBoxes) do
            box.Visible = state and (teamCheckEnabled and player.Team ~= Players.LocalPlayer.Team or not teamCheckEnabled)
        end
    end,
}):AddColorPicker("BoxColor", {
    Text = "Box Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        boxColor = color
        for _, box in pairs(espBoxes) do
            box.Color = color
        end
    end,
})

espbox:AddToggle("EnableNameTags", {
    Text = "Enable NameTags",
    Default = false,
    Callback = function(state)
        NameTagsEnabled = state
        for player, nameTag in pairs(espNameTags) do
            nameTag.Visible = state and (teamCheckEnabled and player.Team ~= Players.LocalPlayer.Team or not teamCheckEnabled)
        end
    end,
}):AddColorPicker("NameTagColor", {
    Text = "NameTag Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        nameTagColor = color
        for _, nameTag in pairs(espNameTags) do
            nameTag.Color = color
        end
    end,
})

espbox:AddToggle("EnableTracer", {
    Text = "Enable Tracers",
    Default = false,
    Callback = function(state)
        TRAEnabled = state
        for player, tracer in pairs(espTracers) do
            tracer.Visible = state and (teamCheckEnabled and player.Team ~= Players.LocalPlayer.Team or not teamCheckEnabled)
        end
    end,
}):AddColorPicker("TracerColor", {
    Text = "Tracer Color",
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        tracerColor = color
        for _, tracer in pairs(espTracers) do
            tracer.Color = color
        end
    end,
})

local worldbox = VisualsTab:AddRightGroupbox("World")

local lighting = game:GetService("Lighting")
local camera = game.Workspace.CurrentCamera
local lockedTime, fovValue, nebulaEnabled = 12, 70, false
local originalAmbient, originalOutdoorAmbient = lighting.Ambient, lighting.OutdoorAmbient
local originalFogStart, originalFogEnd, originalFogColor = lighting.FogStart, lighting.FogEnd, lighting.FogColor

local nebulaThemeColor = Color3.fromRGB(173, 216, 230)

worldbox:AddSlider("world_time", {
    Text = "Clock Time", Default = 12, Min = 0, Max = 24, Rounding = 1,
    Callback = function(v) lockedTime = v lighting.ClockTime = v end,
})

local oldNewIndex
oldNewIndex = hookmetamethod(game, "__newindex", function(self, property, value)
    if not checkcaller() and self == lighting then
        if property == "ClockTime" then value = lockedTime end
    end
    return oldNewIndex(self, property, value)
end)

worldbox:AddSlider("fov_slider", {
    Text = "FOV", Default = 70, Min = 30, Max = 120, Rounding = 2,
    Callback = function(v) fovValue = v end,
})

game:GetService("RunService").RenderStepped:Connect(function() camera.FieldOfView = fovValue end)

worldbox:AddToggle("nebula_theme", {
    Text = "Nebula Theme", Default = false,
    Callback = function(state)
        nebulaEnabled = state
        if state then
            local b = Instance.new("BloomEffect", lighting) b.Intensity, b.Size, b.Threshold, b.Name = 0.7, 24, 1, "NebulaBloom"
            local c = Instance.new("ColorCorrectionEffect", lighting) c.Saturation, c.Contrast, c.TintColor, c.Name = 0.5, 0.2, nebulaThemeColor, "NebulaColorCorrection"
            local a = Instance.new("Atmosphere", lighting) a.Density, a.Offset, a.Glare, a.Haze, a.Color, a.Decay, a.Name = 0.4, 0.25, 1, 2, nebulaThemeColor, Color3.fromRGB(25, 25, 112), "NebulaAtmosphere"
            lighting.Ambient, lighting.OutdoorAmbient = nebulaThemeColor, nebulaThemeColor
            lighting.FogStart, lighting.FogEnd = 100, 500
            lighting.FogColor = nebulaThemeColor
        else
            for _, v in pairs({"NebulaBloom", "NebulaColorCorrection", "NebulaAtmosphere"}) do
                local obj = lighting:FindFirstChild(v) if obj then obj:Destroy() end
            end
            lighting.Ambient, lighting.OutdoorAmbient = originalAmbient, originalOutdoorAmbient
            lighting.FogStart, lighting.FogEnd = originalFogStart, originalFogEnd
            lighting.FogColor = originalFogColor
        end
    end,
}):AddColorPicker("nebula_color_picker", {
    Text = "Nebula Color", Default = Color3.fromRGB(173, 216, 230),
    Callback = function(c)
        nebulaThemeColor = c
        if nebulaEnabled then
            local nc = lighting:FindFirstChild("NebulaColorCorrection") if nc then nc.TintColor = c end
            local na = lighting:FindFirstChild("NebulaAtmosphere") if na then na.Color = c end
            lighting.Ambient, lighting.OutdoorAmbient = c, c
            lighting.FogColor = c
        end
    end,
})


local Lighting = game:GetService("Lighting")
local Visuals = {}
local Skyboxes = {}

function Visuals:NewSky(Data)
    local Name = Data.Name
    Skyboxes[Name] = {
        SkyboxBk = Data.SkyboxBk,
        SkyboxDn = Data.SkyboxDn,
        SkyboxFt = Data.SkyboxFt,
        SkyboxLf = Data.SkyboxLf,
        SkyboxRt = Data.SkyboxRt,
        SkyboxUp = Data.SkyboxUp,
        MoonTextureId = Data.Moon or "rbxasset://sky/moon.jpg",
        SunTextureId = Data.Sun or "rbxasset://sky/sun.jpg"
    }
end

function Visuals:SwitchSkybox(Name)
    local OldSky = Lighting:FindFirstChildOfClass("Sky")
    if OldSky then OldSky:Destroy() end

    local Sky = Instance.new("Sky", Lighting)
    for Index, Value in pairs(Skyboxes[Name]) do
        Sky[Index] = Value
    end
end

if Lighting:FindFirstChildOfClass("Sky") then
    local OldSky = Lighting:FindFirstChildOfClass("Sky")
    Visuals:NewSky({
        Name = "Game's Default Sky",
        SkyboxBk = OldSky.SkyboxBk,
        SkyboxDn = OldSky.SkyboxDn,
        SkyboxFt = OldSky.SkyboxFt,
        SkyboxLf = OldSky.SkyboxLf,
        SkyboxRt = OldSky.SkyboxRt,
        SkyboxUp = OldSky.SkyboxUp
    })
end

Visuals:NewSky({
    Name = "Sunset",
    SkyboxBk = "rbxassetid://600830446",
    SkyboxDn = "rbxassetid://600831635",
    SkyboxFt = "rbxassetid://600832720",
    SkyboxLf = "rbxassetid://600886090",
    SkyboxRt = "rbxassetid://600833862",
    SkyboxUp = "rbxassetid://600835177"
})

Visuals:NewSky({
    Name = "Arctic",
    SkyboxBk = "http://www.roblox.com/asset/?id=225469390",
    SkyboxDn = "http://www.roblox.com/asset/?id=225469395",
    SkyboxFt = "http://www.roblox.com/asset/?id=225469403",
    SkyboxLf = "http://www.roblox.com/asset/?id=225469450",
    SkyboxRt = "http://www.roblox.com/asset/?id=225469471",
    SkyboxUp = "http://www.roblox.com/asset/?id=225469481"
})

Visuals:NewSky({
    Name = "Space",
    SkyboxBk = "http://www.roblox.com/asset/?id=166509999",
    SkyboxDn = "http://www.roblox.com/asset/?id=166510057",
    SkyboxFt = "http://www.roblox.com/asset/?id=166510116",
    SkyboxLf = "http://www.roblox.com/asset/?id=166510092",
    SkyboxRt = "http://www.roblox.com/asset/?id=166510131",
    SkyboxUp = "http://www.roblox.com/asset/?id=166510114"
})

Visuals:NewSky({
    Name = "Roblox Default",
    SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex",
    SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex",
    SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex",
    SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex",
    SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex",
    SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
})

Visuals:NewSky({
    Name = "Red Night", 
    SkyboxBk = "http://www.roblox.com/Asset/?ID=401664839";
    SkyboxDn = "http://www.roblox.com/Asset/?ID=401664862";
    SkyboxFt = "http://www.roblox.com/Asset/?ID=401664960";
    SkyboxLf = "http://www.roblox.com/Asset/?ID=401664881";
    SkyboxRt = "http://www.roblox.com/Asset/?ID=401664901";
    SkyboxUp = "http://www.roblox.com/Asset/?ID=401664936";
})

Visuals:NewSky({
    Name = "Deep Space", 
    SkyboxBk = "http://www.roblox.com/asset/?id=149397692";
    SkyboxDn = "http://www.roblox.com/asset/?id=149397686";
    SkyboxFt = "http://www.roblox.com/asset/?id=149397697";
    SkyboxLf = "http://www.roblox.com/asset/?id=149397684";
    SkyboxRt = "http://www.roblox.com/asset/?id=149397688";
    SkyboxUp = "http://www.roblox.com/asset/?id=149397702";
})

Visuals:NewSky({
    Name = "Pink Skies", 
    SkyboxBk = "http://www.roblox.com/asset/?id=151165214";
    SkyboxDn = "http://www.roblox.com/asset/?id=151165197";
    SkyboxFt = "http://www.roblox.com/asset/?id=151165224";
    SkyboxLf = "http://www.roblox.com/asset/?id=151165191";
    SkyboxRt = "http://www.roblox.com/asset/?id=151165206";
    SkyboxUp = "http://www.roblox.com/asset/?id=151165227";
})

Visuals:NewSky({
    Name = "Purple Sunset", 
    SkyboxBk = "rbxassetid://264908339";
    SkyboxDn = "rbxassetid://264907909";
    SkyboxFt = "rbxassetid://264909420";
    SkyboxLf = "rbxassetid://264909758";
    SkyboxRt = "rbxassetid://264908886";
    SkyboxUp = "rbxassetid://264907379";
})

Visuals:NewSky({
    Name = "Blue Night", 
    SkyboxBk = "http://www.roblox.com/Asset/?ID=12064107";
    SkyboxDn = "http://www.roblox.com/Asset/?ID=12064152";
    SkyboxFt = "http://www.roblox.com/Asset/?ID=12064121";
    SkyboxLf = "http://www.roblox.com/Asset/?ID=12063984";
    SkyboxRt = "http://www.roblox.com/Asset/?ID=12064115";
    SkyboxUp = "http://www.roblox.com/Asset/?ID=12064131";
})

Visuals:NewSky({
    Name = "Blossom Daylight", 
    SkyboxBk = "http://www.roblox.com/asset/?id=271042516";
    SkyboxDn = "http://www.roblox.com/asset/?id=271077243";
    SkyboxFt = "http://www.roblox.com/asset/?id=271042556";
    SkyboxLf = "http://www.roblox.com/asset/?id=271042310";
    SkyboxRt = "http://www.roblox.com/asset/?id=271042467";
    SkyboxUp = "http://www.roblox.com/asset/?id=271077958";
})

Visuals:NewSky({
    Name = "Blue Nebula", 
    SkyboxBk = "http://www.roblox.com/asset?id=135207744";
    SkyboxDn = "http://www.roblox.com/asset?id=135207662";
    SkyboxFt = "http://www.roblox.com/asset?id=135207770";
    SkyboxLf = "http://www.roblox.com/asset?id=135207615";
    SkyboxRt = "http://www.roblox.com/asset?id=135207695";
    SkyboxUp = "http://www.roblox.com/asset?id=135207794";
})

Visuals:NewSky({
    Name = "Blue Planet", 
    SkyboxBk = "rbxassetid://218955819";
    SkyboxDn = "rbxassetid://218953419";
    SkyboxFt = "rbxassetid://218954524";
    SkyboxLf = "rbxassetid://218958493";
    SkyboxRt = "rbxassetid://218957134";
    SkyboxUp = "rbxassetid://218950090";
})

Visuals:NewSky({
    Name = "Deep Space", 
    SkyboxBk = "http://www.roblox.com/asset/?id=159248188";
    SkyboxDn = "http://www.roblox.com/asset/?id=159248183";
    SkyboxFt = "http://www.roblox.com/asset/?id=159248187";
    SkyboxLf = "http://www.roblox.com/asset/?id=159248173";
    SkyboxRt = "http://www.roblox.com/asset/?id=159248192";
    SkyboxUp = "http://www.roblox.com/asset/?id=159248176";
})

local SkyboxNames = {}
for Name, _ in pairs(Skyboxes) do
    table.insert(SkyboxNames, Name)
end

local worldbox = VisualsTab:AddRightGroupbox("SkyBox")
local SkyboxDropdown = worldbox:AddDropdown("SkyboxSelector", {
    AllowNull = false,
    Text = "Select Skybox",
    Default = "Game's Default Sky",
    Values = SkyboxNames
}):OnChanged(function(SelectedSkybox)
    if Skyboxes[SelectedSkybox] then
        Visuals:SwitchSkybox(SelectedSkybox)
    end
end)

local localPlayer = game:GetService("Players").LocalPlayer
local Cmultiplier = 1  
local isSpeedActive = false
local isFlyActive = false
local isNoClipActive = false
local isFunctionalityEnabled = true  
local flySpeed = 1
local camera = workspace.CurrentCamera
local humanoid = nil

frabox:AddToggle("functionalityEnabled", {
    Text = "Enable/Disable movement",
    Default = true,
    Tooltip = "Enable or disable.",
    Callback = function(value)
        isFunctionalityEnabled = value
    end
})

frabox:AddToggle("speedEnabled", {
    Text = "Speed Toggle",
    Default = false,
    Tooltip = "It makes you go fast.",
    Callback = function(value)
        isSpeedActive = value
    end
}):AddKeyPicker("speedToggleKey", {
    Default = "C",  
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Speed Toggle Key",
    Tooltip = "CFrame keybind.",
    Callback = function(value)
        isSpeedActive = value
    end
})

frabox:AddSlider("cframespeed", {
    Text = "CFrame Multiplier",
    Default = 1,
    Min = 1,
    Max = 200,
    Rounding = 1,
    Tooltip = "The CFrame speed.",
    Callback = function(value)
        Cmultiplier = value
    end,
})

frabox:AddToggle("flyEnabled", {
    Text = "CFly Toggle",
    Default = false,
    Tooltip = "Toggle CFrame Fly functionality.",
    Callback = function(value)
        isFlyActive = value
    end
}):AddKeyPicker("flyToggleKey", {
    Default = "F",  
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "CFly Toggle Key",
    Tooltip = "CFrame Fly keybind.",
    Callback = function(value)
        isFlyActive = value
    end
})

frabox:AddSlider("flySpeed", {
    Text = "CFly Speed",
    Default = 1,
    Min = 1,
    Max = 250,
    Rounding = 1,
    Tooltip = "The CFrame Fly speed.",
    Callback = function(value)
        flySpeed = value
    end,
})

frabox:AddToggle("noClipEnabled", {
    Text = "NoClip Toggle",
    Default = false,
    Tooltip = "Enable or disable NoClip.",
    Callback = function(value)
        isNoClipActive = value
    end
}):AddKeyPicker("noClipToggleKey", {
    Default = "N",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "NoClip Toggle Key",
    Tooltip = "Keybind to toggle NoClip.",
    Callback = function(value)
        isNoClipActive = value
    end
})

local masterToggle = false

local function enableMasterToggle(value)
    masterToggle = value
end

WarTycoonBox:AddToggle("Master Toggle", {
    Text = "Enable/Disable",
    Default = false,
    Tooltip = "Enable or disable all features globally.",
    Callback = enableMasterToggle
})

local hookEnabled = false
local oldNamecall

local function enableBulletHitManipulation(value)
    if not masterToggle then return end
    BManipulation = value
    local remote = game:GetService("ReplicatedStorage").BulletFireSystem.BulletHit

    if BManipulation then
        if not hookEnabled then
            hookEnabled = true
            oldNamecall = hookmetamethod(remote, "__namecall", newcclosure(function(self, ...)
                if typeof(self) == "Instance" then
                    local method = getnamecallmethod()
                    if method and (method == "FireServer" and self == remote) then
                        local HitPart = getClosestPlayer()
                        if HitPart then
                            local remArgs = {...}
                            remArgs[2] = HitPart
                            remArgs[3] = HitPart.Position
                            setnamecallmethod(method)
                            return oldNamecall(self, unpack(remArgs))
                        else
                            setnamecallmethod(method)
                        end
                    end
                end
                return oldNamecall(self, ...)
            end))
        end
    else
        BsManipulation = false
        if hookEnabled then
            hookEnabled = false
            if oldNamecall then
                hookmetamethod(remote, "__namecall", oldNamecall)
            end
        end
    end
end

WarTycoonBox:AddToggle("BulletHit manipulation", {
    Text = "Magic Bullet [beta]",
    Default = false,
    Tooltip = "Magic Bullet?",
    Callback = function(value)
        enableBulletHitManipulation(value)
    end
})

local hookEnabled = false
local oldNamecall

local function enableRocketHitManipulation(value)
    if not masterToggle then return end
    RManipulation = value
    local remote = game:GetService("ReplicatedStorage").RocketSystem.Events.RocketHit

    if RManipulation and not hookEnabled then
        hookEnabled = true
        oldNamecall = hookmetamethod(remote, "__namecall", newcclosure(function(self, ...)
            if typeof(self) == "Instance" and getnamecallmethod() == "FireServer" and self == remote then
                local remArgs = {...}
                local targetPart = getClosestPlayer()
                if targetPart then
                    remArgs[1] = targetPart.Position
                    remArgs[2] = (targetPart.Position - game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position).unit
                    remArgs[5] = targetPart
                    setnamecallmethod("FireServer")
                    return oldNamecall(self, unpack(remArgs))
                end
            end
            return oldNamecall(self, ...)
        end))
    elseif not RManipulation and hookEnabled then
        hookEnabled = false
        if oldNamecall then hookmetamethod(remote, "__namecall", oldNamecall) end
    end
end

WarTycoonBox:AddToggle("RocketHit manipulation", {
    Text = "Magic Rocket",
    Default = false,
    Tooltip = "Enables Magic Rocket manipulation",
    Callback = enableRocketHitManipulation
})

local function modifyWeaponSettings(property, value)
    local function findSettingsModule(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("ModuleScript") then
                local success, module = pcall(function() return require(child) end)
                if success and module[property] ~= nil then
                    return module
                end
            end
            local found = findSettingsModule(child)
            if found then
                return found
            end
        end
        return nil
    end

    local player = game:GetService("Players").LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()
    local foundModules = {}


    local function findSettingsInWarTycoon(item)
        local weaponName = item.Name
        local settingsModule = game:GetService("ReplicatedStorage"):WaitForChild("Configurations"):WaitForChild("ACS_Guns"):FindFirstChild(weaponName)
        if settingsModule then
            return settingsModule:FindFirstChild("Settings")
        end
        return nil
    end

    if getgenv().WarTycoon then
        if getgenv().WeaponOnHands then
            local toolInHand = character:FindFirstChildOfClass("Tool")
            if toolInHand then
                local settingsModule = findSettingsInWarTycoon(toolInHand)
                if settingsModule then
                    local success, module = pcall(function() return require(settingsModule) end)
                    if success and module[property] ~= nil then
                        module[property] = value
                    end
                end
            end
        else
            for _, item in pairs(backpack:GetChildren()) do
                local settingsModule = findSettingsInWarTycoon(item)
                if settingsModule then
                    local success, module = pcall(function() return require(settingsModule) end)
                    if success and module[property] ~= nil then
                        module[property] = value
                    end
                end
            end
        end
    else
        if getgenv().WeaponOnHands then
            local toolInHand = character:FindFirstChildOfClass("Tool")
            if toolInHand then
                local settingsModule = findSettingsModule(toolInHand)
                if settingsModule then
                    local success, module = pcall(function() return require(settingsModule) end)
                    if success and module[property] ~= nil then
                        module[property] = value
                    end
                end
            end
        else
            for _, item in pairs(backpack:GetChildren()) do
                local settingsModule = findSettingsModule(item)
                if settingsModule then
                    local success, module = pcall(function() return require(settingsModule) end)
                    if success and module[property] ~= nil then
                        module[property] = value
                    end
                end
            end
        end
    end
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local isRPGSpamEnabled = false
local spamSpeed = 1
local rocketsToFire = 1
local RocketSystem, FireRocket, FireRocketClient, ACS_Client
local function startRPGSpam()
    if not masterToggle then return end
    if not isRPGSpamEnabled then return end

    if not RocketSystem then
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        RocketSystem = ReplicatedStorage:WaitForChild("RocketSystem")
        FireRocket = RocketSystem:WaitForChild("Events"):WaitForChild("FireRocket")
        FireRocketClient = RocketSystem:WaitForChild("Events"):WaitForChild("FireRocketClient")
    end

    local function getActiveWeapon()
        local validWeapons = {"RPG", "Javelin", "Stinger"}
        for _, weaponName in ipairs(validWeapons) do
            local weapon = workspace[LocalPlayer.Name]:FindFirstChild(weaponName)
            if weapon and weapon:IsA("Tool") and weapon.Parent == workspace[LocalPlayer.Name] then
                return weaponName
            end
        end
        return nil
    end

    local activeWeapon = getActiveWeapon()
    if not activeWeapon then return end

    for i = 1, rocketsToFire do
        if not isRPGSpamEnabled then return end

        local closestPlayer = getClosestPlayer()
        if not closestPlayer then return end

        local targetPosition = closestPlayer.Position
        local directionToTarget = (targetPosition - LocalPlayer.Character.HumanoidRootPart.Position).unit

        FireRocket:InvokeServer(directionToTarget, workspace[LocalPlayer.Name][activeWeapon], workspace[LocalPlayer.Name][activeWeapon], targetPosition)
        FireRocketClient:Fire(
            targetPosition,
            directionToTarget,
            {
                ["expShake"] = {["fadeInTime"] = 0.05, ["magnitude"] = 3, ["rotInfluence"] = {0.4, 0, 0.4}, ["fadeOutTime"] = 0.5, ["posInfluence"] = {1, 1, 0}, ["roughness"] = 3},
                ["gravity"] = Vector3.new(0, -20, 0),
                ["HelicopterDamage"] = 450,
                ["FireRate"] = 15,
                ["VehicleDamage"] = 350,
                ["ExpName"] = RPG,
                ["ExpRadius"] = 12,
                ["BoatDamage"] = 300,
                ["TankDamage"] = 300,
                ["Acceleration"] = 8,
                ["ShieldDamage"] = 170,
                ["Distance"] = 4000,
                ["PlaneDamage"] = 500,
                ["GunshipDamage"] = 170,
                ["velocity"] = 200,
                ["ExplosionDamage"] = 120
            },
            RocketSystem.Rockets["RPG Rocket"],
            workspace[LocalPlayer.Name][activeWeapon],
            workspace[LocalPlayer.Name][activeWeapon],
            LocalPlayer
        )
    end
end


WarTycoonBox:AddToggle("RPG Spam", {
    Text = "Toggle rockets Spam",
    Default = false,
    Tooltip = "RPG | JAVELIN | STINGER.",
    Callback = function(value)
        isRPGSpamEnabled = value
    end,
}):AddKeyPicker("RPG Spam Key", {
    Default = "Q",
    SyncToggleState = true,
    Mode = "Toggle",  
    Text = "Rockets Spam Key",
    Tooltip = "RPG | JAVELIN | STINGER",
    Callback = function()
        if isRPGSpamEnabled then
            startRPGSpam()
        end
    end,
})

WarTycoonBox:AddSlider("Rocket Count", {
    Text = "Rockets per Spam",
    Default = math.huge,
    Min = 100000,
    Max = math.huge,
    Rounding = 0,
    Tooltip = "Adjust how many rockets to fire at once.",
    Callback = function(value)
        rocketsToFire = math.floor(value)
    end,
})

WarTycoonBox:AddSlider("Spam Speed", {
    Text = "Rockets Spam Speed",
    Default = -math.huge,
    Min = -math.huge,
    Max = 100000,
    Rounding = 1,
    Tooltip = "Adjust the speed of RPG spam.",
    Callback = function(value)
        spamSpeed = value
    end,
})

game:GetService("RunService").Heartbeat:Connect(function()
    if isRPGSpamEnabled then
        wait(1 / spamSpeed)
        startRPGSpam()
    end
end)

local isQuickLagRPGExecuting = false

local function startQuickLagRPG()
    if not masterToggle then return end
    local camera, playerName = workspace.Camera, game:GetService("Players").LocalPlayer.Name
    local repeatCount = 500

    local validWeapons = {"RPG", "Javelin", "Stinger"}

    local function getActiveWeapon()
        for _, weaponName in ipairs(validWeapons) do
            local weapon = workspace[playerName]:FindFirstChild(weaponName)
            if weapon and weapon:IsA("Tool") and weapon.Parent == workspace[playerName] then
                return weaponName
            end
        end
        return nil
    end

    local function fireQuickLagRocket(weaponName)
        if not weaponName then return end

        local fireRocketVector = camera.CFrame.LookVector
        local fireRocketPosition = camera.CFrame.Position
        game:GetService("ReplicatedStorage").RocketSystem.Events.FireRocket:InvokeServer(
            fireRocketVector, workspace[playerName][weaponName], workspace[playerName][weaponName], fireRocketPosition
        )

        local fireRocketClientTable = {
            ["expShake"] = {["fadeInTime"] = 0.05, ["magnitude"] = 3, ["rotInfluence"] = {0.4, 0, 0.4}, ["fadeOutTime"] = 0.5, ["posInfluence"] = {1, 1, 0}, ["roughness"] = 3},
            ["gravity"] = Vector3.new(0, -20, 0), ["HelicopterDamage"] = 450, ["FireRate"] = 15, ["VehicleDamage"] = 350, ["ExpName"] = "Rocket",
            ["RocketAmount"] = 1, ["ExpRadius"] = 12, ["BoatDamage"] = 300, ["TankDamage"] = 300, ["Acceleration"] = 8, ["ShieldDamage"] = 11170,
            ["Distance"] = 4000, ["PlaneDamage"] = 500, ["GunshipDamage"] = 170, ["velocity"] = 200, ["ExplosionDamage"] = 120
        }

        local fireRocketClientInstance1 = game:GetService("ReplicatedStorage").RocketSystem.Rockets["RPG Rocket"]
        local fireRocketClientInstance2 = workspace[playerName][weaponName]
        local fireRocketClientInstance3 = workspace[playerName][weaponName]
        game:GetService("ReplicatedStorage").RocketSystem.Events.FireRocketClient:Fire(
            camera.CFrame.Position, camera.CFrame.LookVector, fireRocketClientTable, fireRocketClientInstance1, fireRocketClientInstance2, fireRocketClientInstance3,
            game:GetService("Players").LocalPlayer, nil, { [1] = workspace[playerName]:FindFirstChild(weaponName) }
        )
    end

    local activeWeapon = getActiveWeapon()
    if activeWeapon then
        for i = 1, repeatCount do
            task.spawn(fireQuickLagRocket, activeWeapon)
        end
    else
        warn("No active weapon: RPG | JAVELIN | STINGER")
    end
end

WarTycoonBox:AddToggle("Quick Lag RPG", {
    Text = "Quick Lag rocket",
    Default = false,
    Tooltip = "Enable or disable Quick Lag rocket.",
    Callback = function(value)
        if value then
            if not isQuickLagRPGExecuting then
                isQuickLagRPGExecuting = true
                startQuickLagRPG()
            end
        else
            isQuickLagRPGExecuting = false
        end
    end,
}):AddKeyPicker("Quick Lag rocket Key", {
    Default = "I",
    Mode = "Toggle",
    Text = "гуик важна",
    Tooltip = "просто забей бинд норм стоит",
    Callback = function()
        if not isQuickLagRPGExecuting then
            isQuickLagRPGExecuting = true
            startQuickLagRPG()
        else
            isQuickLagRPGExecuting = false
        end
    end,
})

local P, M, C = game.Players.LocalPlayer, game.Players.LocalPlayer:GetMouse(), workspace.CurrentCamera
local ExplosiveEnabled, ExplosiveMode, Holding = false, "Click", false

local function GetActiveWeapon()
    if not masterToggle then return end
    return (P.Character or P.CharacterAdded:Wait()):FindFirstChild("Stinger")
end

local function FireRocket()
    if not ExplosiveEnabled then return end
    local weapon = GetActiveWeapon()
    if weapon then
        local targetPosition = M.Hit.Position
        local RS = game:GetService("ReplicatedStorage").RocketSystem.Events
        RS.FireRocket:InvokeServer(C.CFrame.LookVector, weapon, weapon, C.CFrame.Position, nil, workspace.Terrain)
        RS.RocketHit:FireServer(targetPosition, C.CFrame.LookVector, weapon, weapon, workspace.Terrain, workspace.Terrain, P.Name .. "Rocket")
    end
end

local function SpamRockets()
    while Holding do
        for i = 1, 100 do
            if not Holding then break end
            FireRocket()
        end
    end
end

M.Button1Down:Connect(function()
    if ExplosiveEnabled then
        if ExplosiveMode == "Click" then
            FireRocket()
        elseif ExplosiveMode == "Click Hold Spam" then
            Holding = true
            for i = 1, 10 do
                coroutine.wrap(SpamRockets)()
            end
        end
    end
end)

M.Button1Up:Connect(function() Holding = false end)

WarTycoonBox:AddToggle("ExplosiveEnabled", {
    Text = "Stinger click",
    Default = false,
    Tooltip = "shit function",
    Callback = function(state)
        ExplosiveEnabled = state
    end
})

WarTycoonBox:AddDropdown("ExplosiveMode", {
    AllowNull = false,
    Multi = false,
    Text = "Select Mode",
    Default = "Click",
    Values = {"Click", "Click Hold Spam"},
    Tooltip = "Choose click mode.",
    Callback = function(value)
        ExplosiveMode = value
    end
})

local antiLagConnection

WarTycoonBox:AddToggle("AntiLag", {
    Text = "Anti-Lag",
    Default = false,
    Tooltip = "Removing all VisualRockets",
    Callback = function(value)
        if not enableMasterToggle then
            if antiLagConnection then
                antiLagConnection:Disconnect()
                antiLagConnection = nil
            end
            return
        end

        if value then
            local visualRocketsFolder = workspace:WaitForChild("VisualRockets")
            for _, object in ipairs(visualRocketsFolder:GetChildren()) do
                object:Destroy()
            end
            antiLagConnection = visualRocketsFolder.ChildAdded:Connect(function(newObject)
                newObject:Destroy()
            end)

        else
            if antiLagConnection then
                antiLagConnection:Disconnect()
                antiLagConnection = nil
            end
        end
    end
})

ACSEngineBox:AddToggle("WarTycoon", {
    Text = "War Tycoon",
    Default = false,
    Tooltip = "Enable War Tycoon mode to search for weapon settings in ACS_Guns.",
    Callback = function(value)
        getgenv().WarTycoon = value
    end
})

ACSEngineBox:AddToggle("WeaponOnHands", {
    Text = "Weapon In Hands",
    Default = false,
    Tooltip = "Apply changes only to the weapon in hands if enabled.",
    Callback = function(value)
        getgenv().WeaponOnHands = value
    end
})

ACSEngineBox:AddButton('INF AMMO', function()
    modifyWeaponSettings("Ammo", math.huge)
end)

ACSEngineBox:AddButton('NO RECOIL | NO SPREAD', function()
    modifyWeaponSettings("VRecoil", {0, 0})
    modifyWeaponSettings("HRecoil", {0, 0})
    modifyWeaponSettings("MinSpread", 0)
    modifyWeaponSettings("MaxSpread", 0)
    modifyWeaponSettings("RecoilPunch", 0)
    modifyWeaponSettings("AimRecoilReduction", 0)
end)

ACSEngineBox:AddButton('INF BULLET DISTANCE', function()
    modifyWeaponSettings("Distance", 25000)
end)

ACSEngineBox:AddInput("BulletSpeedInput", {
    Text = "Bullet Speed",
    Default = "10000",
    Tooltip = "Set the bullet speed",
    Callback = function(value)
        getgenv().bulletSpeedValue = tonumber(value) or 10000
    end
})

ACSEngineBox:AddButton('CHANGE BULLET SPEED', function()
    modifyWeaponSettings("BSpeed", getgenv().bulletSpeedValue or 10000)
    modifyWeaponSettings("MuzzleVelocity", getgenv().bulletSpeedValue or 10000)
end)

local fireRateInput
fireRateInput = ACSEngineBox:AddInput('FireRateInput', {
    Text = 'Enter Fire Rate',
    Default = '8888',
    Tooltip = 'Type the fire rate value you want to apply.',
})

ACSEngineBox:AddButton('CHANGE FIRE RATE', function()
    modifyWeaponSettings("FireRate", tonumber(fireRateInput.Value) or 8888)
    modifyWeaponSettings("ShootRate", tonumber(fireRateInput.Value) or 8888)
end)

local bulletsInput = ACSEngineBox:AddInput('BulletsInput', {
    Text = 'Enter Bullets',
    Default = '50',
    Tooltip = 'Type the number of bullets you want to apply.',
    Numeric = true
})

ACSEngineBox:AddButton('MULTI BULLETS', function()
    local bulletsValue = tonumber(Options.BulletsInput.Value) or 50
    modifyWeaponSettings("Bullets", bulletsValue)
end)

local inputField
inputField = ACSEngineBox:AddInput('FireModeInput', {
    Text = 'Enter Fire Mode',
    Default = 'Auto',
    Tooltip = 'Type the fire mode you want to apply.',
})

ACSEngineBox:AddButton('CHANGE FIRE MODE', function()
    modifyWeaponSettings("Mode", inputField.Value or 'Auto')
end)

local targetStrafe = GeneralTab:AddLeftGroupbox("Target Strafe")
local strafeEnabled = false
local strafeAllowed = true
local strafeSpeed, strafeRadius = 50, 5
local strafeMode, targetPlayer = "Horizontal", nil
local originalCameraMode = nil

local function startTargetStrafe()
    if not strafeAllowed then return end
    targetPlayer = getClosestPlayer()
    if targetPlayer and targetPlayer.Parent then
        originalCameraMode = game:GetService("Players").LocalPlayer.CameraMode
        game:GetService("Players").LocalPlayer.CameraMode = Enum.CameraMode.Classic
        local targetPos = targetPlayer.Position
        LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPos))
        Camera.CameraSubject = targetPlayer.Parent:FindFirstChild("Humanoid")
    end
end

local function strafeAroundTarget()
    if not (strafeAllowed and targetPlayer and targetPlayer.Parent) then return end
    local targetPos = targetPlayer.Position
    local angle = tick() * (strafeSpeed / 10)
    local offset = strafeMode == "Horizontal"
        and Vector3.new(math.cos(angle) * strafeRadius, 0, math.sin(angle) * strafeRadius)
        or Vector3.new(math.cos(angle) * strafeRadius, strafeRadius, math.sin(angle) * strafeRadius)
    LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPos + offset))
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, targetPos)
end

local function stopTargetStrafe()
    game:GetService("Players").LocalPlayer.CameraMode = originalCameraMode or Enum.CameraMode.Classic
    Camera.CameraSubject = LocalPlayer.Character.Humanoid
    strafeEnabled, targetPlayer = false, nil
end


targetStrafe:AddToggle("strafeControlToggle", {
    Text = "Enable/Disable",
    Default = true,
    Tooltip = "Enable or disable the ability to use Target Strafe.",
    Callback = function(value)
        strafeAllowed = value
        if not strafeAllowed and strafeEnabled then
            stopTargetStrafe()
        end
    end
})

targetStrafe:AddToggle("strafeToggle", {
    Text = "Enable Target Strafe",
    Default = false,
    Tooltip = "Enable or disable Target Strafe.",
    Callback = function(value)
        if strafeAllowed then
            strafeEnabled = value
            if strafeEnabled then startTargetStrafe() else stopTargetStrafe() end
        end
    end
}):AddKeyPicker("strafeToggleKey", {
    Default = "L",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Target Strafe Toggle Key",
    Tooltip = "Key to toggle Target Strafe",
    Callback = function(value)
        if strafeAllowed then
            strafeEnabled = value
            if strafeEnabled then startTargetStrafe() else stopTargetStrafe() end
        end
    end
})

targetStrafe:AddDropdown("strafeModeDropdown", {
    AllowNull = false,
    Text = "Target Strafe Mode",
    Default = "Horizontal",
    Values = {"Horizontal", "UP"},
    Tooltip = "Select the strafing mode.",
    Callback = function(value) strafeMode = value end
})

targetStrafe:AddSlider("strafeRadiusSlider", {
    Text = "Strafe Radius",
    Default = 5,
    Min = 1,
    Max = 20,
    Rounding = 1,
    Tooltip = "Set the radius of movement around the target.",
    Callback = function(value) strafeRadius = value end
})

targetStrafe:AddSlider("strafeSpeedSlider", {
    Text = "Strafe Speed",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 1,
    Tooltip = "Set the speed of strafing around the target.",
    Callback = function(value) strafeSpeed = value end
})

game:GetService("RunService").RenderStepped:Connect(function()
    if strafeEnabled and strafeAllowed then strafeAroundTarget() end
end)

while true do
    task.wait()

    if isFunctionalityEnabled then
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            humanoid = localPlayer.Character:FindFirstChild("Humanoid")
            
            if isSpeedActive and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                local moveDirection = humanoid.MoveDirection.Unit
                localPlayer.Character.HumanoidRootPart.CFrame = localPlayer.Character.HumanoidRootPart.CFrame + moveDirection * Cmultiplier
            end

            if isFlyActive then
                local flyDirection = Vector3.zero

                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then
                    flyDirection = flyDirection + camera.CFrame.LookVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then
                    flyDirection = flyDirection - camera.CFrame.LookVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then
                    flyDirection = flyDirection - camera.CFrame.RightVector
                end
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then
                    flyDirection = flyDirection + camera.CFrame.RightVector
                end

                if flyDirection.Magnitude > 0 then
                    flyDirection = flyDirection.Unit
                end

                local newPosition = localPlayer.Character.HumanoidRootPart.Position + flyDirection * flySpeed
                localPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(newPosition)
                localPlayer.Character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
            end

            if isNoClipActive then
                for _, v in pairs(localPlayer.Character:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        v.CanCollide = false
                    end
                end
            end
        end
    end
end

ThemeManager:LoadDefaultTheme()

print("Загружено нахуй.")
