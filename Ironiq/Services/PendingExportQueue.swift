import Foundation

// Stores IDs of sessions and templates that failed to export.
// On next app launch or explicit retry, the sync coordinator reads this list
// and attempts re-export before marking sync healthy.

enum PendingExportType: String, Codable {
    case session
    case template
}

struct PendingExportItem: Codable, Identifiable {
    let id: UUID
    let type: PendingExportType
    let addedAt: Date
    var retryCount: Int
}

final class PendingExportQueue: @unchecked Sendable {
    static let shared = PendingExportQueue()

    private let key: String
    private let lock = NSLock()

    // Uses a fixed key for the shared singleton.
    // Tests can create isolated instances with a unique key to avoid polluting shared state.
    init(key: String = "ironiq.pendingExports") {
        self.key = key
    }

    func add(sessionId: UUID) {
        insert(PendingExportItem(id: sessionId, type: .session, addedAt: Date(), retryCount: 0))
    }

    func add(templateId: UUID) {
        insert(PendingExportItem(id: templateId, type: .template, addedAt: Date(), retryCount: 0))
    }

    func remove(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        var items = load()
        items.removeAll { $0.id == id }
        save(items)
    }

    func allItems() -> [PendingExportItem] {
        lock.lock()
        defer { lock.unlock() }
        return load()
    }

    var isEmpty: Bool {
        allItems().isEmpty
    }

    func incrementRetry(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        var items = load()
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].retryCount += 1
        }
        save(items)
    }

    // MARK: - Private

    private func insert(_ item: PendingExportItem) {
        lock.lock()
        defer { lock.unlock() }
        var items = load()
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        save(items)
    }

    private func load() -> [PendingExportItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([PendingExportItem].self, from: data)
        else { return [] }
        return items
    }

    private func save(_ items: [PendingExportItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
