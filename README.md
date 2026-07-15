# joinFive (SwiftUI)

Port SwiftUI du projet `ShivangMishra/joinfive` :
- grille 50x50
- seed initial Morpion Solitaire
- modes `5D` et `5T`
- joueur humain + simulation ordinateur
- algorithmes `Random Search`, `NMCS`, `NRPA`
- hints, undo, reset, score, temps ecoule

## Lancer dans Xcode

Ouvrir `joinFive.xcodeproj`, choisir le scheme `joinFive`, puis lancer.

## Build en ligne de commande

```bash
cd /Users/pgreze/Documents/dev_mac/joinFive
xcodebuild -project joinFive.xcodeproj -scheme joinFive -configuration Debug -destination 'platform=macOS' build
```
