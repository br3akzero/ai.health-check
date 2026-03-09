import GRDB

final class DatabaseManager: Sendable {
    let dbQueue: DatabaseQueue

    init(at path: String) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        dbQueue = try DatabaseQueue(path: path, configuration: config)
        try Self.runMigrations(dbQueue)
    }

    init() throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        dbQueue = try DatabaseQueue(configuration: config)
        try Self.runMigrations(dbQueue)
    }
}
