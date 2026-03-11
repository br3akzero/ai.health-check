import MCP
import GRDB
import Foundation

struct CRUDDocumentTools {
    let db: DatabaseManager

    var tools: [Tool] {
        [
            Tool(
                name: "store_extraction_results",
                description: "Batch-insert extracted entities from AI analysis. Links raw text spans to clinical records via the extracted_entity table. Returns count of entities stored.",
                inputSchema: .object([
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
                inputSchema: .object([
                    "document_id": .object(["type": "integer", "description": "Document ID"]),
                    "summary_type": .object(["type": "string", "description": "Type (brief, detailed, clinical)"]),
                    "content": .object(["type": "string", "description": "Summary content"]),
                ])
            ),
        ]
    }

    func handle(_ params: CallTool.Parameters) async throws -> CallTool.Result? {
        switch params.name {
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
