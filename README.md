# Apollo - Backstage pour Olympe

Backstage est une plateforme open source pour créer des portails de développeurs. Ce repo contient l'application Backstage personnalisée pour la plateforme Olympe.

## 🚀 Démarrage Rapide

### 1. Initialiser l'Application Backstage

```bash
# Dans le repo apollo
npx @backstage/create-app@latest

# Réponses recommandées :
# - Application name: apollo
# - Backend package name: @olympe/backend
# - Database: PostgreSQL (sera configuré via Kubernetes)
```

### 2. Configuration

Une fois l'application créée, configurez `app-config.yaml` ou `app-config.production.yaml` avec les variables d'environnement pour Kubernetes (voir ci-dessous).

### 3. Build et Déploiement

Le workflow GitHub Actions build et push automatiquement l'image vers `ghcr.io/arioual-utech/backstage:latest` à chaque push sur `main` ou `master`.

## 📁 Structure du Projet

```
apollo/
├── .github/
│   └── workflows/
│       └── ci.yml          # Workflow GitHub Actions
├── Dockerfile              # Image Docker multi-stage
├── package.json
├── yarn.lock
├── app-config.yaml         # Configuration développement
├── app-config.production.yaml  # Configuration production
├── packages/
│   ├── app/                # Frontend Backstage
│   └── backend/             # Backend Backstage
└── README.md
```

## ⚙️ Configuration

### app-config.production.yaml

La configuration de production utilise des variables d'environnement injectées par Kubernetes :

```yaml
app:
  title: Olympe Backstage
  baseUrl: https://apollo.olymp.ovh
  support:
    url: https://github.com/arioual-utech/olympe/issues

backend:
  baseUrl: https://apollo.olymp.ovh
  listen:
    port: 7007
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      database: ${POSTGRES_DB}
      ssl:
        rejectUnauthorized: false

integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

auth:
  environment: production
  providers:
    github:
      production:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
```

Les variables d'environnement sont définies dans le déploiement Kubernetes (repo `olympe`).

## 🐳 Build Docker

L'image est construite automatiquement via GitHub Actions. Pour builder localement :

```bash
docker build -t ghcr.io/arioual-utech/backstage:latest .
docker push ghcr.io/arioual-utech/backstage:latest
```

## 🔧 Développement Local

```bash
# Installer les dépendances
yarn install

# Démarrer le backend
yarn dev:backend

# Démarrer le frontend (dans un autre terminal)
yarn dev:app
```

## 📦 Déploiement

Le déploiement est géré par ArgoCD dans le repo `olympe`. Après chaque push sur `main`, le workflow :

1. Build l'image Docker
2. Push vers `ghcr.io/arioual-utech/backstage:latest`
3. Déclenche un sync ArgoCD automatique

## 🔐 Secrets GitHub

Configurez le secret `ARGOCD_API_TOKEN` dans Settings → Secrets and variables → Actions pour permettre le sync automatique ArgoCD.

## 📚 Documentation

- [Backstage Documentation](https://backstage.io/docs)
- [Backstage Plugins](https://backstage.io/plugins)
- [Configuration Olympe](../olympe/sources/backstage/README.md)

