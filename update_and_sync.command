#!/bin/bash
# Двойной щелчок на macOS: скачать main с GitHub и открыть Rojo для Studio.
# Окно Terminal должно оставаться открытым, пока идёт синхронизация.

cd "$(dirname "$0")" || exit 1

pause_close() {
	echo
	echo "Нажми Enter, чтобы закрыть окно."
	read -r _
}

trap 'echo; echo "Синхронизация остановлена."; exit 0' INT

printf '\033]0;%s\007' "Высокое напряжение — Rojo"

echo
echo "=== Высокое напряжение: обновление и синхронизация со Studio ==="
echo
echo "Папка проекта: $(pwd)"
echo

if ! command -v git >/dev/null 2>&1; then
	echo "Git не установлен, поэтому скачать обновление с GitHub нельзя."
	echo
	echo "Поставь Git одним из способов:"
	echo "  https://git-scm.com/downloads"
	echo "  или в Terminal команда: xcode-select --install"
	echo
	echo "После установки закрой это окно и дважды щёлкни файл ещё раз."
	pause_close
	exit 1
fi

ROJO_CMD=""
if command -v rojo >/dev/null 2>&1; then
	ROJO_CMD="rojo"
elif [[ -x "./rojo" ]]; then
	ROJO_CMD="./rojo"
fi

if [[ -z "$ROJO_CMD" ]]; then
	echo "Rojo не установлен. Без него Studio не увидит файлы проекта."
	echo
	echo "Вариант 1. Скачай Rojo 7 (не версию 6):"
	echo "  https://github.com/rojo-rbx/rojo/releases"
	echo "  Нужен архив rojo-7.x-macos-aarch64.zip на Mac с процессором Apple"
	echo "  или rojo-7.x-macos-x86_64.zip на старом Intel Mac."
	echo "  Распакуй программу rojo и добавь её в PATH, либо положи файл rojo"
	echo "  в эту папку проекта и сделай его запускаемым: chmod +x rojo"
	echo
	echo "Вариант 2. Поставь Rokit или Aftman, затем в этой папке выполни:"
	echo "  rokit install"
	echo "  или"
	echo "  aftman install"
	echo "  Rokit:  https://github.com/rojo-rbx/rokit"
	echo "  Aftman: https://github.com/LPGhatguy/aftman"
	echo
	echo "После установки закрой окно и дважды щёлкни файл ещё раз."
	pause_close
	exit 1
fi

ROJO_VER="$("$ROJO_CMD" --version 2>&1 || true)"
case "$ROJO_VER" in
	*" 7."*) ;;
	*)
		echo "Найдена программа Rojo, но нужна версия 7."
		echo "Сейчас она отвечает так: $ROJO_VER"
		echo "Скачай Rojo 7: https://github.com/rojo-rbx/rojo/releases"
		echo "Либо в этой папке выполни: rokit install    или    aftman install"
		pause_close
		exit 1
		;;
esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "Эта папка не является копией проекта с GitHub."
	echo "Сначала один раз выполни в Terminal:"
	echo "  git clone https://github.com/Makemood/mmm.git"
	echo "Потом зайди в появившуюся папку mmm и дважды щёлкни этот файл."
	pause_close
	exit 1
fi

echo "Проверяю, нет ли незакоммиченных правок..."
git update-index -q --refresh >/dev/null 2>&1 || true
if ! git diff-index --quiet HEAD --; then
	echo "В папке есть несохранённые изменения в файлах."
	echo "Скрипт их не стирает и поэтому остановился."
	echo "Убери правки или сделай коммит, затем запусти файл снова."
	pause_close
	exit 1
fi

echo "Скачиваю сведения о ветках с GitHub..."
if ! git fetch origin; then
	echo "Не удалось связаться с GitHub. Проверь интернет и запусти файл снова."
	pause_close
	exit 1
fi

git remote set-head origin -a >/dev/null 2>&1 || true
BRANCH="main"
if HEAD_REF="$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null)"; then
	BRANCH="${HEAD_REF#origin/}"
fi
if [[ -z "$BRANCH" || "$BRANCH" == "HEAD" ]]; then
	BRANCH="main"
fi

echo "Переключаюсь на ветку $BRANCH..."
if ! git checkout "$BRANCH"; then
	echo "Не удалось переключиться на ветку $BRANCH."
	echo "Если ты менял файлы, сохрани их отдельно и запусти скрипт снова."
	pause_close
	exit 1
fi

echo "Подтягиваю свежие файлы..."
if ! git pull --ff-only origin "$BRANCH"; then
	echo "Не удалось просто подтянуть обновление: локальная ветка разошлась с GitHub."
	echo "Скрипт не перезаписывает твои коммиты. Попроси того, кто помогал с Git, посмотреть папку."
	pause_close
	exit 1
fi

echo
echo "Файлы обновлены."
echo
echo "Дальше:"
echo "  1. Открой Roblox Studio и то место, которое сохранил в прошлый раз."
echo "     Если места ещё нет: File, New, шаблон Baseplate."
echo "  2. В плагине Rojo нажми Connect."
echo "     Адрес обычно localhost:34872 — его можно не менять."
echo "  3. Скрипты появятся или обновятся в Explorer."
echo
echo "Это окно не закрывай. Пока оно открыто, Studio видит папку проекта."
echo "Если окно уже было открыто и ты снова сделаешь git pull в этой папке,"
echo "правки приедут в Studio сами, кнопку Connect второй раз жать не нужно."
echo "Остановить синхронизацию: закрой окно или нажми Ctrl+C."
echo

"$ROJO_CMD" serve
SERVE_STATUS=$?
if [[ "$SERVE_STATUS" -ne 0 ]]; then
	echo
	echo "Rojo остановился с ошибкой."
	echo "Если написано, что порт занят, синхронизация уже идёт в другом окне."
	echo "То окно не закрывай: свежие файлы уже скачаны, и Studio подхватит их сама,"
	echo "если плагин Rojo подключён."
	pause_close
	exit "$SERVE_STATUS"
fi

echo
echo "Rojo остановлен."
pause_close
exit 0
