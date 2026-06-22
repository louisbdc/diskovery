import SwiftUI

/// Outil « node_modules » : trouve récursivement tous les dossiers node_modules.
@MainActor
enum NodeModulesTool {
    static let descriptor = ToolDescriptor(
        id: "node-modules",
        name: "node_modules",
        icon: "shippingbox",
        makeView: { store in AnyView(NodeModulesView(viewModel: store.nodeModules)) }
    )
}
