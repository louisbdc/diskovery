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

Sans variables d'environnement, le bundle est signé en **ad-hoc** (dev local).

### Build signé Developer ID + notarisé (distribution)

Pour un `.dmg` qui s'ouvre **sans aucun avertissement** une fois téléchargé :

```bash
export DISKOVERY_SIGN_IDENTITY="Developer ID Application: VOTRE NOM (TEAMID)"
export DISKOVERY_NOTARY_PROFILE="diskovery"   # via `xcrun notarytool store-credentials`
./make-dmg.sh
```

Le script signe (Developer ID + hardened runtime + timestamp), **notarise** l'app
et le `.dmg` auprès d'Apple, et **agrafe** les tickets. Résultat : ouverture propre,
sans manipulation côté utilisateur.

> Note : un build **ad-hoc** (sans ces variables) déclenche, lui, un avertissement
> Gatekeeper au premier lancement (clic droit → Ouvrir, ou Réglages → Confidentialité
> et sécurité → « Ouvrir quand même »).

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
