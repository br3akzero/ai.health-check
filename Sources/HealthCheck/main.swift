import MCP
import Foundation

let dbPath = FileManager.default.currentDirectoryPath + "/Data/healthcheck.sqlite"
let dbDir = (dbPath as NSString).deletingLastPathComponent

if CommandLine.arguments.contains("--init") {
    if !FileManager.default.fileExists(atPath: dbDir) {
        try FileManager.default.createDirectory(atPath: dbDir, withIntermediateDirectories: true)
    }
    let _ = try DatabaseManager(at: dbPath)
    print("Database initialized at: \(dbPath)")
    exit(0)
}

guard FileManager.default.fileExists(atPath: dbPath) else {
    fputs("Error: Database not found at \(dbPath)\n", stderr)
    fputs("Run 'swift run HealthCheck --init' to create it.\n", stderr)
    exit(1)
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
