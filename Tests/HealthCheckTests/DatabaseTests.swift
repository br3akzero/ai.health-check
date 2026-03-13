import Testing
import Foundation
import GRDB
@testable import HealthCheck

// MARK: - Migration Tests

@Test("All 19 tables exist after migration")
func allTablesExist() throws {
    let manager = try makeDB()

    let expectedTables: Set<String> = [
        "patient", "facility", "doctor", "facility_doctor", "document",
        "encounter", "document_encounter", "diagnosis", "medication", "lab_result",
        "vital_sign", "procedure_record", "immunization", "allergy", "imaging",
        "document_chunk", "document_summary", "extracted_entity", "document_page"
    ]

    let actualTables: Set<String> = try manager.dbQueue.read { db in
        let rows = try Row.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'")
        return Set(rows.map { $0["name"] as String })
    }

    for table in expectedTables {
        #expect(actualTables.contains(table), "Missing table: \(table)")
    }
}

@Test("Column validation for patient table")
func patientColumns() throws {
    let manager = try makeDB()

    let expectedColumns: Set<String> = [
        "id", "first_name", "last_name", "date_of_birth", "gender",
        "blood_type", "notes", "created_at", "updated_at"
    ]

    let actualColumns: Set<String> = try manager.dbQueue.read { db in
        let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(patient)")
        return Set(rows.map { $0["name"] as String })
    }

    #expect(actualColumns == expectedColumns)
}

@Test("Column validation for document table")
func documentColumns() throws {
    let manager = try makeDB()

    let expectedColumns: Set<String> = [
        "id", "patient_id", "facility_id", "doctor_id", "file_path",
        "file_hash", "file_name", "document_date", "document_type", "tags",
        "language", "page_count", "processing_status", "processing_error",
        "raw_text", "created_at", "updated_at"
    ]

    let actualColumns: Set<String> = try manager.dbQueue.read { db in
        let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(document)")
        return Set(rows.map { $0["name"] as String })
    }

    #expect(actualColumns == expectedColumns)
}

@Test("Column validation for lab_result table")
func labResultColumns() throws {
    let manager = try makeDB()

    let expectedColumns: Set<String> = [
        "id", "patient_id", "encounter_id", "test_name", "test_category",
        "value", "numeric_value", "unit", "reference_range_low",
        "reference_range_high", "reference_range_text", "flag",
        "test_date", "notes", "created_at"
    ]

    let actualColumns: Set<String> = try manager.dbQueue.read { db in
        let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(lab_result)")
        return Set(rows.map { $0["name"] as String })
    }

    #expect(actualColumns == expectedColumns)
}

@Test("file_hash UNIQUE constraint prevents duplicate documents")
func fileHashUnique() throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)

    try manager.dbQueue.write { db in
        _ = try makeDocument(patientId: patientId, fileHash: "same_hash").inserted(db)
    }

    #expect(throws: (any Error).self) {
        try manager.dbQueue.write { db in
            _ = try makeDocument(patientId: patientId, fileHash: "same_hash").inserted(db)
        }
    }
}

@Test("Foreign key enforcement rejects invalid patient_id")
func foreignKeyEnforcement() throws {
    let manager = try makeDB()

    #expect(throws: (any Error).self) {
        try manager.dbQueue.write { db in
            _ = try makeDocument(patientId: 999).inserted(db)
        }
    }
}

// MARK: - Model CRUD Tests

@Test("Patient insert and fetch round-trip")
func patientRoundTrip() throws {
    let manager = try makeDB()

    let inserted = try manager.dbQueue.write { db in
        try makePatient().inserted(db)
    }

    let fetched = try manager.dbQueue.read { db in
        try Patient.fetchOne(db, key: inserted.id)
    }

    let patient = try #require(fetched)
    #expect(patient.id == inserted.id)
    #expect(patient.firstName == "John")
    #expect(patient.lastName == "Doe")
    #expect(patient.dateOfBirth == "1990-05-15")
    #expect(patient.gender == "male")
    #expect(patient.bloodType == "O+")
}

@Test("Document with nullable fields preserves nils")
func documentNullableFields() throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)

    let doc = makeDocument(patientId: patientId)
    let inserted = try manager.dbQueue.write { db in
        try doc.inserted(db)
    }

    let fetched = try manager.dbQueue.read { db in
        try Document.fetchOne(db, key: inserted.id)
    }

    let document = try #require(fetched)
    #expect(document.facilityId == nil)
    #expect(document.doctorId == nil)
    #expect(document.documentDate == nil)
    #expect(document.tags == nil)
    #expect(document.processingError == nil)
    #expect(document.rawText == nil)
    #expect(document.patientId == patientId)
    #expect(document.fileHash == "abc123")
    #expect(document.processingStatus == "processing")
}

@Test("Clinical chain: Encounter → Diagnosis → Medication")
func clinicalChain() throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)

    let encounterId = try manager.dbQueue.write { db in
        try Encounter(
            id: nil,
            patientId: patientId,
            facilityId: nil,
            doctorId: nil,
            encounterDate: "2026-01-15",
            encounterType: "office_visit",
            chiefComplaint: "Annual checkup",
            notes: nil,
            createdAt: timestamp()
        ).inserted(db).id!
    }

    let diagnosisId = try manager.dbQueue.write { db in
        try Diagnosis(
            id: nil,
            patientId: patientId,
            encounterId: encounterId,
            icdCode: "E11.9",
            description: "Type 2 diabetes mellitus",
            diagnosisDate: "2026-01-15",
            status: "active",
            notes: nil,
            createdAt: timestamp()
        ).inserted(db).id!
    }

    let medicationId = try manager.dbQueue.write { db in
        try Medication(
            id: nil,
            patientId: patientId,
            diagnosisId: diagnosisId,
            doctorId: nil,
            name: "Metformin",
            atcCode: "A10BA02",
            ndcCode: nil,
            dosage: "500mg",
            frequency: "twice daily",
            route: "oral",
            startDate: "2026-01-15",
            endDate: nil,
            isActive: true,
            notes: nil,
            createdAt: timestamp()
        ).inserted(db).id!
    }

    let encounter = try manager.dbQueue.read { db in
        try Encounter.fetchOne(db, key: encounterId)
    }
    let diagnosis = try manager.dbQueue.read { db in
        try Diagnosis.fetchOne(db, key: diagnosisId)
    }
    let medication = try manager.dbQueue.read { db in
        try Medication.fetchOne(db, key: medicationId)
    }

    #expect(try #require(encounter).patientId == patientId)
    #expect(try #require(diagnosis).encounterId == encounterId)
    #expect(try #require(diagnosis).patientId == patientId)
    #expect(try #require(medication).diagnosisId == diagnosisId)
    #expect(try #require(medication).patientId == patientId)
    #expect(try #require(medication).name == "Metformin")
    #expect(try #require(medication).isActive == true)
}

@Test("LabResult with numeric values and flag")
func labResultNumericRoundTrip() throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)

    let labId = try manager.dbQueue.write { db in
        try LabResult(
            id: nil,
            patientId: patientId,
            encounterId: nil,
            testName: "Glucose",
            testCategory: "Chemistry",
            value: "126 mg/dL",
            numericValue: 126.5,
            unit: "mg/dL",
            referenceRangeLow: 70.0,
            referenceRangeHigh: 100.0,
            referenceRangeText: "70-100 mg/dL",
            flag: "high",
            testDate: "2026-01-15",
            notes: "Fasting",
            createdAt: timestamp()
        ).inserted(db).id!
    }

    let fetched = try manager.dbQueue.read { db in
        try LabResult.fetchOne(db, key: labId)
    }

    let lab = try #require(fetched)
    #expect(lab.testName == "Glucose")
    #expect(lab.numericValue == 126.5)
    #expect(lab.referenceRangeLow == 70.0)
    #expect(lab.referenceRangeHigh == 100.0)
    #expect(lab.referenceRangeText == "70-100 mg/dL")
    #expect(lab.flag == "high")
    #expect(lab.unit == "mg/dL")
}

@Test("DocumentChunk insert and fetch by document_id")
func documentChunksByDocumentId() throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)

    let docId = try manager.dbQueue.write { db in
        try makeDocument(patientId: patientId).inserted(db).id!
    }

    try manager.dbQueue.write { db in
        for i in 0..<3 {
            _ = try DocumentChunk(
                id: nil,
                documentId: docId,
                chunkIndex: i,
                content: "Chunk \(i) content",
                pageNumber: 1,
                sectionHeading: nil,
                tokenCount: 50,
                createdAt: timestamp()
            ).inserted(db)
        }
    }

    let chunks = try manager.dbQueue.read { db in
        try DocumentChunk
            .filter(Column("document_id") == docId)
            .order(Column("chunk_index"))
            .fetchAll(db)
    }

    #expect(chunks.count == 3)
    #expect(chunks[0].chunkIndex == 0)
    #expect(chunks[1].chunkIndex == 1)
    #expect(chunks[2].chunkIndex == 2)
    #expect(chunks[0].content == "Chunk 0 content")
}

@Test("Junction table: FacilityDoctor composite key")
func facilityDoctorJunction() throws {
    let manager = try makeDB()

    let facilityId = try manager.dbQueue.write { db in
        try Facility(
            id: nil,
            name: "City Lab",
            facilityType: "lab",
            phone: nil,
            address: nil,
            website: nil,
            createdAt: timestamp()
        ).inserted(db).id!
    }

    let doctorId = try manager.dbQueue.write { db in
        try Doctor(
            id: nil,
            firstName: "Jane",
            lastName: "Smith",
            specialty: "Endocrinology",
            createdAt: timestamp()
        ).inserted(db).id!
    }

    try manager.dbQueue.write { db in
        try FacilityDoctor(facilityId: facilityId, doctorId: doctorId).insert(db)
    }

    let fetched = try manager.dbQueue.read { db in
        try FacilityDoctor.fetchOne(db, sql: "SELECT * FROM facility_doctor WHERE facility_id = ? AND doctor_id = ?", arguments: [facilityId, doctorId])
    }

    let junction = try #require(fetched)
    #expect(junction.facilityId == facilityId)
    #expect(junction.doctorId == doctorId)
}

@Test("Junction table: DocumentEncounter composite key")
func documentEncounterJunction() throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)

    let docId = try manager.dbQueue.write { db in
        try makeDocument(patientId: patientId).inserted(db).id!
    }

    let encounterId = try manager.dbQueue.write { db in
        try Encounter(
            id: nil,
            patientId: patientId,
            facilityId: nil,
            doctorId: nil,
            encounterDate: "2026-01-15",
            encounterType: "lab_visit",
            chiefComplaint: nil,
            notes: nil,
            createdAt: timestamp()
        ).inserted(db).id!
    }

    try manager.dbQueue.write { db in
        try DocumentEncounter(documentId: docId, encounterId: encounterId).insert(db)
    }

    let fetched = try manager.dbQueue.read { db in
        try DocumentEncounter.fetchOne(db, sql: "SELECT * FROM document_encounter WHERE document_id = ? AND encounter_id = ?", arguments: [docId, encounterId])
    }

    let junction = try #require(fetched)
    #expect(junction.documentId == docId)
    #expect(junction.encounterId == encounterId)
}

// MARK: - Column Strategy Tests

@Test("Snake_case to camelCase column mapping")
func snakeCaseToCamelCase() throws {
    let manager = try makeDB()

    let inserted = try manager.dbQueue.write { db in
        try makePatient().inserted(db)
    }

    let row = try manager.dbQueue.read { db in
        try Row.fetchOne(db, sql: "SELECT first_name, last_name, date_of_birth FROM patient WHERE id = ?", arguments: [inserted.id])
    }

    let r = try #require(row)
    #expect((r["first_name"] as String) == "John")
    #expect((r["last_name"] as String) == "Doe")
    #expect((r["date_of_birth"] as String) == "1990-05-15")
}
