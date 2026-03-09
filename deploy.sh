#!/usr/bin/env bash
set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}→ infra deploy script${NC}"

# 1. Обновляем сам infra-repo
echo "Pulling latest infra..."
git pull --ff-only || { echo -e "${RED}git pull failed${NC}"; exit 1; }

# 2. Обновляем все submodules (самый безопасный вариант)
echo "Updating submodules..."
git submodule sync --recursive
git submodule update --init --recursive --remote
# --remote тянет последние коммиты с main/master веток submodule-ов

# Альтернатива: если хочешь фиксировать конкретные коммиты — коммить изменения в .gitmodules вручную

# 3. Пересобираем и поднимаем compose (без downtime для уже работающих сервисов)
echo "Docker compose up --build ..."
docker compose up -d --build --remove-orphans

# 4. Удаляем всё ненужное (очень аккуратно!)
echo "Pruning unused Docker objects..."

# Самое безопасное: только stopped containers, dangling images, unused networks
docker system prune -f --filter "until=24h"

# Если очень хочется volumes тоже чистить (осторожно! потеряешь данные неиспользуемых volume)
# docker system prune -f --volumes --filter "until=720h"   # старше 30 дней

# Более агрессивно, но часто — удаляем все stopped + dangling + cache
# docker builder prune -f --all --filter "until=168h"     # cache старше недели

echo -e "${GREEN}Deploy finished successfully ✓${NC}"
echo "→ Check logs: docker compose logs -f"