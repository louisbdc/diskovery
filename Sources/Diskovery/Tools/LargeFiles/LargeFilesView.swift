import SwiftUI
import DiskoveryCore

struct LargeFilesView: View {
    @Bindable var viewModel: LargeFilesViewModel
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
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Analyse en cours… \(viewModel.scanCompleted) fichiers examinés")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal)
                .padding(.vertical, 6)
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
        .navigationTitle("Gros fichiers")
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

            Picker("Nombre", selection: $viewModel.limit) {
                ForEach(LargeFilesViewModel.limitOptions, id: \.self) { n in
                    Text("Top \(n)").tag(n)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .help("Nombre de fichiers les plus gros à afficher")

            Spacer()

            if viewModel.state == .loaded {
                Text("\(viewModel.entries.count) fichiers · \(SizeFormatter.string(viewModel.totalSize))")
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
                icon: "doc.text.magnifyingglass",
                title: "Traquez les plus gros fichiers",
                message: "Choisissez un dossier pour lister les fichiers les plus volumineux, où qu'ils se cachent dans l'arborescence.",
                hint: "Astuce : cochez plusieurs fichiers pour les supprimer en une fois.",
                actionTitle: "Choisir un dossier",
                action: { isImporterPresented = true }
            )
        case .scanning where viewModel.entries.isEmpty:
            ScanningView(message: "Recherche des gros fichiers…")
        case .scanning, .loaded:
            EntryTable(
                entries: viewModel.filteredEntries,
                sortOrder: $sortOrder,
                firstColumnTitle: "Fichier",
                showsChevronForDirectories: false,
                selection: $selection,
                onActivate: { FinderReveal.reveal($0.url) },
                onDelete: { pendingDeletion = PendingDeletion(single: $0) }
            )
        case .error(let message):
            ContentUnavailableView(
                "Erreur",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }
}
