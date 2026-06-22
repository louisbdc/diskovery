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

Génère `dist/Diskovery.app` et `dist/Diskovery.dmg`. Le bundle est signé en ad-hoc
(signature propre) mais **non notarisé** par Apple.

## Première ouverture (app téléchargée)

Diskovery n'est pas notarisée par Apple (la notarisation nécessite un compte Apple
Developer payant). Après téléchargement, macOS affiche donc **un avertissement au
premier lancement**. C'est normal — il suffit de l'autoriser une fois :

**macOS 15 (Sequoia) et plus récent :**
1. Double-cliquez sur Diskovery → un message indique qu'elle ne peut pas être ouverte.
2. Ouvrez **Réglages Système → Confidentialité et sécurité**.
3. En bas, à côté de « Diskovery a été bloqué… », cliquez **« Ouvrir quand même »**.
4. Confirmez. Les lancements suivants se font normalement.

**macOS 14 (Sonoma) et antérieur :**
1. **Clic droit** (ou Ctrl-clic) sur Diskovery → **Ouvrir**.
2. Dans la boîte de dialogue, cliquez **Ouvrir**.

**Alternative en Terminal** (retire la mise en quarantaine) :
```bash
xattr -dr com.apple.quarantine /Applications/Diskovery.app
```

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
