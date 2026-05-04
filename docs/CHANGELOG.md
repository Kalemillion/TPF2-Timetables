# CHANGELOG

## v1.6

Résumé
- Consolidation des apports de H3lyx (v1.4) et ConstaJ (v1.5).
- Objectif : stabilité, compatibilité ascendante, et corrections GUI/logic.

Principales modifications
- Hardening et compatibilité
  - Renforcement de `timetable.setTimetableObject` pour gérer les payloads malformés (non-table) et normaliser les IDs de ligne/station fournis en string.
  - Migration automatique de champs legacy `conditions.condition` → `conditions.type`.
  - Initialisation défensive des champs `stations`, `ArrDep`, `vehiclesWaiting` pour éviter nil errors.
  - GUI: `handleEvent` ignore proprement les `timetableUpdate` malformés et logge l’événement au lieu de planter.

- Comportement de départ / caches
  - Nettoyage explicite de l’entrée `vehiclesWaiting[vehicle] = nil` dans `departIfReady` (ArrDep) pour éviter que des véhicules partis gardent des allocations de créneaux.
  - Ajout d’un cache des lignes avec timetable: `timetable.initializeTimetableLinesCache()`, `getCachedTimetableLines()`, `addLineToTimetableCache()`, `removeLineFromTimetableCache()` ; initialisation appelée au chargement GUI.
  - `timetable_gui` : le flag `timetableChanged` est correctement positionné sur événements et remis à false après envoi.

- Tests & CI (local)
  - Ajout de `tests/timetable_fusion_tests.lua` couvrant:
    - nettoyage `vehiclesWaiting` dans `departIfReady`,
    - initialisation et contenu du cache `timetableLinesCache`,
    - comportement GUI: `handleEvent` → `timetable.setTimetableObject` → `guiUpdate` envoi d’événement,
    - hardening : payload malformé et migration legacy `condition` → `type`.
  - Harmonisation des require/package.loaded dans les suites de tests H3lyx/ConstaJ vers les chemins canoniques (`timetable`, `timetable_helper`, `guard`).

Notes techniques et compatibilité
- Rétrocompatibilité : les formats de timetable avec IDs en string ou champ legacy `condition` sont acceptés et normalisés au chargement.
- Runtime tests : les tests unitaires sont prévus pour être exécutés dans l’environnement TF2 (en jeu). Un runtime Lua standalone n’est pas obligatoire pour la validation initiale.
- Recommandation de déploiement : tester en environnement local TF2 (sauvegarde du dossier mods), lancer les interactions GUI et surveiller la console pour les logs d’erreur ou messages de compatibilité.
