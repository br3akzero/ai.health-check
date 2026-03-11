import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var procedureTool: [Tool] {
        [Tool(
            name: "create_procedure",
            description: "Create a new procedure record. Returns the procedure ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "encounter_id": .object(["type": "integer", "description": "Encounter ID"]),
                "doctor_id": .object(["type": "integer", "description": "Doctor ID"]),
                "procedure_name": .object(["type": "string", "description": "Procedure name"]),
                "procedure_code": .object(["type": "string", "description": "CPT/procedure code"]),
                "procedure_date": .object(["type": "string", "description": "Procedure date (ISO 8601)"]),
                "body_site": .object(["type": "string", "description": "Body site"]),
                "outcome": .object(["type": "string", "description": "Outcome"]),
                "notes": .object(["type": "string", "description": "Notes"]),
            ])
        )]
    }

    func createProcedure(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let procedureName = stringArg(args, "procedure_name"),
              let procedureDate = stringArg(args, "procedure_date") else {
            return .init(content: [.text("Missing required: patient_id, procedure_name, procedure_date")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try ProcedureRecord(
                id: nil,
                patientId: patientId,
                encounterId: intArg(args, "encounter_id"),
                doctorId: intArg(args, "doctor_id"),
                procedureName: procedureName,
                procedureCode: stringArg(args, "procedure_code"),
                procedureDate: procedureDate,
                bodySite: stringArg(args, "body_site"),
                outcome: stringArg(args, "outcome"),
                notes: stringArg(args, "notes"),
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
