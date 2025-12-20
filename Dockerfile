FROM node:18-bookworm-slim AS base

WORKDIR /app

# Installer les dépendances système
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    git \
    && rm -rf /var/lib/apt/lists/*

# Stage de build
FROM base AS build

# Installer yarn globalement
RUN corepack enable && corepack prepare yarn@stable --activate

# Copier les fichiers de configuration des packages
COPY package.json yarn.lock* package-lock.json* ./
COPY packages/backend/package.json ./packages/backend/
COPY packages/app/package.json ./packages/app/

# Installer les dépendances (yarn est préféré car yarn.lock existe)
RUN if [ -f yarn.lock ]; then \
      yarn install --frozen-lockfile; \
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

