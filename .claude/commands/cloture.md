---
description: Écrire le résumé de fin de session (usage Claude Code uniquement)
---
<!-- RÉSERVÉ À CLAUDE CODE -->
1. Lire `.claude/sessions/_PROTOCOLE.md`.
2. Déterminer la date du jour (Europe/Paris) avec `TZ=Europe/Paris date +%F` et l'heure avec `TZ=Europe/Paris date +%H:%M`.
3. Lancer `git status`, `git log --oneline -10`, `git rev-parse --abbrev-ref HEAD`.
4. Ajouter une section au fichier `.claude/sessions/AAAA-MM-JJ.md` (le créer si absent) au FORMAT strict du protocole.
5. Appliquer la rotation si plus de 30 fichiers.
6. Committer uniquement ce fichier : `git add .claude/sessions && git commit -m "chore(session): résumé AAAA-MM-JJ"`. Ne pas pousser sans accord.
7. Confirmer en une ligne.
