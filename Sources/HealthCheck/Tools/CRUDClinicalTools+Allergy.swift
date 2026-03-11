import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var allergyTool: [Tool] {
        [Tool(
            name: "create_allergy",
            description: "Create a new allergy record. Returns the allergy ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "allergen": .object(["type": "string", "description": "Allergen name"]),
                "allergen_type": .object(["type": "string", "description": "Type (drug, food, environmental, other)"]),
                "reaction": .object(["type": "string", "description": "Reaction description"]),
                "severity": .object(["type": "string", "description": "Severity (mild, moderate, severe)"]),
                "onset_date": .object(["type": "string", "description": "Onset date (ISO 8601)"]),
                "status": .object(["type": "string", "description": "Status (active, resolved)"]),
            ])
        )]
    }

    func createAllergy(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let allergen = stringArg(args, "allergen"),
              let allergenType = stringArg(args, "allergen_type"),
              let severity = stringArg(args, "severity"),
              let status = stringArg(args, "status") else {
            return .init(content: [.text("Missing required: patient_id, allergen, allergen_type, severity, status")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try Allergy(
                id: nil,
                patientId: patientId,
                allergen: allergen,
                allergenType: allergenType,
                reaction: stringArg(args, "reaction"),
                severity: severity,
                onsetDate: stringArg(args, "onset_date"),
                status: status,
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
