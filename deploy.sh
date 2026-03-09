#!/bin/bash
set -euo pipefail

# === Настройки ===
PROJECT_DIR="~/infra-nmp"                  # ← измени на свой реальный путь!
LOG_FILE="$PROJECT_DIR/deploy.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

cd "$PROJECT_DIR" || { echo "[$DATE] Ошибка: директория $PROJECT_DIR не найдена" >&2; exit 1; }

echo "[$DATE] 🚀 Starting deployment..." | tee -a "$LOG_FILE"

# 1. Обновляем infra + подтягиваем свежие данные субмодулей
echo "[$DATE] 🔄 Pulling infra + submodules data..." | tee -a "$LOG_FILE"
git pull --ff-only --recurse-submodules || { echo "[$DATE] git pull failed" | tee -a "$LOG_FILE"; exit 1; }

# 2. Переключаем субмодули на последние коммиты (по ветке из .gitmodules)
echo "[$DATE] 🔄 Updating submodules to latest remote..." | tee -a "$LOG_FILE"
git submodule update --init --recursive --remote || { echo "[$DATE] submodule update failed" | tee -a "$LOG_FILE"; exit 1; }

# 3. Показываем статус (для логов и отладки)
echo "[$DATE] 📊 Submodules status after update:" | tee -a "$LOG_FILE"
git submodule status | tee -a "$LOG_FILE"
echo "[$DATE] Git status:" | tee -a "$LOG_FILE"
git status --short | tee -a "$LOG_FILE"

# 4. Если субмодули обновились → фиксируем это в infra
if git diff --quiet --exit-code -- frontend backend; then
    echo "[$DATE] ✅ Submodules already at latest — no commit needed" | tee -a "$LOG_FILE"
else
    echo "[$DATE] 📌 Submodules updated → committing new references..." | tee -a "$LOG_FILE"
    git add frontend backend
    git commit -m "chore(auto): update submodules to latest ($(date '+%Y-%m-%d %H:%M'))" || {
        echo "[$DATE] commit skipped (возможно уже закоммичено или конфликт)" | tee -a "$LOG_FILE"
    }

    # Пушим изменения (если ветка позволяет)
    echo "[$DATE] ⬆️ Pushing updated infra..." | tee -a "$LOG_FILE"
    git push || echo "[$DATE] ⚠️ git push failed (protected branch? нет прав?)" | tee -a "$LOG_FILE"
fi

# 5. Docker
echo "[$DATE] 🐳 Building images (если изменились)..." | tee -a "$LOG_FILE"
docker compose build --pull --no-cache=false || echo "[$DATE] build warning — continuing" | tee -a "$LOG_FILE"

echo "[$DATE] 🔄 (Re)starting services..." | tee -a "$LOG_FILE"
docker compose up -d --remove-orphans

# 6. Чистка
echo "[$DATE] 🧹 Pruning old images & containers..." | tee -a "$LOG_FILE"
docker image prune -f
docker system prune -f --filter "until=48h"   # можно агрессивнее, если хочешь

echo "[$DATE] ✅ Deployment completed!" | tee -a "$LOG_FILE"