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
    var onActivate: (Entry) -> Void = { _ in }
    var onDelete: ((Entry) -> Void)?

    private var sortedEntries: [Entry] {
        entries.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedEntries, sortOrder: $sortOrder) {
            TableColumn(firstColumnTitle, value: \.name) { entry in
                nameCell(entry)
            }

            TableColumn("Taille", value: \.sizeBytes) { entry in
                Text(SizeFormatter.string(entry.sizeBytes))
                    .monospacedDigit()
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
