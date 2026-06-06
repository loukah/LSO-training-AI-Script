# Carrier Landing trainer LSO 

Salut,

Voici un petit mod contenant un IFLOLS, que j’ai adapté à partir d’un autre mod créé par un membre de la communauté, ainsi qu’un système de guidage et de notation textuelle et audio pour l’entraînement à l’appontage sur piste.

L’objectif est de permettre aux personnes souhaitant s’entraîner dans des conditions proches de l’entraînement des pilotes de l’aéronavale de le faire sur une piste terrestre. Cela peut aussi convenir à ceux qui, comme moi, préfèrent s’entraîner sur le plancher des vaches plutôt que sur un bateau qui bouge.

Ce fichier a été entièrement codé avec Codex et Claude Code, en raison de mon manque d’expérience en développement informatique. À l’origine, il était conçu pour mon usage strictement personnel, mais je pense qu’il peut aussi être utile à d’autres personnes.

IFLOLS de base :
https://www.digitalcombatsimulator.com/fr/files/3330472/

Un grand merci à NYChancellor, que je n’ai malheureusement pas réussi à contacter et qui a créer L'IFLOS de base. <3

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
