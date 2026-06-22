import Observation

/// Détient les view models des outils pour toute la durée de la session.
///
/// Vit au niveau de `ContentView` (racine), si bien que changer d'outil dans la
/// barre latérale ne détruit plus l'état : revenir sur un outil retrouve son
/// scan, sa navigation et ses résultats intacts.
@Observable
@MainActor
final class SessionStore {
    let diskUsage = FolderNavigatorViewModel()
    let nodeModules = NodeModulesViewModel()
}
