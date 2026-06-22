import SwiftUI

/// Outil « Caches de build » : trouve les dossiers de cache/artefacts à nettoyer
/// (node_modules, target, dist, .gradle…) à travers les écosystèmes.
@MainActor
enum BuildCachesTool {
    static let descriptor = ToolDescriptor(
        id: "build-caches",
        name: "Caches de build",
        icon: "hammer",
        makeView: { store in AnyView(BuildCachesView(viewModel: store.buildCaches)) }
    )
}
