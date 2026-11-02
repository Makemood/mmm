-- Тип в Studio: ModuleScript
-- Куда класть: ServerScriptService → WeaponService
--
-- Клиент говорит только «куда целился».
-- Попал или нет, решает сервер лучом (raycast) от головы персонажа.
-- Так нельзя нарисовать себе попадание через стену: стена стоит на сервере.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ChargeService = require(script.Parent:WaitForChild("ChargeService"))

local WeaponService = {}

local lastShot = {}
local lastWarn = {}

local function effectsFolder()
	local folder = workspace:FindFirstChild("Effects")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Effects"
		folder.Parent = workspace
	end
	return folder
end

local function playOptionalSound(id, parent)
	if type(id) ~= "string" or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.45
	sound.RollOffMaxDistance = 120
	sound.Parent = parent
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function createTool()
	local tool = Instance.new("Tool")
	tool.Name = Config.Weapon.ToolName
	tool.ToolTip = "Стреляет от сердца. Каждый выстрел тратит немного заряда."
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	-- Если пушка в руке криво повёрнута — крути эти градусы.
	tool.Grip = CFrame.new(0.1, -0.2, -0.35) * CFrame.Angles(math.rad(-90), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.45, 1.7)
	handle.Color = Color3.fromRGB(28, 30, 36)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(0.12, 0.12, 1.15)
	stripe.Color = Config.Weapon.TracerColor
	stripe.Material = Enum.Material.Neon
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.Massless = true
	stripe.CastShadow = false
	stripe.CFrame = handle.CFrame * CFrame.new(0, 0.24, -0.15)
	stripe.Parent = tool

	local stripeWeld = Instance.new("Weld")
	stripeWeld.Part0 = handle
	stripeWeld.Part1 = stripe
	stripeWeld.C0 = CFrame.new(0, 0.24, -0.15)
	stripeWeld.Parent = stripe

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.1, -0.9)
	muzzle.Parent = handle

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "MuzzleSparks"
	sparks.Texture = Config.Assets.SparkTexture
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Enabled = false
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.05, 0.12)
	sparks.Speed = NumberRange.new(8, 16)
	sparks.SpreadAngle = Vector2.new(18, 18)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Color = ColorSequence.new(Config.Weapon.TracerColor)
	sparks.Parent = handle

	return tool
end

local function findHumanoid(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return humanoid
			end
		end
		current = current.Parent
	end
	return nil
end

local function muzzleWorldPosition(tool, fallback)
	local handle = tool and tool:FindFirstChild("Handle")
	local attachment = handle and handle:FindFirstChild("Muzzle")
	if attachment then
		return attachment.WorldPosition, handle
	end
	return fallback, handle
end

local function makeTracer(fromPos, toPos)
	local delta = toPos - fromPos
	local distance = delta.Magnitude
	if distance < 0.2 then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Config.Weapon.TracerColor
	tracer.Size = Vector3.new(0.12, 0.12, distance)
	tracer.CFrame = CFrame.new(fromPos, toPos) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = effectsFolder()
	Debris:AddItem(tracer, 0.07)
end

local function makeSparks(position, color)
	local anchor = Instance.new("Part")
	anchor.Name = "HitSpark"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Position = position
	anchor.Parent = effectsFolder()

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Config.Assets.SparkTexture
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Enabled = true
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.12, 0.3)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = anchor
	emitter:Emit(16)
	Debris:AddItem(anchor, 0.5)
end

local function warnOnce(player, text)
	local now = os.clock()
	if now - (lastWarn[player] or 0) < 1.8 then
		return
	end
	lastWarn[player] = now
	ChargeService.notify(player, text)
end

local function onFire(player, direction)
	if typeof(direction) ~= "Vector3" then
		return
	end
	if direction.X ~= direction.X or direction.Y ~= direction.Y or direction.Z ~= direction.Z then
		return
	end
	local magnitude = direction.Magnitude
	if magnitude < 0.01 or magnitude > 5 then
		return
	end
	direction = direction.Unit

	local now = os.clock()
	if now - (lastShot[player] or 0) < Config.Weapon.FireCooldown then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local tool = character:FindFirstChild(Config.Weapon.ToolName)
	if not tool or not tool:IsA("Tool") then
		return
	end

	if ChargeService.getCharge(player) < Config.Weapon.MinChargeToFire then
		warnOnce(player, "Слишком мало заряда для выстрела")
		return
	end

	lastShot[player] = now
	ChargeService.addCharge(player, -Config.Weapon.ChargeCost)

	local head = character:FindFirstChild("Head") or root
	local origin = head.Position
	local muzzlePos, handle = muzzleWorldPosition(tool, origin)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { character }
	local effects = workspace:FindFirstChild("Effects")
	local pickups = workspace:FindFirstChild("Pickups")
	if effects then
		table.insert(exclude, effects)
	end
	if pickups then
		table.insert(exclude, pickups)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction * Config.Weapon.Range, params)
	local hitPos = result and result.Position or (origin + direction * Config.Weapon.Range)
	makeTracer(muzzlePos, hitPos)

	if handle then
		local flash = Instance.new("PointLight")
		flash.Color = Config.Weapon.TracerColor
		flash.Brightness = 8
		flash.Range = 12
		flash.Shadows = false
		flash.Parent = handle
		Debris:AddItem(flash, 0.05)
		local muzzleSparks = handle:FindFirstChild("MuzzleSparks")
		if muzzleSparks and muzzleSparks:IsA("ParticleEmitter") then
			muzzleSparks:Emit(8)
		end
		playOptionalSound(Config.Sounds.Shot, handle)
	end

	if not result then
		return
	end

	local victim = findHumanoid(result.Instance)
	local sparkColor = Config.Weapon.HitColor
	if victim and victim.Health > 0 and victim.Parent ~= character then
		sparkColor = Config.Weapon.FleshColor
		local damage = Config.Weapon.Damage
		if result.Instance.Name == "Head" then
			damage = damage * Config.Weapon.HeadshotMultiplier
		end
		local healthBefore = victim.Health
		victim:TakeDamage(damage)
		if healthBefore > 0 and victim.Health <= 0 then
			local victimPlayer = Players:GetPlayerFromCharacter(victim.Parent)
			local isEnemy = victim.Parent:GetAttribute("IsEnemy") == true
			if victimPlayer ~= player and (victimPlayer or isEnemy) then
				ChargeService.addCharge(player, Config.Charge.KillReward)
				ChargeService.notify(player, "Убийство: +" .. tostring(Config.Charge.KillReward) .. " к заряду")
			end
		end
	end
	makeSparks(result.Position, sparkColor)
end

local function equipLater(player, character, template)
	task.spawn(function()
		if not character or not character.Parent then
			return
		end
		-- StarterPack сам кладёт копию в рюкзак в момент появления.
		-- Ждём её и только потом делаем запасную, иначе пушек будет две.
		if character:FindFirstChild(Config.Weapon.ToolName) then
			return
		end
		local backpack = player:WaitForChild("Backpack", 8)
		if not backpack or not character.Parent then
			return
		end
		local tool = backpack:FindFirstChild(Config.Weapon.ToolName)
		if not tool then
			tool = backpack:WaitForChild(Config.Weapon.ToolName, 4)
		end
		if not tool and not character:FindFirstChild(Config.Weapon.ToolName) then
			tool = template:Clone()
			tool.Parent = backpack
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if tool and humanoid and humanoid.Health > 0 and tool.Parent == backpack then
			pcall(function()
				humanoid:EquipTool(tool)
			end)
		end
	end)
end

function WeaponService.start(fireRemote)
	local existing = StarterPack:FindFirstChild(Config.Weapon.ToolName)
	if existing then
		existing:Destroy()
	end
	local template = createTool()
	template.Parent = StarterPack

	fireRemote.OnServerEvent:Connect(onFire)

	local function hook(player)
		player.CharacterAdded:Connect(function(character)
			equipLater(player, character, template)
		end)
		if player.Character then
			equipLater(player, player.Character, template)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
		lastWarn[player] = nil
	end)
end

return WeaponService
