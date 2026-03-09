import Foundation
import GRDB
@testable import HealthCheck
@testable import PDF

func makeDB() throws -> DatabaseManager {
    try DatabaseManager()
}

func timestamp() -> String {
    ISO8601DateFormatter().string(from: .now)
}

func makePatient() -> Patient {
    Patient(
        id: nil,
        firstName: "John",
        lastName: "Doe",
        dateOfBirth: "1990-05-15",
        gender: "male",
        bloodType: "O+",
        createdAt: timestamp(),
        updatedAt: timestamp()
    )
}

func insertPatient(db: DatabaseManager) throws -> Int64 {
    try db.dbQueue.write { db in
        try makePatient().inserted(db).id!
    }
}

func makePageExtraction(
    pageNumber: Int = 1,
    pdfKitText: String = "",
    ocrText: String = "",
    ocrConfidence: Float = 0.9,
    paragraphs: [String] = []
) -> PageExtraction {
    PageExtraction(
        pageNumber: pageNumber,
        pdfKitText: pdfKitText,
        ocrText: ocrText,
        ocrConfidence: ocrConfidence,
        tables: [],
        lists: [],
        paragraphs: paragraphs,
        detectedData: []
    )
}

func makeReconciledPage(
    pageNumber: Int = 1,
    text: String,
    paragraphs: [String] = []
) -> ReconciledPage {
    ReconciledPage(
        pageNumber: pageNumber,
        text: text,
        textSource: .pdfKit,
        qualityScore: 0.9,
        ocrConfidence: 0.9,
        tables: [],
        lists: [],
        paragraphs: paragraphs,
        detectedData: []
    )
}

func makeDocument(patientId: Int64, fileHash: String = "abc123") -> Document {
    let ts = timestamp()
    return Document(
        id: nil,
        patientId: patientId,
        facilityId: nil,
        doctorId: nil,
        filePath: "/tmp/test.pdf",
        fileHash: fileHash,
        fileName: "test.pdf",
        documentDate: nil,
        documentType: "lab_report",
        tags: nil,
        language: "en",
        pageCount: 5,
        processingStatus: "processing",
        processingError: nil,
        rawText: nil,
        createdAt: ts,
        updatedAt: ts
    )
}
