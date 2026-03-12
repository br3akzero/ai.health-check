import MCP
import GRDB
import Foundation

struct QueryTools {
    let db: DatabaseManager

    var tools: [Tool] {
        patientTools + clinicalTools + timelineTools + providerTools + documentTools
    }

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        switch params.name {
        // Patient
        case "get_patient_summary": return try await getPatientSummary(params)
        case "list_patients": return try await listPatients()
        // Clinical
        case "get_lab_history": return try await getLabHistory(params)
        case "get_medication_list": return try await getMedicationList(params)
        case "get_encounter": return try await getEncounter(params)
        case "get_diagnosis": return try await getDiagnosis(params)
        case "get_allergies": return try await getAllergies(params)
        case "get_immunization_history": return try await getImmunizationHistory(params)
        // Timeline
        case "get_health_timeline": return try await getHealthTimeline(params)
        // Provider
        case "get_doctor": return try await getDoctor(params)
        case "list_doctors": return try await listDoctors()
        case "get_facility": return try await getFacility(params)
        case "list_facilities": return try await listFacilities()
        // Document
        case "search_documents": return try await searchDocuments(params)
        case "get_document": return try await getDocument(params)
        case "list_documents": return try await listDocuments(params)
        default: return nil
        }
    }
}

// MARK: - JSON Helpers

extension QueryTools {
    func jsonResult(_ value: some Encodable) throws -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = String(data: try encoder.encode(value), encoding: .utf8) ?? "[]"
        return .init(content: [.text(json)], isError: false)
    }
}
