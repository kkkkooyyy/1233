local function safeLoad(url)
    local success, result = pcall(function() return loadstring(game:HttpGet(url))() end)
    if not success then
        warn("加载失败: " .. url)
        return nil
    end
    return result
end

local Library = safeLoad("https://raw.githubusercontent.com/kongbaNB/ui/refs/heads/main/黑曜石主库.ui")
local ThemeManager = safeLoad("https://raw.githubusercontent.com/kongbaNB/ui/refs/heads/main/主题管理.ui")
local SaveManager = safeLoad("https://raw.githubusercontent.com/kongbaNB/ui/refs/heads/main/配置管理.ui")

if not Library then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "错误",
        Text = "UI 库加载失败，请检查网络或脚本资源",
        Duration = 5,
    })
    return
end

local Options = Library.Options
local Toggles = Library.Toggles
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local Window = Library:CreateWindow({xiaoyi脚本})
    Title = "决斗场",
    Footer = "赤急霸 制作",
    Icon = 131153193945220,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

Library:Notify({
    Title = "决斗场",
    Description = "创作者：赤急霸
QQ：3977491459
脚本已加载成功",
    Time = 5,
})

local Tabs = {
    Combat = Window:AddTab("杀戮", "sword"),
    Block = Window:AddTab("格挡", "shield"),
    Hitbox = Window:AddTab("暴力", "hammer"),
    Settings = Window:AddTab("设置", "settings"),
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayerCharRequest = Remotes:WaitForChild("PlayerCharacter"):WaitForChild("Request")
local QueueJumpRemote = PlayerCharRequest:WaitForChild("QueueJump")

local lightLoopEnabled = false
local heavyLoopEnabled = false
local lightConnection = nil
local heavyConnection = nil
local lastLightTime = 0
local lastHeavyTime = 0
local lightInterval = 0.5
local heavyInterval = 0.5

local jumpConnection = nil
local jumpCooldown = 0.5
local lastJumpTime = 0
local previousDistances = {}

local teleportConnection = nil
local teleportDistance = 2.5
local teleportCooldown = 1
local lastTeleportTime = 0

local hitboxEnabled = false
local noCollisionEnabled = false
local hitbox_original_properties = {}
local hitboxSize = 21
local hitboxTransparency = 6
local defaultBodyParts = {
    "UpperTorso",
    "Head",
    "HumanoidRootPart"
}

local function fireAttack(attackType)
    local remote = Remotes:FindFirstChild("QueueBasicAttack")
    if remote then
        remote:FireServer("26", "Katana", attackType)
    end
end

local function findNearestPlayer()
    local character = LocalPlayer.Character
    if not character or not character.PrimaryPart then return nil, math.huge end
    local root = character.PrimaryPart
    local currentPos = root.Position
    local nearestPlayer = nil
    local nearestDist = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and char.PrimaryPart then
                local dist = (char.PrimaryPart.Position - currentPos).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPlayer = player
                end
            end
        end
    end
    return nearestPlayer, nearestDist
end

local function teleportBehind(player)
    if not player then return end
    local char = player.Character
    if not char or not char.PrimaryPart then return end
    local targetRoot = char.PrimaryPart
    local targetCFrame = targetRoot.CFrame
    local behindPos = targetCFrame.Position - targetCFrame.LookVector * teleportDistance
    local localChar = LocalPlayer.Character
    if localChar and localChar.PrimaryPart then
        localChar.PrimaryPart.Position = behindPos
    end
end

local function savedPart(player, part)
    if not hitbox_original_properties[player] then
        hitbox_original_properties[player] = {}
    end
    if not hitbox_original_properties[player][part.Name] then
        hitbox_original_properties[player][part.Name] = {
            CanCollide = part.CanCollide,
            Transparency = part.Transparency,
            Size = part.Size
        }
    end
end

local function restoredPart(player)
    if hitbox_original_properties[player] then
        for partName, properties in pairs(hitbox_original_properties[player]) do
            local part = player.Character and player.Character:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.CanCollide = properties.CanCollide
                part.Transparency = properties.Transparency
                part.Size = properties.Size
            end
        end
    end
end

local function findClosestPart(player, partName)
    if not player.Character then return nil end
    for _, part in ipairs(player.Character:GetChildren()) do
        if part:IsA("BasePart") and part.Name:lower():match(partName:lower()) then
            return part
        end
    end
    return nil
end

local function extendHitbox(player)
    for _, partName in ipairs(defaultBodyParts) do
        local part = player.Character and (player.Character:FindFirstChild(partName) or findClosestPart(player, partName))
        if part and part:IsA("BasePart") then
            savedPart(player, part)
            part.CanCollide = not noCollisionEnabled
            part.Transparency = hitboxTransparency / 10
            part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        end
    end
end

local function updateHitboxes()
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            extendHitbox(v)
        end
    end
end

local function onCharacterAdded(character)
    task.wait(0.1)
    if hitboxEnabled then
        updateHitboxes()
    end
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(onCharacterAdded)
    player.CharacterRemoving:Connect(function()
        restoredPart(player)
        hitbox_original_properties[player] = nil
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

task.spawn(function()
    while true do
        if hitboxEnabled then
            updateHitboxes()
            for player, _ in pairs(hitbox_original_properties) do
                if not player.Parent or not player.Character or not player.Character:IsDescendantOf(game) then
                    restoredPart(player)
                    hitbox_original_properties[player] = nil
                end
            end
        end
        task.wait(0.1)
    end
end)

local combatLeft = Tabs.Combat:AddLeftGroupbox("攻击")
combatLeft:AddButton("轻击", function()
    fireAttack("Light01")
end)
combatLeft:AddButton("重击", function()
    fireAttack("Heavy01")
end)

combatLeft:AddToggle("LightKill", {
    Text = "轻击杀戮",
    Default = false,
    Callback = function(value)
        lightLoopEnabled = value
        if value then
            task.spawn(function()
                while lightLoopEnabled do
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                                if (myPos - plr.Character.HumanoidRootPart.Position).Magnitude <= 11 then
                                    fireAttack("Light01")
                                    break
                                end
                            end
                        end
                    end
                    task.wait(0.25)
                end
            end)
        end
    end
})

combatLeft:AddToggle("HeavyKill", {
    Text = "重击杀戮",
    Default = false,
    Callback = function(value)
        heavyLoopEnabled = value
        if value then
            task.spawn(function()
                while heavyLoopEnabled do
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                                if (myPos - plr.Character.HumanoidRootPart.Position).Magnitude <= 11 then
                                    fireAttack("Heavy01")
                                    break
                                end
                            end
                        end
                    end
                    task.wait(0.36)
                end
            end)
        end
    end
})

local combatRight = Tabs.Combat:AddRightGroupbox("强制攻击")
combatRight:AddToggle("ForceLight", {
    Text = "强制轻击杀戮",
    Default = false,
    Callback = function(value)
        if value then
            lightConnection = RunService.Heartbeat:Connect(function()
                if tick() - lastLightTime >= lightInterval then
                    fireAttack("Light01")
                    lastLightTime = tick()
                end
            end)
        else
            if lightConnection then
                lightConnection:Disconnect()
                lightConnection = nil
            end
        end
    end
})
combatRight:AddToggle("ForceHeavy", {
    Text = "强制重击杀戮",
    Default = false,
    Callback = function(value)
        if value then
            heavyConnection = RunService.Heartbeat:Connect(function()
                if tick() - lastHeavyTime >= heavyInterval then
                    fireAttack("Heavy01")
                    lastHeavyTime = tick()
                end
            end)
        else
            if heavyConnection then
                heavyConnection:Disconnect()
                heavyConnection = nil
            end
        end
    end
})

local blockLeft = Tabs.Block:AddLeftGroupbox("躲避")
blockLeft:AddToggle("AutoJump", {
    Text = "自动跳跃躲避攻击",
    Default = false,
    Callback = function(value)
        if value then
            jumpConnection = RunService.Heartbeat:Connect(function()
                local character = LocalPlayer.Character
                if not character or not character.PrimaryPart then return end
                local root = character.PrimaryPart
                local currentPos = root.Position
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        local char = plr.Character
                        if char and char.PrimaryPart then
                            local targetRoot = char.PrimaryPart
                            local dist = (targetRoot.Position - currentPos).Magnitude
                            local prevDist = previousDistances[plr]
                            if prevDist and dist < prevDist then
                                if tick() - lastJumpTime > jumpCooldown then
                                    QueueJumpRemote:FireServer("34", Vector3.zero, 1)
                                    lastJumpTime = tick()
                                end
                            end
                            previousDistances[plr] = dist
                        else
                            previousDistances[plr] = nil
                        end
                    end
                end
            end)
        else
            if jumpConnection then
                jumpConnection:Disconnect()
                jumpConnection = nil
                previousDistances = {}
            end
        end
    end
})

blockLeft:AddToggle("AutoTeleport", {
    Text = "自动传送躲避攻击",
    Default = false,
    Callback = function(value)
        if value then
            teleportConnection = RunService.Heartbeat:Connect(function()
                local nearestPlayer = findNearestPlayer()
                if nearestPlayer and tick() - lastTeleportTime > teleportCooldown then
                    teleportBehind(nearestPlayer)
                    lastTeleportTime = tick()
                end
            end)
        else
            if teleportConnection then
                teleportConnection:Disconnect()
                teleportConnection = nil
            end
        end
    end
})

local hitboxLeft = Tabs.Hitbox:AddLeftGroupbox("Hitbox控制")
hitboxLeft:AddToggle("HitboxToggle", {
    Text = "开启Hitbox",
    Default = false,
    Callback = function(value)
        hitboxEnabled = value
        if not value then
            for _, plr in ipairs(Players:GetPlayers()) do
                restoredPart(plr)
            end
            hitbox_original_properties = {}
        else
            updateHitboxes()
        end
    end
})
hitboxLeft:AddSlider("HitboxSize", {
    Text = "Hitbox大小",
    Default = 21,
    Min = 1,
    Max = 25,
    Rounding = 0,
    Callback = function(value)
        hitboxSize = value
        if hitboxEnabled then
            updateHitboxes()
        end
    end
})
hitboxLeft:AddSlider("HitboxTransparency", {
    Text = "Hitbox透明度",
    Default = 6,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(value)
        hitboxTransparency = value
        if hitboxEnabled then
            updateHitboxes()
        end
    end
})
hitboxLeft:AddToggle("NoCollision", {
    Text = "无碰撞",
    Default = false,
    Callback = function(value)
        noCollisionEnabled = value
        if hitboxEnabled then
            updateHitboxes()
        end
    end
})

local SettingsGroup = Tabs.Settings:AddLeftGroupbox("脚本管理")
SettingsGroup:AddButton("卸载脚本", function()
    Library:Unload()
end)

if ThemeManager then
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("DuelTheme")
    ThemeManager:ApplyToTab(Tabs.Settings)
end
if SaveManager then
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetFolder("DuelConfig")
    SaveManager:BuildConfigSection(Tabs.Settings)
end

Library:OnUnload(function()
    if lightConnection then lightConnection:Disconnect() lightConnection = nil end
    if heavyConnection then heavyConnection:Disconnect() heavyConnection = nil end
    if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
    if teleportConnection then teleportConnection:Disconnect() teleportConnection = nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        restoredPart(plr)
    end
    hitboxEnabled = false
    noCollisionEnabled = false
end)

