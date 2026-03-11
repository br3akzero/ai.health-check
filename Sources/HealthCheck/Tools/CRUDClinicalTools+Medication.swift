import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var medicationTool: [Tool] {
        [Tool(
            name: "create_medication",
            description: "Create a new medication/prescription. Returns the medication ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "diagnosis_id": .object(["type": "integer", "description": "Diagnosis ID"]),
                "doctor_id": .object(["type": "integer", "description": "Prescribing doctor ID"]),
                "name": .object(["type": "string", "description": "Medication name"]),
                "atc_code": .object(["type": "string", "description": "WHO ATC code"]),
                "ndc_code": .object(["type": "string", "description": "US NDC code"]),
                "dosage": .object(["type": "string", "description": "Dosage (e.g. 500mg)"]),
                "frequency": .object(["type": "string", "description": "Frequency (e.g. twice daily)"]),
                "route": .object(["type": "string", "description": "Route (oral, IV, topical, etc.)"]),
                "start_date": .object(["type": "string", "description": "Start date (ISO 8601)"]),
                "end_date": .object(["type": "string", "description": "End date (ISO 8601)"]),
                "is_active": .object(["type": "boolean", "description": "Whether medication is currently active"]),
                "notes": .object(["type": "string", "description": "Notes"]),
            ])
        )]
    }

    func createMedication(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let name = stringArg(args, "name"),
              let dosage = stringArg(args, "dosage"),
              let frequency = stringArg(args, "frequency"),
              let route = stringArg(args, "route"),
              let startDate = stringArg(args, "start_date") else {
            return .init(content: [.text("Missing required: patient_id, name, dosage, frequency, route, start_date")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try Medication(
                id: nil,
                patientId: patientId,
                diagnosisId: intArg(args, "diagnosis_id"),
                doctorId: intArg(args, "doctor_id"),
                name: name,
                atcCode: stringArg(args, "atc_code"),
                ndcCode: stringArg(args, "ndc_code"),
                dosage: dosage,
                frequency: frequency,
                route: route,
                startDate: startDate,
                endDate: stringArg(args, "end_date"),
                isActive: boolArg(args, "is_active") ?? true,
                notes: stringArg(args, "notes"),
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
