import SwiftUI
import DiskoveryCore

/// Barre d'action de sélection : affichée au-dessus d'un tableau, elle explique
/// quoi faire (cocher pour supprimer), récapitule la sélection et offre une
/// suppression directe vers la Corbeille — sans menu contextuel.
struct SelectionBar: View {
    let selectedCount: Int
    let selectedSize: Int64
    let onSelectAll: () -> Void
    let onClear: () -> Void
    let onDelete: () -> Void

    private var hasSelection: Bool { selectedCount > 0 }

    var body: some View {
        HStack(spacing: 12) {
            if hasSelection {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                Text("\(selectedCount) sélectionné\(selectedCount > 1 ? "s" : "") · \(SizeFormatter.string(selectedSize))")
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                Button("Tout désélectionner", action: onClear)
                    .buttonStyle(.link)
            } else {
                Image(systemName: "checklist")
                    .foregroundStyle(.secondary)
                Text("Cochez les éléments à supprimer")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Tout sélectionner", action: onSelectAll)
                    .buttonStyle(.link)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Label("Mettre à la corbeille", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!hasSelection)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// Case à cocher de sélection d'une ligne, pilotée par un ensemble d'URLs.
struct SelectionCheckbox: View {
    @Binding var selection: Set<URL>
    let url: URL

    var body: some View {
        Toggle("", isOn: Binding(
            get: { selection.contains(url) },
            set: { isOn in
                if isOn { selection.insert(url) } else { selection.remove(url) }
            }
        ))
        .labelsHidden()
        .toggleStyle(.checkbox)
    }
}
