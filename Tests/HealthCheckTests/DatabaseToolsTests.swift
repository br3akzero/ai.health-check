import Testing
import Foundation
import MCP
import GRDB
@testable import HealthCheck

// MARK: - Database Tools Tests

@Test("getSchemaInfo returns all 19 tables")
func schemaInfoAllTables() async throws {
    let manager = try makeDB()
    let tools = DatabaseTools(db: manager)

    let params = CallTool.Parameters(name: "get_schema_info")
    let result = try await tools.handle(params)

    let callResult = try #require(result)
    let textContent = try #require(callResult.content.first)

    guard case .text(let json) = textContent else {
        Issue.record("Expected text content")
        return
    }

    let entries = try JSONDecoder().decode([[String: String]].self, from: Data(json.utf8))
    let tableNames = Set(entries.map { $0["table"]! })

    let expectedTables: Set<String> = [
        "patient", "facility", "doctor", "facility_doctor", "document",
        "encounter", "document_encounter", "diagnosis", "medication", "lab_result",
        "vital_sign", "procedure_record", "immunization", "allergy", "imaging",
        "document_chunk", "document_summary", "extracted_entity", "document_page"
    ]

    for table in expectedTables {
        #expect(tableNames.contains(table), "Missing table: \(table)")
    }
}

@Test("getSchemaInfo returns correct columns for patient table")
func schemaInfoPatientColumns() async throws {
    let manager = try makeDB()
    let tools = DatabaseTools(db: manager)

    let params = CallTool.Parameters(name: "get_schema_info")
    let result = try await tools.handle(params)

    let callResult = try #require(result)
    let textContent = try #require(callResult.content.first)

    guard case .text(let json) = textContent else {
        Issue.record("Expected text content")
        return
    }

    let entries = try JSONDecoder().decode([[String: String]].self, from: Data(json.utf8))
    let patientColumns = entries.filter { $0["table"] == "patient" }

    let expected: [(name: String, type: String, nullable: String)] = [
        ("id", "INTEGER", "nullable"),
        ("first_name", "TEXT", "required"),
        ("last_name", "TEXT", "required"),
        ("date_of_birth", "TEXT", "nullable"),
        ("gender", "TEXT", "nullable"),
        ("blood_type", "TEXT", "nullable"),
        ("notes", "TEXT", "nullable"),
        ("created_at", "TEXT", "required"),
        ("updated_at", "TEXT", "required"),
    ]

    #expect(patientColumns.count == expected.count)

    for exp in expected {
        let col = patientColumns.first { $0["column"] == exp.name }
        let found = try #require(col, "Missing column: \(exp.name)")
        #expect(found["type"] == exp.type, "\(exp.name) type mismatch")
        #expect(found["nullable"] == exp.nullable, "\(exp.name) nullable mismatch")
    }
}

@Test("handle returns nil for unknown tool")
func unknownToolReturnsNil() async throws {
    let manager = try makeDB()
    let tools = DatabaseTools(db: manager)

    let params = CallTool.Parameters(name: "nonexistent_tool")
    let result = try await tools.handle(params)

    #expect(result == nil)
}
