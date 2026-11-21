#!/usr/bin/env bash
# Cree la base et l'utilisateur de Keycloak au premier demarrage du volume PostgreSQL.
# Execute une seule fois par l'image officielle (docker-entrypoint-initdb.d), volume vide uniquement.
# Le script peut etre "source" par l'entrypoint : pas de set -u ici ; ON_ERROR_STOP arrete psql sur erreur.

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v kc_db="$KEYCLOAK_DB_NAME" -v kc_user="$KEYCLOAK_DB_USER" -v kc_pass="$KEYCLOAK_DB_PASSWORD" <<'SQL'
CREATE ROLE :"kc_user" WITH LOGIN PASSWORD :'kc_pass';
CREATE DATABASE :"kc_db" OWNER :"kc_user";
SQL
