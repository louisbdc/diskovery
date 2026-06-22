import Foundation

/// Boîte générique protégée par verrou, pour partager un état mutable entre
/// threads (par ex. depuis `DispatchQueue.concurrentPerform`).
/// `@unchecked Sendable` : sûreté garantie manuellement par le `NSLock`.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
