import Foundation
import DiskoveryCore

/// Benchmark avant/après pour `directEntries`.
///
/// Compare l'ancienne approche séquentielle (taille de chaque enfant calculée
/// l'une après l'autre) à la nouvelle approche parallèle multicœur.
///
/// Usage : `swift run -c release DiskoveryBench [chemin]`
/// (par défaut : le dossier personnel de l'utilisateur).
@main
struct Bench {
    static func main() async {
        let path = CommandLine.arguments.dropFirst().first
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let url = URL(fileURLWithPath: path)

        let children = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: []
        )) ?? []

        print("Dossier  : \(url.path)")
        print("Enfants  : \(children.count)")
        print("Cœurs    : \(ProcessInfo.processInfo.activeProcessorCount)")
        print("")

        // Approche séquentielle (référence « avant »), caches vidés au préalable.
        await FileScanner.clearCache()
        let seqStart = Date()
        var seqTotal: Int64 = 0
        for child in children {
            seqTotal += FileScanner.directorySize(of: child)
        }
        let seqElapsed = Date().timeIntervalSince(seqStart)

        // Approche parallèle actuelle (« après »), caches vidés pour une mesure honnête.
        await FileScanner.clearCache()
        let parStart = Date()
        let entries = await FileScanner.directEntries(of: url, useCache: false)
        let parElapsed = Date().timeIntervalSince(parStart)
        let parTotal = entries.reduce(0) { $0 + $1.sizeBytes }

        // Troisième mesure : re-scan APRÈS un premier parcours (cache de tailles chaud)
        // — représente le coût réel d'« entrer dans un dossier ».
        let warmStart = Date()
        _ = await FileScanner.directEntries(of: url, useCache: false)
        let warmElapsed = Date().timeIntervalSince(warmStart)

        let speedup = parElapsed > 0 ? seqElapsed / parElapsed : 0

        print(String(format: "Séquentiel (avant)      : %7.3f s", seqElapsed))
        print(String(format: "Parallèle  (après)      : %7.3f s", parElapsed))
        print(String(format: "Accélération            : %6.2fx", speedup))
        print(String(format: "Re-scan (cache chaud) ↩ : %7.3f s  ← coût d'« entrer »", warmElapsed))
        print("")
        print("Total séquentiel : \(seqTotal) octets")
        print("Total parallèle  : \(parTotal) octets")
        print("Cohérence tailles: \(seqTotal == parTotal ? "OK ✓" : "DIVERGENCE ✗")")

        await benchmarkNodeModulesSearch(under: url)
    }

    /// Compare la recherche de node_modules séquentielle (ancien énumérateur unique)
    /// à la nouvelle recherche parallélisée.
    static func benchmarkNodeModulesSearch(under root: URL) async {
        print("")
        print("— Recherche node_modules —")

        // Référence « avant » : un seul énumérateur séquentiel.
        let seqStart = Date()
        let seqCount = sequentialNodeModulesCount(under: root)
        let seqElapsed = Date().timeIntervalSince(seqStart)

        // « Après » : recherche parallèle.
        let parStart = Date()
        let parMatches = await FileScanner.locateNodeModules(under: root)
        let parElapsed = Date().timeIntervalSince(parStart)

        let speedup = parElapsed > 0 ? seqElapsed / parElapsed : 0
        print("node_modules trouvés    : \(parMatches.count) (séq. \(seqCount))")
        print(String(format: "Séquentiel (avant)      : %7.3f s", seqElapsed))
        print(String(format: "Parallèle  (après)      : %7.3f s", parElapsed))
        print(String(format: "Accélération            : %6.2fx", speedup))
        print("Cohérence nombre        : \(seqCount == parMatches.count ? "OK ✓" : "DIVERGENCE ✗")")
    }

    /// Recherche séquentielle de référence (un seul énumérateur, comme avant).
    static func sequentialNodeModulesCount(under root: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var count = 0
        for case let element as URL in enumerator {
            let values = try? element.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isSymbolicLink != true,
                  values?.isDirectory == true,
                  element.lastPathComponent == "node_modules" else {
                continue
            }
            enumerator.skipDescendants()
            count += 1
        }
        return count
    }
}
