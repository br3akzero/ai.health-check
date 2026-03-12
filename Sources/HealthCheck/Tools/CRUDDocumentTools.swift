import MCP
import GRDB
import Foundation

struct CRUDDocumentTools {
    let db: DatabaseManager

    var tools: [Tool] {
        [
            Tool(
                name: "update_document",
                description: """
                    Update document metadata and review status after extraction. \
                    IMPORTANT: Before setting processing_status to 'completed', you MUST do a full verification with the user. \
                    Step 1: Show the raw document text (call get_document_text or get_document_pages). \
                    Step 2: Next to it, list EVERY entity you extracted with its value. \
                    Step 3: Identify any sections of the raw text you did NOT extract from and explicitly tell the user. \
                    Step 4: Ask the user to confirm nothing was missed. \
                    Common mistakes: skipping differential/formula sections in lab reports, missing medication dosages, ignoring vital signs embedded in clinical notes. \
                    Only mark completed after the user explicitly approves. If they find missing data, extract it and re-verify.
                    """,
                inputSchema: schema([
                    "document_id": .object(["type": "integer", "description": "Document ID"]),
                    "document_type": .object(["type": "string", "description": "Type: lab_report, prescription, discharge, imaging, referral, insurance, other (optional)"]),
                    "document_date": .object(["type": "string", "description": "Document date ISO 8601 (optional)"]),
                    "tags": .object(["type": "string", "description": "Comma-separated tags (optional)"]),
                    "processing_status": .object(["type": "string", "description": "Status: pending, pending_review, processing, completed, failed (optional)"]),
                    "facility_id": .object(["type": "integer", "description": "Link to facility (optional)"]),
                    "doctor_id": .object(["type": "integer", "description": "Link to doctor (optional)"]),
                    "language": .object(["type": "string", "description": "Document language code, e.g. en, bs, tr (optional)"]),
                ])
            ),
            Tool(
                name: "store_extraction_results",
                description: "Batch-insert extracted entities from AI analysis. Links raw text spans to clinical records via the extracted_entity table. Returns count of entities stored.",
                inputSchema: schema([
                    "document_id": .object(["type": "integer", "description": "Document ID"]),
                    "entities": .object([
                        "type": "array",
                        "description": "Array of extracted entities",
                        "items": .object([
                            "type": "object",
                            "properties": .object([
                                "chunk_id": .object(["type": "integer", "description": "Chunk ID where entity was found"]),
                                "entity_type": .object(["type": "string", "description": "Type (diagnosis, medication, lab_result, vital_sign, procedure, immunization, allergy, imaging)"]),
                                "entity_table": .object(["type": "string", "description": "Table where the clinical record was stored"]),
                                "entity_id": .object(["type": "integer", "description": "ID of the clinical record"]),
                                "raw_text": .object(["type": "string", "description": "Raw text span from the document"]),
                                "confidence": .object(["type": "number", "description": "Extraction confidence (0.0–1.0)"]),
                            ])
                        ])
                    ])
                ])
            ),
            Tool(
                name: "save_document_summary",
                description: "Store an AI-generated summary for a document. Returns the summary ID.",
                inputSchema: schema([
                    "document_id": .object(["type": "integer", "description": "Document ID"]),
                    "summary_type": .object(["type": "string", "description": "Type (brief, detailed, clinical)"]),
                    "content": .object(["type": "string", "description": "Summary content"]),
                ])
            ),
        ]
    }

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        switch params.name {
        case "update_document":
            return try await updateDocument(params)
        case "store_extraction_results":
            return try await storeExtractionResults(params)
        case "save_document_summary":
            return try await saveDocumentSummary(params)
        default:
            return nil
        }
    }
}

// MARK: - Database API

private extension CRUDDocumentTools {
    func updateDocument(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let documentId = intArg(args, "document_id") else {
            return .init(content: [.text("Missing required parameter: document_id")], isError: true)
        }

        let now = ISO8601DateFormatter().string(from: .now)

        try await db.dbQueue.write { db in
            guard var doc = try Document.fetchOne(db, key: documentId) else {
                throw DatabaseError(message: "Document not found")
            }

            if let type = stringArg(args, "document_type") { doc.documentType = type }
            if let date = stringArg(args, "document_date") { doc.documentDate = date }
            if let tags = stringArg(args, "tags") { doc.tags = tags }
            if let status = stringArg(args, "processing_status") { doc.processingStatus = status }
            if let facilityId = intArg(args, "facility_id") { doc.facilityId = facilityId }
            if let doctorId = intArg(args, "doctor_id") { doc.doctorId = doctorId }
            if let language = stringArg(args, "language") { doc.language = language }
            doc.updatedAt = now

            try doc.update(db)
        }

        return .init(content: [.text("{\"updated\": true, \"document_id\": \(documentId)}")], isError: false)
    }

    func storeExtractionResults(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let documentId = intArg(args, "document_id"),
              case .array(let entities) = args["entities"] else {
            return .init(content: [.text("Missing required: document_id, entities (array)")], isError: true)
        }

        let now = ISO8601DateFormatter().string(from: .now)

        let count = try await db.dbQueue.write { db -> Int in
            var inserted = 0
            for entity in entities {
                guard case .object(let obj) = entity,
                      let entityType = stringArg(obj, "entity_type"),
                      let rawText = stringArg(obj, "raw_text") else {
                    continue
                }

                let record = ExtractedEntity(
                    id: nil,
                    documentId: documentId,
                    chunkId: intArg(obj, "chunk_id"),
                    entityType: entityType,
                    entityTable: stringArg(obj, "entity_table"),
                    entityId: intArg(obj, "entity_id"),
                    rawText: rawText,
                    confidence: doubleArg(obj, "confidence") ?? 0.0,
                    createdAt: now
                )
                _ = try record.inserted(db)
                inserted += 1
            }
            return inserted
        }

        return .init(content: [.text("{\"stored\": \(count)}")], isError: false)
    }

    func saveDocumentSummary(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        guard let args = params.arguments,
              let documentId = intArg(args, "document_id"),
              let summaryType = stringArg(args, "summary_type"),
              let content = stringArg(args, "content") else {
            return .init(content: [.text("Missing required: document_id, summary_type, content")], isError: true)
        }

        let id = try await db.dbQueue.write { db in
            try DocumentSummary(
                id: nil,
                documentId: documentId,
                summaryType: summaryType,
                content: content,
                createdAt: ISO8601DateFormatter().string(from: .now)
            ).inserted(db).id!
        }

        return .init(content: [.text("{\"id\": \(id)}")], isError: false)
    }
}
