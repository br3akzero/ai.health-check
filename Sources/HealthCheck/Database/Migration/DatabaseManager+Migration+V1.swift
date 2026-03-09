import GRDB

extension DatabaseManager {
    static func migrationV1(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_core") { db in
            try db.create(table: "patient") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("first_name", .text).notNull()
                t.column("last_name", .text).notNull()
                t.column("date_of_birth", .text)
                t.column("gender", .text)
                t.column("blood_type", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }

            try db.create(table: "facility") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("facility_type", .text).notNull()
                t.column("phone", .text)
                t.column("address", .text)
                t.column("website", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "doctor") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("first_name", .text).notNull()
                t.column("last_name", .text).notNull()
                t.column("specialty", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "facility_doctor") { t in
                t.column("facility_id", .integer).notNull()
                    .references("facility", onDelete: .cascade)
                t.column("doctor_id", .integer).notNull()
                    .references("doctor", onDelete: .cascade)
                t.primaryKey(["facility_id", "doctor_id"])
            }

            try db.create(table: "document") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("facility_id", .integer)
                    .references("facility", onDelete: .setNull)
                t.column("doctor_id", .integer)
                    .references("doctor", onDelete: .setNull)
                t.column("file_path", .text).notNull()
                t.column("file_hash", .text).notNull().unique()
                t.column("file_name", .text).notNull()
                t.column("document_date", .text)
                t.column("document_type", .text).notNull()
                t.column("tags", .text)
                t.column("language", .text).notNull().defaults(to: "en")
                t.column("page_count", .integer).notNull().defaults(to: 0)
                t.column("processing_status", .text).notNull().defaults(to: "pending")
                t.column("processing_error", .text)
                t.column("raw_text", .text)
                t.column("created_at", .text).notNull()
                t.column("updated_at", .text).notNull()
            }
        }

        migrator.registerMigration("v1_clinical") { db in
            try db.create(table: "encounter") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("facility_id", .integer)
                    .references("facility", onDelete: .setNull)
                t.column("doctor_id", .integer)
                    .references("doctor", onDelete: .setNull)
                t.column("encounter_date", .text).notNull()
                t.column("encounter_type", .text).notNull()
                t.column("chief_complaint", .text)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "document_encounter") { t in
                t.column("document_id", .integer).notNull()
                    .references("document", onDelete: .cascade)
                t.column("encounter_id", .integer).notNull()
                    .references("encounter", onDelete: .cascade)
                t.primaryKey(["document_id", "encounter_id"])
            }

            try db.create(table: "diagnosis") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("encounter_id", .integer)
                    .references("encounter", onDelete: .setNull)
                t.column("icd_code", .text)
                t.column("description", .text).notNull()
                t.column("diagnosis_date", .text).notNull()
                t.column("status", .text).notNull()
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "medication") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("diagnosis_id", .integer)
                    .references("diagnosis", onDelete: .setNull)
                t.column("doctor_id", .integer)
                    .references("doctor", onDelete: .setNull)
                t.column("name", .text).notNull()
                t.column("dosage", .text).notNull()
                t.column("frequency", .text).notNull()
                t.column("route", .text).notNull()
                t.column("start_date", .text).notNull()
                t.column("end_date", .text)
                t.column("is_active", .boolean).notNull().defaults(to: true)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "lab_result") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("encounter_id", .integer)
                    .references("encounter", onDelete: .setNull)
                t.column("test_name", .text).notNull()
                t.column("test_category", .text)
                t.column("value", .text).notNull()
                t.column("numeric_value", .double)
                t.column("unit", .text)
                t.column("reference_range_low", .double)
                t.column("reference_range_high", .double)
                t.column("reference_range_text", .text)
                t.column("flag", .text)
                t.column("test_date", .text).notNull()
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "vital_sign") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("encounter_id", .integer)
                    .references("encounter", onDelete: .setNull)
                t.column("vital_type", .text).notNull()
                t.column("value", .text).notNull()
                t.column("numeric_value", .double)
                t.column("numeric_value_2", .double)
                t.column("unit", .text)
                t.column("measured_date", .text).notNull()
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "procedure_record") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("encounter_id", .integer)
                    .references("encounter", onDelete: .setNull)
                t.column("doctor_id", .integer)
                    .references("doctor", onDelete: .setNull)
                t.column("procedure_name", .text).notNull()
                t.column("procedure_code", .text)
                t.column("procedure_date", .text).notNull()
                t.column("body_site", .text)
                t.column("outcome", .text)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "immunization") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("vaccine_name", .text).notNull()
                t.column("vaccine_code", .text)
                t.column("dose_number", .integer)
                t.column("administration_date", .text).notNull()
                t.column("administered_by", .text)
                t.column("lot_number", .text)
                t.column("site", .text)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "allergy") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("allergen", .text).notNull()
                t.column("allergen_type", .text).notNull()
                t.column("reaction", .text)
                t.column("severity", .text).notNull()
                t.column("onset_date", .text)
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "imaging") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("patient_id", .integer).notNull()
                    .references("patient", onDelete: .cascade)
                t.column("encounter_id", .integer)
                    .references("encounter", onDelete: .setNull)
                t.column("doctor_id", .integer)
                    .references("doctor", onDelete: .setNull)
                t.column("imaging_type", .text).notNull()
                t.column("body_part", .text).notNull()
                t.column("imaging_date", .text).notNull()
                t.column("findings", .text)
                t.column("impression", .text)
                t.column("notes", .text)
                t.column("created_at", .text).notNull()
            }
        }

        migrator.registerMigration("v1_documentIntelligence") { db in
            try db.create(table: "document_chunk") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("document_id", .integer).notNull()
                    .references("document", onDelete: .cascade)
                t.column("chunk_index", .integer).notNull()
                t.column("content", .text).notNull()
                t.column("page_number", .integer)
                t.column("section_heading", .text)
                t.column("token_count", .integer).notNull()
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "document_summary") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("document_id", .integer).notNull()
                    .references("document", onDelete: .cascade)
                t.column("summary_type", .text).notNull()
                t.column("content", .text).notNull()
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "extracted_entity") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("document_id", .integer).notNull()
                    .references("document", onDelete: .cascade)
                t.column("chunk_id", .integer)
                    .references("document_chunk", onDelete: .setNull)
                t.column("entity_type", .text).notNull()
                t.column("entity_table", .text)
                t.column("entity_id", .integer)
                t.column("raw_text", .text).notNull()
                t.column("confidence", .double).notNull()
                t.column("created_at", .text).notNull()
            }
        }

        migrator.registerMigration("v1_indexes") { db in
            try db.create(
                index: "idx_document_patient_date",
                on: "document",
                columns: ["patient_id", "document_date"]
            )
            try db.create(
                index: "idx_document_status",
                on: "document",
                columns: ["processing_status"]
            )
            try db.create(
                index: "idx_encounter_patient_date",
                on: "encounter",
                columns: ["patient_id", "encounter_date"]
            )
            try db.create(
                index: "idx_diagnosis_patient_status",
                on: "diagnosis",
                columns: ["patient_id", "status"]
            )
            try db.create(
                index: "idx_lab_result_patient_test_date",
                on: "lab_result",
                columns: ["patient_id", "test_name", "test_date"]
            )
            try db.create(
                index: "idx_medication_patient_active",
                on: "medication",
                columns: ["patient_id", "is_active"]
            )
            try db.create(
                index: "idx_vital_sign_patient_type_date",
                on: "vital_sign",
                columns: ["patient_id", "vital_type", "measured_date"]
            )
            try db.create(
                index: "idx_document_chunk_doc_index",
                on: "document_chunk",
                columns: ["document_id", "chunk_index"]
            )
            try db.create(
                index: "idx_extracted_entity_document",
                on: "extracted_entity",
                columns: ["document_id"]
            )
            try db.create(
                index: "idx_extracted_entity_table_id",
                on: "extracted_entity",
                columns: ["entity_table", "entity_id"]
            )
        }
    }
}
