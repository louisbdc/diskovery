import SwiftUI

/// Barre de progression déterminée affichée pendant un scan, avec compteur et pourcentage.
struct ScanProgressBar: View {
    let fraction: Double
    let completed: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: fraction)
            HStack {
                Text("Analyse en cours… \(completed)/\(total)")
                Spacer()
                Text("\(Int(fraction * 100)) %")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
