#!/usr/bin/env bash
# Cree local/.env a partir de .env.example et remplit chaque variable vide avec une valeur aleatoire.
# Aucune valeur n'est affichee ; .env est ignore par git. Ne remplace jamais un .env existant.
# Usage (depuis local/) : ./scripts/init-env.sh
set -euo pipefail

cd "$(dirname "$0")/.."
if [ -e .env ]; then
  echo ".env existe deja : rien a faire (le supprimer pour le regenerer, puis docker compose down -v)."
  exit 0
fi

rand() { openssl rand -hex "$1"; }
umask 077
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    *_USER=)     printf '%su_%s\n' "$line" "$(rand 4)" ;;
    *_PASSWORD=) printf '%s%s\n' "$line" "$(rand 16)" ;;
    *=)          echo "Variable vide non geree par ce script : ${line%=}" >&2; exit 1 ;;
    *)           printf '%s\n' "$line" ;;
  esac
done < .env.example > .env
echo ".env cree avec des valeurs aleatoires (consultables dans local/.env)."
