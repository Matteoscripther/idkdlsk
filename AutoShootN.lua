getgenv().Elysian = {
    ['Camlock'] = {
        ['Manual Prediction'] = 0.1475,
        ['Auto Prediction'] = {
            ['Enabled'] = true,
            ['Ping'] = {
                ['20'] = 0.10036,
                ['30'] = 0.1130,
                ['40'] = 0.13544,
                ['50'] = 0.1357,
                ['60'] = 0.13598,
                ['70'] = 0.13892,
                ['80'] = 0.1403,
                ['90'] = 0.1446,
                ['100'] = 0.1475
            }
        },
        ['Smoothing'] = {
            ['Enabled'] = false,
            ['Value'] = 0.013
        },
        ['Offset'] = {
            ['Jump'] = -1,
            ['Fall'] = -1,
        },
        ['Auto Shoot'] = true,
        ['Airshot Function'] = {
            ['Enabled'] = true,
            ['Part'] = "LowerTorso"
        },
        ['Target Part'] = "HumanoidRootPart"
    },
    ['HvH'] = {
        ['Target Strafe'] = {
            ['Enabled'] = true,
            ['Speed'] = 100,
            ['Distance'] = 10,
            ['Height'] = 7,
        },
        ['Cframe Walk'] = {
            ['Enabled'] = true,
            ['Amount'] = 3
        }
    }
}

local userInputService = game:GetService("UserInputService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local client = players.LocalPlayer
local camera = workspace.CurrentCamera
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local Locking = false
local Plr = nil
local strafing = false
local cframing = false
local auto_shooting = false

local playerData = {}
local SMOOTHNESS_FACTOR = 2

local function GetEvent()
    for _, v in pairs(game.ReplicatedStorage:GetChildren()) do
        if v.Name == "MainEvent" or v.Name == "Bullets" or v.Name == ".gg/untitledhood" or v.Name == "Remote" or v.Name == "MAINEVENT" or v.Name == ".gg/flamehood" then
            return v
        end
    end
end

local function GetArgs()
    local PlaceId = game.PlaceId
    if PlaceId == 2788229376 or PlaceId == 4106313503 or PlaceId == 11143225577 or PlaceId == 17319408836 or PlaceId == 18110728826 then
        return "UpdateMousePosI"
    elseif PlaceId == 5602055394 or PlaceId == 7951883376 then
        return "MousePos"
    elseif PlaceId == 10100958808 or PlaceId == 12645617354 or PlaceId == 14171242539 or PlaceId == 14412436145 or PlaceId == 14412355918 or PlaceId == 14413720089 or PlaceId == 17403265390 or PlaceId == 17403166075 or PlaceId == 17403262882 or PlaceId == 15186202290 or PlaceId == 15763494605 then
        return "MOUSE"
    elseif PlaceId == 9825515356 then
        return "MousePosUpdate"
    elseif PlaceId == 15166543806 then
        return "MoonUpdateMousePos"
    elseif PlaceId == 16033173781 or PlaceId == 7213786345 then
        return "UpdateMousePosI"
    else
        return "UpdateMousePos"
    end
end

local mainEvent = GetEvent()

function GetClosestToCenter()
    local closestDist = math.huge
    local closestPlr = nil
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    
    for _, v in ipairs(players:GetPlayers()) do
        if v ~= client and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            local screenPos, onScreen = camera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
            if onScreen then
                local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                if distToCenter < closestDist then
                    closestPlr = v
                    closestDist = distToCenter
                end
            end
        end
    end
    return closestPlr
end

local function getPart()
    if not Plr or not Plr.Character then
        return nil
    end

    local humanoid = Plr.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return nil
    end

    if humanoid:GetState() == Enum.HumanoidStateType.Freefall and getgenv().Elysian['Camlock']['Airshot Function']['Enabled'] then
        local airshotPart = Plr.Character:FindFirstChild(getgenv().Elysian['Camlock']['Airshot Function']['Part'])
        if airshotPart then
            return airshotPart
        end
    end

    local targetPart = Plr.Character:FindFirstChild(getgenv().Elysian['Camlock']['Target Part'])
    if targetPart then
        return targetPart
    end

    return Plr.Character:FindFirstChild("HumanoidRootPart")
end

local function getPredictionValue()
    if getgenv().Elysian['Camlock']['Auto Prediction']['Enabled'] then
        local ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        local pingTable = getgenv().Elysian['Camlock']['Auto Prediction']['Ping']
        
        for i = ping, 0, -1 do
            if pingTable[tostring(i)] then
                return pingTable[tostring(i)]
            end
        end
        
        return pingTable['100']
    else
        return getgenv().Elysian['Camlock']['Manual Prediction']
    end
end

local function calculatePosition(victim, velocity)
    local prediction = getPredictionValue()
    local jumpOffset = getgenv().Elysian['Camlock']['Offset']['Jump']
    local fallOffset = getgenv().Elysian['Camlock']['Offset']['Fall']
    
    local playerData = playerData[victim.Parent.Parent]
    if not playerData then
        playerData = {
            SmoothedVelocity = velocity
        }
        playerData[victim.Parent.Parent] = playerData
    end
    
    playerData.SmoothedVelocity = playerData.SmoothedVelocity:Lerp(velocity, 0.5)
    
    local pos = victim.Position + playerData.SmoothedVelocity * prediction

    if victim.Parent and victim.Parent:FindFirstChild("Humanoid") then
        local humanoid = victim.Parent.Humanoid
        if humanoid:GetState() == Enum.HumanoidStateType.Jumping then
            pos = pos + Vector3.new(0, jumpOffset, 0)
        elseif humanoid:GetState() == Enum.HumanoidStateType.Freefall then
            pos = pos + Vector3.new(0, fallOffset, 0)
        end
    end

    return pos
end

local function CharAdded()
    if Locking and Plr and Plr.Character and playerData[Plr] then
        local Part = getPart()
        if Part then
            local Position = calculatePosition(Part, playerData[Plr].Velocity)
            mainEvent:FireServer(GetArgs(), Position)
        end
    end
end

client.Character.ChildAdded:Connect(function(child)
    if child:IsA("Tool") then
        child.Activated:Connect(CharAdded)
    end
end)

client.CharacterAdded:Connect(function(character)
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            child.Activated:Connect(CharAdded)
        end
    end)
end)

local function Process(player, dT)
    if not player or not player.Character then
        return
    end

    local PrimaryPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not PrimaryPart then
        return
    end

    if not playerData[player] then
        playerData[player] = {
            PreviousPosition = PrimaryPart.Position,
            Velocity = Vector3.new(0, 0, 0),
            OnScreen = false,
            ScreenPosition = Vector2.new(0, 0)
        }
    end

    local CurrentPosition = PrimaryPart.Position
    local PreviousPosition = playerData[player].PreviousPosition
    local Displacement = CurrentPosition - PreviousPosition

    local targetVelocity = Displacement / dT
    playerData[player].Velocity = playerData[player].Velocity:Lerp(targetVelocity, 0.5)
    playerData[player].PreviousPosition = CurrentPosition
    
    local ScreenPosition, OnScreen = workspace.CurrentCamera:WorldToViewportPoint(CurrentPosition)

    playerData[player].OnScreen = OnScreen
    playerData[player].ScreenPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
end

local strafeAngle = 0

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function SavePositions(positions)
    local json = HttpService:JSONEncode(positions)
    writefile("button_positions.json", json)
end

local function LoadPositions()
    if isfile("button_positions.json") then
        local json = readfile("button_positions.json")
        return HttpService:JSONDecode(json)
    end
    return {}
end

local savedPositions = LoadPositions()

local function CreateButton(name, defaultPosition, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 100, 0, 50)
    Button.Position = savedPositions[name] and UDim2.new(0, savedPositions[name].X, 0, savedPositions[name].Y) or defaultPosition
    Button.Text = name
    Button.Parent = ScreenGui
    Button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Button.BorderSizePixel = 0
    Button.Font = Enum.Font.Code
    Button.TextColor3 = Color3.new(255, 255, 255)
    Button.TextSize = 16
    Button.AutoButtonColor = false

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Button

    local Shadow = Instance.new("Frame")
    Shadow.Size = UDim2.new(1, 6, 1, 6)
    Shadow.Position = UDim2.new(0, -3, 0, -3)
    Shadow.BackgroundColor3 = Color3.fromRGB(47, 47, 47)
    Shadow.BackgroundTransparency = 0.7
    Shadow.ZIndex = -1
    Shadow.Parent = Button

    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 8)
    ShadowCorner.Parent = Shadow

    local isActive = false

    local function updateButtonState()
        local targetColor = isActive and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = game:GetService("TweenService"):Create(Shadow, tweenInfo, {BackgroundColor3 = targetColor})
        tween:Play()
    end

    Button.MouseButton1Click:Connect(function()
        isActive = not isActive
        updateButtonState()
        callback(isActive)
    end)

    local dragStart, startPos

    Button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragStart = input.Position
            startPos = Button.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragStart = nil
                    savedPositions[name] = {X = Button.Position.X.Offset, Y = Button.Position.Y.Offset}
                    SavePositions(savedPositions)
                end
            end)
        end
    end)

    Button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            if dragStart then
                local delta = input.Position - dragStart
                Button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
    
    return Button, function() return isActive end
end

local AutoShootButton, getAutoShootState = CreateButton("AutoShoot", UDim2.new(0, 10, 0, 10), function(state)
    auto_shooting = state
end)

local function AutoShoot()
    if Locking and Plr then
        local character = client.Character
        if character then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool and tool:IsA("Tool") then
                tool:Activate()
            end
        end
    end
end

runService.Heartbeat:Connect(function()
    if auto_shooting then
        AutoShoot()
    end
end)

local AkaliNotif = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kinlei/Dynissimo/main/Scripts/AkaliNotif.lua"))();
local Notify = AkaliNotif.Notify;
Notify({
    Description = "Made By Zati";
    Title = "Join Zati Discord";
    Duration = 10; 
})