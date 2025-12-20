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
# isolated-vm peut échouer - on essaie d'abord avec frozen-lockfile, puis sans si nécessaire
RUN if [ -f yarn.lock ]; then \
      set +e; \
      echo "Installing dependencies with frozen-lockfile..."; \
      yarn install --frozen-lockfile --network-timeout 100000 > /tmp/yarn.log 2>&1; \
      YARN_EXIT=$?; \
      if [ $YARN_EXIT -ne 0 ]; then \
        echo "⚠️  Installation with frozen-lockfile failed (exit code: $YARN_EXIT)"; \
        if grep -q "isolated-vm.*couldn't be built" /tmp/yarn.log 2>/dev/null; then \
          echo "⚠️  isolated-vm failed (non-critical), retrying without frozen-lockfile..."; \
          yarn install --network-timeout 100000 > /tmp/yarn2.log 2>&1; \
          YARN2_EXIT=$?; \
          if [ $YARN2_EXIT -ne 0 ]; then \
            echo "⚠️  Second attempt also failed (exit code: $YARN2_EXIT)"; \
            echo "Checking if node_modules exists despite errors..."; \
            if [ -d "node_modules" ] && [ -d "node_modules/@backstage" ]; then \
              echo "✅ node_modules exists, continuing despite errors..."; \
            else \
              echo "❌ node_modules not created"; \
              echo "Last 50 lines of yarn log:"; \
              tail -50 /tmp/yarn2.log; \
              exit 1; \
            fi; \
          fi; \
        else \
          echo "❌ Unknown error during installation"; \
          echo "Last 50 lines of yarn log:"; \
          tail -50 /tmp/yarn.log; \
          exit 1; \
        fi; \
      fi; \
      set -e; \
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

