import MCP
import GRDB
import Foundation

extension QueryTools {
    var patientTools: [Tool] {
        [
            Tool(
                name: "get_patient_summary",
                description: "Get a comprehensive patient summary: demographics, active diagnoses, current medications, allergies, and recent encounters/labs.",
                inputSchema: .object([
                    "patient_id": .object(["type": "integer", "description": "Patient ID"]),
                ])
            ),
            Tool(
                name: "list_patients",
                description: "List all patients with basic demographics.",
                inputSchema: .object([:])
            ),
        ]
    }
}

// MARK: - Database API

extension QueryTools {
    func getPatientSummary(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let patientId = intArg(args, "patient_id") else {
            return .init(content: [.text("Missing required parameter: patient_id")], isError: true)
        }

        let jsonData = try await db.dbQueue.read { db -> Data in
            guard let patient = try Patient.fetchOne(db, key: patientId) else {
                return try JSONSerialization.data(withJSONObject: ["error": "Patient not found"])
            }

            var result: [String: Any] = [
                "id": patient.id!,
                "first_name": patient.firstName,
                "last_name": patient.lastName,
            ]
            if let dob = patient.dateOfBirth { result["date_of_birth"] = dob }
            if let gender = patient.gender { result["gender"] = gender }
            if let bloodType = patient.bloodType { result["blood_type"] = bloodType }

            let diagnoses = try Diagnosis.filter(Column("patient_id") == patientId && Column("status") != "resolved")
                .order(Column("diagnosis_date").desc)
                .fetchAll(db)
            result["active_diagnoses"] = diagnoses.map { d in
                var entry: [String: Any] = ["id": d.id!, "description": d.description, "status": d.status, "diagnosis_date": d.diagnosisDate]
                if let icd = d.icdCode { entry["icd_code"] = icd }
                return entry
            }

            let medications = try Medication.filter(Column("patient_id") == patientId && Column("is_active") == true)
                .order(Column("name"))
                .fetchAll(db)
            result["current_medications"] = medications.map { m in
                var entry: [String: Any] = ["id": m.id!, "name": m.name, "dosage": m.dosage, "frequency": m.frequency, "route": m.route]
                if let end = m.endDate { entry["end_date"] = end }
                return entry
            }

            let allergies = try Allergy.filter(Column("patient_id") == patientId && Column("status") == "active")
                .order(Column("severity").desc)
                .fetchAll(db)
            result["allergies"] = allergies.map { a in
                var entry: [String: Any] = ["id": a.id!, "allergen": a.allergen, "allergen_type": a.allergenType, "severity": a.severity]
                if let reaction = a.reaction { entry["reaction"] = reaction }
                return entry
            }

            let encounters = try Encounter.filter(Column("patient_id") == patientId)
                .order(Column("encounter_date").desc)
                .limit(5)
                .fetchAll(db)
            result["recent_encounters"] = encounters.map { e in
                var entry: [String: Any] = ["id": e.id!, "encounter_date": e.encounterDate, "encounter_type": e.encounterType]
                if let complaint = e.chiefComplaint { entry["chief_complaint"] = complaint }
                return entry
            }

            let labs = try LabResult.filter(Column("patient_id") == patientId)
                .order(Column("test_date").desc)
                .limit(10)
                .fetchAll(db)
            result["recent_labs"] = labs.map { l in
                var entry: [String: Any] = ["id": l.id!, "test_name": l.testName, "value": l.value, "test_date": l.testDate]
                if let unit = l.unit { entry["unit"] = unit }
                if let flag = l.flag { entry["flag"] = flag }
                return entry
            }

            return try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "{}")], isError: false)
    }

    func listPatients() async throws -> CallTool.Result {
        let patients = try await db.dbQueue.read { db in
            try Patient.order(Column("last_name"), Column("first_name")).fetchAll(db)
        }
        return try jsonResult(patients)
    }
}
