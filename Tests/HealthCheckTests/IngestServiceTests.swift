import Testing
import Foundation
import GRDB
@testable import HealthCheck
@testable import PDF

// MARK: - Mock Extractor

private struct MockExtractor: DocumentExtractor {
    let pages: [ExtractedPage]

    func extract(from url: URL) async throws -> [ExtractedPage] {
        pages
    }
}

private func makeMockExtractor() -> MockExtractor {
    MockExtractor(pages: [
        ExtractedPage(
            raw: makePageExtraction(
                pageNumber: 1,
                pdfKitText: "Patient blood pressure was 120/80 mmHg.",
                ocrText: "Patient blood pressure was 120/80 mmHg.",
                paragraphs: ["Patient blood pressure was 120/80 mmHg."]
            ),
            reconciled: makeReconciledPage(
                pageNumber: 1,
                text: "Patient blood pressure was 120/80 mmHg.",
                paragraphs: ["Patient blood pressure was 120/80 mmHg."]
            )
        ),
        ExtractedPage(
            raw: makePageExtraction(
                pageNumber: 2,
                pdfKitText: "Glucose level was 95 mg/dL within normal range.",
                ocrText: "Glucose level was 95 mg/dL within normal range.",
                paragraphs: ["Glucose level was 95 mg/dL within normal range."]
            ),
            reconciled: makeReconciledPage(
                pageNumber: 2,
                text: "Glucose level was 95 mg/dL within normal range.",
                paragraphs: ["Glucose level was 95 mg/dL within normal range."]
            )
        ),
    ])
}

private func makeTempFile(content: String = "test file content") throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}

// MARK: - IngestService Tests

@Test("Successful ingestion creates document and returns pending_review")
func successfulIngestion() async throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)
    let file = try makeTempFile()
    let service = IngestService(db: manager, extractor: makeMockExtractor())

    let result = try await service.ingest(filePath: file.path, patientId: patientId)

    #expect(result.status == "pending_review")
    #expect(result.pageCount == 2)
    #expect(result.chunkCount > 0)

    let doc = try await manager.dbQueue.read { db in
        try Document.fetchOne(db, key: result.documentId)
    }
    #expect(doc != nil)
}

@Test("Duplicate detection returns existing document")
func duplicateDetection() async throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)
    let file = try makeTempFile()
    let service = IngestService(db: manager, extractor: makeMockExtractor())

    let first = try await service.ingest(filePath: file.path, patientId: patientId)
    let second = try await service.ingest(filePath: file.path, patientId: patientId)

    #expect(second.status == "duplicate")
    #expect(second.pageCount == 0)
    #expect(second.chunkCount == 0)
    #expect(second.documentId == first.documentId)
}

@Test("Chunks are stored in database correctly")
func chunksStoredInDB() async throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)
    let file = try makeTempFile()
    let service = IngestService(db: manager, extractor: makeMockExtractor())

    let result = try await service.ingest(filePath: file.path, patientId: patientId)

    let chunks = try await manager.dbQueue.read { db in
        try DocumentChunk
            .filter(Column("document_id") == result.documentId)
            .order(Column("chunk_index"))
            .fetchAll(db)
    }

    #expect(chunks.count == result.chunkCount)
    #expect(chunks[0].chunkIndex == 0)
    #expect(!chunks[0].content.isEmpty)
}

@Test("Document raw_text is populated after ingestion")
func rawTextPopulated() async throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)
    let file = try makeTempFile()
    let service = IngestService(db: manager, extractor: makeMockExtractor())

    let result = try await service.ingest(filePath: file.path, patientId: patientId)

    let doc = try await manager.dbQueue.read { db in
        try Document.fetchOne(db, key: result.documentId)
    }

    let document = try #require(doc)
    let rawText = try #require(document.rawText)
    #expect(rawText.contains("blood pressure"))
    #expect(rawText.contains("Glucose"))
}

@Test("Document status updates to pending_review")
func statusUpdatesToPendingReview() async throws {
    let manager = try makeDB()
    let patientId = try insertPatient(db: manager)
    let file = try makeTempFile()
    let service = IngestService(db: manager, extractor: makeMockExtractor())

    let result = try await service.ingest(filePath: file.path, patientId: patientId)

    let doc = try await manager.dbQueue.read { db in
        try Document.fetchOne(db, key: result.documentId)
    }

    #expect(try #require(doc).processingStatus == "pending_review")
}
