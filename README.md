# Timetables 1.6 — README

Présentation
- Module Transport Fever 2 fournissant une gestion avancée de grilles horaires (timetables) pour lignes et véhicules.
- Objectif : offrir des contraintes de départ/arrivée, des stratégies de debounce et d'auto-debounce, et une interface GUI pour gérer les horaires en jeu.

Prérequis et compatibilité
- Transport Fever 2 (version compatible avec les mods scriptés).
- Installer le dossier du mod dans le répertoire mods de TF2 (voir Instructions d'installation).
- Version du mod : v1.6 (minorVersion = 6). Conçu pour être rétrocompatible avec les formats de timetable hérités ; sauvegardez vos parties avant test.

Fichiers clés (références)
- mod.lua — métadonnées du mod et version.
- res/config/game_script/timetable_gui.lua — code de l'interface utilisateur et intégration GUI.
- res/scripts/timetable.lua — logique centrale des timetables (ArrDep, debounce, cache, etc.).
- tests/timetable_fusion_tests.lua — tests unitaires locaux ajoutés pour non-régression.
- docs/CHANGELOG.md — notes de release v1.6.


Fonctionnalités disponibles (ce qui est implémenté)
- ArrDep : contraintes d'arrivée/départ (ArrDep) avec gestion des véhicules en attente.
- Debounce : mécanisme de délai (debounce) pour regrouper ou séparer départs selon règles configurées.
- Auto-debounce : variante automatique liée à la fréquence de la ligne.
- GUI : interface pour visualiser/éditer timetables, déclencher envois d'événements et initialiser le cache des lignes avec timetable.
- Cache des lignes : `timetable.initializeTimetableLinesCache()` et API associées pour gestion interne des lignes actives.

Notes de compatibilité ascendante
- Le code effectue une normalisation des payloads de timetable à la charge :
  - conversions d'IDs fournis en string → nombres (si applicable).
  - migration automatique du champ legacy `conditions.condition` → `conditions.type`.
  - initialisation défensive des champs manquants (`stations`, `ArrDep`, `vehiclesWaiting`).
- Recommandation : faire une sauvegarde du dossier mods et des saves avant tester la mise à jour en production.

Usage rapide (déclencher / vérifier)
- Ouvrir l'interface définie dans res/config/game_script/timetable_gui.lua pour éditer et appliquer les timetables.
- Les changements dans l'UI déclenchent `timetable.setTimetableObject(...)` et posent le flag `timetableChanged` pour envoi d'événements GUI.
- Les cas de départ automatique sont gérés dans res/scripts/timetable.lua (fonctions `departIfReady`, `readyToDepartArrDep`, `readyToDepartDebounce`, etc.).

Tests et validation locale
- Un fichier de tests unitaires est présent : tests/timetable_fusion_tests.lua. Il couvre non-régression pour : nettoyage vehiclesWaiting, initialisation du cache des lignes, comportement GUI basique et hardening des payloads.
- Les tests sont conçus pour être exécutés dans l’environnement TF2 (en jeu) ou via un runtime Lua compatible si vous avez l’environnement de test hors-jeu.

Support / signalement de bugs
- Ouvrir une issue sur le dépôt/fork que vous utilisez, en joignant : version du mod (mod.lua), brève description, étapes pour reproduire, et logs console si possible.
