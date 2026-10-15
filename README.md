# Dernière Vague

Jeu de survie en vue à la première personne pour Android : des vagues de zombies de plus en plus
nombreuses, des armes à acheter au mur, une caisse mystère, des boissons d'atouts et une machine
qui améliore les armes. Fait avec Godot 4.6 (rendu « Compatibility », adapté aux GPU Mali).

**Télécharger l'APK :** [derniere-vague.apk](../../releases/latest/download/derniere-vague.apk)

## Contrôles

| Action | Manette | Clavier / souris | Tactile |
|---|---|---|---|
| Se déplacer | Stick gauche | ZQSD / WASD | Stick à gauche de l'écran |
| Regarder | Stick droit | Souris | Glisser à droite de l'écran |
| Tirer / Viser | RT / LT | Clic gauche / droit | TIR / VISER |
| Recharger, acheter, réparer | X (maintenir pour réparer) | R / E | RECH. / ACTION |
| Changer d'arme | Y | 1, 2, Tab | ARME |
| Couteau | B ou RB | V | COUTEAU |
| Sauter / Sprinter | A / clic stick gauche | Espace / Maj | SAUT / stick poussé au bord |
| Pause | Start | Échap | II |

## Contenu

- 4 salles (Hall, Atelier, Réserve, Laboratoire) reliées par des passages à acheter.
- 8 fenêtres barricadées : les zombies arrachent les planches, vous les reclouez (+10 points).
- Armes au mur : Carabine K14, Fusil à pompe Grêle, Mitraillettes Vipère et Ouragan, Fusil d'assaut Faucon.
- Caisse mystère (950) : Mitrailleuse Titan, Fusil Aiguille, Double canon Mâchoire, Revolver Taureau, Désintégrateur…
- La Forge (5000) : améliore l'arme en main.
- Atouts : Cuirasse, Main Leste, Double Détente, Pied Léger, Second Souffle.
- Bonus : Munitions max, Double points, Élimination instantanée, Bombe, Charpentier.

## Développement

- `tools/gen_assets.py` génère toutes les textures et tous les sons (aucun fichier tiers).
- Test automatique : `godot --headless --fixed-fps 60 --path . -- --bot --god --rounds=5`
  (un robot joue les manches et le jeu s'arrête à la manche demandée).
- Visite avec captures : `godot --path . -- --tour --shots=/tmp/captures`.
- Chaque push sur `main` compile l'APK (GitHub Actions) et publie une release.
