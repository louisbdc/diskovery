import SwiftUI

/// État de chargement sobre, affiché au centre de la zone de résultats pendant
/// qu'un scan commence (avant les premiers résultats). Volontairement discret et
/// cohérent avec le reste de l'app — la progression détaillée est déjà en haut.
struct ScanningView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Écran d'accueil d'un outil, affiché tant qu'aucun dossier n'a été choisi.
/// Met en avant le but de l'outil et un appel à l'action clair et visible —
/// plus accueillant qu'un simple message d'indisponibilité.
struct ToolWelcome: View {
    let icon: String
    let title: String
    let message: String
    var hint: String?
    let actionTitle: String
    let action: () -> Void
    var accent: Color = .accentColor

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 104, height: 104)
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button(action: action) {
                Label(actionTitle, systemImage: "folder.badge.plus")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let hint {
                Label(hint, systemImage: "lightbulb")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
