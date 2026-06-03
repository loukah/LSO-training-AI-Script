# LSO Training AI Script

Scripts Lua pour DCS afin de preparer un systeme de notation LSO sur pistes terrestres.

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
