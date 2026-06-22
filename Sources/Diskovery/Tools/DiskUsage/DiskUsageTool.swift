import SwiftUI

/// Outil « Espace disque » : liste les fichiers et sous-dossiers directs d'un dossier.
@MainActor
enum DiskUsageTool {
    static let descriptor = ToolDescriptor(
        id: "disk-usage",
        name: "Espace disque",
        icon: "internaldrive",
        makeView: { store in AnyView(DiskUsageView(viewModel: store.diskUsage)) }
    )
}
