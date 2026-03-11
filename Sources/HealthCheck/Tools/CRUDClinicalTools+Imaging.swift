import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var imagingTool: [Tool] {
        [Tool(
            name: "create_imaging",
            description: "Create a new imaging record. Returns the imaging ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "encounter_id": .object(["type": "integer", "description": "Encounter ID"]),
                "doctor_id": .object(["type": "integer", "description": "Doctor ID"]),
                "imaging_type": .object(["type": "string", "description": "Type (x_ray, ct, mri, ultrasound, pet, mammogram)"]),
                "body_part": .object(["type": "string", "description": "Body part imaged"]),
                "imaging_date": .object(["type": "string", "description": "Imaging date (ISO 8601)"]),
                "findings": .object(["type": "string", "description": "Findings"]),
                "impression": .object(["type": "string", "description": "Radiologist impression"]),
                "notes": .object(["type": "string", "description": "Notes"]),
            ])
        )]
    }

    func createImaging(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let imagingType = stringArg(args, "imaging_type"),
              let bodyPart = stringArg(args, "body_part"),
              let imagingDate = stringArg(args, "imaging_date") else {
            return .init(content: [.text("Missing required: patient_id, imaging_type, body_part, imaging_date")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try Imaging(
                id: nil,
                patientId: patientId,
                encounterId: intArg(args, "encounter_id"),
                doctorId: intArg(args, "doctor_id"),
                imagingType: imagingType,
                bodyPart: bodyPart,
                imagingDate: imagingDate,
                findings: stringArg(args, "findings"),
                impression: stringArg(args, "impression"),
                notes: stringArg(args, "notes"),
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
