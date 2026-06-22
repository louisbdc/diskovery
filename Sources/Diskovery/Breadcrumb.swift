import SwiftUI

/// Fil d'Ariane cliquable, du dossier racine jusqu'au dossier courant.
/// Cliquer sur un segment y navigue directement.
struct Breadcrumb: View {
    let items: [BreadcrumbItem]
    let onSelect: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.url) { index, item in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button {
                        onSelect(item.url)
                    } label: {
                        Text(item.name)
                            .fontWeight(index == items.count - 1 ? .semibold : .regular)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == items.count - 1 ? Color.primary : Color.accentColor)
                    .disabled(index == items.count - 1)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}

/// Un segment du fil d'Ariane : un nom affiché et l'URL absolue correspondante.
struct BreadcrumbItem: Hashable {
    let name: String
    let url: URL
}
