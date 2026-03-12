import MCP
import GRDB
import Foundation

extension QueryTools {
    var providerTools: [Tool] {
        [
            Tool(
                name: "get_doctor",
                description: "Get doctor details including linked facilities.",
                inputSchema: .object([
                    "doctor_id": .object(["type": "integer", "description": "Doctor ID"]),
                ])
            ),
            Tool(
                name: "list_doctors",
                description: "List all doctors with their specialties.",
                inputSchema: .object([:])
            ),
            Tool(
                name: "get_facility",
                description: "Get facility details including linked doctors.",
                inputSchema: .object([
                    "facility_id": .object(["type": "integer", "description": "Facility ID"]),
                ])
            ),
            Tool(
                name: "list_facilities",
                description: "List all facilities with their types.",
                inputSchema: .object([:])
            ),
        ]
    }
}

// MARK: - Database API

extension QueryTools {
    func getDoctor(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let doctorId = intArg(args, "doctor_id") else {
            return .init(content: [.text("Missing required parameter: doctor_id")], isError: true)
        }

        let jsonData = try await db.dbQueue.read { db -> Data in
            guard let doctor = try Doctor.fetchOne(db, key: doctorId) else {
                return try JSONSerialization.data(withJSONObject: ["error": "Doctor not found"])
            }

            var entry: [String: Any] = [
                "id": doctor.id!,
                "first_name": doctor.firstName,
                "last_name": doctor.lastName,
            ]
            if let specialty = doctor.specialty { entry["specialty"] = specialty }

            let facilities = try Row.fetchAll(db, sql: """
                SELECT f.* FROM facility f
                JOIN facility_doctor fd ON fd.facility_id = f.id
                WHERE fd.doctor_id = ?
                ORDER BY f.name
                """, arguments: [doctorId])

            entry["facilities"] = facilities.map { row in
                var f: [String: Any] = [
                    "id": (row["id"] as Int64?) ?? 0,
                    "name": (row["name"] as String?) ?? "",
                    "facility_type": (row["facility_type"] as String?) ?? "",
                ]
                if let phone = row["phone"] as String? { f["phone"] = phone }
                if let address = row["address"] as String? { f["address"] = address }
                return f
            }

            return try JSONSerialization.data(withJSONObject: entry, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "{}")], isError: false)
    }

    func listDoctors() async throws -> CallTool.Result {
        let doctors = try await db.dbQueue.read { db in
            try Doctor.order(Column("last_name"), Column("first_name")).fetchAll(db)
        }
        return try jsonResult(doctors)
    }

    func getFacility(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let facilityId = intArg(args, "facility_id") else {
            return .init(content: [.text("Missing required parameter: facility_id")], isError: true)
        }

        let jsonData = try await db.dbQueue.read { db -> Data in
            guard let facility = try Facility.fetchOne(db, key: facilityId) else {
                return try JSONSerialization.data(withJSONObject: ["error": "Facility not found"])
            }

            var entry: [String: Any] = [
                "id": facility.id!,
                "name": facility.name,
                "facility_type": facility.facilityType,
            ]
            if let phone = facility.phone { entry["phone"] = phone }
            if let address = facility.address { entry["address"] = address }
            if let website = facility.website { entry["website"] = website }

            let doctors = try Row.fetchAll(db, sql: """
                SELECT d.* FROM doctor d
                JOIN facility_doctor fd ON fd.doctor_id = d.id
                WHERE fd.facility_id = ?
                ORDER BY d.last_name, d.first_name
                """, arguments: [facilityId])

            entry["doctors"] = doctors.map { row in
                var d: [String: Any] = [
                    "id": (row["id"] as Int64?) ?? 0,
                    "first_name": (row["first_name"] as String?) ?? "",
                    "last_name": (row["last_name"] as String?) ?? "",
                ]
                if let specialty = row["specialty"] as String? { d["specialty"] = specialty }
                return d
            }

            return try JSONSerialization.data(withJSONObject: entry, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "{}")], isError: false)
    }

    func listFacilities() async throws -> CallTool.Result {
        let facilities = try await db.dbQueue.read { db in
            try Facility.order(Column("name")).fetchAll(db)
        }
        return try jsonResult(facilities)
    }
}
