import Foundation

/// Everything worth writing to disk between sessions.
struct SaveGame: Codable, Equatable {
    var version: Int = 1
    var experience: Int = 0
    var currentHP: Int = 24
    var currentInk: Int = 10
    var coins: Int = 15
    var inventory: [InventorySlot] = [
        InventorySlot(itemID: "patch", count: 3)
    ]
    var weaponID: String = "stub_pencil"
    var shieldID: String?
    var ownedEquipment: [String] = ["stub_pencil"]
    var mapID: String = "pencil_plains"
    var tileX: Int = 8
    var tileY: Int = 10
    var flags: [String] = []
    var defeatedCount: Int = 0
    var playtimeSeconds: Double = 0

    static let fresh = SaveGame()
}

/// Reads and writes the save file. One slot is plenty for a game this size.
enum SaveSystem {
    private static let filename = "notebookgame.save.json"

    private static var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(filename)
    }

    static var hasSave: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func load() -> SaveGame? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SaveGame.self, from: data)
    }

    static func save(_ game: SaveGame) {
        guard let data = try? JSONEncoder().encode(game) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func deleteSave() {
        try? FileManager.default.removeItem(at: url)
    }
}
