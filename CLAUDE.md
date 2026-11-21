# CLAUDE.md — nautilus-infra

## Rôle

Déploiement de tout le projet sur un VPS français (~8 Go RAM) avec k3s.

```
charts/
  nautilus-api/        # API Quarkus (image native en prod)
  keycloak/            # ou chart amont épinglé + values
  postgresql/          # PostgreSQL + PostGIS
  minio/               # stockage objet (justificatifs chauffeurs, chiffrés)
  osrm/                # itinéraires, extrait OSM Pays de la Loire
  observability/       # Prometheus, Loki, Grafana (léger)
environments/
  recette/values-*.yaml
  production/values-*.yaml
secrets/               # fichiers chiffrés SOPS (age) uniquement
scripts/               # bootstrap k3s, sauvegarde, restauration
```

## État

Environnement local en place (U44, U45) : `local/compose.yaml` (PostGIS + Keycloak, realm `nautilus` importé depuis `local/keycloak/import/` ; OSRM sur l'extrait Pays de la Loire, préparé automatiquement par `local/osrm/`), vérifié par `local/scripts/verify.sh` et le workflow `local-env`. VPS : bootstrap k3s + cert-manager, puis chart `nautilus-api` (en attente du VPS).

## Règles

- Traefik (inclus dans k3s) + cert-manager pour le TLS.
- Recette et production dans des namespaces séparés.
- Secrets : uniquement chiffrés avec SOPS ; jamais de secret en clair, même temporairement.
- Charts amont : versions épinglées.
- Requests/limits mémoire sur chaque pod : le budget RAM est serré (k3s + Keycloak + OSRM + PostgreSQL + Grafana + recette). Surveiller et documenter la consommation.
- Sauvegarde quotidienne chiffrée PostgreSQL + MinIO hors du VPS ; script de restauration testé mensuellement.
- Déploiement depuis GitHub Actions (images sur GHCR, `helm upgrade --install`).

## Contexte projet (commun)

- Projet : **Nautilus** (nom de code), appli VTC marketplace dédiée aux PMR, lancement à Nantes (métropole + aéroport + gare).
- Side project, développeur unique, budget quasi nul, < 5 h/semaine, démarrage janvier 2027.
- Référence fonctionnelle : `nautilus/docs/cahier-des-charges.md`. Glossaire : `nautilus/docs/glossaire.md`. Décisions transverses : `nautilus/docs/decisions.md`.
- Lot en cours : **lot 0 – prototype** avec données fictives. Objectif : un prototype fonctionnel et démontrable. La validation terrain est faite par un autre intervenant.
- Licence : PolyForm Noncommercial 1.0.0. Ne jamais ajouter de dépendance dont la licence interdit cet usage.

## Règles transverses

- Langue : identifiants de code en anglais (voir glossaire FR -> EN) ; docs, commits et messages à l'utilisateur en français.
- Commits : Conventional Commits.
- Mode de travail : Claude développe seul et pilote le projet en Scrum autogéré. Fouad est le client (MOA/MOE) : il supervise et teste, il ne lit pas les tickets. Processus complet : `nautilus/.claude/scrum/PROCESS.md` (à lire avant toute action sur le backlog).
- Autonomie : branches, commits, push de branches, PR, fusion après CI verte, gestion des issues et du tableau de projet sont autorisés sans demander. Demander à Fouad avant : déploiement en production, secret ou service payant, publication sur les stores, opération destructive (force push, suppression), changement de périmètre ou de règle métier du cahier des charges.
- Accessibilité WCAG 2.2 AA obligatoire sur toute interface : c'est un critère d'acceptation, pas une option.
- Données : profil de besoins = besoins fonctionnels, jamais de pathologie. Aucune donnée personnelle réelle dans le code, les tests ou les fixtures.
- Secrets : jamais dans le dépôt (même privé).
- Contrat d'API : la source de vérité est `nautilus-contrat-api`. Ne jamais modifier un client généré à la main.

## Sessions Claude Code

- Au démarrage, le dernier résumé est injecté automatiquement (hook SessionStart). Commande `/reprise` pour reprendre proprement.
- En fin de session, ou quand l'utilisateur annonce une pause : `/cloture`.
- Protocole : `.claude/sessions/_PROTOCOLE.md`. Ce dossier est réservé à Claude Code ; ne pas le mentionner dans la documentation destinée aux humains.
