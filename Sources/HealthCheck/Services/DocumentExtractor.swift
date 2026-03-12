import Foundation
import PDF

struct ExtractedPage: Sendable {
    let raw: PageExtraction
    let reconciled: ReconciledPage
}

protocol DocumentExtractor: Sendable {
    func extract(from url: URL) async throws -> [ExtractedPage]
}

struct PDFDocumentExtractor: DocumentExtractor {
    func extract(from url: URL) async throws -> [ExtractedPage] {
        let parser = PDFParser()
        let reconciler = TextReconciler()
        let stream = try parser.extract(from: url)

        var pages: [ExtractedPage] = []
        for try await extraction in stream {
            let reconciled = reconciler.reconcile(page: extraction)
            pages.append(ExtractedPage(raw: extraction, reconciled: reconciled))
        }

        return pages
    }
}
