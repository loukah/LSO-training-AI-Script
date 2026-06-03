# Systeme LSO DCS - trigger zones

## Installation

1. Ajoute `lso_system_initial_points.lua` dans ta mission avec un trigger `DO SCRIPT FILE`.
2. Place le centre d'une trigger zone sur le seuil de piste que tu veux utiliser.
3. Nomme la zone avec `LSO:` suivi du cap d'appontage.

```text
LSO:245
```

Le centre de la zone donne les coordonnees du seuil. Le rayon de la zone est ignore par le script.

## Detection aeroport / piste

Le script reprend la logique du locator:

1. il cherche l'aeroport DCS le plus proche du seuil;
2. il cherche la piste correspondant au cap donne;
3. il essaie `DCS getRunways`;
4. puis `DCS getDesc`;
5. puis la table manuelle dans le Lua: `LSO.manualRunwaysByAirbase`.

Si aucune piste ne correspond au cap dans la tolerance de 15 degres, le message affiche que la piste est introuvable.

## Exemple de message

```text
LSO: script lance OK
1 piste(s) detectee(s):
- Kobuleti / RWY25 | cap 245 | seuil X ... Z ... | elev ... | AD 0.4 km | ecart cap 1 | table Lua
```

## Options utiles

- `LSO:245`: cap d'appontage.
- `gs=3.5`: angle du plan de descente.
- `width=45`: largeur de piste en metres.
- `corner=L` ou `corner=R`: si le centre de zone est place sur un coin du seuil.
- `range=5000`: distance de detection avant le seuil.
- `lat=150`: demi-largeur laterale de detection au seuil.
- `minspd=105 maxspd=150`: fenetre de vitesse optionnelle en noeuds.

Le systeme fonctionne pour les joueurs bleu et rouge et ne depend pas d'un type d'avion precis.
