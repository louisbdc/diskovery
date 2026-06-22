import SwiftUI
import DiskoveryCore

/// Demande de suppression en attente de confirmation : un ou plusieurs éléments,
/// leur taille cumulée et un libellé lisible.
struct PendingDeletion: Identifiable {
    let id = UUID()
    let urls: [URL]
    let size: Int64
    let label: String

    var count: Int { urls.count }

    init(single entry: Entry) {
        self.urls = [entry.url]
        self.size = entry.sizeBytes
        self.label = entry.name
    }

    init(many entries: [Entry]) {
        self.urls = entries.map(\.url)
        self.size = entries.reduce(0) { $0 + $1.sizeBytes }
        self.label = "\(entries.count) élément\(entries.count > 1 ? "s" : "")"
    }
}

/// Message de statut après une suppression, selon le mode et le résultat.
func removalMessage(_ result: FileRemover.RemovalResult, freed: Int64, permanently: Bool) -> String {
    let verb = permanently ? "supprimé(s) définitivement" : "mis à la corbeille"
    if result.allSucceeded {
        return "\(result.removed.count) élément(s) · \(SizeFormatter.string(freed)) \(verb)."
    }
    return "\(result.removed.count) \(verb), \(result.failures.count) en échec."
}

extension View {
    /// Boîte de confirmation de suppression offrant **deux choix** : mettre à la
    /// Corbeille (réversible) ou supprimer définitivement (irréversible).
    /// `perform` reçoit les URLs et un booléen `permanently`.
    func deleteConfirmation(
        _ pending: Binding<PendingDeletion?>,
        perform: @escaping (Set<URL>, Bool) -> Void
    ) -> some View {
        confirmationDialog(
            "Comment supprimer ?",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending.wrappedValue
        ) { deletion in
            Button("Mettre à la corbeille", role: .destructive) {
                perform(Set(deletion.urls), false)
                pending.wrappedValue = nil
            }
            Button("Supprimer définitivement", role: .destructive) {
                perform(Set(deletion.urls), true)
                pending.wrappedValue = nil
            }
            Button("Annuler", role: .cancel) { pending.wrappedValue = nil }
        } message: { deletion in
            Text("""
            \(deletion.label) · \(SizeFormatter.string(deletion.size))

            « Mettre à la corbeille » est réversible. « Supprimer définitivement » ne l'est pas.
            """)
        }
    }
}
