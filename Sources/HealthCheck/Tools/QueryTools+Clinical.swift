import MCP
import GRDB
import Foundation

extension QueryTools {
    var clinicalTools: [Tool] {
        [
            Tool(
                name: "get_lab_history",
                description: "Get lab results for a patient, optionally filtered by test name and date range. Results ordered chronologically.",
                inputSchema: .object([
                    "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                    "test_name": .object(["type": "string", "description": "Filter by test name (optional)"]),
                    "date_from": .object(["type": "string", "description": "Start date ISO 8601 (optional)"]),
                    "date_to": .object(["type": "string", "description": "End date ISO 8601 (optional)"]),
                ])
            ),
            Tool(
                name: "get_medication_list",
                description: "Get medications for a patient. Optionally filter to active-only. Includes prescribing doctor and linked diagnosis.",
                inputSchema: .object([
                    "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                    "active_only": .object(["type": "boolean", "description": "Only active medications (default: false)"]),
                ])
            ),
            Tool(
                name: "get_encounter",
                description: "Get a full encounter with all linked clinical data: diagnoses, labs, vitals, procedures, medications.",
                inputSchema: .object([
                    "encounter_id": .object(["type": "integer", "description": "Encounter ID"]),
                ])
            ),
            Tool(
                name: "get_diagnosis",
                description: "Get diagnoses for a patient, optionally filtered by status (active/resolved/chronic/suspected).",
                inputSchema: .object([
                    "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                    "status": .object(["type": "string", "description": "Filter by status (optional)"]),
                ])
            ),
            Tool(
                name: "get_allergies",
                description: "Get all allergies for a patient with severity, reaction, and status.",
                inputSchema: .object([
                    "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                ])
            ),
            Tool(
                name: "get_immunization_history",
                description: "Get full immunization/vaccine history for a patient, ordered by date.",
                inputSchema: .object([
                    "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                ])
            ),
        ]
    }
}

// MARK: - Database API

extension QueryTools {
    func getLabHistory(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id") else {
            return .init(content: [.text("Missing required parameter: patient_id")], isError: true)
        }

        let testName = stringArg(args, "test_name")
        let dateFrom = stringArg(args, "date_from")
        let dateTo = stringArg(args, "date_to")

        let results = try await db.dbQueue.read { db in
            var query = LabResult.filter(Column("patient_id") == patientId)
            if let testName { query = query.filter(Column("test_name") == testName) }
            if let dateFrom { query = query.filter(Column("test_date") >= dateFrom) }
            if let dateTo { query = query.filter(Column("test_date") <= dateTo) }
            return try query.order(Column("test_date").desc).fetchAll(db)
        }

        return try jsonResult(results)
    }

    func getMedicationList(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id") else {
            return .init(content: [.text("Missing required parameter: patient_id")], isError: true)
        }

        let activeOnly = boolArg(args, "active_only") ?? false

        let jsonData = try await db.dbQueue.read { db -> Data in
            var sql = """
                SELECT m.*, d.first_name AS doctor_first_name, d.last_name AS doctor_last_name,
                       diag.description AS diagnosis_description
                FROM medication m
                LEFT JOIN doctor d ON m.doctor_id = d.id
                LEFT JOIN diagnosis diag ON m.diagnosis_id = diag.id
                WHERE m.patient_id = ?
                """
            var arguments: [any DatabaseValueConvertible] = [patientId]

            if activeOnly {
                sql += " AND m.is_active = ?"
                arguments.append(true)
            }

            sql += " ORDER BY m.is_active DESC, m.name"
            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))

            let medications = rows.map { row -> [String: Any] in
                var entry: [String: Any] = [
                    "id": (row["id"] as Int64?) ?? 0,
                    "name": (row["name"] as String?) ?? "",
                    "dosage": (row["dosage"] as String?) ?? "",
                    "frequency": (row["frequency"] as String?) ?? "",
                    "route": (row["route"] as String?) ?? "",
                    "start_date": (row["start_date"] as String?) ?? "",
                    "is_active": (row["is_active"] as Bool?) ?? false,
                ]
                if let endDate = row["end_date"] as String? { entry["end_date"] = endDate }
                if let notes = row["notes"] as String? { entry["notes"] = notes }
                if let atcCode = row["atc_code"] as String? { entry["atc_code"] = atcCode }
                if let ndcCode = row["ndc_code"] as String? { entry["ndc_code"] = ndcCode }
                if let firstName = row["doctor_first_name"] as String?,
                   let lastName = row["doctor_last_name"] as String? {
                    entry["prescribing_doctor"] = "\(firstName) \(lastName)"
                }
                if let diagDesc = row["diagnosis_description"] as String? {
                    entry["diagnosis"] = diagDesc
                }
                return entry
            }

            return try JSONSerialization.data(withJSONObject: medications, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "[]")], isError: false)
    }

    func getEncounter(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let encounterId = intArg(args, "encounter_id") else {
            return .init(content: [.text("Missing required parameter: encounter_id")], isError: true)
        }

        let jsonData = try await db.dbQueue.read { db -> Data in
            guard let encounter = try Encounter.fetchOne(db, key: encounterId) else {
                return try JSONSerialization.data(withJSONObject: ["error": "Encounter not found"])
            }

            var entry: [String: Any] = [
                "id": encounter.id!,
                "patient_id": encounter.patientId,
                "encounter_date": encounter.encounterDate,
                "encounter_type": encounter.encounterType,
            ]
            if let facilityId = encounter.facilityId { entry["facility_id"] = facilityId }
            if let doctorId = encounter.doctorId { entry["doctor_id"] = doctorId }
            if let complaint = encounter.chiefComplaint { entry["chief_complaint"] = complaint }
            if let notes = encounter.notes { entry["notes"] = notes }

            if let doctorId = encounter.doctorId, let doctor = try Doctor.fetchOne(db, key: doctorId) {
                entry["doctor"] = "\(doctor.firstName) \(doctor.lastName)"
            }
            if let facilityId = encounter.facilityId, let facility = try Facility.fetchOne(db, key: facilityId) {
                entry["facility"] = facility.name
            }

            let diagnoses = try Diagnosis.filter(Column("encounter_id") == encounterId).fetchAll(db)
            entry["diagnoses"] = diagnoses.map { d in
                var e: [String: Any] = ["id": d.id!, "description": d.description, "status": d.status]
                if let icd = d.icdCode { e["icd_code"] = icd }
                return e
            }

            let labs = try LabResult.filter(Column("encounter_id") == encounterId).fetchAll(db)
            entry["lab_results"] = labs.map { l in
                var e: [String: Any] = ["id": l.id!, "test_name": l.testName, "value": l.value]
                if let unit = l.unit { e["unit"] = unit }
                if let flag = l.flag { e["flag"] = flag }
                return e
            }

            let vitals = try VitalSign.filter(Column("encounter_id") == encounterId).fetchAll(db)
            entry["vital_signs"] = vitals.map { v in
                var e: [String: Any] = ["id": v.id!, "vital_type": v.vitalType, "value": v.value]
                if let unit = v.unit { e["unit"] = unit }
                return e
            }

            let procedures = try ProcedureRecord.filter(Column("encounter_id") == encounterId).fetchAll(db)
            entry["procedures"] = procedures.map { p in
                var e: [String: Any] = ["id": p.id!, "procedure_name": p.procedureName, "procedure_date": p.procedureDate]
                if let outcome = p.outcome { e["outcome"] = outcome }
                return e
            }

            let imaging = try Imaging.filter(Column("encounter_id") == encounterId).fetchAll(db)
            entry["imaging"] = imaging.map { i in
                var e: [String: Any] = ["id": i.id!, "imaging_type": i.imagingType, "body_part": i.bodyPart, "imaging_date": i.imagingDate]
                if let findings = i.findings { e["findings"] = findings }
                if let impression = i.impression { e["impression"] = impression }
                return e
            }

            return try JSONSerialization.data(withJSONObject: entry, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "{}")], isError: false)
    }

    func getDiagnosis(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id") else {
            return .init(content: [.text("Missing required parameter: patient_id")], isError: true)
        }

        let status = stringArg(args, "status")

        let results = try await db.dbQueue.read { db in
            var query = Diagnosis.filter(Column("patient_id") == patientId)
            if let status { query = query.filter(Column("status") == status) }
            return try query.order(Column("diagnosis_date").desc).fetchAll(db)
        }

        return try jsonResult(results)
    }

    func getAllergies(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id") else {
            return .init(content: [.text("Missing required parameter: patient_id")], isError: true)
        }

        let results = try await db.dbQueue.read { db in
            try Allergy.filter(Column("patient_id") == patientId)
                .order(Column("severity").desc)
                .fetchAll(db)
        }

        return try jsonResult(results)
    }

    func getImmunizationHistory(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id") else {
            return .init(content: [.text("Missing required parameter: patient_id")], isError: true)
        }

        let results = try await db.dbQueue.read { db in
            try Immunization.filter(Column("patient_id") == patientId)
                .order(Column("administration_date").desc)
                .fetchAll(db)
        }

        return try jsonResult(results)
    }
}
