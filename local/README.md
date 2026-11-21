# Environnement local : PostgreSQL/PostGIS + Keycloak + OSRM

Pour développer et tester l'authentification et le calcul d'itinéraires sans VPS ni quota. Tout tourne dans Docker, uniquement sur `127.0.0.1`.

| Service | Image (épinglée par digest) | Adresse | Mémoire max |
| --- | --- | --- | --- |
| PostgreSQL 16 + PostGIS 3.4 | `postgis/postgis:16-3.4` (même image que les Dev Services de l'API) | `localhost:5432`, base `nautilus` | 512 Mo |
| Keycloak 26.8.2 (mode dev, stockage dans PostgreSQL, base `keycloak`) | `quay.io/keycloak/keycloak:26.8.2` | http://localhost:8180 (santé : http://localhost:9000/health/ready) | 1 Go |
| OSRM 26.11.0 (profil voiture, algorithme MLD), extrait OSM Pays de la Loire | `ghcr.io/project-osrm/osrm-backend:v26.11.0-debian` | http://127.0.0.1:5000 | 1 Go (préparation ponctuelle : 3 Go) |

Consommation mesurée au repos : Keycloak ~660 Mo, PostgreSQL ~140 Mo, OSRM ~500 Mo (détails : « OSRM »).

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
docker compose up -d --wait   # démarre et attend que les healthchecks soient verts (~30 s ; premier démarrage : voir « OSRM »)
./scripts/verify.sh           # facultatif : vérifie PostGIS, le realm, les clients et les comptes de test
```

Au premier démarrage, Keycloak importe le realm `nautilus` depuis `keycloak/import/nautilus-realm.json`.
Aux démarrages suivants, l'import est ignoré (le realm existe déjà) : voir « Réinitialiser ».

Sans OSRM (authentification seule) : `docker compose up -d --wait postgres keycloak`, puis `./scripts/verify.sh --sans-osrm`.

Les ports se changent dans `.env` (`POSTGRES_PORT`, `KEYCLOAK_PORT`, `KEYCLOAK_MANAGEMENT_PORT`, `OSRM_PORT`).

Nom du projet compose : `nautilus-local` (fixé dans `compose.yaml`, d'où les volumes `nautilus-local_postgres-data` et
`nautilus-local_osrm-data`). Pour lancer une seconde pile isolée (autre clone, essais), changer le nom et les ports :
`COMPOSE_PROJECT_NAME=nautilus-essai docker compose up -d --wait` (les scripts respectent cette variable).

## Arrêter

```bash
docker compose stop     # arrête, conserve les données
docker compose down     # arrête et supprime les conteneurs, conserve les données (volume)
```

## Réinitialiser

Supprime les données de la base applicative et de Keycloak, puis réimporte le realm versionné, **sans toucher aux données OSRM**
(dont la préparation est longue) :

```bash
docker compose down
docker volume rm nautilus-local_postgres-data
docker compose up -d --wait
```

`docker compose down -v` supprime en plus les données OSRM : l'extrait sera retéléchargé et préparé au démarrage suivant.

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

## OSRM

Distances et durées routières (profil voiture) sur l'extrait OpenStreetMap Pays de la Loire de Geofabrik.

### Données

- Extrait daté du 1er janvier 2026 (`pays-de-la-loire-260101.osm.pbf`, ~360 Mo), conservé durablement par Geofabrik :
  les résultats sont reproductibles d'un poste à l'autre. Son empreinte MD5 est vérifiée après téléchargement.
- Préparation automatique dans `docker compose up`, en trois services enchaînés :
  `osrm-download` (téléchargement) -> `osrm-prepare` (`osrm-extract`, `osrm-partition`, `osrm-customize`) -> `osrm` (serveur).
- Relançable : les deux premiers services ne refont rien si les données du volume `osrm-data` correspondent déjà à
  l'extrait, au profil et à la version d'OSRM (fichiers témoins `download.ok` et `prepare.ok`) ; ils s'arrêtent en quelques secondes.
- Premier démarrage : téléchargement (~8 min ici, le débit du serveur Geofabrik étant d'environ 0,7 Mo/s) puis préparation ~45 s (poste de développement, 20 cœurs).
- Changer d'extrait (plus récent, autre région) : renseigner `OSRM_PBF_URL` et `OSRM_PBF_MD5` (contenu du fichier `.md5` publié à côté
  de l'extrait) dans `.env`, puis `docker compose up -d --wait` : le téléchargement et la préparation se refont d'eux-mêmes.
- Forcer une nouvelle préparation : `docker compose down`, `docker volume rm nautilus-local_osrm-data`, puis redémarrer.
- Disque : ~1 Go dans le volume (extrait compris).
- Licence des données : © contributeurs OpenStreetMap, ODbL (attribution à afficher sur toute carte ou résultat présenté).

### Mémoire

| Étape | Limite | Mesuré |
| --- | --- | --- |
| Préparation (`osrm-prepare`, une seule fois) | 3 Go (`OSRM_PREPARE_MEMORY`) | pic ~2,1 Go (2,4 Go selon le journal d'OSRM) |
| Serveur `osrm` | 1 Go (`OSRM_MEMORY`) | ~500 Mo au repos |

Impact sur le budget : la pile locale complète passe de ~0,8 Go à ~1,4 Go au repos (limites cumulées : 2,5 Go).
Pour le VPS (~8 Go), la préparation devra se faire hors du VPS (CI ou poste) : seul le serveur y tournera.

### Temps de réponse (trajet nantais)

Trajet de référence : gare de Nantes (sortie sud, `-1.5418,47.2172`) -> aéroport Nantes Atlantique (`-1.6108,47.1532`).

```bash
curl -s "http://127.0.0.1:5000/route/v1/driving/-1.5418,47.2172;-1.6108,47.1532?overview=false"
```

Mesuré le 21/11/2026 (`./scripts/verify.sh`, 20 requêtes successives, poste de développement sous Docker Desktop) :
itinéraire de 14 km / 23 min, réponse médiane **2 ms** (max 2 ms) côté client, calcul ~0,5 ms côté serveur (journal d'OSRM).
Sous Windows, appeler `127.0.0.1` plutôt que `localhost` : `localhost` tente d'abord l'IPv6 (`::1`), sur lequel rien
n'écoute, et ajoute ~200 ms à chaque requête (mesuré : 210 ms au lieu de 2 ms).

`verify.sh` contrôle aussi la plausibilité de l'itinéraire (entre 8 et 25 km), une matrice 3x3 (`/table`) et un temps médian sous 500 ms.

Autres services utiles : `/table/v1/driving/...` (matrice de durées, jusqu'à 1000 points), `/nearest/v1/driving/...`.
Documentation de l'API : https://project-osrm.org/docs/v5.24.0/api/

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
