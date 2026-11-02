-- Тип в Studio: ModuleScript
-- Куда класть: ReplicatedStorage → Config
--
-- Все «ручки» игры в одном месте.
-- Поменял число → сохранился → снова нажал Play.
-- Не нужно искать баланс по другим скриптам.
--
-- Этот модуль виден и серверу, и клиенту (он лежит в ReplicatedStorage).
-- Секретов здесь нет: клиент только рисует картинку, цифры заряда
-- всё равно меняет только сервер.

local Config = {}

-- Поставь true, если хочешь видеть заряд в окне Output каждую четверть секунды.
Config.Debug = false

-- Сколько жизни даёт сердце-батарейка.
Config.Charge = {
	Max = 100,
	-- Первый заход. Хватит, чтобы осмотреться и дойти до синего щитка.
	Start = 70,
	-- После смерти заряд не обнуляется навсегда: иначе игрок
	-- сразу умер бы снова. Если заряда меньше этого числа — поднимаем до него.
	RespawnFloor = 50,
	-- Стоя на месте. 70 / 2 = 35 секунд от старта до нуля.
	DrainPerSecond = 2,
	-- Бег немного замедляет потерю, но не отменяет её.
	MoveRegenPerSecond = 0.5,
	-- Маленькая прибавка за прыжок. Спамить прыжком сердце не спасти.
	JumpRegen = 0.25,
	-- Как часто сервер пересчитывает заряд. Меньше — плавнее полоска.
	TickInterval = 0.25,
	-- Ниже этого порога темнеет экран.
	LowThreshold = 35,
	-- Ниже этого сердце «колотится» быстрее и текст становится страшнее.
	CriticalThreshold = 15,
	-- Выше этого персонаж бежит быстрее.
	HighThreshold = 75,
	-- Прибавка за убийство игрока или бандита.
	KillReward = 16,
	BaseWalkSpeed = 16,
	SpeedBonus = 9,
	LowSpeedPenalty = 4,
}

-- Синий электрощиток на улице.
Config.ElectricBox = {
	-- Сколько заряда отдаёт полное удержание.
	ChargeAmount = 38,
	-- Сколько секунд держать клавишу.
	Duration = 3,
	-- Пауза щитка после использования. Стоять на одном вечно выгодно,
	-- но каждый успешный заряд шумит и зовёт бандитов.
	Cooldown = 12,
	-- Если отойти дальше — зарядка прерывается.
	MaxDistance = 12,
	-- Сколько секунд бандиты слышат щиток.
	NoiseDuration = 8,
}

-- Жёлтая батарея, которую роняет бандит.
Config.Battery = {
	Charge = 20,
	-- Через сколько секунд неподобранная батарея исчезает.
	Lifetime = 25,
}

-- Пушка. Урон и кулдаун проверяет сервер, даже если клиент врёт.
Config.Weapon = {
	ToolName = "Вольтган",
	Damage = 18,
	-- Попадание в часть с именем Head.
	HeadshotMultiplier = 1.5,
	FireCooldown = 0.2,
	Range = 300,
	-- Выстрел тратит крошку заряда: пушка питается от сердца.
	ChargeCost = 0.35,
	-- Ниже этого выстрела нет.
	MinChargeToFire = 1,
	TracerColor = Color3.fromRGB(120, 220, 255),
	HitColor = Color3.fromRGB(255, 170, 90),
	FleshColor = Color3.fromRGB(255, 80, 70),
}

Config.Enemy = {
	Health = 100,
	WalkSpeed = 13,
	-- Ближе этого бандит сам бежит к игроку.
	AggroRange = 48,
	-- Ближе этого бандит слышит работающий щиток.
	NoiseRange = 140,
	AttackRange = 5.5,
	AttackDamage = 8,
	AttackCooldown = 1.2,
	RespawnDelay = 12,
	-- Сколько секунд тело лежит, прежде чем исчезнуть.
	CorpseTime = 4,
}

Config.Player = {
	RespawnTime = 4,
	-- Защита сразу после появления (ForceField у SpawnLocation).
	-- Сердце этой защитой НЕ прикрыто: ноль заряда всё равно убивает.
	SpawnProtection = 2,
}

-- Карта собирается заново при каждом Play. Поменяй Seed — район станет другим.
Config.Map = {
	Seed = 220,
	Cells = 4,
	RoadWidth = 22,
	BlockSize = 52,
}

Config.Lighting = {
	ClockTime = 0.15,
	Brightness = 1.15,
	BloomIntensity = 0.5,
	BloomSize = 26,
	BloomThreshold = 0.9,
	AtmosphereDensity = 0.38,
	AtmosphereHaze = 2.2,
	FogStart = 90,
	FogEnd = 520,
}

-- Встроенные текстуры клиента Roblox, не модели из каталога.
-- Они не «протухают», потому что лежат внутри самого Roblox.
Config.Assets = {
	SparkTexture = "rbxasset://textures/particles/sparkles_main.dds",
	SmokeTexture = "rbxasset://textures/particles/smoke_main.dds",
}

-- Пустая строка = звука нет, игра не сломается.
-- Когда найдёшь звук в Toolbox: правый клик → Copy Asset ID,
-- вставь сюда в виде "rbxassetid:123456789".
Config.Sounds = {
	Shot = "",
	Recharge = "",
	Heartbeat = "",
	Pickup = "",
}

Config.Colors = {
	Asphalt = Color3.fromRGB(24, 24, 28),
	Sidewalk = Color3.fromRGB(58, 56, 64),
	SidewalkDark = Color3.fromRGB(46, 44, 52),
	Plaza = Color3.fromRGB(38, 36, 48),
	BuildingA = Color3.fromRGB(28, 30, 40),
	BuildingB = Color3.fromRGB(36, 28, 42),
	BuildingC = Color3.fromRGB(22, 26, 34),
	Brick = Color3.fromRGB(48, 32, 36),
	Metal = Color3.fromRGB(42, 44, 50),
	Lamp = Color3.fromRGB(255, 214, 160),
	Cyan = Color3.fromRGB(70, 220, 255),
	Magenta = Color3.fromRGB(255, 50, 170),
	Purple = Color3.fromRGB(170, 80, 255),
	WarmWindow = Color3.fromRGB(255, 176, 80),
	CoolWindow = Color3.fromRGB(120, 190, 255),
	GreenWindow = Color3.fromRGB(80, 255, 170),
	Heart = Color3.fromRGB(255, 40, 120),
	Battery = Color3.fromRGB(255, 220, 60),
}

-- Цвет полоски: зелёный на 100, жёлтый на 50, красный на 0.
function Config.chargeColor(charge)
	local value = charge or 0
	if value < 0 then
		value = 0
	elseif value > 100 then
		value = 100
	end
	local green = Color3.fromRGB(60, 230, 120)
	local yellow = Color3.fromRGB(255, 210, 50)
	local red = Color3.fromRGB(255, 55, 45)
	if value >= 50 then
		return yellow:Lerp(green, (value - 50) / 50)
	end
	return red:Lerp(yellow, value / 50)
end

return Config
