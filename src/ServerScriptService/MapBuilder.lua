-- Тип в Studio: ModuleScript
-- Куда класть: ServerScriptService → MapBuilder
--
-- Город не нарисован руками. При каждом Play скрипт собирает его из деталей (Part).
-- Поэтому в редакторе карта пустая — это нормально. Нажми Play.
--
-- Никаких моделей из каталога: только материалы и эффекты самого Roblox.
-- Чужие постройки в Workspace скрипт не удаляет, кроме Baseplate и старого Map.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local MapBuilder = {}

local CELLS = Config.Map.Cells
local ROAD = Config.Map.RoadWidth
local BLOCK = Config.Map.BlockSize
local PITCH = ROAD + BLOCK
local GROUND_TOP = 0
local SIDEWALK_TOP = 0.45
local PLAZA_TOP = 0.55

local function makePart(props)
	local p = Instance.new(props.className or "Part")
	p.Name = props.name or "Part"
	p.Anchored = true
	p.Size = props.size or Vector3.new(4, 1, 4)
	if props.cframe then
		p.CFrame = props.cframe
	else
		p.Position = props.position or Vector3.new(0, 0, 0)
	end
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Color = props.color or Color3.new(1, 1, 1)
	p.Transparency = props.transparency or 0
	p.Reflectance = props.reflectance or 0
	p.CanCollide = props.canCollide ~= false
	p.CanQuery = props.canQuery ~= false
	p.CanTouch = props.canTouch == true
	p.CastShadow = props.castShadow ~= false
	if props.shape then
		p.Shape = props.shape
	end
	-- У старых деталей бывают «шипы» на гранях. У Truss их может не быть — не роняем весь город из‑за этого.
	pcall(function()
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end)
	p.Parent = props.parent
	return p
end

local function ensureEffect(className, name)
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then
		return found
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child.ClassName == className and child.Name ~= "ChargeGrade" and child.Name ~= "ChargeBlur" then
			child.Name = name
			return child
		end
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

local function setupLighting()
	local L = Config.Lighting
	Lighting.Technology = Enum.Technology.Future
	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	Lighting.Ambient = Color3.fromRGB(46, 40, 76)
	Lighting.OutdoorAmbient = Color3.fromRGB(56, 48, 92)
	Lighting.ColorShift_Top = Color3.fromRGB(90, 50, 140)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.85
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.GeographicLatitude = 20
	Lighting.ExposureCompensation = -0.15
	Lighting.FogColor = Color3.fromRGB(28, 18, 48)
	Lighting.FogStart = L.FogStart
	Lighting.FogEnd = L.FogEnd

	local atmosphere = ensureEffect("Atmosphere", "Atmosphere")
	atmosphere.Density = L.AtmosphereDensity
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(70, 50, 110)
	atmosphere.Decay = Color3.fromRGB(40, 20, 60)
	atmosphere.Glare = 0.15
	atmosphere.Haze = L.AtmosphereHaze

	local bloom = ensureEffect("BloomEffect", "CityBloom")
	bloom.Intensity = L.BloomIntensity
	bloom.Size = L.BloomSize
	bloom.Threshold = L.BloomThreshold

	local grade = ensureEffect("ColorCorrectionEffect", "CityColor")
	grade.Saturation = 0.15
	grade.Contrast = 0.12
	grade.Brightness = -0.02
	grade.TintColor = Color3.fromRGB(230, 220, 255)

	local sun = ensureEffect("SunRaysEffect", "CitySunRays")
	sun.Intensity = 0.04
	sun.Spread = 0.8
end

local function clearOldStuff()
	local oldMap = workspace:FindFirstChild("Map")
	if oldMap then
		oldMap:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

local function cellCenter(i, j)
	local mid = (CELLS - 1) / 2
	return (i - mid) * PITCH, (j - mid) * PITCH
end

local function isPlaza(i, j)
	local lo = math.floor(CELLS / 2) - 1
	local hi = math.floor(CELLS / 2)
	return i >= lo and i <= hi and j >= lo and j <= hi
end

local function isCornerLot(i, j)
	local last = CELLS - 1
	return (i == 0 and j == 0) or (i == last and j == last)
end

local function roadCoord(n)
	return (n - CELLS / 2) * PITCH
end

local function insidePlaza(x, z, half)
	return math.abs(x) < half and math.abs(z) < half
end

local function addWindows(model, body, rng)
	local floors = math.clamp(math.floor(body.Size.Y / 7), 2, 9)
	local cols = math.clamp(math.floor(body.Size.X / 9), 2, 4)
	local bodyBottom = body.Position.Y - body.Size.Y / 2
	local usable = math.max(body.Size.Y - 8, floors)
	local windowColors = {
		Config.Colors.WarmWindow,
		Config.Colors.CoolWindow,
		Config.Colors.GreenWindow,
		Config.Colors.Cyan,
	}
	for floor = 1, floors do
		local y = bodyBottom + 5 + (floor - 0.5) * (usable / floors)
		for col = 1, cols do
			local xOff = -body.Size.X / 2 + 3 + (col - 0.5) * ((body.Size.X - 5) / cols)
			local lit = rng:NextNumber() > 0.28
			local color = windowColors[rng:NextInteger(1, #windowColors)]
			if not lit then
				color = Color3.fromRGB(12, 14, 20)
			end
			for _, face in ipairs({ -1, 1 }) do
				makePart({
					name = "Window",
					size = Vector3.new(math.min(3.2, body.Size.X / cols - 1.2), 2.3, 0.22),
					position = Vector3.new(body.Position.X + xOff, y, body.Position.Z + face * (body.Size.Z / 2 + 0.12)),
					color = color,
					material = lit and Enum.Material.Neon or Enum.Material.Glass,
					transparency = lit and 0 or 0.4,
					canCollide = false,
					castShadow = false,
					parent = model,
				})
			end
		end
	end
end

local function addCornerLights(model, body, color)
	local hx = body.Size.X / 2
	local hz = body.Size.Z / 2
	local corners = {
		Vector3.new(hx, 0, hz),
		Vector3.new(hx, 0, -hz),
		Vector3.new(-hx, 0, hz),
		Vector3.new(-hx, 0, -hz),
	}
	for _, corner in ipairs(corners) do
		makePart({
			name = "Trim",
			size = Vector3.new(0.4, body.Size.Y, 0.4),
			position = body.Position + Vector3.new(corner.X, 0, corner.Z),
			color = color,
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
			parent = model,
		})
	end
end

local function addDoor(model, body, color)
	local bottom = body.Position.Y - body.Size.Y / 2
	local z = body.Position.Z - body.Size.Z / 2 - 0.18
	local x = body.Position.X
	for _, offset in ipairs({ -2.3, 2.3 }) do
		makePart({
			name = "DoorJamb",
			size = Vector3.new(0.32, 6.2, 0.28),
			position = Vector3.new(x + offset, bottom + 3.1, z),
			color = color,
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
			parent = model,
		})
	end
	makePart({
		name = "DoorLintel",
		size = Vector3.new(5, 0.32, 0.28),
		position = Vector3.new(x, bottom + 6.2, z),
		color = color,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
end

local function addSign(model, body, rng)
	local words = { "ВОЛЬТ", "220V", "НЕОН", "БАР", "КЛУБ", "ОТЕЛЬ", "ЗАРЯД", "НОЧЬ", "PULSE" }
	local palette = { Config.Colors.Cyan, Config.Colors.Magenta, Config.Colors.WarmWindow, Config.Colors.Purple }
	local color = palette[rng:NextInteger(1, #palette)]
	local y = body.Position.Y + body.Size.Y / 2 - 7
	local z = body.Position.Z - body.Size.Z / 2 - 0.6
	local board = makePart({
		name = "Sign",
		size = Vector3.new(math.clamp(body.Size.X * 0.55, 8, 16), 3.2, 0.4),
		cframe = CFrame.lookAt(Vector3.new(body.Position.X, y, z), Vector3.new(body.Position.X, y, z - 5)),
		color = color,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(12, 10, 16)
	label.Text = words[rng:NextInteger(1, #words)]
	label.Parent = gui
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.6
	light.Range = 16
	light.Shadows = false
	light.Parent = board
end

local function addRoofClutter(model, body, rng)
	local roofY = body.Position.Y + body.Size.Y / 2
	local boxes = rng:NextInteger(1, 3)
	for _ = 1, boxes do
		local sx = rng:NextNumber(3, 6)
		local sy = rng:NextNumber(2, 4.5)
		local sz = rng:NextNumber(2.5, 5)
		makePart({
			name = "AC",
			size = Vector3.new(sx, sy, sz),
			position = Vector3.new(
				body.Position.X + rng:NextNumber(-body.Size.X * 0.25, body.Size.X * 0.25),
				roofY + sy / 2,
				body.Position.Z + rng:NextNumber(-body.Size.Z * 0.25, body.Size.Z * 0.25)
			),
			color = Config.Colors.Metal,
			material = Enum.Material.DiamondPlate,
			parent = model,
		})
	end
	if body.Size.Y > 48 then
		local beacon = makePart({
			name = "RoofBeacon",
			size = Vector3.new(0.6, 8, 0.6),
			position = Vector3.new(body.Position.X, roofY + 4, body.Position.Z),
			color = Config.Colors.Magenta,
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
			parent = model,
		})
		local light = Instance.new("PointLight")
		light.Color = Config.Colors.Magenta
		light.Brightness = 2
		light.Range = 22
		light.Shadows = false
		light.Parent = beacon
	end
end

-- TrussPart — готовая лестница Roblox. Подойди и держи прыжок или иди вперёд.
local function addTruss(model, body)
	-- У TrussPart высота лучше чётная: так лестница не ломает размер.
	local height = math.max(4, math.floor(body.Size.Y / 2) * 2)
	local truss = makePart({
		className = "TrussPart",
		name = "FireEscape",
		size = Vector3.new(2, height, 2),
		position = Vector3.new(
			body.Position.X - body.Size.X / 2 - 1.2,
			(body.Position.Y - body.Size.Y / 2) + height / 2,
			body.Position.Z
		),
		color = Color3.fromRGB(35, 36, 40),
		material = Enum.Material.Metal,
		parent = model,
	})
	local roofY = body.Position.Y + body.Size.Y / 2
	makePart({
		name = "RoofStep",
		size = Vector3.new(6, 0.5, 6),
		position = Vector3.new(truss.Position.X + 2.2, roofY + 0.25, truss.Position.Z),
		color = Config.Colors.Metal,
		material = Enum.Material.DiamondPlate,
		parent = model,
	})
end

local function addBuilding(cx, cz, rng, forcedHeight, parent)
	local height = forcedHeight or rng:NextInteger(24, 70)
	local width = rng:NextInteger(30, 40)
	local depth = math.clamp(width - rng:NextInteger(0, 6), 26, 40)
	local palette = {
		{ color = Config.Colors.BuildingA, material = Enum.Material.Concrete },
		{ color = Config.Colors.BuildingB, material = Enum.Material.Concrete },
		{ color = Config.Colors.BuildingC, material = Enum.Material.SmoothPlastic },
		{ color = Config.Colors.Brick, material = Enum.Material.Brick },
	}
	local look = palette[rng:NextInteger(1, #palette)]
	local trimColors = { Config.Colors.Cyan, Config.Colors.Magenta, Config.Colors.Purple, Config.Colors.WarmWindow }
	local trim = trimColors[rng:NextInteger(1, #trimColors)]

	local model = Instance.new("Model")
	model.Name = "Building"
	local body = makePart({
		name = "Body",
		size = Vector3.new(width, height, depth),
		position = Vector3.new(cx, SIDEWALK_TOP + height / 2, cz),
		color = look.color,
		material = look.material,
		parent = model,
	})
	addWindows(model, body, rng)
	addCornerLights(model, body, trim)
	addDoor(model, body, trim)
	addRoofClutter(model, body, rng)
	if height <= 32 or rng:NextNumber() < 0.45 then
		addTruss(model, body)
	end
	if rng:NextNumber() < 0.7 then
		addSign(model, body, rng)
	end
	model.Parent = parent
end

local function addLamp(position, shadows, parent)
	local model = Instance.new("Model")
	model.Name = "StreetLamp"
	local pole = makePart({
		name = "Pole",
		size = Vector3.new(18, 0.55, 0.55),
		cframe = CFrame.new(position + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		shape = Enum.PartType.Cylinder,
		color = Color3.fromRGB(36, 36, 42),
		material = Enum.Material.Metal,
		parent = model,
	})
	makePart({
		name = "Arm",
		size = Vector3.new(3.2, 0.28, 0.28),
		position = position + Vector3.new(1.4, 17.6, 0),
		color = pole.Color,
		material = Enum.Material.Metal,
		parent = model,
	})
	local head = makePart({
		name = "Head",
		size = Vector3.new(1.4, 0.35, 0.8),
		position = position + Vector3.new(2.6, 17.3, 0),
		color = Config.Colors.Lamp,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 62
	spot.Range = 36
	spot.Brightness = 2.4
	spot.Color = Config.Colors.Lamp
	spot.Shadows = shadows
	spot.Parent = head
	local point = Instance.new("PointLight")
	point.Range = 14
	point.Brightness = 1.1
	point.Color = Config.Colors.Lamp
	point.Shadows = false
	point.Parent = head
	model.Parent = parent
end

local function addCar(x, surfaceY, z, yaw, rng, parent)
	local model = Instance.new("Model")
	model.Name = "Car"
	local paints = {
		Color3.fromRGB(170, 20, 40),
		Color3.fromRGB(20, 20, 24),
		Color3.fromRGB(30, 70, 140),
		Color3.fromRGB(220, 220, 230),
		Color3.fromRGB(90, 20, 120),
	}
	local paint = paints[rng:NextInteger(1, #paints)]
	-- Низ кузова чуть выше дороги, колёса стоят на асфальте.
	local bodyY = surfaceY + 1.35
	local cf = CFrame.new(x, bodyY, z) * CFrame.Angles(0, yaw, 0)
	makePart({
		name = "Body",
		size = Vector3.new(6.2, 1.5, 11),
		cframe = cf,
		color = paint,
		material = Enum.Material.SmoothPlastic,
		parent = model,
	})
	makePart({
		name = "Cabin",
		size = Vector3.new(5.3, 1.15, 5),
		cframe = cf * CFrame.new(0, 1.15, -0.35),
		color = Color3.fromRGB(10, 14, 20),
		material = Enum.Material.Glass,
		transparency = 0.45,
		canCollide = false,
		parent = model,
	})
	if rng:NextNumber() < 0.75 then
		local glowColor = rng:NextNumber() > 0.5 and Config.Colors.Cyan or Config.Colors.Magenta
		local glow = makePart({
			name = "Underglow",
			size = Vector3.new(5, 0.18, 8),
			cframe = cf * CFrame.new(0, -0.7, 0),
			color = glowColor,
			material = Enum.Material.Neon,
			canCollide = false,
			canQuery = false,
			castShadow = false,
			parent = model,
		})
		local light = Instance.new("PointLight")
		light.Color = glowColor
		light.Brightness = 1.2
		light.Range = 10
		light.Shadows = false
		light.Parent = glow
	end
	-- У цилиндра «длина» уже по оси X — это ось колеса, дополнительный поворот не нужен.
	local wheels = {
		Vector3.new(-3.15, -0.65, 3.4),
		Vector3.new(3.15, -0.65, 3.4),
		Vector3.new(-3.15, -0.65, -3.4),
		Vector3.new(3.15, -0.65, -3.4),
	}
	for _, offset in ipairs(wheels) do
		makePart({
			name = "Wheel",
			size = Vector3.new(0.65, 1.4, 1.4),
			cframe = cf * CFrame.new(offset),
			shape = Enum.PartType.Cylinder,
			color = Color3.fromRGB(12, 12, 12),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
			parent = model,
		})
	end
	model.Parent = parent
end

local function addElectricBox(position, parent)
	local model = Instance.new("Model")
	model.Name = "ElectricBox"
	model:SetAttribute("IsElectricBox", true)
	local box = makePart({
		name = "ElectricBox",
		size = Vector3.new(3.2, 4.2, 1.4),
		position = position + Vector3.new(0, 2.1, 0),
		color = Color3.fromRGB(32, 36, 42),
		material = Enum.Material.DiamondPlate,
		canTouch = true,
		parent = model,
	})
	box:SetAttribute("IsElectricBox", true)
	makePart({
		name = "Screen",
		size = Vector3.new(2.1, 1.3, 0.18),
		position = box.Position + Vector3.new(0, 0.45, -0.75),
		color = Config.Colors.Cyan,
		material = Enum.Material.Neon,
		canCollide = false,
		castShadow = false,
		parent = model,
	})
	makePart({
		name = "Beacon",
		size = Vector3.new(0.35, 16, 0.35),
		position = box.Position + Vector3.new(0, 10, 0),
		color = Config.Colors.Cyan,
		material = Enum.Material.Neon,
		transparency = 0.55,
		canCollide = false,
		canQuery = false,
		castShadow = false,
		parent = model,
	})
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = Config.Colors.Cyan
	glow.Brightness = 2.6
	glow.Range = 18
	glow.Shadows = false
	glow.Parent = box
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = Config.Assets.SparkTexture
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Rate = 5
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Speed = NumberRange.new(1, 3.5)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Color = ColorSequence.new(Config.Colors.Cyan)
	sparks.Parent = box
	model.PrimaryPart = box
	model.Parent = parent
	return box
end

local function addSpawnMarker(position, parent)
	local marker = makePart({
		name = "EnemySpawn",
		size = Vector3.new(2, 2, 2),
		position = Vector3.new(position.X, 4, position.Z),
		transparency = 1,
		canCollide = false,
		canQuery = false,
		parent = parent,
	})
	return marker
end

local function addHeart(parent)
	local model = Instance.new("Model")
	model.Name = "HeartMonument"
	makePart({
		name = "Pedestal",
		size = Vector3.new(10, 3, 10),
		position = Vector3.new(0, PLAZA_TOP + 1.5, 0),
		color = Color3.fromRGB(28, 28, 34),
		material = Enum.Material.Metal,
		parent = model,
	})
	local function ball(offset, size, color)
		return makePart({
			name = "Heart",
			size = size,
			position = Vector3.new(0, PLAZA_TOP, 0) + offset,
			shape = Enum.PartType.Ball,
			color = color,
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
			parent = model,
		})
	end
	local heartY = 16
	ball(Vector3.new(-2.3, heartY + 2.2, 0), Vector3.new(5.6, 5.6, 5.2), Config.Colors.Heart)
	ball(Vector3.new(2.3, heartY + 2.2, 0), Vector3.new(5.6, 5.6, 5.2), Config.Colors.Heart)
	ball(Vector3.new(0, heartY - 1, 0), Vector3.new(7.6, 6.6, 5.6), Config.Colors.Heart)
	ball(Vector3.new(0, heartY - 4.4, 0), Vector3.new(4.4, 4.2, 4), Config.Colors.Heart)
	ball(Vector3.new(0, heartY - 6.6, 0), Vector3.new(2.2, 2.2, 2), Config.Colors.Heart)
	local boltColor = Color3.fromRGB(255, 240, 80)
	makePart({
		name = "Bolt",
		size = Vector3.new(0.45, 4.5, 0.45),
		cframe = CFrame.new(0.4, PLAZA_TOP + heartY + 1, -2.4) * CFrame.Angles(0, 0, math.rad(28)),
		color = boltColor,
		material = Enum.Material.Neon,
		canCollide = false,
		canQuery = false,
		castShadow = false,
		parent = model,
	})
	makePart({
		name = "Bolt",
		size = Vector3.new(0.45, 4.5, 0.45),
		cframe = CFrame.new(-0.5, PLAZA_TOP + heartY - 2.6, -2.4) * CFrame.Angles(0, 0, math.rad(-32)),
		color = boltColor,
		material = Enum.Material.Neon,
		canCollide = false,
		canQuery = false,
		castShadow = false,
		parent = model,
	})
	local core = model:FindFirstChild("Heart")
	if core then
		local light = Instance.new("PointLight")
		light.Color = Config.Colors.Heart
		light.Brightness = 4
		light.Range = 42
		light.Shadows = false
		light.Parent = core
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = Config.Assets.SparkTexture
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Rate = 8
		sparks.Lifetime = NumberRange.new(0.4, 0.9)
		sparks.Speed = NumberRange.new(1, 3)
		sparks.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparks.Color = ColorSequence.new(boltColor)
		sparks.Parent = core
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(280, 70)
		billboard.StudsOffset = Vector3.new(0, 6, 0)
		billboard.MaxDistance = 240
		billboard.Parent = core
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 1)
		title.Font = Enum.Font.BuilderSansExtraBold
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 230, 240)
		title.TextStrokeTransparency = 0.4
		title.Text = "ВЫСОКОЕ НАПРЯЖЕНИЕ"
		title.Parent = billboard
	end
	model.Parent = parent
end

local function addTutorialStairs(parent)
	-- Обычные ступеньки, по ним можно просто зайти, без лестницы-фермы.
	local x = -18
	for step = 1, 8 do
		makePart({
			name = "TutorialStep",
			size = Vector3.new(8, 1, 2.2),
			position = Vector3.new(x, PLAZA_TOP + step - 0.5, 8 + step * 2.1),
			color = Config.Colors.Metal,
			material = Enum.Material.DiamondPlate,
			parent = parent,
		})
	end
	local deck = makePart({
		name = "TutorialDeck",
		size = Vector3.new(12, 1, 10),
		position = Vector3.new(x, PLAZA_TOP + 8, 8 + 8 * 2.1 + 4),
		color = Color3.fromRGB(32, 34, 42),
		material = Enum.Material.Metal,
		parent = parent,
	})
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(160, 40)
	sign.StudsOffset = Vector3.new(0, 3, 0)
	sign.MaxDistance = 80
	sign.Parent = deck
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.TextColor3 = Config.Colors.Cyan
	label.Text = "НА КРЫШУ"
	label.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
end

local function addBackdrop(rng, parent)
	for index = 1, 14 do
		local angle = (index / 14) * math.pi * 2 + 0.2
		local radius = 230 + (index % 3) * 22
		local height = rng:NextInteger(80, 150)
		local width = rng:NextInteger(26, 42)
		local depth = rng:NextInteger(22, 36)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local body = makePart({
			name = "Skyline",
			size = Vector3.new(width, height, depth),
			position = Vector3.new(x, height / 2, z),
			color = Color3.fromRGB(16, 16, 24),
			material = Enum.Material.Concrete,
			parent = parent,
		})
		local bands = rng:NextInteger(3, 5)
		for band = 1, bands do
			local y = 12 + (band - 1) * (height / (bands + 1))
			makePart({
				name = "SkylineWindows",
				size = Vector3.new(width + 0.4, 1.4, depth + 0.4),
				position = Vector3.new(x, y, z),
				color = (band % 2 == 0) and Config.Colors.CoolWindow or Config.Colors.WarmWindow,
				material = Enum.Material.Neon,
				transparency = 0.15,
				canCollide = false,
				castShadow = false,
				parent = parent,
			})
		end
		if index % 2 == 0 then
			local cap = makePart({
				name = "SkylineCap",
				size = Vector3.new(2, 10, 2),
				position = Vector3.new(x, height + 5, z),
				color = (index % 4 == 0) and Config.Colors.Magenta or Config.Colors.Cyan,
				material = Enum.Material.Neon,
				canCollide = false,
				castShadow = false,
				parent = parent,
			})
			local light = Instance.new("PointLight")
			light.Color = cap.Color
			light.Brightness = 2
			light.Range = 28
			light.Shadows = false
			light.Parent = cap
		end
		body.Name = "SkylineTower"
	end
end

function MapBuilder.build()
	setupLighting()
	clearOldStuff()

	local rng = Random.new(Config.Map.Seed)
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace

	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = map
		return f
	end

	local groundFolder = folder("Ground")
	local roadFolder = folder("Roads")
	local buildingFolder = folder("Buildings")
	local propFolder = folder("Props")
	local lightFolder = folder("Lights")
	local boxFolder = folder("ElectricBoxes")
	local spawnFolder = folder("Spawns")

	makePart({
		name = "Ground",
		size = Vector3.new(1100, 12, 1100),
		position = Vector3.new(0, GROUND_TOP - 6, 0),
		color = Config.Colors.Asphalt,
		material = Enum.Material.Asphalt,
		parent = groundFolder,
	})

	local plazaHalf = PITCH - ROAD / 2 - 2

	for i = 0, CELLS - 1 do
		for j = 0, CELLS - 1 do
			if not isPlaza(i, j) then
				local cx, cz = cellCenter(i, j)
				local lot = isCornerLot(i, j)
				makePart({
					name = lot and "Parking" or "Sidewalk",
					size = Vector3.new(BLOCK - 6, 0.45, BLOCK - 6),
					position = Vector3.new(cx, SIDEWALK_TOP - 0.225, cz),
					color = lot and Color3.fromRGB(30, 30, 34) or Config.Colors.Sidewalk,
					material = lot and Enum.Material.Asphalt or Enum.Material.Concrete,
					parent = groundFolder,
				})
			end
		end
	end

	makePart({
		name = "Plaza",
		size = Vector3.new(plazaHalf * 2, 0.55, plazaHalf * 2),
		position = Vector3.new(0, PLAZA_TOP - 0.275, 0),
		color = Config.Colors.Plaza,
		material = Enum.Material.Concrete,
		parent = groundFolder,
	})

	local roadLines = {}
	for n = 0, CELLS do
		table.insert(roadLines, roadCoord(n))
	end

	for _, z in ipairs(roadLines) do
		local x = -roadLines[#roadLines]
		while x < roadLines[#roadLines] do
			local cx = x + 6
			if not insidePlaza(cx, z, plazaHalf - 4) then
				makePart({
					name = "Lane",
					size = Vector3.new(3.2, 0.08, 0.45),
					position = Vector3.new(cx, 0.06, z),
					color = Color3.fromRGB(230, 210, 120),
					material = Enum.Material.SmoothPlastic,
					canCollide = false,
					castShadow = false,
					parent = roadFolder,
				})
			end
			x += 14
		end
	end
	for _, x in ipairs(roadLines) do
		local z = -roadLines[#roadLines]
		while z < roadLines[#roadLines] do
			local cz = z + 6
			if not insidePlaza(x, cz, plazaHalf - 4) then
				makePart({
					name = "Lane",
					size = Vector3.new(0.45, 0.08, 3.2),
					position = Vector3.new(x, 0.06, cz),
					color = Color3.fromRGB(230, 210, 120),
					material = Enum.Material.SmoothPlastic,
					canCollide = false,
					castShadow = false,
					parent = roadFolder,
				})
			end
			z += 14
		end
	end

	local buildingCount = 0
	local shortLeft = 3
	for i = 0, CELLS - 1 do
		for j = 0, CELLS - 1 do
			local cx, cz = cellCenter(i, j)
			if isCornerLot(i, j) then
				for slot = -1, 1 do
					addCar(cx + slot * 10, SIDEWALK_TOP, cz - 12, 0, rng, propFolder)
				end
				makePart({
					name = "Fence",
					size = Vector3.new(BLOCK - 10, 2.2, 0.4),
					position = Vector3.new(cx, SIDEWALK_TOP + 1.1, cz - (BLOCK - 6) / 2 + 1),
					color = Config.Colors.Metal,
					material = Enum.Material.Metal,
					parent = propFolder,
				})
				addSpawnMarker(Vector3.new(cx, 4, cz + 8), spawnFolder)
			elseif not isPlaza(i, j) then
				local forced = nil
				if shortLeft > 0 then
					forced = rng:NextInteger(18, 28)
					shortLeft -= 1
				end
				addBuilding(cx, cz, rng, forced, buildingFolder)
				buildingCount += 1
			end
		end
	end

	addHeart(propFolder)
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2
		local radius = 13
		makePart({
			name = "Ring",
			size = Vector3.new(2.4, 0.22, 0.55),
			cframe = CFrame.new(math.cos(angle) * radius, PLAZA_TOP + 0.12, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0),
			color = (i % 2 == 0) and Config.Colors.Cyan or Config.Colors.Magenta,
			material = Enum.Material.Neon,
			canCollide = false,
			castShadow = false,
			parent = propFolder,
		})
	end

	local spawn = makePart({
		className = "SpawnLocation",
		name = "Spawn",
		size = Vector3.new(8, 1, 8),
		position = Vector3.new(0, PLAZA_TOP + 0.5, 30),
		color = Color3.fromRGB(18, 22, 34),
		material = Enum.Material.Metal,
		parent = spawnFolder,
	})
	spawn.Duration = Config.Player.SpawnProtection
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false

	addTutorialStairs(propFolder)

	for puddle = 1, 5 do
		local angle = puddle * 1.3
		makePart({
			name = "Puddle",
			size = Vector3.new(7 + puddle, 0.12, 4 + puddle),
			cframe = CFrame.new(math.cos(angle) * 24, PLAZA_TOP + 0.08, math.sin(angle) * 18) * CFrame.Angles(0, angle, 0),
			color = Color3.fromRGB(20, 24, 36),
			material = Enum.Material.Glass,
			transparency = 0.35,
			reflectance = 0.35,
			canCollide = false,
			canQuery = false,
			castShadow = false,
			parent = propFolder,
		})
	end

	local labels = { "ЦЕНТР", "ВОЛЬТ", "НЕОН", "НОЧЬ" }
	local signSpots = {
		Vector3.new(plazaHalf - 6, PLAZA_TOP, 8),
		Vector3.new(-plazaHalf + 6, PLAZA_TOP, -8),
		Vector3.new(8, PLAZA_TOP, plazaHalf - 6),
		Vector3.new(-8, PLAZA_TOP, -plazaHalf + 6),
	}
	for index, spot in ipairs(signSpots) do
		local pole = makePart({
			name = "StreetSign",
			size = Vector3.new(0.4, 7, 0.4),
			position = spot + Vector3.new(0, 3.5, 0),
			color = Config.Colors.Metal,
			material = Enum.Material.Metal,
			parent = propFolder,
		})
		local board = Instance.new("BillboardGui")
		board.Name = "StreetSignBoard"
		board.Size = UDim2.fromOffset(120, 36)
		board.StudsOffset = Vector3.new(0, 4.2, 0)
		board.MaxDistance = 120
		board.Parent = pole
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
		label.BackgroundTransparency = 0.2
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextScaled = true
		label.TextColor3 = Config.Colors.Cyan
		label.Text = labels[index]
		label.Parent = board
		local signCorner = Instance.new("UICorner")
		signCorner.CornerRadius = UDim.new(0, 6)
		signCorner.Parent = label
	end

	-- Первый щиток стоит перед точкой появления, чтобы его было видно сразу.
	addElectricBox(Vector3.new(12, PLAZA_TOP, 16), boxFolder)
	local inset = plazaHalf - 14
	local corners = {
		Vector3.new(-inset, PLAZA_TOP, -inset),
		Vector3.new(inset, PLAZA_TOP, -inset),
		Vector3.new(-inset, PLAZA_TOP, inset),
		Vector3.new(inset, PLAZA_TOP, inset * 0.35),
	}
	for _, corner in ipairs(corners) do
		addElectricBox(corner, boxFolder)
	end
	local innerPos = roadCoord(math.floor(CELLS / 2) + 1)
	local innerNeg = roadCoord(math.floor(CELLS / 2) - 1)
	addElectricBox(Vector3.new(innerPos + 10, SIDEWALK_TOP, 48), boxFolder)
	addElectricBox(Vector3.new(innerNeg - 10, SIDEWALK_TOP, -36), boxFolder)
	addElectricBox(Vector3.new(-40, SIDEWALK_TOP, innerPos + 10), boxFolder)

	local lampIndex = 0
	for _, x in ipairs(roadLines) do
		for _, z in ipairs(roadLines) do
			if not insidePlaza(x, z, plazaHalf - 6) then
				lampIndex += 1
				local ox = (x >= 0) and (ROAD / 2 + 3) or -(ROAD / 2 + 3)
				local oz = (z >= 0) and (ROAD / 2 + 3) or -(ROAD / 2 + 3)
				addLamp(Vector3.new(x + ox, GROUND_TOP, z + oz), lampIndex % 5 == 0, lightFolder)
			end
		end
	end
	addLamp(Vector3.new(-20, PLAZA_TOP, 34), true, lightFolder)
	addLamp(Vector3.new(22, PLAZA_TOP, 34), false, lightFolder)

	local function nearIntersection(x, z)
		local nearX = false
		local nearZ = false
		for _, road in ipairs(roadLines) do
			if math.abs(x - road) < 16 then
				nearX = true
			end
			if math.abs(z - road) < 16 then
				nearZ = true
			end
		end
		return nearX and nearZ
	end

	local cars = 0
	local carLimit = 14
	for _, z in ipairs(roadLines) do
		local x = -innerPos + 28
		while x <= innerPos - 8 and cars < carLimit do
			local side = (cars % 2 == 0) and 8 or -8
			local px = x
			local pz = z + side
			local farFromSpawn = (Vector3.new(px, 0, pz) - Vector3.new(0, 0, 30)).Magnitude > 24
			if farFromSpawn and not nearIntersection(px, pz) and not insidePlaza(px, pz, plazaHalf + 2) then
				addCar(px, GROUND_TOP, pz, math.rad(90), rng, propFolder)
				cars += 1
			end
			x += 56
		end
	end

	addBackdrop(rng, buildingFolder)

	addSpawnMarker(Vector3.new(innerPos + 8, 4, 18), spawnFolder)
	addSpawnMarker(Vector3.new(innerNeg - 8, 4, -12), spawnFolder)
	addSpawnMarker(Vector3.new(16, 4, innerNeg - 8), spawnFolder)
	addSpawnMarker(Vector3.new(-18, 4, innerPos + 8), spawnFolder)

	local boxes = {}
	for _, inst in ipairs(boxFolder:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name == "ElectricBox" then
			table.insert(boxes, inst)
		end
	end
	local spawns = {}
	for _, inst in ipairs(spawnFolder:GetChildren()) do
		if inst.Name == "EnemySpawn" then
			table.insert(spawns, inst.Position)
		end
	end

	print(string.format("[Адреналин] Город собран: зданий %d, щитков %d, точек бандитов %d.", buildingCount, #boxes, #spawns))

	return {
		folder = map,
		electricBoxes = boxes,
		enemySpawns = spawns,
	}
end

return MapBuilder
