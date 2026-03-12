import GRDB

struct DocumentPage: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "document_page"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var documentId: Int64
    var pageNumber: Int
    var pdfkitText: String?
    var ocrText: String?
    var reconciledText: String
    var ingestType: String
    var createdAt: String

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
