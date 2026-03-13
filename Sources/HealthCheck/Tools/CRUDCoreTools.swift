import MCP
import GRDB
import Foundation

struct CRUDCoreTools {
    let db: DatabaseManager

    var tools: [Tool] {
        [
            Tool(
                name: "upsert_patient",
                description: "Create or update a patient. If id is provided, updates the existing record. Returns the patient ID.",
                inputSchema: schema([
                    "id": .object(["type": "integer", "description": "Patient ID (omit to create new)"]),
                    "first_name": .object(["type": "string", "description": "First name"]),
                    "last_name": .object(["type": "string", "description": "Last name"]),
                    "date_of_birth": .object(["type": "string", "description": "Date of birth (ISO 8601)"]),
                    "gender": .object(["type": "string", "description": "Gender"]),
                    "blood_type": .object(["type": "string", "description": "Blood type (e.g. O+, A-)"]),
                    "notes": .object(["type": "string", "description": "Free-text notes (social history, lifestyle, etc.)"]),
                ])
            ),
            Tool(
                name: "upsert_facility",
                description: "Create or update a facility. If id is provided, updates the existing record. Returns the facility ID.",
                inputSchema: schema([
                    "id": .object(["type": "integer", "description": "Facility ID (omit to create new)"]),
                    "name": .object(["type": "string", "description": "Facility name"]),
                    "facility_type": .object(["type": "string", "description": "Type (hospital, clinic, lab, pharmacy, imaging_center)"]),
                    "phone": .object(["type": "string", "description": "Phone number"]),
                    "address": .object(["type": "string", "description": "Address"]),
                    "website": .object(["type": "string", "description": "Website URL"]),
                ])
            ),
            Tool(
                name: "upsert_doctor",
                description: "Create or update a doctor. If id is provided, updates the existing record. Returns the doctor ID.",
                inputSchema: schema([
                    "id": .object(["type": "integer", "description": "Doctor ID (omit to create new)"]),
                    "first_name": .object(["type": "string", "description": "First name"]),
                    "last_name": .object(["type": "string", "description": "Last name"]),
                    "specialty": .object(["type": "string", "description": "Medical specialty"]),
                ])
            ),
            Tool(
                name: "link_doctor_to_facility",
                description: "Link a doctor to a facility. Creates the relationship if it doesn't exist.",
                inputSchema: schema([
                    "facility_id": .object(["type": "integer", "description": "Facility ID"]),
                    "doctor_id": .object(["type": "integer", "description": "Doctor ID"]),
                ])
            ),
        ]
    }

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        switch params.name {
        case "upsert_patient":
            return try await upsertPatient(params)
        case "upsert_facility":
            return try await upsertFacility(params)
        case "upsert_doctor":
            return try await upsertDoctor(params)
        case "link_doctor_to_facility":
            return try await linkDoctorToFacility(params)
        default:
            return nil
        }
    }
}

// MARK: - Database API

private extension CRUDCoreTools {
    func upsertPatient(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              case .string(let firstName) = args["first_name"],
              case .string(let lastName) = args["last_name"] else {
            return .init(content: [.text("Missing required parameters: first_name, last_name")], isError: true)
        }

        let now = ISO8601DateFormatter().string(from: .now)
        let existingId = args["id"].flatMap { if case .int(let v) = $0 { Int64(v) } else { nil } }

        let id: Int64 = try await db.dbQueue.write { db in
            if let existingId, var existing = try Patient.fetchOne(db, key: existingId) {
                existing.firstName = firstName
                existing.lastName = lastName
                if let dob = stringArg(args, "date_of_birth") { existing.dateOfBirth = dob }
                if let gender = stringArg(args, "gender") { existing.gender = gender }
                if let bloodType = stringArg(args, "blood_type") { existing.bloodType = bloodType }
                if let notes = stringArg(args, "notes") { existing.notes = notes }
                existing.updatedAt = now
                try existing.update(db)
                return existingId
            } else {
                let record = Patient(
                    id: nil,
                    firstName: firstName,
                    lastName: lastName,
                    dateOfBirth: args["date_of_birth"].flatMap { if case .string(let v) = $0 { v } else { nil } },
                    gender: args["gender"].flatMap { if case .string(let v) = $0 { v } else { nil } },
                    bloodType: args["blood_type"].flatMap { if case .string(let v) = $0 { v } else { nil } },
                    notes: args["notes"].flatMap { if case .string(let v) = $0 { v } else { nil } },
                    createdAt: now,
                    updatedAt: now
                )
                return try record.inserted(db).id!
            }
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }

    func upsertFacility(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              case .string(let name) = args["name"],
              case .string(let facilityType) = args["facility_type"] else {
            return .init(content: [.text("Missing required parameters: name, facility_type")], isError: true)
        }

        let now = ISO8601DateFormatter().string(from: .now)
        let existingId = args["id"].flatMap { if case .int(let v) = $0 { Int64(v) } else { nil } }

        let id: Int64 = try await db.dbQueue.write { db in
            if let existingId, var existing = try Facility.fetchOne(db, key: existingId) {
                existing.name = name
                existing.facilityType = facilityType
                existing.phone = args["phone"].flatMap { if case .string(let v) = $0 { v } else { nil } }
                existing.address = args["address"].flatMap { if case .string(let v) = $0 { v } else { nil } }
                existing.website = args["website"].flatMap { if case .string(let v) = $0 { v } else { nil } }
                try existing.update(db)
                return existingId
            } else {
                let record = Facility(
                    id: nil,
                    name: name,
                    facilityType: facilityType,
                    phone: args["phone"].flatMap { if case .string(let v) = $0 { v } else { nil } },
                    address: args["address"].flatMap { if case .string(let v) = $0 { v } else { nil } },
                    website: args["website"].flatMap { if case .string(let v) = $0 { v } else { nil } },
                    createdAt: now
                )
                return try record.inserted(db).id!
            }
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }

    func upsertDoctor(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              case .string(let firstName) = args["first_name"],
              case .string(let lastName) = args["last_name"] else {
            return .init(content: [.text("Missing required parameters: first_name, last_name")], isError: true)
        }

        let now = ISO8601DateFormatter().string(from: .now)
        let existingId = args["id"].flatMap { if case .int(let v) = $0 { Int64(v) } else { nil } }

        let id: Int64 = try await db.dbQueue.write { db in
            if let existingId, var existing = try Doctor.fetchOne(db, key: existingId) {
                existing.firstName = firstName
                existing.lastName = lastName
                existing.specialty = args["specialty"].flatMap { if case .string(let v) = $0 { v } else { nil } }
                try existing.update(db)
                return existingId
            } else {
                let record = Doctor(
                    id: nil,
                    firstName: firstName,
                    lastName: lastName,
                    specialty: args["specialty"].flatMap { if case .string(let v) = $0 { v } else { nil } },
                    createdAt: now
                )
                return try record.inserted(db).id!
            }
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }

    func linkDoctorToFacility(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              case .int(let facilityId) = args["facility_id"],
              case .int(let doctorId) = args["doctor_id"] else {
            return .init(content: [.text("Missing required parameters: facility_id, doctor_id")], isError: true)
        }

        try await db.dbQueue.write { db in
            let existing = try FacilityDoctor.fetchOne(
                db,
                sql: "SELECT * FROM facility_doctor WHERE facility_id = ? AND doctor_id = ?",
                arguments: [facilityId, doctorId]
            )
            if existing == nil {
                try FacilityDoctor(facilityId: Int64(facilityId), doctorId: Int64(doctorId)).insert(db)
            }
        }

        return .init(content: [.text("{\"status\": \"linked\"}")], isError: false)
    }
}
