import GRDB

extension DatabaseManager {
    static func runMigrations(_ dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrationV1(&migrator)
        migrationV2(&migrator)
        migrationV3(&migrator)
        try migrator.migrate(dbQueue)
    }
}
