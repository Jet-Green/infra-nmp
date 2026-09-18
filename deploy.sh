#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$PROJECT_DIR/deploy.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

cd "$PROJECT_DIR"

log "🚀 Starting deployment..."

# 1. Обновляем infra
log "🔄 Pulling infra..."
git pull --ff-only

# 2. Субмодули — на последние коммиты master (ссылки в infra с сервера не коммитим)
log "🔄 Updating submodules to latest remote..."
git submodule sync --recursive
git submodule update --init --recursive --remote
git submodule status | tee -a "$LOG_FILE"

# 3. Docker
log "🐳 Building images..."
docker compose build --pull

log "🔄 (Re)starting services..."
docker compose up -d --remove-orphans

# 4. Миграции базы (migrate-mongo, идемпотентно)
log "🗃  Applying migrations..."
sleep 5
docker compose exec -T backend npm run migrate:up 2>&1 | tee -a "$LOG_FILE"

# 4. Чистка
log "🧹 Pruning old images..."
docker image prune -f

log "✅ Deployment completed!"
