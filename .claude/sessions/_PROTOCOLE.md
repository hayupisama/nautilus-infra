<!-- RÉSERVÉ À CLAUDE CODE. Pas destiné à une lecture humaine. -->
# PROTOCOLE SESSIONS

BUT: continuité entre sessions Claude Code sur ce dépôt.
EMPLACEMENT: `.claude/sessions/AAAA-MM-JJ.md` (date locale Europe/Paris).
PLUSIEURS SESSIONS MÊME JOUR: ajouter une section `## S<n> HH:MM` au fichier du jour, ne jamais créer un 2e fichier.
CHARGEMENT: le hook SessionStart injecte le dernier fichier. Sinon lire le fichier le plus récent (tri lexical).
ÉCRITURE: commande `/cloture` en fin de session, ou dès que l'utilisateur annonce une pause.
REPRISE: commande `/reprise` = relire dernier fichier + `git log --oneline -15` + `git status`, puis résumer en 5 lignes max et proposer la prochaine action.

## FORMAT (strict, compact, pas de prose)

```
## S<n> HH:MM
etat: <vert|orange|rouge> — <1 ligne>
branche: <nom> @ <sha court>
fait:
- <action> -> <fichier|commit>
decisions:
- <décision> | raison: <courte>
en_cours:
- <tâche> | reste: <ce qui manque>
bloquants:
- <problème> | piste: <idée>
suivant:
1. <prochaine action concrète>
pieges:
- <chose à ne pas refaire / subtilité découverte>
refs: <issues, PR, fichiers clés>
```

## RÈGLES
- Max ~40 lignes par section. Supprimer les clés vides.
- Faits vérifiables uniquement (commits, fichiers, commandes lancées). Pas de spéculation.
- Jamais de secret, token, mot de passe, donnée personnelle réelle.
- Ne pas réécrire les sessions passées. Corriger une erreur = nouvelle ligne `correction:` dans la session courante.
- Rotation: au-delà de 30 fichiers, fusionner les plus anciens dans `_ARCHIVE.md` (1 ligne par session: date | état | décisions clés).
- Décision transverse (impacte d'autres dépôts) -> la reporter aussi dans le dépôt `nautilus` (docs/decisions.md) et le signaler dans `suivant`.
