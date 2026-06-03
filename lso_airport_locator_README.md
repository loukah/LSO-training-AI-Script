# LSO Airport Locator

Ce script sert seulement a tester la localisation de l'aeroport.

## Utilisation

1. Place le centre de la zone de declenchement sur le seuil de piste que tu veux tester.
2. Nomme-le avec `LSO:` suivi du cap de piste:

```text
LSO:245
```

Formats acceptes:

```text
LSO:245
LSO 245
LSO-245
LSO_245
lso:245
```

Tu peux aussi garder `LSO` sans cap si tu veux seulement tester l'aeroport le plus proche du seuil.

```text
LSO
```

3. Ajoute `lso_airport_locator.lua` dans ta mission avec `DO SCRIPT FILE`.

## Message affiche

Le script affiche un message comme:

```text
LSO Airport Locator: 1 point(s) trouve(s)
- LSO:245 (trigger zone center) -> Kobuleti | piste RWY25 | cap 245 | donnees aeroport | distance 0.4 km | seuil X ... Z ...
```

Il utilise `zone.x` et `zone.y`, donc le centre de la zone de declenchement. Le rayon de la zone est ignore pour le calcul.

Il cherche l'airbase DCS la plus proche des coordonnees du seuil.

Pour trouver la piste, le script essaie dans cet ordre:

1. `airbase:getRunways()` de DCS.
2. `airbase:getDesc()` si DCS donne des infos utiles dedans.
3. la table manuelle dans le fichier Lua: `Locator.manualRunwaysByAirbase`.

Donc si DCS ne donne pas le cap des pistes, tu peux les ajouter directement dans le Lua.

Exemple dans le fichier:

```lua
[normalizeAirbaseName("Kobuleti")] = {
  { name = "RWY07", heading = 64 },
  { name = "RWY25", heading = 244 },
}
```

Le script compare le cap donne avec les pistes trouvees pour l'aeroport.

Si aucune piste DCS ne correspond assez au cap donne, il affiche:

```text
impossible de trouver la piste
```

Le script accepte un ecart de cap de 15 degres maximum. Au-dessus, il considere que ce n'est pas la bonne piste.

Si DCS ne donne pas de liste de pistes exploitable et que l'aeroport n'est pas dans la table Lua, il affiche:

```text
aucune liste de pistes disponible
```

Rappel du nom standard d'une piste:

```text
LSO:245 -> RWY25
LSO:090 -> RWY09
LSO:355 -> RWY36
```
