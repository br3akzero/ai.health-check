import MCP

struct ToolRegistry {
    let server: Server
    let db: DatabaseManager

    func registerAll() async {
        let databaseTools = DatabaseTools(db: db)

        await server.withMethodHandler(ListTools.self) { _ in
            return .init(tools: databaseTools.tools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            if let result = try await databaseTools.handle(params) {
                return result
            }
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    }
}
