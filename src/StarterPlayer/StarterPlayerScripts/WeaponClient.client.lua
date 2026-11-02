-- Тип в Studio: LocalScript
-- Куда класть: StarterPlayer → StarterPlayerScripts → WeaponClient
--
-- Этот скрипт только читает мышь и говорит серверу направление.
-- Он лежит в StarterPlayerScripts, а не в персонаже: пушка выдаётся
-- в рюкзак заново после смерти, а скрипт должен жить всё это время.
-- Попадания считает сервер (WeaponService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fireRemote = remotes:WaitForChild("FireWeapon")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local shooting = false

local gui = Instance.new("ScreenGui")
gui.Name = "Crosshair"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(xScale, yScale, xPx, yPx)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, xPx, 0.5, yPx)
	frame.Size = UDim2.fromOffset(xScale, yScale)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui
	return frame
end

local bars = {
	bar(2, 10, 0, -10),
	bar(2, 10, 0, 10),
	bar(10, 2, -10, 0),
	bar(10, 2, 10, 0),
}
local dot = bar(3, 3, 0, 0)

local function toolEquipped()
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChild(Config.Weapon.ToolName)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		shooting = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		shooting = false
	end
end)

task.spawn(function()
	while true do
		local tool = toolEquipped()
		if shooting and tool then
			local character = tool.Parent
			local head = character:FindFirstChild("Head")
			local root = character:FindFirstChild("HumanoidRootPart")
			local origin = (head and head.Position) or (root and root.Position)
			if origin and mouse.Hit then
				local direction = mouse.Hit.Position - origin
				if direction.Magnitude > 0.2 then
					fireRemote:FireServer(direction.Unit)
				end
			end
			task.wait(Config.Weapon.FireCooldown)
		else
			task.wait(0.05)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local equipped = toolEquipped() ~= nil
	local charge = player:GetAttribute("Charge")
	if type(charge) ~= "number" then
		charge = Config.Charge.Max
	end
	local color = Config.chargeColor(charge)
	for _, frame in ipairs(bars) do
		frame.Visible = equipped
		frame.BackgroundColor3 = color
	end
	dot.Visible = equipped
	dot.BackgroundColor3 = color
end)

print("[Адреналин] Прицел готов. ЛКМ — стрелять.")
