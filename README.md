# Spirit Tech Revolution — Infrastructure partagée

Infra commune à tous les projets Spirit Tech, déployée sur un VPS unique.
Un seul `docker compose up` démarre l'ensemble des services.

## Services

| Service | URL | Description |
|---|---|---|
| Keycloak 26 | `https://auth.spirittechrevolution.com` | IAM — un realm par projet |
| Traefik v3 | `https://traefik.spirittechrevolution.com` | Reverse proxy + SSL Let's Encrypt |
| pgAdmin 4 | `https://db.spirittechrevolution.com` | Gestion des bases PostgreSQL |
| MinIO console | `https://minio.spirittechrevolution.com` | Object storage S3 — interface web |
| MinIO API S3 | `https://storage.spirittechrevolution.com` | Endpoint S3 pour les backends |
| Dozzle | `https://logs.spirittechrevolution.com` | Logs temps réel des containers |

## Prérequis

- VPS : `155.117.40.193` (spirit-tech-revolution-vps)
- Docker + Docker Compose installés
- DNS wildcard `*.spirittechrevolution.com` → `155.117.40.193` (configuré sur OVH)
- Ports 80 et 443 ouverts sur le VPS

## Première installation

```bash
git clone <repo> /opt/infra
cd /opt/infra

# 1. Créer le .env
cp .env.example .env
nano .env   # remplir toutes les valeurs

# 2. Initialiser (réseau Docker + acme.json)
chmod +x deploy.sh
./deploy.sh --init

# 3. Démarrer
./deploy.sh
```

## Mise à jour

```bash
cd /opt/infra
./deploy.sh
```

Ou manuellement :

```bash
git pull
docker compose --env-file .env up -d
```

## Architecture réseau

```
Internet
   │  HTTPS 443
   ▼
Traefik (réseau: proxy)
   ├── auth.spirittechrevolution.com  → keycloak:8080
   ├── db.spirittechrevolution.com    → pgadmin:80
   ├── minio.spirittechrevolution.com → minio:9001
   ├── storage.spirittechrevolution.com → minio:9000
   └── logs.spirittechrevolution.com → dozzle:8080

Réseau infra-internal (isolé, pas d'accès externe)
   ├── postgres-shared:5432
   ├── keycloak → postgres-shared
   └── pgadmin  → postgres-shared
```

Deux réseaux Docker :
- `proxy` — externe, partagé avec tous les projets. Traefik écoute dessus.
- `infra-internal` — interne, postgres et les services qui s'y connectent.

## Bases de données

Instance PostgreSQL 17 unique, une base par projet :

| Base | Projet | Schéma |
|---|---|---|
| `db-keycloak` | Keycloak | — |
| `db-dinthialma` | Dinthialma | `dinthialma` |
| `db-pharmagest` | PharmaGest | `pharmagest` |

Les bases sont créées automatiquement au premier démarrage via `postgres/init-db.sh`.

Pour ajouter un nouveau projet : éditer `postgres/init-db.sh` et ajouter un bloc `SELECT 'CREATE DATABASE...'`.

## Connecter un projet à l'infra

Dans le `docker-compose.yml` du projet, rejoindre les réseaux existants :

```yaml
networks:
  proxy:
    external: true
  infra-internal:
    external: true
    name: infra-internal
```

Variables d'environnement backend :
```env
DB_HOST=postgres-shared
DB_PORT=5432
KEYCLOAK_URL=https://auth.spirittechrevolution.com
MINIO_ENDPOINT=http://minio:9000
```

## Variables d'environnement (.env)

Voir `.env.example` pour la liste complète. Fichier `.env` jamais commité (`.gitignore`).

| Variable | Description |
|---|---|
| `INFRA_DOMAIN` | Domaine racine (`spirittechrevolution.com`) |
| `ACME_EMAIL` | Email pour les certificats Let's Encrypt |
| `TRAEFIK_BASIC_AUTH` | Basic auth du dashboard Traefik (généré avec `htpasswd`) |
| `POSTGRES_USER/PASSWORD` | Credentials PostgreSQL partagé |
| `KEYCLOAK_ADMIN_USER/PASSWORD` | Admin Keycloak |
| `PGADMIN_EMAIL/PASSWORD` | Admin pgAdmin |
| `MINIO_ROOT_USER/PASSWORD` | Admin MinIO |

## Commandes utiles

```bash
# Statut des containers
docker compose ps

# Logs d'un service
docker logs -f keycloak
docker logs -f traefik

# Vérifier les routeurs Traefik
curl -s http://localhost:8080/api/http/routers | python3 -m json.tool | grep -E '"name"|"rule"'

# Renouveler les certificats (vider acme.json et redémarrer Traefik)
rm acme.json && touch acme.json && chmod 600 acme.json
docker compose restart traefik
```

## Notes

- **Keycloak** : le healthcheck utilise bash `/dev/tcp` (pas de `curl` dans l'image UBI9).
  Un container `unhealthy` est retiré du routing Traefik — surveiller avec `docker ps`.
- **acme.json** : doit exister avec `chmod 600` avant le premier démarrage de Traefik.
  Si vide ou corrompu, supprimer et recréer pour forcer la ré-émission des certificats.
- **Scaling** : un seul container Keycloak (mode standalone). Pour le clustering,
  ajouter `KC_CACHE=ispn` et plusieurs replicas.
