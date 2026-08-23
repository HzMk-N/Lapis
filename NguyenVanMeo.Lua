local WindUI = loadstring(game:HttpGet('https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua'))()

local Window = WindUI:CreateWindow({
    Title = "ARZ || NguyenVanMeo",
    Icon = "sword",
    Author = "V1.3 | Demonic Week",
    Folder = "ARZ",
    Theme = "Dark",
    Transparent = true,
    Acrylic = false,
    Size = UDim2.fromOffset(620, 480),
    Resizable = true,
})

WindUI:Notify({
    Title = "ARZ",
    Content = "Script V1.3 | Auto Dodge Fixed",
    Duration = 5
})

local MovementTab = Window:Tab({ Title = "Movement", Icon = "move" })
local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
local CombatTab = Window:Tab({ Title = "Combat", Icon = "crosshair" })
local UtilityTab = Window:Tab({ Title = "Utility", Icon = "settings" })

local noclipEnabled = false
local espEnabled = false
local itemEspEnabled = false
local brightEnabled = false
local speedEnabled = false
local currentSpeed = 16
local defaultSpeed = 16

local aimEnabled = false
local showFov = true
local fovSize = 120
local smoothness = 0.18
local maxAimDistance = 180

local antiNoiseEnabled = false
local savedEffects = {}

-- Auto Dodge
local autoDodgeEnabled = false
local dodgeDistance = 10
local dodgeCooldown = 0.18
local lastDodgeTime = 0

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local espObjects = {}
local itemEspObjects = {}

-- FOV Circle an toàn (không crash nếu executor không hỗ trợ Drawing)
local fovCircle = nil
pcall(function()
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1.8
    fovCircle.NumSides = 64
    fovCircle.Radius = fovSize
    fovCircle.Filled = false
    fovCircle.Visible = false
    fovCircle.Color = Color3.fromRGB(0, 255, 180)
    fovCircle.Transparency = 0.25
end)

local dangerousNames = {
    "Tall", "Charge", "Drawer", "Dragger", "Demon Eye", "DemonEye",
    "Kidnapper", "Dimension", "Red Door", "Watermelon", "Mimic", "Shy"
}

local specialNames = {
    "Statue", "Doge", "Crying"
}

local itemNames = {
    "Flashlight", "Crucifix", "Bear Trap", "BearTrap", "Bandage",
    "Shotgun", "Ammo", "Bat", "Baseball Bat", "Slap", "Revive",
    "Trap", "Security", "iPad"
}

local function isPlayerCharacter(model)
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character == model then
            return true
        end
    end
    return false
end

local function getMonsterType(name)
    name = string.lower(name or "")
    for _, n in ipairs(dangerousNames) do
        if string.find(name, string.lower(n)) then
            return "Dangerous"
        end
    end
    for _, n in ipairs(specialNames) do
        if string.find(name, string.lower(n)) then
            return "Special"
        end
    end
    if string.find(name, "ghost") then
        return "Safe"
    end
    return "Unknown"
end

local function isItem(obj)
    local name = string.lower(obj.Name)
    for _, itemName in ipairs(itemNames) do
        if string.find(name, string.lower(itemName)) then
            return true
        end
    end
    return obj:IsA("Tool")
end

local function createESP(target)
    if not target or not target:IsA("Model") then return end
    if espObjects[target] then return end
    if isPlayerCharacter(target) then return end
    if not target:FindFirstChildOfClass("Humanoid") and not target:FindFirstChild("HumanoidRootPart") then return end

    local monsterType = getMonsterType(target.Name)
    local fillColor, outlineColor, textColor

    if monsterType == "Dangerous" then
        fillColor = Color3.fromRGB(255, 40, 40)
        outlineColor = Color3.fromRGB(255, 80, 80)
        textColor = Color3.fromRGB(255, 60, 60)
    elseif monsterType == "Special" then
        fillColor = Color3.fromRGB(255, 140, 0)
        outlineColor = Color3.fromRGB(255, 180, 50)
        textColor = Color3.fromRGB(255, 160, 30)
    elseif monsterType == "Safe" then
        fillColor = Color3.fromRGB(0, 200, 100)
        outlineColor = Color3.fromRGB(0, 255, 150)
        textColor = Color3.fromRGB(0, 255, 150)
    else
        fillColor = Color3.fromRGB(0, 200, 255)
        outlineColor = Color3.fromRGB(0, 255, 255)
        textColor = Color3.fromRGB(0, 255, 200)
    end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = target
    highlight.FillTransparency = 0.45
    highlight.OutlineTransparency = 0
    highlight.FillColor = fillColor
    highlight.OutlineColor = outlineColor
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = target

    local root = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
    if not root then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = root
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 280, 0, 80)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.Parent = target

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextStrokeTransparency = 0.2
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 15
    textLabel.TextColor3 = textColor
    textLabel.Text = target.Name
    textLabel.Parent = billboard

    espObjects[target] = {
        Highlight = highlight,
        Billboard = billboard,
        Text = textLabel,
        Root = root
    }
end

local function createItemESP(target)
    if not target or itemEspObjects[target] then return end

    local part
    if target:IsA("BasePart") then
        part = target
    elseif target:IsA("Model") then
        part = target:FindFirstChildWhichIsA("BasePart") or target.PrimaryPart
    elseif target:IsA("Tool") then
        part = target:FindFirstChild("Handle") or target:FindFirstChildWhichIsA("BasePart")
    end
    if not part then return end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = target
    highlight.FillTransparency = 0.4
    highlight.OutlineTransparency = 0
    highlight.FillColor = Color3.fromRGB(255, 255, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 100)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = target

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = part
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = target

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextStrokeTransparency = 0.2
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 14
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 50)
    textLabel.Text = "[ITEM] " .. target.Name
    textLabel.Parent = billboard

    itemEspObjects[target] = {
        Highlight = highlight,
        Billboard = billboard,
        Text = textLabel,
        Root = part
    }
end

local function updateESP()
    for target, data in pairs(espObjects) do
        if target and target.Parent and data.Text and data.Root then
            local dist = (camera.CFrame.Position - data.Root.Position).Magnitude
            data.Text.Text = string.format("%s\n%.0f m", target.Name, dist)
        else
            pcall(function() if data.Highlight then data.Highlight:Destroy() end end)
            pcall(function() if data.Billboard then data.Billboard:Destroy() end end)
            espObjects[target] = nil
        end
    end
end

local function updateItemESP()
    for target, data in pairs(itemEspObjects) do
        if target and target.Parent and data.Text and data.Root then
            local dist = (camera.CFrame.Position - data.Root.Position).Magnitude
            data.Text.Text = string.format("[ITEM] %s\n%.0f m", target.Name, dist)
        else
            pcall(function() if data.Highlight then data.Highlight:Destroy() end end)
            pcall(function() if data.Billboard then data.Billboard:Destroy() end end)
            itemEspObjects[target] = nil
        end
    end
end

local function removeESP(target)
    if espObjects[target] then
        pcall(function() if espObjects[target].Highlight then espObjects[target].Highlight:Destroy() end end)
        pcall(function() if espObjects[target].Billboard then espObjects[target].Billboard:Destroy() end end)
        espObjects[target] = nil
    end
end

local function removeItemESP(target)
    if itemEspObjects[target] then
        pcall(function() if itemEspObjects[target].Highlight then itemEspObjects[target].Highlight:Destroy() end end)
        pcall(function() if itemEspObjects[target].Billboard then itemEspObjects[target].Billboard:Destroy() end end)
        itemEspObjects[target] = nil
    end
end

local function scanMonsters()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj:FindFirstChildOfClass("Humanoid") or obj:FindFirstChild("HumanoidRootPart")) then
            if not isPlayerCharacter(obj) then
                createESP(obj)
            end
        end
    end
end

local function scanItems()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isItem(obj) and not obj:IsDescendantOf(player.Character) and not obj:IsDescendantOf(player.Backpack) then
            createItemESP(obj)
        end
    end
end

local function toggleBright(state)
    brightEnabled = state
    if state then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1000000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    else
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
    end
end

local function toggleAntiNoise(state)
    antiNoiseEnabled = state
    if state then
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("BloomEffect")
            or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorGradingEffect") then
                savedEffects[effect] = effect.Enabled
                effect.Enabled = false
            end
        end
        Lighting.FogEnd = 1000000
        Lighting.FogStart = 0
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then
            atmosphere.Density = 0
            atmosphere.Glare = 0
            atmosphere.Haze = 0
        end
        WindUI:Notify({ Title = "Anti Noise", Content = "Đã tắt hiệu ứng!", Duration = 3 })
    else
        for effect, wasEnabled in pairs(savedEffects) do
            if effect and effect.Parent then
                effect.Enabled = wasEnabled
            end
        end
        table.clear(savedEffects)
        WindUI:Notify({ Title = "Anti Noise", Content = "Đã bật lại hiệu ứng", Duration = 3 })
    end
end

local function giveTPTool()
    local tool = Instance.new("Tool")
    tool.Name = "Teleport Tool"
    tool.RequiresHandle = false
    tool.Parent = player.Backpack
    tool.Activated:Connect(function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local mouse = player:GetMouse()
        if root and mouse.Hit then
            root.CFrame = mouse.Hit + Vector3.new(0, 5, 0)
        end
    end)
end

local function setWalkSpeed(speed)
    currentSpeed = speed
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = speed
    end
end

local function doAutoDodge()
    if not autoDodgeEnabled then return end
    if tick() - lastDodgeTime < dodgeCooldown then return end

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    local closestDist = math.huge
    local closestRoot = nil

    for target, data in pairs(espObjects) do
        if target and target.Parent and data.Root and data.Root.Parent then
            if getMonsterType(target.Name) \~= "Safe" then
                local dist = (hrp.Position - data.Root.Position).Magnitude
                if dist < closestDist and dist <= dodgeDistance then
                    closestDist = dist
                    closestRoot = data.Root
                end
            end
        end
    end

    if closestRoot then
        local directions = {
            hrp.CFrame.RightVector,
            -hrp.CFrame.RightVector,
            hrp.CFrame.LookVector,
            -hrp.CFrame.LookVector
        }
        local dir = directions[math.random(1, 4)]
        dir = Vector3.new(dir.X, 0, dir.Z).Unit
        hrp.CFrame = hrp.CFrame + (dir * 9)
        lastDodgeTime = tick()
    end
end

local function getClosestMonsterInFOV()
    local closest = nil
    local shortest = math.huge
    local cam = workspace.CurrentCamera
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    for target, data in pairs(espObjects) do
        if target and target.Parent and data.Root and data.Root.Parent then
            if getMonsterType(target.Name) \~= "Safe" then
                local pos, onScreen = cam:WorldToViewportPoint(data.Root.Position)
                if onScreen then
                    local distToCenter = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    local worldDist = (cam.CFrame.Position - data.Root.Position).Magnitude
                    if distToCenter <= fovSize and worldDist <= maxAimDistance then
                        local priority = (getMonsterType(target.Name) == "Dangerous" and 1) or (getMonsterType(target.Name) == "Special" and 2) or 3
                        local score = distToCenter + (priority * 25)
                        if score < shortest then
                            shortest = score
                            closest = data.Root
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function doAimbot()
    if not aimEnabled then return end
    local targetPart = getClosestMonsterInFOV()
    if targetPart then
        local cam = workspace.CurrentCamera
        local goal = CFrame.new(cam.CFrame.Position, targetPart.Position + Vector3.new(0, 1.4, 0))
        cam.CFrame = cam.CFrame:Lerp(goal, smoothness)
    end
end
MovementTab:Toggle({
    Title = "Speed",
    Callback = function(v)
        speedEnabled = v
        setWalkSpeed(v and currentSpeed or defaultSpeed)
    end
})

MovementTab:Slider({
    Title = "WalkSpeed",
    Value = { Min = 16, Max = 200, Default = 16 },
    Callback = function(v)
        currentSpeed = v
        if speedEnabled then setWalkSpeed(v) end
    end
})

MovementTab:Toggle({ Title = "NoClip", Callback = function(v) noclipEnabled = v end })

MovementTab:Toggle({
    Title = "Auto Dodge",
    Callback = function(v)
        autoDodgeEnabled = v
        if v then
            WindUI:Notify({ Title = "Auto Dodge", Content = "Đã bật!", Duration = 3 })
        end
    end
})

MovementTab:Slider({
    Title = "Dodge Distance",
    Value = { Min = 5, Max = 25, Default = 10 },
    Callback = function(v) dodgeDistance = v end
})

MovementTab:Button({ Title = "Tool Teleport", Callback = giveTPTool })

VisualsTab:Toggle({ Title = "Fullbright", Callback = toggleBright })

VisualsTab:Toggle({
    Title = "Anti Noise (tắt hiệu ứng tối)",
    Callback = toggleAntiNoise
})

VisualsTab:Toggle({
    Title = "ESP Monster",
    Callback = function(v)
        espEnabled = v
        if v then
            scanMonsters()
        else
            for t, _ in pairs(espObjects) do removeESP(t) end
        end
    end
})

VisualsTab:Toggle({
    Title = "ESP Item",
    Callback = function(v)
        itemEspEnabled = v
        if v then
            scanItems()
        else
            for t, _ in pairs(itemEspObjects) do removeItemESP(t) end
        end
    end
})

CombatTab:Toggle({
    Title = "Aimbot",
    Callback = function(v) aimEnabled = v end
})

CombatTab:Slider({
    Title = "FOV Size",
    Value = { Min = 40, Max = 400, Default = 120 },
    Callback = function(v) fovSize = v end
})

CombatTab:Slider({
    Title = "Smoothness",
    Value = { Min = 0.05, Max = 0.8, Default = 0.18 },
    Callback = function(v) smoothness = v end
})

CombatTab:Slider({
    Title = "Max Distance",
    Value = { Min = 50, Max = 400, Default = 180 },
    Callback = function(v) maxAimDistance = v end
})

UtilityTab:Button({
    Title = "Reset Character",
    Callback = function()
        if player.Character then player.Character:BreakJoints() end
    end
})

UtilityTab:Button({
    Title = "Unlock Camera",
    Callback = function()
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Custom
        player.CameraMode = Enum.CameraMode.Classic
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            cam.CameraSubject = player.Character.Humanoid
        end
        player.CameraMinZoomDistance = 0.5
        player.CameraMaxZoomDistance = 400
        WindUI:Notify({ Title = "Camera", Content = "Unlocked!", Duration = 3 })
    end
})

RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end

    if speedEnabled then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.WalkSpeed = currentSpeed end
    end

    if noclipEnabled then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end

    if espEnabled then updateESP() end
    if itemEspEnabled then updateItemESP() end

    if antiNoiseEnabled then
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("BlurEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("BloomEffect")
            or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorGradingEffect") then
                effect.Enabled = false
            end
        end
        Lighting.FogEnd = 1000000
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then
            atmosphere.Density = 0
            atmosphere.Glare = 0
            atmosphere.Haze = 0
        end
    end

    doAutoDodge()

    if fovCircle then
        local vs = camera.ViewportSize
        fovCircle.Position = Vector2.new(vs.X / 2, vs.Y / 2)
        fovCircle.Radius = fovSize
        fovCircle.Visible = showFov and aimEnabled
    end

    if aimEnabled then
        doAimbot()
    end
end)

Workspace.DescendantAdded:Connect(function(desc)
    task.wait(0.35)
    if espEnabled and desc:IsA("Model") and (desc:FindFirstChildOfClass("Humanoid") or desc:FindFirstChild("HumanoidRootPart")) then
        if not isPlayerCharacter(desc) then
            createESP(desc)
        end
    end
    if itemEspEnabled and isItem(desc) then
        if not desc:IsDescendantOf(player.Character) and not desc:IsDescendantOf(player.Backpack) then
            createItemESP(desc)
        end
    end
end)
