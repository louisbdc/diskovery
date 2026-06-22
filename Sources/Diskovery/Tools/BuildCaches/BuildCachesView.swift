import SwiftUI
import DiskoveryCore

struct BuildCachesView: View {
    @Bindable var viewModel: BuildCachesViewModel
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
                progress
            }

            if let message = viewModel.statusMessage {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text(message).lineLimit(2)
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 6)
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
        .navigationTitle("Caches de build")
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

            Menu {
                ForEach(Ecosystem.allCases) { eco in
                    Toggle(isOn: Binding(
                        get: { viewModel.enabledEcosystems.contains(eco) },
                        set: { isOn in
                            if isOn { viewModel.enabledEcosystems.insert(eco) }
                            else { viewModel.enabledEcosystems.remove(eco) }
                        }
                    )) {
                        Label(eco.label, systemImage: eco.icon)
                    }
                }
            } label: {
                Label("Écosystèmes (\(viewModel.enabledEcosystems.count))", systemImage: "line.3.horizontal.decrease.circle")
            }
            .fixedSize()
            .help("Choisir les écosystèmes à rechercher")

            Spacer()

            if viewModel.state == .loaded {
                Text("\(viewModel.entries.count) trouvés · \(SizeFormatter.string(viewModel.totalSize))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding()
    }

    private var progress: some View {
        VStack(spacing: 4) {
            if viewModel.isDiscovering {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Recherche… \(viewModel.scanTotal) dossiers trouvés")
                    Spacer()
                }
            } else {
                ProgressView(value: viewModel.scanFraction)
                HStack {
                    Text("Mesure des tailles… \(viewModel.scanCompleted)/\(viewModel.scanTotal)")
                    Spacer()
                    Text("\(Int(viewModel.scanFraction * 100)) %")
                }
                .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ToolWelcome(
                icon: "hammer",
                title: "Récupérez l'espace des caches de build",
                message: "Choisissez un dossier de code pour trouver les caches et artefacts régénérables (node_modules, target, dist, .gradle…) à travers vos écosystèmes.",
                hint: "Astuce : filtrez les écosystèmes, puis cochez ce que vous voulez nettoyer.",
                actionTitle: "Choisir un dossier",
                action: { isImporterPresented = true }
            )
        case .scanning where viewModel.entries.isEmpty:
            ScanningView(message: "Recherche des caches…")
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
        let fractions = SizeProportion.fractions(for: viewModel.filteredEntries)
        return Table(viewModel.filteredEntries.sorted(using: sortOrder), sortOrder: $sortOrder) {
            TableColumn("") { entry in
                SelectionCheckbox(selection: $selection, url: entry.url)
            }
            .width(28)

            TableColumn("Chemin", value: \.url.path) { entry in
                pathCell(entry)
            }

            TableColumn("Taille", value: \.sizeBytes) { entry in
                SizeBarCell(sizeBytes: entry.sizeBytes, fraction: fractions[entry.id] ?? 0)
            }
            .width(min: 100, ideal: 120)
        }
    }

    private func pathCell(_ entry: Entry) -> some View {
        Label {
            Text(entry.url.path)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: viewModel.ecosystem(for: entry)?.icon ?? "shippingbox.fill")
                .foregroundStyle(Color.accentColor)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { FinderReveal.reveal(entry.url) }
        .contextMenu {
            Button("Révéler dans le Finder") { FinderReveal.reveal(entry.url) }
            Button("Supprimer…", role: .destructive) { pendingDeletion = PendingDeletion(single: entry) }
        }
    }
}
