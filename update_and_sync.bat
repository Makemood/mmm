@echo off
setlocal EnableExtensions
cd /d "%~dp0"
chcp 65001 >nul
title Высокое напряжение — Rojo

echo.
echo === Высокое напряжение: обновление и синхронизация со Studio ===
echo.
echo Папка проекта: %CD%
echo.

where git >nul 2>&1
if errorlevel 1 goto :no_git

set "ROJO_CMD=rojo"
where rojo >nul 2>&1
if not errorlevel 1 goto :have_rojo
if not exist "%~dp0rojo.exe" goto :no_rojo
set "ROJO_CMD=%~dp0rojo.exe"

:have_rojo
"%ROJO_CMD%" --version >"%TEMP%\rojo-version.txt" 2>&1
findstr /C:" 7." "%TEMP%\rojo-version.txt" >nul
if errorlevel 1 goto :bad_rojo_ver

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 goto :not_repo

echo Проверяю, нет ли незакоммиченных правок...
git update-index -q --refresh >nul 2>&1
git diff-index --quiet HEAD --
if errorlevel 1 goto :dirty

echo Скачиваю сведения о ветках с GitHub...
git fetch origin
if errorlevel 1 goto :net_fail

git remote set-head origin -a >nul 2>&1
set "BRANCH=main"
for /f "tokens=1,* delims=/" %%A in ('git rev-parse --abbrev-ref origin/HEAD 2^>nul') do (
  if /I "%%A"=="origin" if not "%%B"=="" set "BRANCH=%%B"
)

echo Переключаюсь на ветку %BRANCH%...
git checkout %BRANCH%
if errorlevel 1 goto :checkout_fail

echo Подтягиваю свежие файлы...
git pull --ff-only origin %BRANCH%
if errorlevel 1 goto :pull_fail

echo.
echo Файлы обновлены.
echo.
echo Дальше:
echo   1. Открой Roblox Studio и то место, которое сохранил в прошлый раз.
echo      Если места ещё нет: File, New, шаблон Baseplate.
echo   2. В плагине Rojo нажми Connect.
echo      Адрес обычно localhost:34872 — его можно не менять.
echo   3. Скрипты появятся или обновятся в Explorer.
echo.
echo Это окно не закрывай. Пока оно открыто, Studio видит папку проекта.
echo Если окно уже было открыто и ты снова сделаешь git pull в этой папке,
echo правки приедут в Studio сами, кнопку Connect второй раз жать не нужно.
echo Остановить синхронизацию: закрой окно или нажми Ctrl+C.
echo.

"%ROJO_CMD%" serve
if errorlevel 1 goto :serve_fail

echo.
echo Rojo остановлен.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 0

:no_git
echo Git не установлен, поэтому скачать обновление с GitHub нельзя.
echo.
echo Скачай Git для Windows и установи:
echo https://git-scm.com/downloads
echo.
echo В установщике оставь пункт, который добавляет Git в командную строку:
echo Git from the command line and also from 3rd-party software.
echo После установки закрой это окно и дважды щёлкни файл ещё раз.
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1

:no_rojo
echo Rojo не установлен. Без него Studio не увидит файлы проекта.
echo.
echo Вариант 1. Скачай Rojo 7, не версию 6:
echo https://github.com/rojo-rbx/rojo/releases
echo Нужен архив rojo-7.x-windows-x86_64.zip
echo Распакуй rojo.exe и добавь его папку в PATH,
echo либо просто положи rojo.exe в эту папку проекта.
echo.
echo Вариант 2. Поставь Rokit или Aftman, затем в этой папке выполни:
echo   rokit install
echo   или
echo   aftman install
echo Rokit:  https://github.com/rojo-rbx/rokit
echo Aftman: https://github.com/LPGhatguy/aftman
echo.
echo После установки закрой окно и дважды щёлкни файл ещё раз.
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1

:bad_rojo_ver
echo Найдена программа Rojo, но нужна версия 7.
echo Сейчас она отвечает так:
type "%TEMP%\rojo-version.txt"
echo.
echo Скачай Rojo 7: https://github.com/rojo-rbx/rojo/releases
echo Либо в этой папке выполни: rokit install    или    aftman install
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1

:not_repo
echo Эта папка не является копией проекта с GitHub.
echo Сначала один раз открой командную строку и выполни:
echo   git clone https://github.com/Makemood/mmm.git
echo Потом зайди в появившуюся папку mmm и дважды щёлкни этот файл.
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1

:dirty
echo В папке есть несохранённые изменения в файлах.
echo Скрипт их не стирает и поэтому остановился.
echo Убери правки или сделай коммит, затем запусти файл снова.
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1

:net_fail
echo Не удалось связаться с GitHub. Проверь интернет и запусти файл снова.
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1

:checkout_fail
echo Не удалось переключиться на ветку %BRANCH%.
echo Если ты менял файлы, сохрани их отдельно и запусти скрипт снова.
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1

:pull_fail
echo Не удалось просто подтянуть обновление: локальная ветка разошлась с GitHub.
echo Скрипт не перезаписывает твои коммиты.
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1

:serve_fail
echo.
echo Rojo остановился с ошибкой.
echo Если написано, что порт занят, синхронизация уже идёт в другом окне.
echo То окно не закрывай: свежие файлы уже скачаны, и Studio подхватит их сама,
echo если плагин Rojo подключён.
echo.
echo Нажми любую клавишу, чтобы закрыть окно.
pause >nul
exit /b 1
