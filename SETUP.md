# Guide de Setup Initial - Apollo Backstage

Ce guide vous accompagne pour initialiser l'application Backstage dans le repo apollo.

## Étape 1 : Initialiser Backstage

Exécutez la commande suivante dans le répertoire `apollo` :

```bash
npx @backstage/create-app@latest
```

### Réponses recommandées :

- **Application name** : `apollo`
- **Backend package name** : `@olympe/backend`
- **Database** : `PostgreSQL` (sera configuré via Kubernetes, pas besoin de configurer la connexion maintenant)

## Étape 2 : Configurer app-config.production.yaml

Après l'initialisation, créez ou modifiez `app-config.production.yaml` :

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
  cors:
    origin: https://apollo.olymp.ovh
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
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

proxy:
  '/github':
    target: https://api.github.com
    headers:
      Authorization: token ${GITHUB_TOKEN}
      Accept: application/vnd.github.v3+json
    allowedMethods: ['GET']

auth:
  environment: production
  providers:
    github:
      production:
        clientId: ${AUTH_GITHUB_CLIENT_ID}
        clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}
        enterpriseInstanceUrl: null

catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location]
  locations:
    - type: url
      target: https://github.com/arioual-utech/olympe/blob/main/catalog-info.yaml

kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - url: http://kubernetes.default.svc
          name: olympe
          authProvider: 'serviceAccount'
          skipTLSVerify: false
          skipMetricsLookup: false

techdocs:
  builder: 'local'
  generator:
    runIn: 'local'
  publisher:
    type: 'local'
```

## Étape 3 : Vérifier le Dockerfile

Le `Dockerfile` est déjà créé et configuré. Vérifiez qu'il est bien présent à la racine du projet.

## Étape 4 : Configurer les Secrets GitHub

1. Allez sur votre repo GitHub : Settings → Secrets and variables → Actions
2. Ajoutez le secret `ARGOCD_API_TOKEN` avec votre token ArgoCD

Pour générer un token ArgoCD :
```bash
# Via ArgoCD CLI
argocd account generate-token --account api-user

# Ou via l'interface web ArgoCD
# Settings → Accounts → api-user → Generate New Token
```

## Étape 5 : Premier Commit et Push

```bash
git add .
git commit -m "Initial Backstage setup for Apollo"
git push origin main
```

Le workflow GitHub Actions va automatiquement :
1. ✅ Builder l'image Docker
2. ✅ La pousser vers `ghcr.io/arioual-utech/backstage:latest`
3. ✅ Déclencher un sync ArgoCD

## Étape 6 : Vérifier le Déploiement

Après le premier build :

```bash
# Vérifier que l'image a été créée
# (sur GitHub, allez dans Packages)

# Vérifier le déploiement ArgoCD
kubectl get application backstage -n argocd

# Vérifier les pods
kubectl get pods -n backstage

# Vérifier les logs
kubectl logs -n backstage deployment/backstage
```

## Personnalisation (Optionnel)

### Ajouter des Plugins

Pour ajouter des plugins Backstage, modifiez :

1. `packages/app/package.json` - Ajoutez le plugin
2. `packages/app/src/App.tsx` - Importez et utilisez le plugin
3. `packages/backend/src/plugins/` - Ajoutez le plugin backend si nécessaire

Exemple pour ajouter le plugin Kubernetes :
```bash
yarn workspace app add @backstage/plugin-kubernetes
yarn workspace backend add @backstage/plugin-kubernetes-backend
```

### Configurer le Catalogue

Le catalogue est configuré pour importer depuis le repo `olympe`. Vous pouvez ajouter d'autres sources dans `app-config.production.yaml`.

## Dépannage

### Le build échoue

Vérifiez les logs du workflow GitHub Actions dans l'onglet "Actions".

### L'image ne peut pas être pullée

Assurez-vous que :
- Le secret `regcred` existe dans le namespace `backstage` (défini dans `olympe`)
- L'image est publique ou le secret a les bonnes permissions

### ArgoCD ne sync pas

Vérifiez que :
- Le secret `ARGOCD_API_TOKEN` est bien configuré
- L'URL `themis.olymp.ovh` est accessible depuis GitHub Actions
- Le nom de l'application dans ArgoCD est bien `backstage`




