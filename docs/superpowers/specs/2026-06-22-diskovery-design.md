# Diskovery — Design

**Date :** 2026-06-22
**Statut :** Approuvé pour planification

## Vision

Diskovery est une app macOS native (SwiftUI) qui sert de **hub d'outils** d'analyse et de
nettoyage de l'espace disque. Au lancement, l'app n'exécute aucune analyse : elle présente
dans une sidebar la liste des outils disponibles. L'utilisateur choisit un outil, sélectionne
un dossier cible, et lance l'analyse.

L'objectif central est **l'extensibilité** : ajouter un nouvel outil doit se faire en créant
un fichier et en l'enregistrant dans un registre, sans modifier le reste de l'app.

Distribution visée : usage personnel, `.dmg` non signé (Gatekeeper contourné au 1er lancement).

## Outils du départ

Deux outils, réimplémentant nativement en Swift la logique des scripts bash d'origine
(`scripts/disk-usage.sh` et `scripts/node_modules_size.sh`, conservés pour référence) :

1. **Espace disque** — l'utilisateur choisit un dossier ; l'app liste les fichiers et
   sous-dossiers, triables par taille/nom, avec recherche.
2. **node_modules** — l'utilisateur choisit un dossier ; l'app trouve récursivement tous les
   dossiers `node_modules` et affiche leur taille cumulée, triables.

## Architecture

### Registre d'outils basé sur un protocole

```swift
protocol DiskTool: Identifiable {
    var id: String { get }
    var name: String { get }
    var icon: String { get }        // nom de SF Symbol
    associatedtype Body: View
    @ViewBuilder func makeView() -> Body
}
```

Pour permettre l'hétérogénéité dans une collection, les outils sont exposés via un type
effacé (`AnyDiskTool`) ou une struct de description (`ToolDescriptor { id, name, icon, view }`).
Décision d'implémentation : **`ToolDescriptor`** — une struct simple portant les métadonnées
et une closure `() -> AnyView`. Plus simple que la gymnastique des `associatedtype`, et
suffisant pour le besoin.

```swift
struct ToolDescriptor: Identifiable {
    let id: String
    let name: String
    let icon: String
    let makeView: () -> AnyView
}

enum ToolRegistry {
    static let all: [ToolDescriptor] = [
        DiskUsageTool.descriptor,
        NodeModulesTool.descriptor,
        // ← ajouter ici les futurs outils
    ]
}
```

**Ajouter un outil = 1 nouveau dossier dans `Tools/` + 1 ligne dans `ToolRegistry.all`.**

### Couche cœur réutilisable (`Core/`)

- **`FileScanner`** — parcours du système de fichiers via `FileManager.enumerator`, calcul
  des tailles (taille allouée sur disque). Fonctions pures et testables, asynchrones
  (`async`) pour ne pas bloquer l'UI. Réutilisé par les deux outils.
  - `directSizes(of:) async -> [Entry]` : fichiers et sous-dossiers directs d'un dossier.
  - `findNodeModules(under:) async -> [Entry]` : tous les `node_modules` sous un chemin.
- **`ByteFormatter`** — wrapper autour de `ByteCountFormatter` pour afficher Ko/Mo/Go.
- **`Entry`** — modèle immuable d'un résultat : `{ url, name, sizeBytes, isDirectory }`.

### Couche UI

- **`DiskoveryApp`** — point d'entrée `@main`.
- **`ContentView`** — `NavigationSplitView` : sidebar listant `ToolRegistry.all`,
  zone de détail affichant l'outil sélectionné.
- **Vue de chaque outil** — bouton « Choisir un dossier » (`NSOpenPanel` via
  `.fileImporter`), indicateur de chargement pendant le scan async, puis résultats dans une
  `Table` SwiftUI triable + champ de recherche.

### Flux de données

```
Sélection outil (sidebar)
   → Vue outil
      → fileImporter → URL dossier
         → Task { await FileScanner.… }   (hors du main thread)
            → [Entry] trié
               → Table (tri + recherche côté vue)
```

État géré par un `@Observable` view-model par outil (`DiskUsageViewModel`,
`NodeModulesViewModel`) portant : `state` (idle / scanning / loaded / error), `entries`,
`sortOrder`, `searchText`.

## Gestion des erreurs

- Permissions refusées / dossier illisible : capturer l'erreur, passer le `state` en `.error`
  avec un message lisible. Ne jamais crasher.
- Les fichiers inaccessibles pendant un parcours sont ignorés silencieusement (comme le
  `2>/dev/null` des scripts), mais comptés dans un éventuel « N éléments ignorés ».
- Annulation : le `Task` de scan est annulable si l'utilisateur change d'outil ou relance.

## Tests

- **Unitaires (`FileScanner`, `ByteFormatter`)** : créer une arborescence temporaire dans
  `FileManager.temporaryDirectory`, vérifier tailles et détection des `node_modules`.
  Cible : couvrir la logique cœur (le plus critique). Objectif 80 %+ sur `Core/`.
- L'UI SwiftUI n'est pas testée unitairement (faible valeur ici) ; vérifiée manuellement.

## Distribution

1. Build Release dans Xcode.
2. Génération `.dmg` via `hdiutil` (ou `create-dmg` si disponible) — script `make-dmg.sh`.
3. `.dmg` non signé → 1er lancement : clic droit > Ouvrir pour contourner Gatekeeper.

## Hors périmètre (YAGNI)

- Suppression de fichiers depuis l'app (envisageable plus tard comme nouvel outil).
- Signature / notarisation Apple Developer.
- Bouton « Révéler dans le Finder » (peut être ajouté trivialement plus tard).
- Persistance / historique des scans.
