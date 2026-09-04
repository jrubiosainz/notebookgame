import Foundation

enum AdventureStore {
    private(set) static var loadError: String?
    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("notebook-adventure-v2.json")
    }

    static var hasSave: Bool { FileManager.default.fileExists(atPath: url.path) }

    static func load() -> AdventureSave? { load(from: url) }

    static func save(_ value: AdventureSave) throws { try save(value, to: url) }

    // Explicit URLs also let host validation exercise atomic persistence without touching a player's slot.
    static func load(from url: URL) -> AdventureSave? {
        loadError = nil
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let value = try JSONDecoder().decode(AdventureSave.self, from: Data(contentsOf: url))
            try validate(value)
            return value
        } catch {
            loadError = "No se pudo leer la aventura: \(error.localizedDescription)"
            return nil
        }
    }

    static func save(_ value: AdventureSave, to url: URL) throws {
        try validate(value)
        let data = try JSONEncoder().encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    enum StoreError: Error, LocalizedError {
        case invalidState
        var errorDescription: String? { "La partida contiene datos de aventura incompatibles." }
    }

    private static func validate(_ value: AdventureSave) throws {
        let ids = Set(AdventureCatalog.pages.map(\.id))
        guard value.version <= 2, value.version > 0,
              ids.contains(value.pageID), ids.contains(value.checkpointPage),
              value.x.isFinite, value.y.isFinite,
              value.elapsed.isFinite, value.elapsed >= 0, value.elapsed < 1_000_000_000,
              value.nextInkAt.isFinite, value.nextCreatureAt.isFinite, value.nextEraseAt.isFinite,
              value.simulationRemainder.isFinite, (0...1).contains(value.simulationRemainder),
              (0...100).contains(value.integrity), (0...100).contains(value.hunger),
              (0...100).contains(value.warmth), (0...3).contains(value.eraserLevel),
              (0...1_000_000_000).contains(value.scraps), (0...1_000_000_000).contains(value.wood),
              (0...1_000_000_000).contains(value.food), (0...1_000_000_000).contains(value.sequence),
              [PagePoint(x: 1, y: 0), PagePoint(x: -1, y: 0),
               PagePoint(x: 0, y: 1), PagePoint(x: 0, y: -1)].contains(value.facing),
              ids.isSuperset(of: value.visited), ids.isSuperset(of: value.ink.keys) else {
            throw StoreError.invalidState
        }
        func inside(_ point: PagePoint, _ pageID: String) -> Bool {
            let page = AdventureCatalog.page(pageID)
            return point.x >= 1 && point.y >= 1 && point.x < page.width - 1 && point.y < page.height - 1
        }
        let page = AdventureCatalog.page(value.pageID)
        guard value.x >= 0.5, value.y >= 0.5, value.x <= Double(page.width) - 1.5,
              value.y <= Double(page.height) - 1.5,
              inside(value.checkpoint, value.checkpointPage),
              !AdventureCatalog.page(value.checkpointPage).blocked.contains(value.checkpoint),
              Set(value.builds.map(\.id)).count == value.builds.count,
              Set(value.creatures.map(\.id)).count == value.creatures.count else { throw StoreError.invalidState }
        for build in value.builds {
            guard ids.contains(build.pageID), inside(build.point, build.pageID),
                  !AdventureCatalog.page(build.pageID).blocked.contains(build.point),
                  build.fuel.isFinite, build.fuel >= 0 else { throw StoreError.invalidState }
        }
        for creature in value.creatures {
            guard ids.contains(creature.pageID), creature.x.isFinite, creature.y.isFinite,
                  creature.x >= 0.5, creature.y >= 0.5,
                  creature.x <= Double(AdventureCatalog.page(creature.pageID).width) - 1.5,
                  creature.y <= Double(AdventureCatalog.page(creature.pageID).height) - 1.5,
                  (0...1).contains(creature.remaining) else { throw StoreError.invalidState }
        }
        for (pageID, tiles) in value.ink {
            guard tiles.allSatisfy({ inside($0, pageID) }) else { throw StoreError.invalidState }
        }
    }
}
