import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var immunizationTool: [Tool] {
        [Tool(
            name: "create_immunization",
            description: "Create a new immunization record. Returns the immunization ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "vaccine_name": .object(["type": "string", "description": "Vaccine name"]),
                "vaccine_code": .object(["type": "string", "description": "CVX vaccine code"]),
                "dose_number": .object(["type": "integer", "description": "Dose number in series"]),
                "administration_date": .object(["type": "string", "description": "Administration date (ISO 8601)"]),
                "administered_by": .object(["type": "string", "description": "Administered by"]),
                "lot_number": .object(["type": "string", "description": "Lot number"]),
                "site": .object(["type": "string", "description": "Injection site"]),
                "notes": .object(["type": "string", "description": "Notes"]),
            ])
        )]
    }

    func createImmunization(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let vaccineName = stringArg(args, "vaccine_name"),
              let administrationDate = stringArg(args, "administration_date") else {
            return .init(content: [.text("Missing required: patient_id, vaccine_name, administration_date")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try Immunization(
                id: nil,
                patientId: patientId,
                vaccineName: vaccineName,
                vaccineCode: stringArg(args, "vaccine_code"),
                doseNumber: intArg(args, "dose_number").map { Int($0) },
                administrationDate: administrationDate,
                administeredBy: stringArg(args, "administered_by"),
                lotNumber: stringArg(args, "lot_number"),
                site: stringArg(args, "site"),
                notes: stringArg(args, "notes"),
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
