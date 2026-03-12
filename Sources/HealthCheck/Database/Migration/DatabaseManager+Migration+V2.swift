import GRDB

extension DatabaseManager {
    static func migrationV2(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v2_document_page") { db in
            try db.create(table: "document_page") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("document_id", .integer).notNull()
                    .references("document", onDelete: .cascade)
                t.column("page_number", .integer).notNull()
                t.column("pdfkit_text", .text)
                t.column("ocr_text", .text)
                t.column("reconciled_text", .text).notNull()
                t.column("ingest_type", .text).notNull().defaults(to: "unknown")
                t.column("created_at", .text).notNull()
                t.uniqueKey(["document_id", "page_number"])
            }
        }
    }
}
