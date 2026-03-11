import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var labResultTool: [Tool] {
        [Tool(
            name: "create_lab_result",
            description: "Create a new lab result. Returns the lab result ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "encounter_id": .object(["type": "integer", "description": "Encounter ID"]),
                "test_name": .object(["type": "string", "description": "Test name (e.g. Glucose, HbA1c)"]),
                "test_category": .object(["type": "string", "description": "Category (Chemistry, Hematology, etc.)"]),
                "value": .object(["type": "string", "description": "Result value as string"]),
                "numeric_value": .object(["type": "number", "description": "Numeric result value"]),
                "unit": .object(["type": "string", "description": "Unit (mg/dL, mmol/L, etc.)"]),
                "reference_range_low": .object(["type": "number", "description": "Low end of reference range"]),
                "reference_range_high": .object(["type": "number", "description": "High end of reference range"]),
                "reference_range_text": .object(["type": "string", "description": "Reference range as text"]),
                "flag": .object(["type": "string", "description": "Flag (normal, low, high, critical)"]),
                "test_date": .object(["type": "string", "description": "Test date (ISO 8601)"]),
                "notes": .object(["type": "string", "description": "Notes"]),
            ])
        )]
    }

    func createLabResult(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let testName = stringArg(args, "test_name"),
              let value = stringArg(args, "value"),
              let testDate = stringArg(args, "test_date") else {
            return .init(content: [.text("Missing required: patient_id, test_name, value, test_date")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try LabResult(
                id: nil,
                patientId: patientId,
                encounterId: intArg(args, "encounter_id"),
                testName: testName,
                testCategory: stringArg(args, "test_category"),
                value: value,
                numericValue: doubleArg(args, "numeric_value"),
                unit: stringArg(args, "unit"),
                referenceRangeLow: doubleArg(args, "reference_range_low"),
                referenceRangeHigh: doubleArg(args, "reference_range_high"),
                referenceRangeText: stringArg(args, "reference_range_text"),
                flag: stringArg(args, "flag"),
                testDate: testDate,
                notes: stringArg(args, "notes"),
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
