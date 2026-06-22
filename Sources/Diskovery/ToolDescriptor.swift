import SwiftUI

/// Description légère d'un outil : métadonnées + fabrique de vue.
@MainActor
struct ToolDescriptor: Identifiable {
    let id: String
    let name: String
    let icon: String          // nom de SF Symbol
    /// Fabrique la vue de l'outil à partir du store de session (qui détient son
    /// view model persistant).
    let makeView: (SessionStore) -> AnyView
}

/// Registre central des outils. Ajouter un outil = 1 ligne ici.
@MainActor
enum ToolRegistry {
    static let all: [ToolDescriptor] = [
        DiskUsageTool.descriptor,
        NodeModulesTool.descriptor,
    ]
}
