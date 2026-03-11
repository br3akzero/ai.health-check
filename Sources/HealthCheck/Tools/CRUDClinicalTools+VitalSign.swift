import MCP
import GRDB
import Foundation

extension CRUDClinicalTools {
    var vitalSignTool: [Tool] {
        [Tool(
            name: "create_vital_sign",
            description: "Create a new vital sign measurement. Returns the vital sign ID.",
            inputSchema: .object([
                "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                "encounter_id": .object(["type": "integer", "description": "Encounter ID"]),
                "vital_type": .object(["type": "string", "description": "Type (blood_pressure, heart_rate, temperature, respiratory_rate, oxygen_saturation, weight, height, bmi)"]),
                "value": .object(["type": "string", "description": "Value as string (e.g. 120/80)"]),
                "numeric_value": .object(["type": "number", "description": "Primary numeric value (e.g. 120 for systolic)"]),
                "numeric_value_2": .object(["type": "number", "description": "Secondary numeric value (e.g. 80 for diastolic)"]),
                "unit": .object(["type": "string", "description": "Unit (mmHg, bpm, °F, etc.)"]),
                "measured_date": .object(["type": "string", "description": "Measurement date (ISO 8601)"]),
            ])
        )]
    }

    func createVitalSign(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id"),
              let vitalType = stringArg(args, "vital_type"),
              let value = stringArg(args, "value"),
              let measuredDate = stringArg(args, "measured_date") else {
            return .init(content: [.text("Missing required: patient_id, vital_type, value, measured_date")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try VitalSign(
                id: nil,
                patientId: patientId,
                encounterId: intArg(args, "encounter_id"),
                vitalType: vitalType,
                value: value,
                numericValue: doubleArg(args, "numeric_value"),
                numericValue2: doubleArg(args, "numeric_value_2"),
                unit: stringArg(args, "unit"),
                measuredDate: measuredDate,
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
