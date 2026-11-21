# Environnement local : PostgreSQL/PostGIS + Keycloak

Pour développer et tester l'authentification sans VPS. Tout tourne dans Docker, uniquement sur `127.0.0.1`.

| Service | Image (épinglée par digest) | Adresse | Mémoire max |
| --- | --- | --- | --- |
| PostgreSQL 16 + PostGIS 3.4 | `postgis/postgis:16-3.4` (même image que les Dev Services de l'API) | `localhost:5432`, base `nautilus` | 512 Mo |
| Keycloak 26.8.2 (mode dev, stockage dans PostgreSQL, base `keycloak`) | `quay.io/keycloak/keycloak:26.8.2` | http://localhost:8180 (santé : http://localhost:9000/health/ready) | 1 Go |

Consommation mesurée au repos : Keycloak ~660 Mo, PostgreSQL ~140 Mo.

## Prérequis

- Docker Desktop (ou Docker Engine) avec Docker Compose v2.
- Pour les scripts : bash (Git Bash sous Windows), openssl, curl, Python 3.

## Configuration (une seule fois, à faire par chaque personne qui clone le dépôt)

Aucune valeur sensible n'est versionnée, même fictive : identifiants et mots de passe vivent uniquement
dans `local/.env`, propre à votre poste et ignoré par git. `.env.example` est le modèle, sans valeurs.

Au choix :

- automatique : `./scripts/init-env.sh` crée `.env` et remplit chaque variable vide avec une valeur aléatoire ;
- manuel : `cp .env.example .env`, puis remplir chaque variable vide en suivant les commentaires du fichier.

Ne jamais commiter `.env`, ne jamais écrire de valeur dans `.env.example`. Si une variable est vide,
`docker compose` refuse de démarrer en indiquant laquelle.

## Démarrer

Depuis le dossier `local/` :

```bash
./scripts/init-env.sh        # une seule fois (voir « Configuration »)
docker compose up -d --wait   # démarre et attend que les healthchecks soient verts (~30 s, plus au premier téléchargement)
./scripts/verify.sh           # facultatif : vérifie PostGIS, le realm, les clients et les comptes de test
```

Au premier démarrage, Keycloak importe le realm `nautilus` depuis `keycloak/import/nautilus-realm.json`.
Aux démarrages suivants, l'import est ignoré (le realm existe déjà) : voir « Réinitialiser ».

Les ports se changent dans `.env` (`POSTGRES_PORT`, `KEYCLOAK_PORT`, `KEYCLOAK_MANAGEMENT_PORT`).

## Arrêter

```bash
docker compose stop     # arrête, conserve les données
docker compose down     # arrête et supprime les conteneurs, conserve les données (volume)
```

## Réinitialiser

Supprime toutes les données (base applicative, utilisateurs et réglages Keycloak), puis réimporte le realm versionné :

```bash
docker compose down -v
docker compose up -d --wait
```

À faire après toute modification de `nautilus-realm.json`.

## Realm `nautilus`

- Rôles de realm (cumulables) : `passenger`, `booker`, `driver`, `admin`. Ils figurent dans le jeton d'accès sous `realm_access.roles`.
- Inscription en libre-service désactivée ; langue par défaut : français.
- Clients publics, Authorization Code + PKCE (S256 imposé), sans flux direct par mot de passe :

| Client | Usage | URI de redirection autorisées |
| --- | --- | --- |
| `nautilus-passenger-app` | Appli passager (Flutter) | `fr.nautilus.passenger:/oauthredirect`, `http://localhost:*` |
| `nautilus-driver-app` | Appli chauffeur (Flutter) | `fr.nautilus.driver:/oauthredirect`, `http://localhost:*` |
| `nautilus-back-office` | Back-office (Angular) | `http://localhost:4200/*` |
| `nautilus-dev-tools` | **Local uniquement** : obtenir un jeton en ligne de commande (flux mot de passe) pour tester l'API | aucune |

Émetteur (issuer) : `http://localhost:8180/realms/nautilus`.

## Comptes de test

Données entièrement fictives (domaine réservé `.test`). Mot de passe commun : la valeur de
`KEYCLOAK_TEST_USERS_PASSWORD` dans votre `.env`, injectée à l'import du realm (le fichier du realm ne contient
qu'un emplacement `${KEYCLOAK_TEST_USERS_PASSWORD}`). Après l'avoir changée : réinitialiser.

| Identifiant | E-mail | Rôle |
| --- | --- | --- |
| `passenger1` | passenger1@nautilus.test | `passenger` |
| `booker1` | booker1@nautilus.test | `booker` |
| `driver1` | driver1@nautilus.test | `driver` |
| `admin1` | admin1@nautilus.test | `admin` |

Console d'administration : http://localhost:8180/admin (identifiants : `KEYCLOAK_ADMIN_USER` / `KEYCLOAK_ADMIN_PASSWORD` de votre `.env`).

Tester une connexion dans le navigateur : http://localhost:8180/realms/nautilus/account puis se connecter avec un compte ci-dessus.

Obtenir un jeton en ligne de commande (depuis `local/`, le mot de passe est lu dans `.env`) :

```bash
set -a; . ./.env; set +a
curl -s http://localhost:8180/realms/nautilus/protocol/openid-connect/token \
  -d grant_type=password -d client_id=nautilus-dev-tools \
  -d username=passenger1 --data-urlencode "password=$KEYCLOAK_TEST_USERS_PASSWORD"
```

## Brancher l'API (nautilus-api)

En profil dev, à la place des Dev Services :

```properties
%dev.quarkus.datasource.devservices.enabled=false
%dev.quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/nautilus
%dev.quarkus.oidc.devservices.enabled=false
%dev.quarkus.oidc.auth-server-url=http://localhost:8180/realms/nautilus
```

Identifiant et mot de passe de la base se passent par variables d'environnement (`QUARKUS_DATASOURCE_USERNAME`
et `QUARKUS_DATASOURCE_PASSWORD`, valeurs de `POSTGRES_USER` et `POSTGRES_PASSWORD` de votre `.env`), jamais dans un fichier versionné.

## Sécurité

- `.env` est ignoré par git ; `.env.example` ne contient aucune valeur sensible (emplacements vides à remplir).
- Les scripts lisent l'environnement et n'affichent jamais les valeurs ; la CI génère un `.env` aléatoire à chaque exécution.
- Les comptes de test et le client `nautilus-dev-tools` n'existent qu'en local : la recette et la production auront leur propre realm, avec des secrets chiffrés (SOPS).
