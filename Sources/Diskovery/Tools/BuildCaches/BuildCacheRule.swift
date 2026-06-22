import Foundation

/// Écosystème de développement et les noms de dossiers de cache/artefacts qui
/// lui sont propres. Le cœur (`FileScanner`) reste agnostique : il ne reçoit
/// qu'un `Set<String>` de noms ; ce mapping vit côté app.
enum Ecosystem: String, CaseIterable, Identifiable {
    case javascript
    case rust
    case python
    case jvm
    case php
    case xcode

    var id: String { rawValue }

    var label: String {
        switch self {
        case .javascript: "JavaScript"
        case .rust: "Rust"
        case .python: "Python"
        case .jvm: "JVM / Gradle"
        case .php: "PHP"
        case .xcode: "Xcode"
        }
    }

    var icon: String {
        switch self {
        case .javascript: "shippingbox"
        case .rust: "gearshape.2"
        case .python: "ladybug"
        case .jvm: "cup.and.saucer"
        case .php: "chevron.left.forwardslash.chevron.right"
        case .xcode: "hammer"
        }
    }

    /// Noms de dossiers reconnus comme caches/artefacts de cet écosystème.
    var ruleNames: Set<String> {
        switch self {
        case .javascript: ["node_modules", ".next", "dist", "build"]
        case .rust: ["target"]
        case .python: ["__pycache__", ".venv"]
        case .jvm: [".gradle"]
        case .php: ["vendor"]
        case .xcode: ["DerivedData"]
        }
    }

    /// Premier écosystème (par ordre de déclaration) revendiquant un nom de
    /// dossier — sert à rattacher un résultat à un écosystème pour l'affichage.
    static func first(forDirectoryNamed name: String) -> Ecosystem? {
        allCases.first { $0.ruleNames.contains(name) }
    }

    /// Union des noms de règles d'un ensemble d'écosystèmes (dédoublonné).
    static func ruleNames(for ecosystems: Set<Ecosystem>) -> Set<String> {
        ecosystems.reduce(into: Set<String>()) { $0.formUnion($1.ruleNames) }
    }
}
