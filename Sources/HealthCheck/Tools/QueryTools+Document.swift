import MCP
import GRDB
import Foundation

extension QueryTools {
    var documentTools: [Tool] {
        [
            Tool(
                name: "search_documents",
                description: "Full-text search across document chunks. Returns matching documents with relevant chunk excerpts.",
                inputSchema: schema([
                    "query": .object(["type": "string", "description": "Search text to match against document chunks"]),
                    "document_type": .object(["type": "string", "description": "Filter by type: lab_report/prescription/discharge/imaging/referral/insurance/other (optional)"]),
                    "date_from": .object(["type": "string", "description": "Start date ISO 8601 (optional)"]),
                    "date_to": .object(["type": "string", "description": "End date ISO 8601 (optional)"]),
                    "limit": .object(["type": "integer", "description": "Max results (default: 20)"]),
                ])
            ),
            Tool(
                name: "get_document",
                description: "Get document metadata, summary, and optionally all chunks.",
                inputSchema: schema([
                    "document_id": .object(["type": "integer", "description": "Document ID"]),
                    "include_chunks": .object(["type": "boolean", "description": "Include all text chunks (default: false)"]),
                ])
            ),
            Tool(
                name: "get_document_pages",
                description: """
                    Get per-page extraction data for document review. Returns PDFKit text, OCR text, \
                    reconciled text, and ingest_type (which source was picked) for each page. \
                    Use this to show the user both extraction versions so they can verify the reconciled text is correct.
                    """,
                inputSchema: schema([
                    "document_id": .object(["type": "integer", "description": "Document ID"]),
                    "page_number": .object(["type": "integer", "description": "Specific page number (optional, returns all pages if omitted)"]),
                ])
            ),
            Tool(
                name: "list_documents",
                description: "List all documents with optional filters.",
                inputSchema: schema([
                    "patient_id": .object(["type": "integer", "description": "Filter by patient (optional)"]),
                    "document_type": .object(["type": "string", "description": "Filter by type (optional)"]),
                    "processing_status": .object(["type": "string", "description": "Filter by status: pending/pending_review/processing/completed/failed (optional)"]),
                ])
            ),
        ]
    }
}

// MARK: - Database API

extension QueryTools {
    func searchDocuments(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let query = stringArg(args, "query") else {
            return .init(content: [.text("Missing required parameter: query")], isError: true)
        }

        let documentType = stringArg(args, "document_type")
        let dateFrom = stringArg(args, "date_from")
        let dateTo = stringArg(args, "date_to")
        let limit = intArg(args, "limit") ?? 20

        let jsonData = try await db.dbQueue.read { db -> Data in
            var sql = """
                SELECT DISTINCT d.id, d.file_name, d.document_type, d.document_date,
                       d.processing_status, d.patient_id,
                       dc.content AS chunk_content, dc.section_heading, dc.page_number
                FROM document_chunk dc
                JOIN document d ON dc.document_id = d.id
                WHERE dc.content LIKE ?
                """
            let searchPattern = "%\(query)%"
            var arguments: [any DatabaseValueConvertible] = [searchPattern]

            if let documentType {
                sql += " AND d.document_type = ?"
                arguments.append(documentType)
            }
            if let dateFrom {
                sql += " AND d.document_date >= ?"
                arguments.append(dateFrom)
            }
            if let dateTo {
                sql += " AND d.document_date <= ?"
                arguments.append(dateTo)
            }

            sql += " ORDER BY d.document_date DESC LIMIT ?"
            arguments.append(limit)

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))

            let results = rows.map { row in
                var entry: [String: Any] = [
                    "document_id": (row["id"] as Int64?) ?? 0,
                    "file_name": (row["file_name"] as String?) ?? "",
                    "document_type": (row["document_type"] as String?) ?? "",
                    "processing_status": (row["processing_status"] as String?) ?? "",
                ]
                if let date = row["document_date"] as String? { entry["document_date"] = date }
                if let patientId = row["patient_id"] as Int64? { entry["patient_id"] = patientId }
                if let heading = row["section_heading"] as String? { entry["section_heading"] = heading }
                if let page = row["page_number"] as Int? { entry["page_number"] = page }

                if let content = row["chunk_content"] as String? {
                    let excerpt = Self.extractExcerpt(from: content, matching: query)
                    entry["excerpt"] = excerpt
                }

                return entry
            }

            return try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "[]")], isError: false)
    }

    func getDocument(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let documentId = intArg(args, "document_id") else {
            return .init(content: [.text("Missing required parameter: document_id")], isError: true)
        }

        let includeChunks = boolArg(args, "include_chunks") ?? false

        let jsonData = try await db.dbQueue.read { db -> Data in
            guard let doc = try Document.fetchOne(db, key: documentId) else {
                return try JSONSerialization.data(withJSONObject: ["error": "Document not found"])
            }

            var entry: [String: Any] = [
                "id": doc.id!,
                "patient_id": doc.patientId,
                "file_path": doc.filePath,
                "file_name": doc.fileName,
                "document_type": doc.documentType,
                "language": doc.language,
                "page_count": doc.pageCount,
                "processing_status": doc.processingStatus,
            ]
            if let facilityId = doc.facilityId { entry["facility_id"] = facilityId }
            if let doctorId = doc.doctorId { entry["doctor_id"] = doctorId }
            if let date = doc.documentDate { entry["document_date"] = date }
            if let tags = doc.tags { entry["tags"] = tags }
            if let error = doc.processingError { entry["processing_error"] = error }

            let summaries = try DocumentSummary.filter(Column("document_id") == documentId)
                .order(Column("summary_type"))
                .fetchAll(db)
            if !summaries.isEmpty {
                entry["summaries"] = summaries.map { s in
                    ["summary_type": s.summaryType, "content": s.content] as [String: Any]
                }
            }

            if includeChunks {
                let chunks = try DocumentChunk.filter(Column("document_id") == documentId)
                    .order(Column("chunk_index"))
                    .fetchAll(db)
                entry["chunks"] = chunks.map { c in
                    var chunkEntry: [String: Any] = [
                        "chunk_index": c.chunkIndex,
                        "content": c.content,
                        "token_count": c.tokenCount,
                    ]
                    if let page = c.pageNumber { chunkEntry["page_number"] = page }
                    if let heading = c.sectionHeading { chunkEntry["section_heading"] = heading }
                    return chunkEntry
                }
            }

            return try JSONSerialization.data(withJSONObject: entry, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "{}")], isError: false)
    }

    func getDocumentPages(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let documentId = intArg(args, "document_id") else {
            return .init(content: [.text("Missing required parameter: document_id")], isError: true)
        }

        let pageNumber = intArg(args, "page_number")

        let jsonData = try await db.dbQueue.read { db -> Data in
            var query = DocumentPage.filter(Column("document_id") == documentId)
            if let pageNumber {
                query = query.filter(Column("page_number") == pageNumber)
            }
            let pages = try query.order(Column("page_number")).fetchAll(db)

            let results = pages.map { page in
                var entry: [String: Any] = [
                    "page_number": page.pageNumber,
                    "reconciled_text": page.reconciledText,
                    "ingest_type": page.ingestType,
                ]
                if let pdfkit = page.pdfkitText { entry["pdfkit_text"] = pdfkit }
                if let ocr = page.ocrText { entry["ocr_text"] = ocr }
                return entry
            }

            return try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        }

        return .init(content: [.text(String(data: jsonData, encoding: .utf8) ?? "[]")], isError: false)
    }

    func listDocuments(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        let args = params.arguments ?? [:]
        let patientId = intArg(args, "patient_id")
        let documentType = stringArg(args, "document_type")
        let processingStatus = stringArg(args, "processing_status")

        let results = try await db.dbQueue.read { db in
            var query = Document.all()
            if let patientId { query = query.filter(Column("patient_id") == patientId) }
            if let documentType { query = query.filter(Column("document_type") == documentType) }
            if let processingStatus { query = query.filter(Column("processing_status") == processingStatus) }
            return try query.order(Column("document_date").desc).fetchAll(db)
        }

        return try jsonResult(results)
    }

    static func extractExcerpt(from content: String, matching query: String, contextChars: Int = 100) -> String {
        guard let range = content.range(of: query, options: .caseInsensitive) else {
            return String(content.prefix(200))
        }

        let matchStart = content.distance(from: content.startIndex, to: range.lowerBound)
        let excerptStart = max(0, matchStart - contextChars)
        let startIndex = content.index(content.startIndex, offsetBy: excerptStart)
        let endIndex = content.index(startIndex, offsetBy: min(contextChars * 2 + query.count, content.distance(from: startIndex, to: content.endIndex)))

        var excerpt = String(content[startIndex..<endIndex])
        if excerptStart > 0 { excerpt = "..." + excerpt }
        if endIndex < content.endIndex { excerpt = excerpt + "..." }
        return excerpt
    }
}
