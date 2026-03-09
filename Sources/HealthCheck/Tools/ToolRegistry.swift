import MCP

struct ToolRegistry {
    let server: Server
    let db: DatabaseManager

    func registerAll() async {
        await server.withMethodHandler(ListTools.self) { _ in
            return .init(tools: [])
        }

        await server.withMethodHandler(CallTool.self) { params in
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    }
}
