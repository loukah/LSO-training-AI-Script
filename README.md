# Carrier Lnading trainer LSO 

Hey, voici une solution normalemnt simple pour les personnes voulants s'entrainer aux appontages sur des pistes comme le font les pilotes aeronavale des differente marine du monde.
Dans ce code vous trouverez un Airport Locator qui permet de localiser l'aeroport et la piste utiliser pour l'appontage puis le systeme de notation du LSO qui vous permet de bous faire guider lors de la phase d'apporche mais aussi de vous noter sur la qualité de votre approche et appontage.

Ce fichier a était entierment codé avec Codex et Claude code due a mon manque certain dans le domaine du codage informatique ! a la base conçu pour moi je pense qu'il peux servir a d'autre gens que moi. 

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
