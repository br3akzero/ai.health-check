import GRDB

extension DatabaseManager {
    static func migrationV3(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v3_patient_notes") { db in
            try db.alter(table: "patient") { t in
                t.add(column: "notes", .text)
            }
        }
    }
}
