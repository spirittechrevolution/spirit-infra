#!/bin/bash
# ===================================================================
# Script de déploiement / mise à jour de l'infra partagée
# Usage :
#   Première installation : ./deploy.sh --init
#   Mise à jour           : ./deploy.sh
# ===================================================================
set -e

INFRA_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$1" = "--init" ]; then
  echo "=== Initialisation première installation ==="

  # Réseau Docker partagé (tous les projets s'y connectent)
  docker network create proxy 2>/dev/null || echo "Réseau proxy déjà existant."

  # acme.json requis par Traefik pour stocker les certificats Let's Encrypt
  touch "$INFRA_DIR/acme.json"
  chmod 600 "$INFRA_DIR/acme.json"

  echo "Réseau proxy créé. Lancez maintenant : ./deploy.sh"
  exit 0
fi

echo "=== Mise à jour de l'infra Spirit Tech ==="

cd "$INFRA_DIR"

if [ ! -f .env ]; then
  echo "ERREUR : fichier .env manquant."
  echo "Créez-le avec : cp .env.example .env && nano .env"
  exit 1
fi

if [ ! -f acme.json ]; then
  echo "ERREUR : acme.json manquant. Lancez d'abord : ./deploy.sh --init"
  exit 1
fi

git pull

docker compose --env-file .env pull
docker compose --env-file .env up -d

echo ""
echo "=== Infra démarrée ==="
docker compose ps
