import MCP
import GRDB
import Foundation

struct CRUDClinicalTools {
    let db: DatabaseManager

    var tools: [Tool] {
        encounterTool + diagnosisTool + medicationTool + labResultTool
        + vitalSignTool + procedureTool + immunizationTool + allergyTool + imagingTool
    }

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        switch params.name {
        case "create_encounter": return try await createEncounter(params)
        case "create_diagnosis": return try await createDiagnosis(params)
        case "create_medication": return try await createMedication(params)
        case "create_lab_result": return try await createLabResult(params)
        case "create_vital_sign": return try await createVitalSign(params)
        case "create_procedure": return try await createProcedure(params)
        case "create_immunization": return try await createImmunization(params)
        case "create_allergy": return try await createAllergy(params)
        case "create_imaging": return try await createImaging(params)
        default: return nil
        }
    }
}

// MARK: - Value Helpers

func stringArg(_ args: [String: Value], _ key: String) -> String? {
    if case .string(let v) = args[key] { v } else { nil }
}

func intArg(_ args: [String: Value], _ key: String) -> Int64? {
    if case .int(let v) = args[key] { Int64(v) } else { nil }
}

func doubleArg(_ args: [String: Value], _ key: String) -> Double? {
    if case .double(let v) = args[key] { v }
    else if case .int(let v) = args[key] { Double(v) }
    else { nil }
}

func boolArg(_ args: [String: Value], _ key: String) -> Bool? {
    if case .bool(let v) = args[key] { v } else { nil }
}
