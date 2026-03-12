import Foundation
import CryptoKit
import GRDB
import PDF

struct IngestService {
    let db: DatabaseManager
    let extractor: DocumentExtractor

    init(db: DatabaseManager, extractor: DocumentExtractor = PDFDocumentExtractor()) {
        self.db = db
        self.extractor = extractor
    }

    func ingest(filePath: String, patientId: Int64) async throws -> IngestResult {
        let url = URL(fileURLWithPath: filePath)
        let fileHash = try computeHash(for: url)

        if let existing = try await findExistingDocument(hash: fileHash) {
            return IngestResult(documentId: existing, pageCount: 0, chunkCount: 0, status: "duplicate")
        }

        let documentId = try await createDocument(filePath: filePath, fileHash: fileHash, fileName: url.lastPathComponent, patientId: patientId)
        let pages = try await extractor.extract(from: url)
        let reconciled = pages.map { $0.reconciled }
        let chunks = chunkPages(reconciled)
        try await storeChunks(chunks, documentId: documentId)
        try await storePages(pages, documentId: documentId)
        let rawText = reconciled.map { $0.text }.joined(separator: "\n\n")
        try await updateDocument(id: documentId, pageCount: pages.count, rawText: rawText, status: "pending_review")

        return IngestResult(documentId: documentId, pageCount: pages.count, chunkCount: chunks.count, status: "pending_review")
    }

    private func computeHash(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func findExistingDocument(hash: String) async throws -> Int64? {
        try await db.dbQueue.read { db in
            try Document.filter(Column("file_hash") == hash).fetchOne(db)?.id
        }
    }

    private func chunkPages(_ pages: [ReconciledPage]) -> [TextChunk] {
        let chunker = TextChunker()
        return chunker.chunk(pages: pages)
    }
}

// MARK: - Database API

private extension IngestService {
    func createDocument(filePath: String, fileHash: String, fileName: String, patientId: Int64) async throws -> Int64 {
        let now = ISO8601DateFormatter().string(from: Date())
        let doc = Document(
            id: nil,
            patientId: patientId,
            facilityId: nil,
            doctorId: nil,
            filePath: filePath,
            fileHash: fileHash,
            fileName: fileName,
            documentDate: nil,
            documentType: "other",
            tags: nil,
            language: "en",
            pageCount: 0,
            processingStatus: "processing",
            processingError: nil,
            rawText: nil,
            createdAt: now,
            updatedAt: now
        )

        let id = try await db.dbQueue.write { db in
            try doc.inserted(db).id!
        }

        return id
    }

    func storeChunks(_ chunks: [TextChunk], documentId: Int64) async throws {
        let now = ISO8601DateFormatter().string(from: Date())

        try await db.dbQueue.write { db in
            for chunk in chunks {
                let record = DocumentChunk(
                    id: nil,
                    documentId: documentId,
                    chunkIndex: chunk.chunkIndex,
                    content: chunk.content,
                    pageNumber: chunk.pageNumber,
                    sectionHeading: chunk.sectionHeading,
                    tokenCount: chunk.tokenCount,
                    createdAt: now
                )
                _ = try record.inserted(db)
            }
        }
    }

    func storePages(_ pages: [ExtractedPage], documentId: Int64) async throws {
        let now = ISO8601DateFormatter().string(from: Date())

        try await db.dbQueue.write { db in
            for page in pages {
                let ingestType = switch page.reconciled.textSource {
                case .pdfKit: "pdfkit"
                case .ocr: "ocr"
                }

                let record = DocumentPage(
                    id: nil,
                    documentId: documentId,
                    pageNumber: page.raw.pageNumber,
                    pdfkitText: page.raw.pdfKitText,
                    ocrText: page.raw.ocrText,
                    reconciledText: page.reconciled.text,
                    ingestType: ingestType,
                    createdAt: now
                )
                _ = try record.inserted(db)
            }
        }
    }

    func updateDocument(id: Int64, pageCount: Int, rawText: String, status: String) async throws {
        let now = ISO8601DateFormatter().string(from: Date())

        try await db.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE document SET page_count = ?, raw_text = ?, processing_status = ?, updated_at = ? WHERE id = ?",
                arguments: [pageCount, rawText, status, now, id]
            )
        }
    }
}
