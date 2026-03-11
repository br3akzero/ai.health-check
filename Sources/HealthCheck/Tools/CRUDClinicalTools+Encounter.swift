import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var encounterTool: [Tool] {
        [Tool(
            name: "create_encounter",
            description: "Create a new encounter (visit/exam). Returns the encounter ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "facility_id": .object(["type": "integer", "description": "Facility ID"]),
                "doctor_id": .object(["type": "integer", "description": "Doctor ID"]),
                "encounter_date": .object(["type": "string", "description": "Date of encounter (ISO 8601)"]),
                "encounter_type": .object(["type": "string", "description": "Type (office_visit, lab_visit, emergency, inpatient, telehealth)"]),
                "chief_complaint": .object(["type": "string", "description": "Chief complaint"]),
                "notes": .object(["type": "string", "description": "Notes"]),
            ])
        )]
    }

    func createEncounter(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let encounterDate = stringArg(args, "encounter_date"),
              let encounterType = stringArg(args, "encounter_type") else {
            return .init(content: [.text("Missing required: patient_id, encounter_date, encounter_type")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try Encounter(
                id: nil,
                patientId: patientId,
                facilityId: intArg(args, "facility_id"),
                doctorId: intArg(args, "doctor_id"),
                encounterDate: encounterDate,
                encounterType: encounterType,
                chiefComplaint: stringArg(args, "chief_complaint"),
                notes: stringArg(args, "notes"),
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
