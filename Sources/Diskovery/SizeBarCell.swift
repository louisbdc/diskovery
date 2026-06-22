import SwiftUI
import DiskoveryCore

/// Cellule de taille avec barre de proportion en fond : la largeur de la barre
/// reflète la taille relative au plus gros élément visible, pour repérer d'un
/// coup d'œil ce qui pèse le plus.
///
/// La `fraction` (0…1) est précalculée en amont (`SizeProportion.fractions`) :
/// la cellule ne fait aucun calcul de maximum au rendu. Volontairement sobre —
/// une seule `Capsule` unie, sans dégradé, ombre ni animation — pour rester
/// performante dans une `Table` qui recycle ses cellules au défilement.
struct SizeBarCell: View {
    let sizeBytes: Int64
    let fraction: Double
    var tint: Color = .accentColor

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                Capsule()
                    .fill(tint.opacity(0.16))
                    // `max(0, …)` neutralise toute fraction négative ou NaN résiduelle.
                    .frame(width: max(0, geo.size.width * fraction))
            }
            .frame(height: 14)          // hauteur fixe : ne perturbe pas la hauteur de ligne
            .allowsHitTesting(false)    // purement décoratif

            Text(SizeFormatter.string(sizeBytes))
                .monospacedDigit()
        }
    }
}
