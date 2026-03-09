import MCP
import GRDB
import Foundation

struct DatabaseTools {
    let db: DatabaseManager

    var tools: [Tool] {
        [
            Tool(
                name: "get_schema_info",
                description: "Returns all table names with their columns and types. Use this to discover the database structure.",
                inputSchema: .object([:])
            )
        ]
    }

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        switch params.name {
        case "get_schema_info":
            return try await getSchemaInfo()
        default:
            return nil
        }
    }
}

// MARK: - Database API

private extension DatabaseTools {
    func getSchemaInfo() async throws -> CallTool.Result {
        let schema = try await db.dbQueue.read { db in
            var result: [[String: String]] = []

            let tables = try Row.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'grdb_migrations'
                ORDER BY name
                """)

            for tableRow in tables {
                let tableName: String = tableRow["name"]
                let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(\(tableName))")

                for col in columns {
                    let colName: String = col["name"]
                    let colType: String = col["type"]
                    let notNull: Int = col["notnull"]
                    let nullable = notNull == 0 ? "nullable" : "required"

                    result.append([
                        "table": tableName,
                        "column": colName,
                        "type": colType,
                        "nullable": nullable
                    ])
                }
            }

            return result
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let json = String(data: try encoder.encode(schema), encoding: .utf8) ?? "[]"

        return .init(content: [.text(json)], isError: false)
    }
}
