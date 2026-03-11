import MCP
import GRDB
import Foundation

struct IngestTools {
    let db: DatabaseManager

    var tools: [Tool] {
        [
            Tool(
                name: "ingest_document",
                description: "Ingests a PDF document: extracts text (PDFKit + Vision OCR), reconciles, chunks, and stores. Returns document ID and status. Detects duplicates by SHA-256 hash.",
                inputSchema: .object([
                    "file_path": .object([
                        "type": "string",
                        "description": "Absolute path to the PDF file"
                    ]),
                    "patient_id": .object([
                        "type": "integer",
                        "description": "ID of the patient this document belongs to"
                    ])
                ])
            ),
            Tool(
                name: "get_document_text",
                description: "Returns the raw text and chunks for a document. Use this to read document content before extracting clinical entities.",
                inputSchema: .object([
                    "document_id": .object([
                        "type": "integer",
                        "description": "ID of the document to retrieve text for"
                    ])
                ])
            ),
        ]
    }

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        switch params.name {
        case "ingest_document":
            return try await ingestDocument(params)
        case "get_document_text":
            return try await getDocumentText(params)
        default:
            return nil
        }
    }
}

// MARK: - Tool Handlers

private extension IngestTools {
    func ingestDocument(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              case .string(let filePath) = args["file_path"],
              case .int(let patientId) = args["patient_id"] else {
            return .init(content: [.text("Missing required parameters: file_path (string), patient_id (integer)")], isError: true)
        }

        let service = IngestService(db: db)
        let result = try await service.ingest(filePath: filePath, patientId: Int64(patientId))

        let response: [String: Any] = [
            "document_id": result.documentId,
            "page_count": result.pageCount,
            "chunk_count": result.chunkCount,
            "status": result.status
        ]

        let data = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return .init(content: [.text(json)], isError: false)
    }

    func getDocumentText(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              case .int(let documentId) = args["document_id"] else {
            return .init(content: [.text("Missing required parameter: document_id (integer)")], isError: true)
        }

        let docId = Int64(documentId)

        let document = try await db.dbQueue.read { db in
            try Document.fetchOne(db, key: docId)
        }

        guard let document else {
            return .init(content: [.text("Document not found: \(docId)")], isError: true)
        }

        let chunks = try await db.dbQueue.read { db in
            try DocumentChunk
                .filter(Column("document_id") == docId)
                .order(Column("chunk_index"))
                .fetchAll(db)
        }

        var response: [String: Any] = [
            "document_id": docId,
            "file_name": document.fileName,
            "document_type": document.documentType,
            "processing_status": document.processingStatus,
            "page_count": document.pageCount,
        ]

        if let rawText = document.rawText {
            response["raw_text"] = rawText
        }

        let chunkData: [[String: Any]] = chunks.map { chunk in
            var entry: [String: Any] = [
                "chunk_index": chunk.chunkIndex,
                "content": chunk.content,
                "token_count": chunk.tokenCount,
            ]
            if let page = chunk.pageNumber { entry["page_number"] = page }
            if let heading = chunk.sectionHeading { entry["section_heading"] = heading }
            return entry
        }
        response["chunks"] = chunkData

        let data = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return .init(content: [.text(json)], isError: false)
    }
}
