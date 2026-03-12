import MCP
import GRDB
import Foundation

extension QueryTools {
    var timelineTools: [Tool] {
        [
            Tool(
                name: "get_health_timeline",
                description: "Get a unified chronological timeline of all health events for a patient. Combines encounters, diagnoses, labs, medications, vitals, procedures, immunizations, and imaging into a single ordered view.",
                inputSchema: .object([
                    "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                    "date_from": .object(["type": "string", "description": "Start date ISO 8601 (optional)"]),
                    "date_to": .object(["type": "string", "description": "End date ISO 8601 (optional)"]),
                    "event_types": .object(["type": "string", "description": "Comma-separated event types to include: encounter,diagnosis,lab,medication,vital,procedure,immunization,imaging (optional, defaults to all)"]),
                ])
            ),
        ]
    }
}

// MARK: - Database API

extension QueryTools {
    func getHealthTimeline(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id") else {
            return .init(content: [.text("Missing required parameter: patient_id")], isError: true)
        }

        let dateFrom = stringArg(args, "date_from")
        let dateTo = stringArg(args, "date_to")

        let allowedTypes: Set<String>
        if let typesStr = stringArg(args, "event_types") {
            allowedTypes = Set(typesStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        } else {
            allowedTypes = ["encounter", "diagnosis", "lab", "medication", "vital", "procedure", "immunization", "imaging"]
        }

        let jsonData = try await db.dbQueue.read { db -> Data in
            var timeline: [[String: Any]] = []

            if allowedTypes.contains("encounter") {
                var query = Encounter.filter(Column("patient_id") == patientId)
                if let dateFrom { query = query.filter(Column("encounter_date") >= dateFrom) }
                if let dateTo { query = query.filter(Column("encounter_date") <= dateTo) }
                for e in try query.order(Column("encounter_date").desc).fetchAll(db) {
                    var entry: [String: Any] = ["event_type": "encounter", "date": e.encounterDate, "id": e.id!, "encounter_type": e.encounterType]
                    if let complaint = e.chiefComplaint { entry["detail"] = complaint }
                    timeline.append(entry)
                }
            }

            if allowedTypes.contains("diagnosis") {
                var query = Diagnosis.filter(Column("patient_id") == patientId)
                if let dateFrom { query = query.filter(Column("diagnosis_date") >= dateFrom) }
                if let dateTo { query = query.filter(Column("diagnosis_date") <= dateTo) }
                for d in try query.order(Column("diagnosis_date").desc).fetchAll(db) {
                    var entry: [String: Any] = ["event_type": "diagnosis", "date": d.diagnosisDate, "id": d.id!, "detail": d.description, "status": d.status]
                    if let icd = d.icdCode { entry["icd_code"] = icd }
                    timeline.append(entry)
                }
            }

            if allowedTypes.contains("lab") {
                var query = LabResult.filter(Column("patient_id") == patientId)
                if let dateFrom { query = query.filter(Column("test_date") >= dateFrom) }
                if let dateTo { query = query.filter(Column("test_date") <= dateTo) }
                for l in try query.order(Column("test_date").desc).fetchAll(db) {
                    var entry: [String: Any] = ["event_type": "lab", "date": l.testDate, "id": l.id!, "detail": "\(l.testName): \(l.value)"]
                    if let unit = l.unit { entry["unit"] = unit }
                    if let flag = l.flag { entry["flag"] = flag }
                    timeline.append(entry)
                }
            }

            if allowedTypes.contains("medication") {
                var query = Medication.filter(Column("patient_id") == patientId)
                if let dateFrom { query = query.filter(Column("start_date") >= dateFrom) }
                if let dateTo { query = query.filter(Column("start_date") <= dateTo) }
                for m in try query.order(Column("start_date").desc).fetchAll(db) {
                    timeline.append(["event_type": "medication", "date": m.startDate, "id": m.id!, "detail": "\(m.name) \(m.dosage) \(m.frequency)", "is_active": m.isActive])
                }
            }

            if allowedTypes.contains("vital") {
                var query = VitalSign.filter(Column("patient_id") == patientId)
                if let dateFrom { query = query.filter(Column("measured_date") >= dateFrom) }
                if let dateTo { query = query.filter(Column("measured_date") <= dateTo) }
                for v in try query.order(Column("measured_date").desc).fetchAll(db) {
                    var entry: [String: Any] = ["event_type": "vital", "date": v.measuredDate, "id": v.id!, "detail": "\(v.vitalType): \(v.value)"]
                    if let unit = v.unit { entry["unit"] = unit }
                    timeline.append(entry)
                }
            }

            if allowedTypes.contains("procedure") {
                var query = ProcedureRecord.filter(Column("patient_id") == patientId)
                if let dateFrom { query = query.filter(Column("procedure_date") >= dateFrom) }
                if let dateTo { query = query.filter(Column("procedure_date") <= dateTo) }
                for p in try query.order(Column("procedure_date").desc).fetchAll(db) {
                    var entry: [String: Any] = ["event_type": "procedure", "date": p.procedureDate, "id": p.id!, "detail": p.procedureName]
                    if let outcome = p.outcome { entry["outcome"] = outcome }
                    timeline.append(entry)
                }
            }

            if allowedTypes.contains("immunization") {
                var query = Immunization.filter(Column("patient_id") == patientId)
                if let dateFrom { query = query.filter(Column("administration_date") >= dateFrom) }
                if let dateTo { query = query.filter(Column("administration_date") <= dateTo) }
                for i in try query.order(Column("administration_date").desc).fetchAll(db) {
                    var entry: [String: Any] = ["event_type": "immunization", "date": i.administrationDate, "id": i.id!, "detail": i.vaccineName]
                    if let dose = i.doseNumber { entry["dose_number"] = dose }
                    timeline.append(entry)
                }
            }

            if allowedTypes.contains("imaging") {
                var query = Imaging.filter(Column("patient_id") == patientId)
                if let dateFrom { query = query.filter(Column("imaging_date") >= dateFrom) }
                if let dateTo { query = query.filter(Column("imaging_date") <= dateTo) }
                for i in try query.order(Column("imaging_date").desc).fetchAll(db) {
                    var entry: [String: Any] = ["event_type": "imaging", "date": i.imagingDate, "id": i.id!, "detail": "\(i.imagingType) - \(i.bodyPart)"]
                    if let impression = i.impression { entry["impression"] = impression }
                    timeline.append(entry)
                }
            }

            let sorted = timeline.sorted { ($0["date"] as? String ?? "") > ($1["date"] as? String ?? "") }
            return try JSONSerialization.data(withJSONObject: sorted, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "[]")], isError: false)
    }
}
