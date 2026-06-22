import SwiftUI

/// Outil « Gros fichiers » : trouve les plus gros fichiers, où qu'ils soient.
@MainActor
enum LargeFilesTool {
    static let descriptor = ToolDescriptor(
        id: "large-files",
        name: "Gros fichiers",
        icon: "doc.text.magnifyingglass",
        makeView: { store in AnyView(LargeFilesView(viewModel: store.largeFiles)) }
    )
}
