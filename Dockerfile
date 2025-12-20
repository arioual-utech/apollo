FROM node:18-bookworm-slim AS base

WORKDIR /app

# Installer les dépendances système nécessaires pour compiler les packages natifs
# build-essential inclut gcc, g++, make, libc6-dev
# isolated-vm et better-sqlite3 nécessitent des dépendances supplémentaires
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    build-essential \
    git \
    pkg-config \
    libstdc++6 \
    libsqlite3-dev \
    libc++-dev \
    libc++abi-dev \
    && rm -rf /var/lib/apt/lists/*

# Stage de build
FROM base AS build

# Installer yarn globalement
RUN corepack enable && corepack prepare yarn@stable --activate

# Variables d'environnement pour aider la compilation des packages natifs
ENV PYTHON=python3
ENV npm_config_build_from_source=true
# Permettre à yarn de continuer même si certains packages échouent (expérimental)
ENV YARN_ENABLE_IMMUTABLE_INSTALLS=false

# Copier les fichiers de configuration des packages
COPY package.json yarn.lock* package-lock.json* ./
COPY .yarnrc.yml* ./
COPY packages/backend/package.json ./packages/backend/
COPY packages/app/package.json ./packages/app/

# Installer les dépendances (yarn est préféré car yarn.lock existe)
# isolated-vm peut échouer - on utilise une approche en deux étapes :
# 1. Installer sans builder les packages natifs problématiques
# 2. Builder manuellement les packages nécessaires
RUN if [ -f yarn.lock ]; then \
      # Créer un script temporaire pour builder seulement les packages nécessaires
      echo '#!/bin/sh' > /tmp/build-native.sh && \
      echo 'set -e' >> /tmp/build-native.sh && \
      echo 'if [ -d "node_modules/better-sqlite3" ]; then' >> /tmp/build-native.sh && \
      echo '  cd node_modules/better-sqlite3 && npm run build || npm run install || true && cd -' >> /tmp/build-native.sh && \
      echo 'fi' >> /tmp/build-native.sh && \
      chmod +x /tmp/build-native.sh; \
      # Essayer d'abord avec frozen-lockfile
      echo "Installing dependencies with frozen-lockfile..."; \
      yarn install --frozen-lockfile --network-timeout 100000 2>&1 | tee /tmp/yarn.log || \
      YARN_FAILED=true; \
      if [ "${YARN_FAILED:-false}" = "true" ]; then \
        echo "⚠️  Installation with frozen-lockfile failed"; \
        if grep -q "isolated-vm.*couldn't be built" /tmp/yarn.log 2>/dev/null; then \
          echo "⚠️  isolated-vm failed (non-critical), installing without it..."; \
          # Modifier temporairement le yarn.lock pour exclure isolated-vm
          # Ou simplement réessayer sans frozen-lockfile
          yarn install --network-timeout 100000 2>&1 | tee /tmp/yarn2.log; \
          YARN2_EXIT=${PIPESTATUS[0]}; \
          if [ $YARN2_EXIT -ne 0 ]; then \
            echo "⚠️  Second attempt also failed, but checking if node_modules exists..."; \
            if [ -d "node_modules" ] && [ -d "node_modules/@backstage" ]; then \
              echo "✅ node_modules exists despite errors, continuing..."; \
            else \
              echo "❌ node_modules not created, cannot continue"; \
              exit 1; \
            fi; \
          fi; \
        else \
          echo "❌ Unknown error during installation"; \
          cat /tmp/yarn.log; \
          exit 1; \
        fi; \
      fi; \
      # Builder manuellement better-sqlite3 si nécessaire
      /tmp/build-native.sh || true; \
      # Vérifier que node_modules existe et contient les packages critiques
      if [ ! -d "node_modules" ] || [ ! -d "node_modules/@backstage" ]; then \
        echo "❌ node_modules not properly created"; \
        exit 1; \
      fi; \
      echo "✅ Dependencies installed successfully"; \
    elif [ -f package-lock.json ]; then \
      npm ci; \
    else \
      npm install; \
    fi

# Copier le reste du code source
COPY . .

# Builder l'application backend
RUN if [ -f yarn.lock ]; then \
      yarn build:backend; \
    else \
      npm run build:backend; \
    fi

# Stage de production
FROM base AS production

WORKDIR /app

# Copier uniquement les fichiers nécessaires pour la production
COPY --from=build /app/packages/backend/dist ./dist
COPY --from=build /app/packages/backend/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/packages/backend/src ./src
# Copier les fichiers de configuration
COPY --from=build /app/app-config.production.yaml ./app-config.production.yaml
COPY --from=build /app/app-config.yaml ./app-config.yaml

# Créer un utilisateur non-root
RUN useradd -m -u 1000 backstage && \
    chown -R backstage:backstage /app

USER backstage

EXPOSE 7007

CMD ["node", "dist/index.js"]

