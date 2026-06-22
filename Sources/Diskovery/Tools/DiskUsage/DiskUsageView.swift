import SwiftUI
import DiskoveryCore

struct DiskUsageView: View {
    @Bindable var viewModel: FolderNavigatorViewModel
    @State private var isImporterPresented = false
    @State private var sortOrder = [KeyPathComparator(\Entry.sizeBytes, order: .reverse)]
    @State private var pendingDelete: Entry?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar

            if !viewModel.breadcrumb.isEmpty {
                Divider()
                Breadcrumb(items: viewModel.breadcrumb) { url in
                    viewModel.navigateViaBreadcrumb(to: url)
                }
            }

            if viewModel.state == .scanning && viewModel.scanTotal > 0 {
                Divider()
                ScanProgressBar(
                    fraction: viewModel.scanFraction,
                    completed: viewModel.scanCompleted,
                    total: viewModel.scanTotal
                )
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

            Divider()

            content
        }
        .navigationTitle("Espace disque")
        .searchable(text: $viewModel.searchText, prompt: "Filtrer par nom")
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImport(result)
        }
        .confirmationDialog(
            "Mettre cet élément à la corbeille ?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { entry in
            Button("Mettre à la corbeille", role: .destructive) {
                viewModel.delete(entry)
                pendingDelete = nil
            }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: { entry in
            Text("\(entry.name)\n\(SizeFormatter.string(entry.sizeBytes)) seront récupérés.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.goBack()
            } label: {
                Label("Retour", systemImage: "chevron.left")
            }
            .disabled(!viewModel.canGoBack)
            .help("Revenir au dossier précédent")

            Button {
                isImporterPresented = true
            } label: {
                Label("Choisir un dossier", systemImage: "folder.badge.plus")
            }
            .disabled(viewModel.state == .scanning)

            Button {
                viewModel.refreshCurrent()
            } label: {
                Label("Rafraîchir", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.currentURL == nil || viewModel.state == .scanning)
            .help("Recalculer les tailles (ignore le cache)")

            Spacer()

            if viewModel.state == .loaded {
                Text("\(viewModel.entries.count) éléments · \(SizeFormatter.string(viewModel.currentTotalSize))")
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
                systemImage: "folder",
                description: Text("Sélectionnez un dossier pour explorer ce qui occupe le plus d'espace. Double-cliquez sur un dossier pour y entrer.")
            )
        case .scanning where viewModel.entries.isEmpty:
            VStack(spacing: 12) {
                ProgressView()
                Text("Analyse en cours…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .scanning, .loaded:
            // Le tableau se remplit en direct pendant le scan, puis se fige une fois terminé.
            EntryTable(
                entries: viewModel.filteredEntries,
                sortOrder: $sortOrder,
                firstColumnTitle: "Nom",
                onActivate: { viewModel.activate($0) },
                onDelete: { pendingDelete = $0 }
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
