import SwiftUI
import DiskoveryCore

struct NodeModulesView: View {
    @Bindable var viewModel: NodeModulesViewModel
    @State private var isImporterPresented = false
    @State private var sortOrder = [KeyPathComparator(\Entry.sizeBytes, order: .reverse)]
    @State private var selection: Set<URL> = []
    @State private var pendingDeletion: PendingDeletion?

    private var selectedEntries: [Entry] {
        viewModel.filteredEntries.filter { selection.contains($0.url) }
    }

    private var selectedSize: Int64 {
        selectedEntries.reduce(0) { $0 + $1.sizeBytes }
    }

    private var showsSelectionBar: Bool {
        (viewModel.state == .loaded || viewModel.state == .scanning) && !viewModel.filteredEntries.isEmpty
    }

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

            if showsSelectionBar {
                Divider()
                SelectionBar(
                    selectedCount: selection.count,
                    selectedSize: selectedSize,
                    onSelectAll: { selection = Set(viewModel.filteredEntries.map(\.url)) },
                    onClear: { selection = [] },
                    onDelete: { pendingDeletion = PendingDeletion(many: selectedEntries) }
                )
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
            selection = []
            viewModel.handleImport(result)
        }
        .deleteConfirmation($pendingDeletion) { urls, permanently in
            viewModel.deleteSelected(urls, permanently: permanently)
            selection = []
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
                Button {
                    selection = Set(viewModel.oldEntries.map(\.url))
                    pendingDeletion = PendingDeletion(many: viewModel.oldEntries)
                } label: {
                    Label(
                        "Supprimer anciens (\(viewModel.oldCount) · \(SizeFormatter.string(viewModel.oldTotalSize)))",
                        systemImage: "clock.badge.xmark"
                    )
                }
                .help("Sélectionne et propose de supprimer les node_modules anciens")
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
            ToolWelcome(
                icon: "shippingbox",
                title: "Faites le ménage dans vos node_modules",
                message: "Choisissez un dossier de projets pour trouver tous les node_modules. Les dossiers les plus anciens, souvent oubliés, sont mis en avant.",
                hint: "Astuce : « Supprimer anciens » coche d'un coup les dossiers oubliés.",
                actionTitle: "Choisir un dossier",
                action: { isImporterPresented = true }
            )
        case .scanning where viewModel.entries.isEmpty:
            ScanningView(message: "Recherche des node_modules…")
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
        // Proportions calculées sur `filteredEntries` (ce que l'utilisateur voit
        // réellement) : la barre reste cohérente avec une recherche active.
        let fractions = SizeProportion.fractions(for: viewModel.filteredEntries)
        return Table(viewModel.filteredEntries.sorted(using: sortOrder), sortOrder: $sortOrder) {
            TableColumn("") { entry in
                SelectionCheckbox(selection: $selection, url: entry.url)
            }
            .width(28)

            TableColumn("Chemin", value: \.url.path) { entry in
                pathCell(entry)
            }

            TableColumn("Modifié", value: \.modifiedAtSortKey) { entry in
                modifiedCell(entry)
            }
            .width(min: 120, ideal: 150)

            TableColumn("Taille", value: \.sizeBytes) { entry in
                SizeBarCell(
                    sizeBytes: entry.sizeBytes,
                    fraction: fractions[entry.id] ?? 0,
                    tint: viewModel.isOld(entry) ? .orange : .accentColor
                )
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
            Button("Supprimer…", role: .destructive) { pendingDeletion = PendingDeletion(single: entry) }
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
