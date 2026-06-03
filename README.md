# Carrier Landing trainer LSO 

Salut,

Voici une solution normalement simple pour les personnes souhaitant s’entraîner aux appontages sur piste, comme le font les pilotes de l’aéronavale des différentes marines du monde.

Dans ce code, vous trouverez un Airport Locator, qui permet de localiser l’aéroport et la piste utilisés pour l’appontage, ainsi qu’un système de notation LSO. Celui-ci vous guide pendant la phase d’approche et vous attribue une note selon la qualité de votre approche et de votre appontage.

Ce fichier a été entièrement codé avec Codex et Claude Code, en raison de mon manque d’expérience dans le domaine du développement informatique. À l’origine conçu pour mon usage strictement personnel, je pense qu’il peut aussi être utile à d’autres personnes.

## Fichiers

- `lso_airport_locator.lua`: script de test pour verifier qu'une trigger zone placee au seuil retrouve bien l'aeroport et la piste.
- `lso_system_initial_points.lua`: script principal de notation LSO utilisant le centre des trigger zones comme seuil de piste.
- `lso_airport_locator_README.md`: guide du locator.
- `lso_system_initial_points_README.md`: guide du systeme LSO.

## Utilisation rapide

1. Dans le Mission Editor DCS, place le centre d'une trigger zone sur le seuil de piste.
2. Nomme la zone avec le cap d'appontage, par exemple:

```text
LSO:245
```

3. Charge `lso_airport_locator.lua` pour tester la detection aeroport/piste, ou `lso_system_initial_points.lua` pour lancer la notation LSO.

Le script cherche l'aeroport le plus proche du seuil, puis essaie de trouver la piste via `DCS getRunways`, `DCS getDesc`, puis une table Lua manuelle integree.
