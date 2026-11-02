-- Тип в Studio: LocalScript
-- Куда класть: StarterGui → ChargeHUD
--
-- Рисует полоску заряда. Сам заряд НЕ меняет — только читает
-- атрибут Charge, который выставляет сервер.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("ChargeHUD") then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "ChargeHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function textConstraint(parent, maxSize)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.MinTextSize = 10
	c.Parent = parent
	return c
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
panel.BackgroundTransparency = 0.22
panel.BorderSizePixel = 0
panel.Position = UDim2.new(0.02, 0, 0.03, 0)
panel.Size = UDim2.new(0.3, 0, 0, 132)
panel.Parent = gui
corner(panel, 12)
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MinSize = Vector2.new(250, 132)
sizeLimit.MaxSize = Vector2.new(420, 132)
sizeLimit.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Config.Colors.Cyan
stroke.Thickness = 1.5
stroke.Transparency = 0.35
stroke.Parent = panel

local icon = Instance.new("TextLabel")
icon.Name = "Icon"
icon.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
icon.BorderSizePixel = 0
icon.Position = UDim2.new(0, 10, 0, 10)
icon.Size = UDim2.fromOffset(52, 52)
icon.Font = Enum.Font.BuilderSansExtraBold
icon.Text = "❤"
icon.TextColor3 = Color3.fromRGB(255, 70, 100)
icon.TextScaled = true
icon.Parent = panel
corner(icon, 10)
textConstraint(icon, 32)
local iconScale = Instance.new("UIScale")
iconScale.Parent = icon

local bolt = Instance.new("TextLabel")
bolt.BackgroundTransparency = 1
bolt.AnchorPoint = Vector2.new(1, 1)
bolt.Position = UDim2.new(1, 2, 1, 4)
bolt.Size = UDim2.fromOffset(22, 22)
bolt.Font = Enum.Font.BuilderSansExtraBold
bolt.Text = "⚡"
bolt.TextColor3 = Color3.fromRGB(255, 230, 80)
bolt.TextScaled = true
bolt.Parent = icon

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 72, 0, 8)
title.Size = UDim2.new(1, -150, 0, 22)
title.Font = Enum.Font.BuilderSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "ЗАРЯД СЕРДЦА"
title.TextColor3 = Color3.fromRGB(230, 236, 245)
title.TextScaled = true
title.Parent = panel
textConstraint(title, 18)

local percent = Instance.new("TextLabel")
percent.BackgroundTransparency = 1
percent.AnchorPoint = Vector2.new(1, 0)
percent.Position = UDim2.new(1, -12, 0, 6)
percent.Size = UDim2.fromOffset(70, 26)
percent.Font = Enum.Font.BuilderSansExtraBold
percent.TextXAlignment = Enum.TextXAlignment.Right
percent.Text = "70%"
percent.TextColor3 = Config.chargeColor(70)
percent.TextScaled = true
percent.Parent = panel
textConstraint(percent, 22)

local barBack = Instance.new("Frame")
barBack.Name = "ChargeBack"
barBack.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
barBack.BorderSizePixel = 0
barBack.Position = UDim2.new(0, 72, 0, 36)
barBack.Size = UDim2.new(1, -86, 0, 18)
barBack.ClipsDescendants = true
barBack.Parent = panel
corner(barBack, 8)

local barFill = Instance.new("Frame")
barFill.Name = "ChargeFill"
barFill.BackgroundColor3 = Config.chargeColor(70)
barFill.BorderSizePixel = 0
barFill.Size = UDim2.new(0.7, 0, 1, 0)
barFill.Parent = barBack
corner(barFill, 8)

local hpLabel = Instance.new("TextLabel")
hpLabel.BackgroundTransparency = 1
hpLabel.Position = UDim2.new(0, 72, 0, 58)
hpLabel.Size = UDim2.new(1, -86, 0, 14)
hpLabel.Font = Enum.Font.BuilderSans
hpLabel.TextXAlignment = Enum.TextXAlignment.Left
hpLabel.Text = "ЗДОРОВЬЕ"
hpLabel.TextColor3 = Color3.fromRGB(180, 186, 198)
hpLabel.TextScaled = true
hpLabel.Parent = panel
textConstraint(hpLabel, 12)

local hpBack = Instance.new("Frame")
hpBack.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
hpBack.BorderSizePixel = 0
hpBack.Position = UDim2.new(0, 72, 0, 74)
hpBack.Size = UDim2.new(1, -86, 0, 8)
hpBack.ClipsDescendants = true
hpBack.Parent = panel
corner(hpBack, 4)

local hpFill = Instance.new("Frame")
hpFill.BackgroundColor3 = Color3.fromRGB(255, 80, 90)
hpFill.BorderSizePixel = 0
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.Parent = hpBack
corner(hpFill, 4)

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 72, 0, 88)
status.Size = UDim2.new(1, -86, 0, 18)
status.Font = Enum.Font.BuilderSansBold
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "стабильно"
status.TextColor3 = Color3.fromRGB(190, 255, 210)
status.TextScaled = true
status.Parent = panel
textConstraint(status, 16)

local notice = Instance.new("TextLabel")
notice.BackgroundTransparency = 1
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0.22, 0)
notice.Size = UDim2.new(0.6, 0, 0, 28)
notice.Font = Enum.Font.BuilderSansBold
notice.Text = ""
notice.TextColor3 = Color3.fromRGB(255, 236, 170)
notice.TextStrokeTransparency = 0.5
notice.TextScaled = true
notice.Parent = gui
textConstraint(notice, 22)

local warning = Instance.new("TextLabel")
warning.BackgroundTransparency = 1
warning.AnchorPoint = Vector2.new(0.5, 0.5)
warning.Position = UDim2.new(0.5, 0, 0.38, 0)
warning.Size = UDim2.new(0.7, 0, 0, 48)
warning.Font = Enum.Font.BuilderSansExtraBold
warning.Text = ""
warning.TextColor3 = Color3.fromRGB(255, 70, 70)
warning.TextStrokeColor3 = Color3.fromRGB(40, 0, 0)
warning.TextStrokeTransparency = 0.4
warning.TextScaled = true
warning.Parent = gui
textConstraint(warning, 36)

local hint = Instance.new("TextLabel")
hint.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
hint.BackgroundTransparency = 0.35
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 0.96, 0)
hint.Size = UDim2.new(0.72, 0, 0, 52)
hint.Font = Enum.Font.BuilderSans
hint.TextWrapped = true
hint.Text = "Сердце — батарея. ЛКМ стреляет, E у синего щитка заряжает. Бег и прыжки чуть помогают. Ноль — смерть. Жёлтый столб — батарея с бандита."
hint.TextColor3 = Color3.fromRGB(230, 236, 245)
hint.TextScaled = true
hint.Parent = gui
corner(hint, 10)
textConstraint(hint, 18)

local shownCharge = player:GetAttribute("Charge") or Config.Charge.Start
local hintEndsAt = os.clock() + 14
local humanoid = nil

local function bindCharacter(character)
	humanoid = character:WaitForChild("Humanoid", 10)
end

player.CharacterAdded:Connect(function(character)
	task.spawn(bindCharacter, character)
end)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end

local function statusFor(charge)
	if charge <= Config.Charge.CriticalThreshold then
		return "СЕРДЦЕ ОСТАНАВЛИВАЕТСЯ", Color3.fromRGB(255, 70, 70)
	elseif charge <= Config.Charge.LowThreshold then
		return "МАЛО ЭНЕРГИИ", Color3.fromRGB(255, 170, 60)
	elseif charge >= Config.Charge.HighThreshold then
		return "АДРЕНАЛИН", Color3.fromRGB(120, 255, 170)
	end
	return "стабильно", Color3.fromRGB(190, 220, 255)
end

RunService.RenderStepped:Connect(function(dt)
	local target = player:GetAttribute("Charge")
	if type(target) ~= "number" then
		target = 0
	end
	shownCharge += (target - shownCharge) * math.min(1, dt * 8)
	local color = Config.chargeColor(shownCharge)
	local alpha = math.clamp(shownCharge / Config.Charge.Max, 0, 1)
	barFill.Size = UDim2.new(alpha, 0, 1, 0)
	barFill.BackgroundColor3 = color
	percent.Text = tostring(math.floor(shownCharge + 0.5)) .. "%"
	percent.TextColor3 = color
	stroke.Color = color

	local statusText, statusColor = statusFor(target)
	status.Text = statusText
	status.TextColor3 = statusColor

	local pulseSpeed = 3
	if target <= Config.Charge.CriticalThreshold then
		pulseSpeed = 9
	elseif target <= Config.Charge.LowThreshold then
		pulseSpeed = 5
	end
	local beat = 1
	if target <= Config.Charge.LowThreshold then
		beat = 1 + (math.sin(os.clock() * pulseSpeed) * 0.5 + 0.5) * 0.18
	end
	iconScale.Scale = beat
	icon.TextColor3 = color:Lerp(Color3.fromRGB(255, 60, 80), 0.35)

	if target <= Config.Charge.LowThreshold then
		warning.Text = (target <= Config.Charge.CriticalThreshold) and "СЕРДЦЕ ОСТАНАВЛИВАЕТСЯ" or "МАЛО ЭНЕРГИИ"
		warning.TextTransparency = 0.15 + (math.sin(os.clock() * pulseSpeed) * 0.5 + 0.5) * 0.55
	else
		warning.Text = ""
	end

	notice.Text = player:GetAttribute("StatusText") or ""

	if humanoid and humanoid.Parent and humanoid.MaxHealth > 0 then
		hpFill.Size = UDim2.new(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 0, 1, 0)
	end

	local hintLeft = hintEndsAt - os.clock()
	if hintLeft > 2 then
		hint.TextTransparency = 0
		hint.BackgroundTransparency = 0.35
	elseif hintLeft > 0 then
		local fade = 1 - hintLeft / 2
		hint.TextTransparency = fade
		hint.BackgroundTransparency = 0.35 + fade * 0.65
	else
		hint.TextTransparency = 1
		hint.BackgroundTransparency = 1
	end
end)

print("[Адреналин] Интерфейс заряда готов")
