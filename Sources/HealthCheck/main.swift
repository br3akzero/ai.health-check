import MCP
import Foundation

let dbPath = FileManager.default.currentDirectoryPath + "/Data/healthcheck.sqlite"
let dbDir = (dbPath as NSString).deletingLastPathComponent

if !FileManager.default.fileExists(atPath: dbDir) {
    try FileManager.default.createDirectory(atPath: dbDir, withIntermediateDirectories: true)
}

let db = try DatabaseManager(at: dbPath)

let server = Server(
    name: "HealthCheck",
    version: "1.0.0",
    capabilities: .init(
        tools: .init(listChanged: true)
    )
)

let registry = ToolRegistry(server: server, db: db)
await registry.registerAll()

let transport = StdioTransport()
try await server.start(transport: transport)
