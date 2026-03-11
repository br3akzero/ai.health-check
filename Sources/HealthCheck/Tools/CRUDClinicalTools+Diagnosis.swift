import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var diagnosisTool: [Tool] {
        [Tool(
            name: "create_diagnosis",
            description: "Create a new diagnosis. Returns the diagnosis ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "encounter_id": .object(["type": "integer", "description": "Encounter ID"]),
                "icd_code": .object(["type": "string", "description": "ICD-10 code"]),
                "description": .object(["type": "string", "description": "Diagnosis description"]),
                "diagnosis_date": .object(["type": "string", "description": "Date of diagnosis (ISO 8601)"]),
                "status": .object(["type": "string", "description": "Status (active, resolved, chronic)"]),
                "notes": .object(["type": "string", "description": "Notes"]),
            ])
        )]
    }

    func createDiagnosis(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let description = stringArg(args, "description"),
              let diagnosisDate = stringArg(args, "diagnosis_date"),
              let status = stringArg(args, "status") else {
            return .init(content: [.text("Missing required: patient_id, description, diagnosis_date, status")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try Diagnosis(
                id: nil,
                patientId: patientId,
                encounterId: intArg(args, "encounter_id"),
                icdCode: stringArg(args, "icd_code"),
                description: description,
                diagnosisDate: diagnosisDate,
                status: status,
                notes: stringArg(args, "notes"),
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
