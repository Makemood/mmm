-- Тип в Studio: ModuleScript
-- Куда класть: ServerScriptService → ChargeService
--
-- Сервер хранит заряд сердца и сам его уменьшает.
-- Клиент только рисует полоску. Если игрок подменит число у себя на компьютере,
-- сервер этого не спросит — поэтому чит «поставить 100» здесь не работает.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local ChargeService = {}

local spawnToken = {}
local charging = {}

local function leaderstat(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return nil
	end
	return stats:FindFirstChild("Заряд")
end

local function applySpeed(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local charge = player:GetAttribute("Charge") or 0
	local speed = Config.Charge.BaseWalkSpeed
	if charge >= Config.Charge.HighThreshold then
		speed = speed + Config.Charge.SpeedBonus
	elseif charge <= Config.Charge.LowThreshold then
		speed = speed - Config.Charge.LowSpeedPenalty
	end
	humanoid.WalkSpeed = speed
end

local function killFromHeart(player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	-- Прямая запись Health, а не TakeDamage: щит появления
	-- блокирует урон от бандитов, но остановившееся сердце — нет.
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function writeCharge(player, value)
	local clamped = math.clamp(value, 0, Config.Charge.Max)
	player:SetAttribute("Charge", clamped)
	local stat = leaderstat(player)
	if stat then
		stat.Value = math.floor(clamped + 0.5)
	end
	applySpeed(player)
	if clamped <= 0 then
		killFromHeart(player)
	end
	if Config.Debug then
		print("[Адреналин] Заряд", player.Name, clamped)
	end
	return clamped
end

function ChargeService.getCharge(player)
	local current = player:GetAttribute("Charge")
	if type(current) ~= "number" then
		return 0
	end
	return current
end

function ChargeService.addCharge(player, delta)
	if not player or not player:IsA("Player") then
		return 0
	end
	local current = ChargeService.getCharge(player)
	return writeCharge(player, current + delta)
end

function ChargeService.notify(player, text)
	if not player or not player.Parent then
		return
	end
	local seq = (player:GetAttribute("StatusSeq") or 0) + 1
	player:SetAttribute("StatusSeq", seq)
	player:SetAttribute("StatusText", text)
	task.delay(2.4, function()
		if player.Parent and player:GetAttribute("StatusSeq") == seq then
			player:SetAttribute("StatusText", "")
		end
	end)
end

local function playOptionalSound(id, parent)
	if type(id) ~= "string" or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.6
	sound.Parent = parent
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function ensureBoxVisuals(box)
	local glow = box:FindFirstChild("Glow")
	if not glow then
		glow = Instance.new("PointLight")
		glow.Name = "Glow"
		glow.Color = Config.Colors.Cyan
		glow.Brightness = 2.4
		glow.Range = 18
		glow.Shadows = false
		glow.Parent = box
	end

	local sparks = box:FindFirstChild("Sparks")
	if not sparks then
		sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Texture = Config.Assets.SparkTexture
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Rate = 4
		sparks.Lifetime = NumberRange.new(0.25, 0.55)
		sparks.Speed = NumberRange.new(1, 4)
		sparks.SpreadAngle = Vector2.new(40, 40)
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Color = ColorSequence.new(Config.Colors.Cyan)
		sparks.Parent = box
	end

	local prompt = box:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = box
	end
	prompt.ObjectText = "Электрощиток"
	prompt.ActionText = "Зарядить сердце"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = Config.ElectricBox.Duration + 0.4
	prompt.MaxActivationDistance = 9
	prompt.MaxIndicatorDistance = 16
	prompt.RequiresLineOfSight = false

	return glow, sparks, prompt
end

local function setCoolingLook(box, glow, cooling)
	local screen = box:FindFirstChild("Screen")
	if cooling then
		glow.Color = Color3.fromRGB(255, 150, 60)
		glow.Brightness = 0.7
		if screen and screen:IsA("BasePart") then
			screen.Color = Color3.fromRGB(255, 140, 50)
		end
	else
		glow.Color = Config.Colors.Cyan
		glow.Brightness = 2.4
		if screen and screen:IsA("BasePart") then
			screen.Color = Config.Colors.Cyan
		end
	end
end

local function hookBox(box)
	if box:GetAttribute("ChargeHooked") then
		return
	end
	box:SetAttribute("ChargeHooked", true)
	box:SetAttribute("IsElectricBox", true)

	local glow, sparks, prompt = ensureBoxVisuals(box)
	local busyPlayer = nil
	local cooling = false

	prompt.PromptButtonHoldBegan:Connect(function(player)
		if cooling then
			ChargeService.notify(player, "Щиток остывает")
			return
		end
		if busyPlayer or charging[player] then
			ChargeService.notify(player, "Щиток занят")
			return
		end

		busyPlayer = player
		charging[player] = true
		sparks.Enabled = true
		sparks.Rate = 36
		ChargeService.notify(player, "Зарядка сердца...")
		playOptionalSound(Config.Sounds.Recharge, box)

		task.spawn(function()
			local elapsed = 0
			local step = 0.2
			local total = Config.ElectricBox.Duration
			local amount = Config.ElectricBox.ChargeAmount
			local completed = false

			while busyPlayer == player and elapsed < total do
				task.wait(step)
				if busyPlayer ~= player then
					break
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if not root or not humanoid or humanoid.Health <= 0 then
					break
				end
				if (root.Position - box.Position).Magnitude > Config.ElectricBox.MaxDistance then
					ChargeService.notify(player, "Ты отошёл от щитка")
					break
				end
				elapsed += step
				ChargeService.addCharge(player, amount * (step / total))
				if elapsed >= total - 0.01 then
					completed = true
					break
				end
			end

			sparks.Rate = 4
			sparks.Enabled = true
			if charging[player] then
				charging[player] = nil
			end
			if busyPlayer == player then
				busyPlayer = nil
			end

			if elapsed >= 0.4 then
				cooling = true
				prompt.Enabled = false
				setCoolingLook(box, glow, true)
				sparks.Enabled = false
				if completed then
					box:SetAttribute("NoiseUntil", os.clock() + Config.ElectricBox.NoiseDuration)
					ChargeService.notify(player, "Сердце заряжено. Шум зовёт бандитов!")
				end
				task.delay(Config.ElectricBox.Cooldown, function()
					cooling = false
					prompt.Enabled = true
					setCoolingLook(box, glow, false)
					sparks.Enabled = true
					sparks.Rate = 4
				end)
			end
		end)
	end)

	prompt.PromptButtonHoldEnded:Connect(function(player)
		if busyPlayer == player then
			busyPlayer = nil
		end
	end)
end

local function considerBox(inst)
	if inst:IsA("BasePart") and (inst.Name == "ElectricBox" or inst:GetAttribute("IsElectricBox")) then
		hookBox(inst)
	end
end

local function onCharacter(player, character)
	spawnToken[player] = (spawnToken[player] or 0) + 1
	local token = spawnToken[player]

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or spawnToken[player] ~= token then
		return
	end

	-- Обычная смерть не лечит сердце до полного. Только не даём
	-- появиться с нулём: иначе персонаж умер бы в ту же секунду.
	local current = player:GetAttribute("Charge")
	if type(current) ~= "number" or current < Config.Charge.RespawnFloor then
		writeCharge(player, Config.Charge.RespawnFloor)
	else
		applySpeed(player)
	end

	local lastJump = 0
	humanoid.StateChanged:Connect(function(_, newState)
		if newState ~= Enum.HumanoidStateType.Jumping then
			return
		end
		local now = os.clock()
		if now - lastJump < 0.35 then
			return
		end
		lastJump = now
		ChargeService.addCharge(player, Config.Charge.JumpRegen)
	end)

	task.spawn(function()
		local step = Config.Charge.TickInterval
		while spawnToken[player] == token and character.Parent and humanoid.Health > 0 do
			task.wait(step)
			if spawnToken[player] ~= token or humanoid.Health <= 0 then
				break
			end
			local delta = -Config.Charge.DrainPerSecond * step
			if humanoid.MoveDirection.Magnitude > 0.1 then
				delta += Config.Charge.MoveRegenPerSecond * step
			end
			ChargeService.addCharge(player, delta)
		end
	end)
end

local function hookPlayer(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	if not stats:FindFirstChild("Заряд") then
		local value = Instance.new("IntValue")
		value.Name = "Заряд"
		value.Parent = stats
	end

	if type(player:GetAttribute("Charge")) ~= "number" then
		writeCharge(player, Config.Charge.Start)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function ChargeService.start()
	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		spawnToken[player] = nil
		charging[player] = nil
	end)

	for _, inst in ipairs(workspace:GetDescendants()) do
		considerBox(inst)
	end
	workspace.DescendantAdded:Connect(considerBox)
end

return ChargeService
