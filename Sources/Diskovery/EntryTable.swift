import SwiftUI
import DiskoveryCore

/// Tableau triable réutilisable affichant des `Entry` (nom, type, taille).
///
/// `onActivate` est appelé au double-clic sur une ligne (et depuis le menu
/// contextuel) : selon l'outil, cela entre dans un dossier ou révèle l'élément.
struct EntryTable: View {
    let entries: [Entry]
    @Binding var sortOrder: [KeyPathComparator<Entry>]
    let firstColumnTitle: String
    var showsChevronForDirectories: Bool = true
    /// Ensemble des URLs cochées : la colonne de cases à cocher (à gauche) permet
    /// de sélectionner des éléments à supprimer directement.
    @Binding var selection: Set<URL>
    var onActivate: (Entry) -> Void = { _ in }
    var onDelete: ((Entry) -> Void)?

    private var sortedEntries: [Entry] {
        entries.sorted(using: sortOrder)
    }

    /// Fractions de proportion précalculées une fois par lot. Basées sur
    /// `entries` (et non la liste triée) : le tri ne change pas le maximum, donc
    /// changer de tri ne déclenche aucun recalcul.
    private var fractions: [URL: Double] {
        SizeProportion.fractions(for: entries)
    }

    var body: some View {
        Table(sortedEntries, sortOrder: $sortOrder) {
            TableColumn("") { entry in
                SelectionCheckbox(selection: $selection, url: entry.url)
            }
            .width(28)

            TableColumn(firstColumnTitle, value: \.name) { entry in
                nameCell(entry)
            }

            TableColumn("Taille", value: \.sizeBytes) { entry in
                SizeBarCell(sizeBytes: entry.sizeBytes, fraction: fractions[entry.id] ?? 0)
            }
            .width(min: 100, ideal: 120)
        }
    }

    private func nameCell(_ entry: Entry) -> some View {
        HStack {
            Label {
                Text(entry.name)
            } icon: {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                    .foregroundStyle(entry.isDirectory ? Color.accentColor : .secondary)
            }

            Spacer()

            if showsChevronForDirectories && entry.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onActivate(entry) }
        .contextMenu {
            if entry.isDirectory {
                Button("Entrer") { onActivate(entry) }
            }
            Button("Révéler dans le Finder") { FinderReveal.reveal(entry.url) }
            if let onDelete {
                Divider()
                Button("Mettre à la corbeille", role: .destructive) { onDelete(entry) }
            }
        }
    }
}
