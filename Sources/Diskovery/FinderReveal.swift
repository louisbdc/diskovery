import AppKit
import Foundation

/// Révèle une URL (fichier ou dossier) dans le Finder.
enum FinderReveal {
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
