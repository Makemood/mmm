-- Тип в Studio: Script  (обычный серверный скрипт, НЕ ModuleScript и НЕ LocalScript)
-- Куда класть: ServerScriptService → GameServer
--
-- Это единственный серверный скрипт, который запускается сам.
-- Остальные файлы в ServerScriptService — модули: они молчат,
-- пока этот файл их не подключит через require.
--
-- Порядок важный:
-- 1. Создать RemoteEvent, чтобы клиент мог сказать «я выстрелил».
-- 2. Построить город.
-- 3. Включить сердце, пушку и бандитов.

print("[Адреналин] Сервер запускается...")

if _G.__ADRENALIN_BOOTED then
	warn("[Адреналин] GameServer уже запускался. Второй экземпляр выключен, чтобы не построить два города.")
	return
end
_G.__ADRENALIN_BOOTED = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function must(parent, name)
	local inst = parent:WaitForChild(name, 10)
	if not inst then
		error("[Адреналин] Не найден объект «" .. name .. "». Проверь имя и тип: Script / LocalScript / ModuleScript. Смотри таблицу в README.")
	end
	return inst
end

local Config = require(must(ReplicatedStorage, "Config"))
local MapBuilder = require(must(ServerScriptService, "MapBuilder"))
local ChargeService = require(must(ServerScriptService, "ChargeService"))
local WeaponService = require(must(ServerScriptService, "WeaponService"))
local EnemyService = require(must(ServerScriptService, "EnemyService"))

Players.RespawnTime = Config.Player.RespawnTime

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
	remotes:Destroy()
end
remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local fireWeapon = Instance.new("RemoteEvent")
fireWeapon.Name = "FireWeapon"
fireWeapon.Parent = remotes

local world = MapBuilder.build()
ChargeService.start()
WeaponService.start(fireWeapon)
EnemyService.start(world)

print("[Адреналин] Готово. Сердце тикает — не стой на месте.")
