import SwiftUI
import DiskoveryCore

struct NodeModulesView: View {
    @Bindable var viewModel: NodeModulesViewModel
    @State private var isImporterPresented = false
    @State private var sortOrder = [KeyPathComparator(\Entry.sizeBytes, order: .reverse)]
    @State private var pendingSingleDelete: Entry?
    @State private var showBulkConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar

            if viewModel.state == .scanning {
                Divider()
                NodeModulesProgress(
                    isDiscovering: viewModel.isDiscovering,
                    found: viewModel.scanTotal,
                    sized: viewModel.scanCompleted,
                    fraction: viewModel.scanFraction
                )
            }

            if let message = viewModel.statusMessage {
                Divider()
                StatusBanner(message: message)
            }

            Divider()

            content
        }
        .navigationTitle("node_modules")
        .searchable(text: $viewModel.searchText, prompt: "Filtrer par chemin")
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImport(result)
        }
        .confirmationDialog(
            "Mettre ce node_modules à la corbeille ?",
            isPresented: Binding(
                get: { pendingSingleDelete != nil },
                set: { if !$0 { pendingSingleDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingSingleDelete
        ) { entry in
            Button("Mettre à la corbeille", role: .destructive) {
                viewModel.delete(entry)
                pendingSingleDelete = nil
            }
            Button("Annuler", role: .cancel) { pendingSingleDelete = nil }
        } message: { entry in
            Text("\(entry.url.path)\n\(SizeFormatter.string(entry.sizeBytes)) seront récupérés.")
        }
        .confirmationDialog(
            "Mettre à la corbeille tous les node_modules de plus de \(viewModel.threshold.label) ?",
            isPresented: $showBulkConfirm,
            titleVisibility: .visible
        ) {
            Button("Mettre \(viewModel.oldCount) dossiers à la corbeille", role: .destructive) {
                viewModel.deleteOld()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("\(viewModel.oldCount) dossiers · \(SizeFormatter.string(viewModel.oldTotalSize)) seront récupérés.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                isImporterPresented = true
            } label: {
                Label("Choisir un dossier", systemImage: "folder.badge.plus")
            }
            .disabled(viewModel.state == .scanning)

            Picker("Ancien après", selection: $viewModel.threshold) {
                ForEach(AgeThreshold.allCases) { threshold in
                    Text(threshold.label).tag(threshold)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .help("Au-delà de cette ancienneté, un node_modules est marqué « ancien »")

            if viewModel.state == .loaded && viewModel.oldCount > 0 {
                Button(role: .destructive) {
                    showBulkConfirm = true
                } label: {
                    Label(
                        "Supprimer anciens (\(viewModel.oldCount) · \(SizeFormatter.string(viewModel.oldTotalSize)))",
                        systemImage: "trash"
                    )
                }
            }

            Spacer()

            if viewModel.state == .loaded {
                Text("\(viewModel.entries.count) trouvés · \(SizeFormatter.string(viewModel.totalSize))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView(
                "Choisissez un dossier",
                systemImage: "shippingbox",
                description: Text("Sélectionnez un dossier pour trouver tous les node_modules. Les dossiers anciens sont mis en avant.")
            )
        case .scanning where viewModel.entries.isEmpty:
            ContentUnavailableView {
                Label("Recherche des node_modules…", systemImage: "magnifyingglass")
            } description: {
                Text("Exploration parallèle de l'arborescence en cours.")
            }
        case .scanning, .loaded:
            table
        case .error(let message):
            ContentUnavailableView(
                "Erreur",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }

    private var table: some View {
        Table(viewModel.filteredEntries.sorted(using: sortOrder), sortOrder: $sortOrder) {
            TableColumn("Chemin", value: \.url.path) { entry in
                pathCell(entry)
            }

            TableColumn("Modifié", value: \.modifiedAtSortKey) { entry in
                modifiedCell(entry)
            }
            .width(min: 120, ideal: 150)

            TableColumn("Taille", value: \.sizeBytes) { entry in
                Text(SizeFormatter.string(entry.sizeBytes))
                    .monospacedDigit()
            }
            .width(min: 100, ideal: 120)
        }
    }

    private func pathCell(_ entry: Entry) -> some View {
        HStack(spacing: 6) {
            Label {
                Text(entry.url.path)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(viewModel.isOld(entry) ? Color.orange : Color.accentColor)
            }

            if viewModel.isOld(entry) {
                Text("ancien")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.2), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { FinderReveal.reveal(entry.url) }
        .contextMenu {
            Button("Révéler dans le Finder") { FinderReveal.reveal(entry.url) }
            Button("Mettre à la corbeille", role: .destructive) { pendingSingleDelete = entry }
        }
    }

    private func modifiedCell(_ entry: Entry) -> some View {
        Text(RelativeDate.string(entry.modifiedAt))
            .foregroundStyle(viewModel.isOld(entry) ? Color.orange : .secondary)
    }
}

/// Progression du scan node_modules : indéterminée pendant la recherche
/// (compteur de dossiers trouvés), puis déterminée pendant la mesure des tailles.
private struct NodeModulesProgress: View {
    let isDiscovering: Bool
    let found: Int
    let sized: Int
    let fraction: Double

    var body: some View {
        VStack(spacing: 4) {
            if isDiscovering {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Recherche… \(found) node_modules trouvés")
                    Spacer()
                }
            } else {
                ProgressView(value: fraction)
                HStack {
                    Text("Mesure des tailles… \(sized)/\(found)")
                    Spacer()
                    Text("\(Int(fraction * 100)) %")
                }
                .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

/// Bandeau d'information transitoire (résultat d'une suppression).
private struct StatusBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text(message)
                .lineLimit(2)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

/// Formatage relatif d'une date (« il y a 2 mois »).
@MainActor
private enum RelativeDate {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    static func string(_ date: Date?) -> String {
        guard let date else { return "—" }
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension Entry {
    /// Clé de tri stable pour la colonne « Modifié » (les dates manquantes en dernier).
    var modifiedAtSortKey: TimeInterval {
        modifiedAt?.timeIntervalSince1970 ?? 0
    }
}
