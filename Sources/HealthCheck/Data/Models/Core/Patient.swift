import GRDB

struct Patient: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    static let databaseTableName = "patient"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var firstName: String
    var lastName: String
    var dateOfBirth: String?
    var gender: String?
    var bloodType: String?
    var notes: String?
    var createdAt: String
    var updatedAt: String

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
