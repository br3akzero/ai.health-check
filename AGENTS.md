# AGENTS.md - HealthCheck MCP Server

## What This Is

HealthCheck is a local MCP server that ingests patient health PDFs, extracts structured clinical data into a relational database, and exposes 37 tools for an AI agent to query and manage that data. All data stays on the user's machine.

The server is a **dumb data layer**. It parses PDFs and stores/retrieves data. You (the agent) do the intelligence: reading documents, understanding clinical content, extracting entities, answering health questions.

## Setup

The server runs over stdio. Point your MCP client at the pre-built binary:

```json
{
  "mcpServers": {
    "healthcheck": {
      "command": "/path/to/HealthCheck",
      "args": []
    }
  }
}
```

The database must be initialized first with `HealthCheck --init`. Without a database, the server exits with an error.

## Tool Reference

### Database (1 tool)

| Tool | Description |
|------|-------------|
| `get_schema_info` | Returns all table names with columns and types. Call this to discover the database structure. |

### Ingestion (2 tools)

| Tool | Description |
|------|-------------|
| `ingest_document` | Ingests a PDF: extracts text (PDFKit + Vision OCR), reconciles, chunks, and stores. Returns document ID. Detects duplicates by SHA-256 hash. |
| `get_document_text` | Returns raw text and chunks for a document. Use this to read content before extracting entities. |

### CRUD - Core (4 tools)

| Tool | Description |
|------|-------------|
| `upsert_patient` | Create or update a patient. Omit `id` to create, include `id` to update. |
| `upsert_facility` | Create or update a facility (hospital, clinic, lab, pharmacy, imaging_center). |
| `upsert_doctor` | Create or update a doctor with optional specialty. |
| `link_doctor_to_facility` | Link a doctor to a facility. Idempotent. |

### CRUD - Clinical (11 tools)

| Tool | Description |
|------|-------------|
| `create_encounter` | Create a clinical encounter (visit) linked to a patient and optionally a facility/doctor. |
| `create_diagnosis` | Create a diagnosis with ICD-10 code, status (active/resolved/chronic/suspected). |
| `update_diagnosis` | Update an existing diagnosis record. |
| `create_medication` | Create a medication with dosage, frequency, ATC/NDC codes, status (active/discontinued/completed). |
| `update_medication` | Update an existing medication record. |
| `create_lab_result` | Create a lab result with test name, numeric value, unit, reference range, flag (normal/high/low/critical). |
| `create_vital_sign` | Create a vital sign (blood pressure, heart rate, temperature, etc.). |
| `create_procedure` | Create a procedure record with CPT code and outcome. |
| `create_immunization` | Create an immunization/vaccine record with lot number and site. |
| `create_allergy` | Create an allergy with allergen, reaction, severity (mild/moderate/severe/life-threatening). |
| `create_imaging` | Create an imaging result (X-ray, MRI, CT, ultrasound) with findings and impression. |

### CRUD - Document (3 tools)

| Tool | Description |
|------|-------------|
| `update_document` | Update document metadata: type, date, tags, language, linked facility/doctor, processing status. |
| `store_extraction_results` | Batch-insert extracted entities linking raw text spans to clinical records via the extracted_entity table. |
| `save_document_summary` | Store an AI-generated summary (brief, detailed, or clinical) for a document. |

### Query - Patient (2 tools)

| Tool | Description |
|------|-------------|
| `get_patient_summary` | Comprehensive patient summary: demographics, active diagnoses, current medications, allergies, recent encounters/labs. |
| `list_patients` | List all patients with basic demographics. |

### Query - Clinical (6 tools)

| Tool | Description |
|------|-------------|
| `get_lab_history` | Lab results for a patient, optionally filtered by test name and date range. Ordered chronologically. |
| `get_medication_list` | Medications for a patient, optionally active-only. Includes prescribing doctor and linked diagnosis. |
| `get_encounter` | Full encounter with all linked clinical data: diagnoses, labs, vitals, procedures, medications. |
| `get_diagnosis` | Diagnoses for a patient, optionally filtered by status. |
| `get_allergies` | All allergies for a patient with severity, reaction, and status. |
| `get_immunization_history` | Full immunization/vaccine history, ordered by date. |

### Query - Timeline (1 tool)

| Tool | Description |
|------|-------------|
| `get_health_timeline` | Unified chronological timeline of all health events: encounters, diagnoses, labs, medications, vitals, procedures, immunizations, imaging. |

### Query - Provider (4 tools)

| Tool | Description |
|------|-------------|
| `get_doctor` | Doctor details including linked facilities. |
| `list_doctors` | All doctors with specialties. |
| `get_facility` | Facility details including linked doctors. |
| `list_facilities` | All facilities with types. |

### Query - Document (4 tools)

| Tool | Description |
|------|-------------|
| `search_documents` | Full-text search across document chunks. Returns matching documents with relevant excerpts. |
| `get_document` | Document metadata, summary, and optionally all chunks. |
| `get_document_pages` | Per-page extraction data: PDFKit text, OCR text, reconciled text, and which source was picked. |
| `list_documents` | List documents with optional filters. |

## Workflows

### Ingesting a New Document

1. Ensure a patient exists (`list_patients` or `upsert_patient`)
2. Call `ingest_document` with the PDF path and patient ID
3. Call `get_document_text` to read the extracted content
4. Read through the text and identify clinical entities
5. Create the facility and doctor if they appear in the document (`upsert_facility`, `upsert_doctor`, `link_doctor_to_facility`)
6. Create an encounter for the visit (`create_encounter`)
7. Extract all clinical entities (`create_lab_result`, `create_diagnosis`, `create_medication`, etc.)
8. Link entities back to the source text (`store_extraction_results`)
9. Save a summary (`save_document_summary`)
10. Verify extraction with the user, then mark completed (`update_document` with `processing_status: completed`)

### Answering Health Questions

1. Identify the patient (`list_patients`)
2. Use the appropriate query tool:
   - Lab trends: `get_lab_history` with test name
   - Current medications: `get_medication_list` with active filter
   - Full picture: `get_patient_summary`
   - Chronological view: `get_health_timeline`
   - Specific visit: `get_encounter`
3. Present findings clearly with values, units, and reference ranges

### Reviewing a Document

1. Call `get_document_pages` to see per-page extraction data
2. Compare PDFKit text vs OCR text vs reconciled text
3. Use `get_document_text` for the chunked version
4. Verify the reconciler picked the right source for each page

## Key Rules

- **Never make clinical decisions.** You extract and present data. You do not diagnose, recommend treatments, or interpret results clinically.
- **All health data stays local.** Never send patient data to external services.
- **Verify before completing.** Before marking a document as `completed`, show the user what you extracted alongside the raw text and confirm nothing was missed.
- **Handle multilingual content.** Documents may contain mixed languages. Extract entity values accurately regardless of language.
- **Track provenance.** Use `store_extraction_results` to link every extracted entity back to its source text span and chunk.
- **Dates are ISO 8601.** All date fields use ISO 8601 format (e.g., `2026-03-17` or `2026-03-17T10:30:00Z`).
- **IDs are integers.** All entity IDs are integers, but the server accepts them as strings too.
