#!/usr/bin/env bash
set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}→ infra deploy script${NC}"
echo "   Frontend submodule: git@github.com:Jet-Green/nmp.git"
echo "   Backend  submodule: git@github.com:Jet-Green/nmp-backend.git"
echo ""

# 1. Обновляем сам infra-repo
echo "Pulling latest infra..."
git pull --ff-only || { echo -e "${RED}git pull failed${NC}"; exit 1; }

# 2. Обновляем все submodules
echo "Updating submodules..."
git submodule sync --recursive

# Проверяем, инициализированы ли submodule'ы вообще
if [ ! -d "frontend/.git" ] || [ ! -d "backend/.git" ]; then
    echo "Submodules not initialized yet → performing initial checkout..."
    git submodule update --init --recursive || {
        echo -e "${RED}Ошибка инициализации submodule-ов${NC}"
        echo "Возможные причины:"
        echo "  1. SSH-ключ не добавлен в ssh-agent"
        echo "  2. Deploy key не добавлен в репозитории Jet-Green/nmp и nmp-backend"
        echo "  3. .gitmodules содержит https вместо git@"
        echo ""
        echo "Попробуйте вручную:"
        echo "   ssh-add ~/.ssh/id_ed25519   # или ваш ключ"
        echo "   git submodule update --init --recursive"
        exit 1
    }
else
    # уже были инициализированы → просто обновляем до последних коммитов
    git submodule update --recursive --remote || {
        echo -e "${RED}Ошибка обновления submodule-ов${NC}"
        exit 1
    }
fi

# 3. Пересобираем и поднимаем compose
echo "Docker compose up --build ..."
docker compose up -d --build --remove-orphans

# 4. Удаляем ненужное (осторожно)
echo "Pruning unused Docker objects..."
docker system prune -f --filter "until=24h"

# Опционально (раскомментируй при необходимости):
# echo "Cleaning old build cache..."
# docker builder prune -f --filter "until=168h"

echo -e "${GREEN}Deploy finished successfully ✓${NC}"
echo "→ Check logs:     docker compose logs -f"
echo "→ Follow specific: docker compose logs -f frontend backend mongo"
echo ""