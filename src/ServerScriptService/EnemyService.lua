-- Тип в Studio: ModuleScript
-- Куда класть: ServerScriptService → EnemyService
--
-- Бандит — это Model с Humanoid. Сервер сам ведёт его к игроку
-- через PathfindingService (поиск пути вокруг домов) и сам наносит урон.
-- Клиент не решает, попал бандит или нет.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ChargeService = require(script.Parent:WaitForChild("ChargeService"))

local EnemyService = {}

local HIP_HEIGHT = 3.1

local function pickupsFolder()
	local folder = workspace:FindFirstChild("Pickups")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Pickups"
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
	sound.Volume = 0.7
	sound.Parent = parent
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function motorPart(model, rootPart, name, size, color, material, c0, c1)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model

	local motor = Instance.new("Motor6D")
	motor.Name = name .. "Motor"
	motor.Part0 = rootPart
	motor.Part1 = part
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = rootPart
	return part, motor
end

local function createGangster(position, rng)
	local model = Instance.new("Model")
	model.Name = "Бандит"
	model:SetAttribute("IsEnemy", true)

	local suits = {
		Color3.fromRGB(24, 24, 28),
		Color3.fromRGB(62, 18, 26),
		Color3.fromRGB(28, 18, 48),
		Color3.fromRGB(18, 32, 40),
	}
	local skins = {
		Color3.fromRGB(214, 176, 146),
		Color3.fromRGB(168, 124, 96),
		Color3.fromRGB(112, 78, 58),
		Color3.fromRGB(232, 206, 186),
	}
	local visors = {
		Config.Colors.Magenta,
		Config.Colors.Cyan,
		Color3.fromRGB(255, 60, 60),
	}
	local suit = suits[rng:NextInteger(1, #suits)]
	local skin = skins[rng:NextInteger(1, #skins)]
	local visorColor = visors[rng:NextInteger(1, #visors)]

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2.2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.AutomaticScalingEnabled = false
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.MaxHealth = Config.Enemy.Health
	humanoid.Health = Config.Enemy.Health
	humanoid.WalkSpeed = Config.Enemy.WalkSpeed
	humanoid.JumpPower = 50
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	-- Имена частей как у классического R6: так Humanoid не пытается пересобрать модель.
	motorPart(model, root, "Torso", Vector3.new(2, 2.2, 1), suit, Enum.Material.SmoothPlastic, CFrame.new(), CFrame.new())
	local head = motorPart(model, root, "Head", Vector3.new(1.3, 1.3, 1.3), skin, Enum.Material.SmoothPlastic, CFrame.new(0, 1.1, 0), CFrame.new(0, -0.65, 0))
	local _leftArm, leftShoulder = motorPart(model, root, "Left Arm", Vector3.new(0.75, 1.8, 0.75), suit, Enum.Material.SmoothPlastic, CFrame.new(-1.35, 0.9, 0), CFrame.new(0, 0.9, 0))
	local _rightArm, rightShoulder = motorPart(model, root, "Right Arm", Vector3.new(0.75, 1.8, 0.75), suit, Enum.Material.SmoothPlastic, CFrame.new(1.35, 0.9, 0), CFrame.new(0, 0.9, 0))
	local _leftLeg, leftHip = motorPart(model, root, "Left Leg", Vector3.new(0.85, 2, 0.85), Color3.fromRGB(16, 16, 18), Enum.Material.SmoothPlastic, CFrame.new(-0.48, -1.1, 0), CFrame.new(0, 1, 0))
	local _rightLeg, rightHip = motorPart(model, root, "Right Leg", Vector3.new(0.85, 2, 0.85), Color3.fromRGB(16, 16, 18), Enum.Material.SmoothPlastic, CFrame.new(0.48, -1.1, 0), CFrame.new(0, 1, 0))

	local stripe = motorPart(model, root, "Stripe", Vector3.new(1.4, 0.28, 1.05), visorColor, Enum.Material.Neon, CFrame.new(0, 0.15, -0.05), CFrame.new())
	stripe.CanQuery = false
	stripe.CastShadow = false

	local visor = motorPart(model, head, "Visor", Vector3.new(1.25, 0.28, 0.18), visorColor, Enum.Material.Neon, CFrame.new(0, 0.05, -0.68), CFrame.new())
	visor.CanQuery = false
	visor.CastShadow = false
	local eye = Instance.new("PointLight")
	eye.Color = visorColor
	eye.Brightness = 1
	eye.Range = 8
	eye.Shadows = false
	eye.Parent = visor

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 48)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.MaxDistance = 110
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.48, 0)
	nameLabel.Font = Enum.Font.BuilderSansBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 90, 100)
	nameLabel.Text = "БАНДИТ"
	nameLabel.Parent = billboard

	local hpBack = Instance.new("Frame")
	hpBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	hpBack.BorderSizePixel = 0
	hpBack.Position = UDim2.new(0.1, 0, 0.58, 0)
	hpBack.Size = UDim2.new(0.8, 0, 0.28, 0)
	hpBack.Parent = billboard
	local hpFill = Instance.new("Frame")
	hpFill.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	hpFill.BorderSizePixel = 0
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.Parent = hpBack
	humanoid.HealthChanged:Connect(function(health)
		hpFill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
	end)

	model.PrimaryPart = root
	model:PivotTo(CFrame.new(position))
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		enemies = Instance.new("Folder")
		enemies.Name = "Enemies"
		enemies.Parent = workspace
	end
	model.Parent = enemies

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	task.defer(function()
		if root.Parent then
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
		end
	end)

	return model, humanoid, root, {
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		leftHip = leftHip,
		rightHip = rightHip,
	}
end

local function spawnBattery(position)
	local model = Instance.new("Model")
	model.Name = "Battery"

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(1.5, 2.2, 1.5)
	core.Color = Config.Colors.Battery
	core.Material = Enum.Material.Neon
	core.Anchored = true
	core.CanCollide = false
	core.CanTouch = true
	core.Position = position + Vector3.new(0, 2.2, 0)
	core.Parent = model

	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Size = Vector3.new(0.35, 36, 0.35)
	beacon.Color = Config.Colors.Battery
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.5
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon.Position = position + Vector3.new(0, 20, 0)
	beacon.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Config.Colors.Battery
	light.Brightness = 3
	light.Range = 18
	light.Shadows = false
	light.Parent = core

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = Config.Assets.SparkTexture
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Rate = 14
	sparks.Lifetime = NumberRange.new(0.3, 0.7)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Color = ColorSequence.new(Config.Colors.Battery)
	sparks.Parent = core

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Батарея"
	prompt.ActionText = "Подобрать"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	local taken = false
	local function pickup(player)
		if taken or not player or not player:IsA("Player") then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		taken = true
		ChargeService.addCharge(player, Config.Battery.Charge)
		ChargeService.notify(player, "Батарея: +" .. tostring(Config.Battery.Charge) .. " к заряду")
		playOptionalSound(Config.Sounds.Pickup, core)
		model:Destroy()
	end

	prompt.Triggered:Connect(pickup)
	core.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			pickup(player)
		end
	end)

	model.Parent = pickupsFolder()
	local base = core.Position
	task.spawn(function()
		local started = os.clock()
		while model.Parent do
			local t = os.clock() - started
			core.CFrame = CFrame.new(base + Vector3.new(0, math.sin(t * 2) * 0.35, 0)) * CFrame.Angles(0, t * 1.4, 0)
			task.wait(0.03)
		end
	end)
	task.delay(Config.Battery.Lifetime, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function nearestPlayer(root)
	local bestPlayer = nil
	local bestDist = Config.Enemy.AggroRange
	local bestRoot = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and hrp and humanoid.Health > 0 then
			local dist = (hrp.Position - root.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestPlayer = player
				bestRoot = hrp
			end
		end
	end
	return bestPlayer, bestRoot, bestDist
end

local function nearestNoise(root, boxes)
	local best = nil
	local bestDist = Config.Enemy.NoiseRange
	for _, box in ipairs(boxes) do
		if box.Parent and (box:GetAttribute("NoiseUntil") or 0) > os.clock() then
			local dist = (box.Position - root.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = box
			end
		end
	end
	return best
end

local function tryAttack(model, humanoid, root, player)
	local now = os.clock()
	if now < (model:GetAttribute("NextAttack") or 0) then
		return
	end
	local character = player.Character
	local targetHum = character and character:FindFirstChildOfClass("Humanoid")
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not targetHum or not targetRoot or targetHum.Health <= 0 then
		return
	end
	if (targetRoot.Position - root.Position).Magnitude > Config.Enemy.AttackRange then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local delta = targetRoot.Position - root.Position
	local hit = workspace:Raycast(root.Position, delta, params)
	if hit and not hit.Instance:IsDescendantOf(character) then
		return
	end
	model:SetAttribute("NextAttack", now + Config.Enemy.AttackCooldown)
	model:SetAttribute("SwingUntil", now + 0.28)
	targetHum:TakeDamage(Config.Enemy.AttackDamage)
	humanoid.WalkSpeed = Config.Enemy.WalkSpeed
end

local function followPath(model, humanoid, root, destination, stillAlive)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 4,
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, destination)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		humanoid:MoveTo(destination)
		task.wait(0.35)
		return
	end
	local waypoints = path:GetWaypoints()
	for index, waypoint in ipairs(waypoints) do
		if not stillAlive() then
			return
		end
		if index > 1 then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(waypoint.Position)
			local started = os.clock()
			local before = root.Position
			while os.clock() - started < 1.4 and stillAlive() do
				local player, targetRoot = nearestPlayer(root)
				if player and targetRoot and (targetRoot.Position - root.Position).Magnitude <= Config.Enemy.AttackRange + 1 then
					tryAttack(model, humanoid, root, player)
				end
				if (root.Position - waypoint.Position).Magnitude < 3.5 then
					break
				end
				task.wait(0.15)
			end
			if (root.Position - before).Magnitude < 0.6 then
				humanoid.Jump = true
			end
		end
	end
end

local function runEnemy(home, boxes)
	local rng = Random.new(math.floor(math.abs(home.X * 13 + home.Z * 7)) + 1)
	local model, humanoid, root, motors = createGangster(home, rng)
	local alive = true

	local function stillAlive()
		return alive and model.Parent ~= nil and humanoid.Health > 0
	end

	humanoid.Died:Once(function()
		alive = false
		local dropAt = root.Position
		spawnBattery(dropAt)
		task.delay(Config.Enemy.CorpseTime, function()
			if model.Parent then
				model:Destroy()
			end
		end)
		task.delay(Config.Enemy.RespawnDelay, function()
			runEnemy(home, boxes)
		end)
	end)

	task.spawn(function()
		while stillAlive() do
			local moving = humanoid.MoveDirection.Magnitude > 0.15
			local swing = 0
			if moving then
				swing = math.sin(os.clock() * 8) * 0.75
			end
			if os.clock() < (model:GetAttribute("SwingUntil") or 0) then
				motors.rightShoulder.Transform = CFrame.Angles(math.rad(-75), 0, 0)
			else
				motors.rightShoulder.Transform = CFrame.Angles(swing * 0.55, 0, 0)
			end
			motors.leftShoulder.Transform = CFrame.Angles(-swing * 0.55, 0, 0)
			motors.leftHip.Transform = CFrame.Angles(swing, 0, 0)
			motors.rightHip.Transform = CFrame.Angles(-swing, 0, 0)
			task.wait(0.05)
		end
	end)

	task.spawn(function()
		local nextWander = 0
		while stillAlive() do
			local player, targetRoot, dist = nearestPlayer(root)
			if player and targetRoot then
				if dist <= Config.Enemy.AttackRange + 2 then
					tryAttack(model, humanoid, root, player)
					humanoid:MoveTo(targetRoot.Position)
					task.wait(0.2)
				elseif dist < 20 then
					humanoid:MoveTo(targetRoot.Position)
					tryAttack(model, humanoid, root, player)
					task.wait(0.2)
				else
					followPath(model, humanoid, root, targetRoot.Position, stillAlive)
				end
			else
				local box = nearestNoise(root, boxes)
				if box then
					followPath(model, humanoid, root, box.Position, stillAlive)
				else
					if root.Position.Y < -2 then
						model:PivotTo(CFrame.new(home))
					elseif (root.Position - home).Magnitude > 14 then
						followPath(model, humanoid, root, home, stillAlive)
					elseif os.clock() > nextWander then
						nextWander = os.clock() + rng:NextNumber(2.5, 4.5)
						local offset = Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7))
						humanoid:MoveTo(home + offset)
						task.wait(0.4)
					else
						task.wait(0.35)
					end
				end
			end
		end
	end)
end

function EnemyService.start(world)
	local boxes = {}
	if world and world.electricBoxes then
		boxes = world.electricBoxes
	end
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("BasePart") and (inst.Name == "ElectricBox" or inst:GetAttribute("IsElectricBox")) then
			local known = false
			for _, existing in ipairs(boxes) do
				if existing == inst then
					known = true
					break
				end
			end
			if not known then
				table.insert(boxes, inst)
			end
		end
	end

	local spawns = {}
	if world and world.enemySpawns then
		spawns = world.enemySpawns
	end
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name == "EnemySpawn" then
			local known = false
			for _, existing in ipairs(spawns) do
				if (existing - inst.Position).Magnitude < 1 then
					known = true
					break
				end
			end
			if not known then
				table.insert(spawns, inst.Position)
			end
		end
	end

	if #spawns == 0 then
		warn("[Адреналин] Нет частей EnemySpawn — бандиты не появились. Поставь Part с таким именем или проверь MapBuilder.")
		return
	end

	for _, position in ipairs(spawns) do
		runEnemy(position, boxes)
	end
	print("[Адреналин] Бандиты вышли на улицы:", #spawns)
end

return EnemyService
