#!/usr/bin/env bash
# Verifie l'environnement local lance par `docker compose up` (local/compose.yaml) :
#  - conteneurs sains (healthchecks), PostGIS actif, base Keycloak creee ;
#  - realm "nautilus" importe : roles, clients PKCE S256, comptes de test ;
#  - connexion de chaque compte de test et role present dans le jeton.
# Prerequis : docker, curl, python3 (ou python). Usage : ./scripts/verify.sh (depuis local/)
# Les identifiants sont lus dans local/.env ; aucun n'est affiche.
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
# shellcheck disable=SC1091
. ./.env
set +a

KC="http://localhost:${KEYCLOAK_PORT:-8180}"
# Premier interpreteur Python reellement utilisable (sous Windows, "python3" peut etre un raccourci du Store)
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then PY=$c; break; fi
done
[ -n "$PY" ] || { echo "python3 introuvable"; exit 2; }
fail=0
ok()  { printf '  OK   %s\n' "$1"; }
ko()  { printf '  ECHEC %s\n' "$1"; fail=1; }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else ko "$1"; fi; }
json() { "$PY" -c "import sys,json; d=json.load(sys.stdin); print($1)"; }

echo "Conteneurs"
for s in postgres keycloak; do
  st=$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q "$s")" 2>/dev/null || echo absent)
  if [ "$st" = healthy ]; then ok "$s healthy"; else ko "$s : $st"; fi
done

echo "PostgreSQL"
pg() { docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$1" -tAc "$2"; }
check "extension PostGIS dans $POSTGRES_DB" "[ \"\$(pg '$POSTGRES_DB' \"select count(*) from pg_extension where extname='postgis'\")\" = 1 ]"
check "requete spatiale (ST_Distance Nantes-gare / aeroport)" "[ \"\$(pg '$POSTGRES_DB' \"select ST_Distance('SRID=4326;POINT(-1.5418 47.2172)'::geography, 'SRID=4326;POINT(-1.6108 47.1532)'::geography) > 5000\")\" = t ]"
check "base $KEYCLOAK_DB_NAME creee" "[ \"\$(pg '$POSTGRES_DB' \"select count(*) from pg_database where datname='$KEYCLOAK_DB_NAME'\")\" = 1 ]"

echo "Keycloak"
check "health/ready" "curl -fsS http://localhost:${KEYCLOAK_MANAGEMENT_PORT:-9000}/health/ready | grep -q UP"
check "decouverte OIDC du realm nautilus" "curl -fsS $KC/realms/nautilus/.well-known/openid-configuration | grep -q '\"issuer\":\"$KC/realms/nautilus\"'"

admin_token=$(curl -fsS "$KC/realms/master/protocol/openid-connect/token" \
  --data-urlencode grant_type=password --data-urlencode client_id=admin-cli \
  --data-urlencode "username=$KEYCLOAK_ADMIN_USER" --data-urlencode "password=$KEYCLOAK_ADMIN_PASSWORD" | json "d['access_token']")
api() { curl -fsS -H "Authorization: Bearer $admin_token" "$KC/admin/realms/nautilus$1"; }

for r in passenger booker driver admin; do
  check "role $r" "api /roles/$r"
done
for c in nautilus-passenger-app nautilus-driver-app nautilus-back-office; do
  res=$(api "/clients?clientId=$c" | json "'%s %s %s %s' % (d[0]['publicClient'], d[0]['standardFlowEnabled'], d[0]['directAccessGrantsEnabled'], d[0]['attributes'].get('pkce.code.challenge.method'))")
  if [ "$res" = "True True False S256" ]; then ok "client $c public + PKCE S256"; else ko "client $c : $res"; fi
done

echo "Comptes de test (connexion + role dans le jeton)"
for pair in passenger1:passenger booker1:booker driver1:driver admin1:admin; do
  u=${pair%%:*}; r=${pair##*:}
  roles=$(curl -fsS "$KC/realms/nautilus/protocol/openid-connect/token" \
    --data-urlencode grant_type=password --data-urlencode client_id=nautilus-dev-tools \
    --data-urlencode "username=$u" --data-urlencode "password=$KEYCLOAK_TEST_USERS_PASSWORD" \
    | json "' '.join(__import__('json').loads(__import__('base64').urlsafe_b64decode(d['access_token'].split('.')[1]+'==')).get('realm_access',{}).get('roles',[]))" || echo "connexion-impossible")
  case " $roles " in *" $r "*) ok "$u -> $r" ;; *) ko "$u : roles='$roles'" ;; esac
done

if [ "$fail" != 0 ]; then echo "Des verifications ont echoue."; exit 1; fi
echo "Tout est OK."
