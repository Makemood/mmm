-- Тип в Studio: LocalScript
-- Куда класть: StarterPlayer → StarterCharacterScripts → ChargeEffects
--
-- Эффекты экрана, когда сердце садится: темнота, размытие, красная виньетка.
-- Скрипт лежит в персонаже, поэтому при каждой смерти он создаётся заново
-- и сам убирает свои эффекты. Скорость бега здесь НЕ меняется — это делает сервер.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

local function killOld(name)
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = player:FindFirstChild("PlayerGui")
	local oldGui = gui and gui:FindFirstChild(name)
	if oldGui then
		oldGui:Destroy()
	end
end

killOld("ChargeBlur")
killOld("ChargeGrade")
killOld("ChargeVignette")

local blur = Instance.new("BlurEffect")
blur.Name = "ChargeBlur"
blur.Size = 0
blur.Parent = Lighting

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "ChargeGrade"
grade.Parent = Lighting

local vignetteGui = Instance.new("ScreenGui")
vignetteGui.Name = "ChargeVignette"
vignetteGui.ResetOnSpawn = false
vignetteGui.IgnoreGuiInset = true
vignetteGui.DisplayOrder = 2
vignetteGui.Parent = player:WaitForChild("PlayerGui")

local function edge(name, size, position, rotation, transparentAtEnd)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = vignetteGui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	if transparentAtEnd then
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.15),
		})
	end
	gradient.Parent = frame
	return frame
end

local edges = {
	edge("Top", UDim2.new(1, 0, 0.22, 0), UDim2.new(0, 0, 0, 0), 90, true),
	edge("Bottom", UDim2.new(1, 0, 0.28, 0), UDim2.new(0, 0, 0.72, 0), 90, false),
	edge("Left", UDim2.new(0.16, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0, true),
	edge("Right", UDim2.new(0.16, 0, 1, 0), UDim2.new(0.84, 0, 0, 0), 0, false),
}

local flash = Instance.new("Frame")
flash.Name = "DamageFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 5
flash.Parent = vignetteGui

local baseFov = 70
local camera = workspace.CurrentCamera
if camera then
	baseFov = camera.FieldOfView
end

local lastHealth = humanoid.Health
humanoid.HealthChanged:Connect(function(health)
	if health < lastHealth then
		flash.BackgroundTransparency = 0.55
	end
	lastHealth = health
end)

local heartbeatSound = nil
if type(Config.Sounds.Heartbeat) == "string" and Config.Sounds.Heartbeat ~= "" then
	heartbeatSound = Instance.new("Sound")
	heartbeatSound.Name = "Heartbeat"
	heartbeatSound.SoundId = Config.Sounds.Heartbeat
	heartbeatSound.Looped = true
	heartbeatSound.Volume = 0
	heartbeatSound.Parent = character:FindFirstChild("Head") or character
	heartbeatSound:Play()
end

local function severityOf(charge)
	if charge >= Config.Charge.LowThreshold then
		return 0
	end
	return math.clamp((Config.Charge.LowThreshold - charge) / Config.Charge.LowThreshold, 0, 1)
end

local cleaned = false
local connection = RunService.RenderStepped:Connect(function(dt)
	local charge = player:GetAttribute("Charge")
	if type(charge) ~= "number" then
		charge = Config.Charge.Max
	end
	local severity = severityOf(charge)
	local pulseSpeed = 2 + severity * 8
	local pulse = math.sin(os.clock() * pulseSpeed) * 0.5 + 0.5

	blur.Size = severity * (10 + pulse * 6)
	grade.Brightness = -0.42 * severity
	grade.Saturation = -0.55 * severity
	grade.Contrast = 0.08 * severity
	grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 150, 150), severity)

	local edgeVisible = severity * (0.35 + pulse * 0.45)
	for _, frame in ipairs(edges) do
		frame.BackgroundTransparency = 1 - edgeVisible
		frame.BackgroundColor3 = Color3.fromRGB(20, 0, 0):Lerp(Color3.fromRGB(120, 0, 20), severity)
	end

	if flash.BackgroundTransparency < 1 then
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 2.2)
	end

	local cam = workspace.CurrentCamera
	if cam then
		local boost = 0
		if charge >= Config.Charge.HighThreshold then
			local span = math.max(1, Config.Charge.Max - Config.Charge.HighThreshold)
			boost = 8 * math.clamp((charge - Config.Charge.HighThreshold) / span, 0, 1)
		end
		cam.FieldOfView = baseFov + boost
	end

	if heartbeatSound then
		heartbeatSound.Volume = severity * 0.8
		heartbeatSound.PlaybackSpeed = 0.8 + severity * 0.7
	end
end)

local function cleanup()
	if cleaned then
		return
	end
	cleaned = true
	if connection then
		connection:Disconnect()
	end
	if blur then
		blur:Destroy()
	end
	if grade then
		grade:Destroy()
	end
	if vignetteGui then
		vignetteGui:Destroy()
	end
	if heartbeatSound then
		heartbeatSound:Destroy()
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = baseFov
	end
end

script.Destroying:Connect(cleanup)
humanoid.Died:Connect(function()
	task.delay(0.2, cleanup)
end)
