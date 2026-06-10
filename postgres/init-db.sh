#!/bin/bash
# Crée les bases de données des projets hébergés sur le VPS.
# Ce script est exécuté automatiquement par PostgreSQL au premier démarrage.
# Pour ajouter un projet : ajouter un bloc SELECT ci-dessous et redémarrer
# avec `docker compose up -d` (le script ne s'exécute qu'une seule fois).
set -e

echo ">>> Initialisation des bases partagées..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    SELECT 'CREATE DATABASE "db-keycloak"'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'db-keycloak') \gexec

    SELECT 'CREATE DATABASE "db-dinthialma"'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'db-dinthialma') \gexec

    SELECT 'CREATE DATABASE "db-pharmagest"'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'db-pharmagest') \gexec
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "db-dinthialma" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS dinthialma;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "db-pharmagest" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS pharmagest;
EOSQL

echo ">>> Bases initialisées : db-keycloak, db-dinthialma, db-pharmagest"
