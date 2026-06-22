# Diskovery

Application macOS native (SwiftUI) pour explorer ce qui occupe votre espace disque — un **hub d'outils** extensible.

## Outils

- **Espace disque** — navigateur façon DaisyDisk : choisissez un dossier, voyez les plus gros fichiers/sous-dossiers, double-cliquez pour plonger dedans (fil d'Ariane, retour, cache pour une navigation instantanée).
- **node_modules** — trouve récursivement tous les dossiers `node_modules`, met en avant ceux dépassant un seuil d'ancienneté configurable, et permet de les supprimer (un par un ou tous les anciens d'un coup).

Suppression vers la Corbeille (réversible), scans parallélisés sur tous les cœurs avec affichage progressif.

## Lancer en développement

```bash
open Package.swift   # puis Cmd+R dans Xcode
```

ou en ligne de commande :

```bash
swift build
swift test
```

## Construire le .dmg

```bash
./make-dmg.sh
```

Génère `dist/Diskovery.app` et `dist/Diskovery.dmg` (non signé — au 1er lancement : clic droit > Ouvrir).

## Benchmark

```bash
swift run -c release DiskoveryBench ~/un/dossier
```

## Architecture

- `DiskoveryCore` — logique pure et testable (parcours du système de fichiers, tailles, recherche node_modules, cache, corbeille).
- `Diskovery` — l'app SwiftUI (registre d'outils extensible : ajouter un outil = 1 fichier + 1 ligne).

## Ajouter un outil

1. Créer une vue + son view model dans `Sources/Diskovery/Tools/`.
2. Ajouter son view model au `SessionStore`.
3. Enregistrer son `ToolDescriptor` dans `ToolRegistry.all`.
