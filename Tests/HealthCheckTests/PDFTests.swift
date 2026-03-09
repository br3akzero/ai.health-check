import Testing
@testable import PDF

// MARK: - TextReconciler Tests

@Test("Both texts empty returns OCR with score 0.0")
func reconcilerBothEmpty() {
    let page = makePageExtraction(pdfKitText: "", ocrText: "", ocrConfidence: 0.95)
    let result = TextReconciler().reconcile(page: page)

    #expect(result.textSource == .ocr)
    #expect(result.qualityScore == 0.0)
}

@Test("Only PDFKit has text picks PDFKit with score 1.0")
func reconcilerOnlyPdfKit() {
    let page = makePageExtraction(
        pdfKitText: "Patient blood pressure was 120/80 mmHg and heart rate 72 bpm.",
        ocrText: "",
        ocrConfidence: 0.0
    )
    let result = TextReconciler().reconcile(page: page)

    #expect(result.textSource == .pdfKit)
    #expect(result.qualityScore == 1.0)
}

@Test("Only OCR has text picks OCR with score equal to ocrConfidence")
func reconcilerOnlyOcr() {
    let page = makePageExtraction(
        pdfKitText: "",
        ocrText: "Patient blood pressure was 120/80 mmHg and heart rate 72 bpm.",
        ocrConfidence: 0.85
    )
    let result = TextReconciler().reconcile(page: page)

    #expect(result.textSource == .ocr)
    #expect(result.qualityScore == 0.85)
}

@Test("High agreement picks PDFKit with score 0.9")
func reconcilerHighAgreement() {
    let text = "The patient presented with elevated glucose levels of 126 mg/dL. Blood pressure was 140/90 mmHg."
    let page = makePageExtraction(
        pdfKitText: text,
        ocrText: text + " Normal heart rate.",
        ocrConfidence: 0.95
    )
    let result = TextReconciler().reconcile(page: page)

    #expect(result.textSource == .pdfKit)
    #expect(result.qualityScore == 0.9)
}

@Test("Low agreement, clean PDFKit wins over garbage OCR")
func reconcilerPdfKitWinsOnQuality() {
    let page = makePageExtraction(
        pdfKitText: "The patient was prescribed metformin 500mg twice daily for type 2 diabetes management. Follow up in three months.",
        ocrText: "Th\u{FFFD} p\u{FFFD}t\u{FFFD}\u{FFFD}nt w\u{FFFD}s pr\u{FFFD}scr\u{FFFD}b\u{FFFD}d m\u{FFFD}tf\u{FFFD}rm\u{FFFD}n for d\u{FFFD}\u{FFFD}b\u{FFFD}t\u{FFFD}s",
        ocrConfidence: 0.3
    )
    let result = TextReconciler().reconcile(page: page)

    #expect(result.textSource == .pdfKit)
}

@Test("Low agreement, OCR wins with high confidence and domain signals")
func reconcilerOcrWinsOnConfidenceAndDomain() {
    let page = makePageExtraction(
        pdfKitText: "Some generic content that does not contain any medical terminology or useful clinical data for the patient record.",
        ocrText: "Lab results: glucose 126 mg/dL, cholesterol 200 mg/dL, blood pressure 140/90 mmHg, heart rate 72 bpm. Patient diagnosis confirmed.",
        ocrConfidence: 0.98
    )
    let result = TextReconciler().reconcile(page: page)

    #expect(result.textSource == .ocr)
}

// MARK: - TextChunker Tests

@Test("Single short page produces one chunk")
func chunkerSingleShortPage() {
    let page = makeReconciledPage(
        text: "This is a short paragraph about patient health.",
        paragraphs: ["This is a short paragraph about patient health."]
    )
    let chunks = TextChunker().chunk(pages: [page])

    #expect(chunks.count == 1)
    #expect(chunks[0].chunkIndex == 0)
    #expect(chunks[0].content.contains("short paragraph"))
}

@Test("Long content splits into multiple chunks under maxTokens")
func chunkerMultipleChunks() {
    let sentence = "The patient was examined and all vital signs were within normal range for the visit. "
    let longText = String(repeating: sentence, count: 30)
    let paragraphs = (0..<6).map { _ in String(repeating: sentence, count: 5) }

    let page = makeReconciledPage(text: longText, paragraphs: paragraphs)
    let chunker = TextChunker(maxTokens: 100, overlapTokens: 10)
    let chunks = chunker.chunk(pages: [page])

    #expect(chunks.count > 1)
    for (i, chunk) in chunks.enumerated() {
        #expect(chunk.chunkIndex == i)
    }
}

@Test("Overlap exists between consecutive chunks")
func chunkerOverlap() {
    let sentence = "The patient was examined and all vital signs were within normal range for the visit. "
    let paragraphs = (0..<6).map { _ in String(repeating: sentence, count: 5) }
    let longText = paragraphs.joined(separator: "\n\n")

    let page = makeReconciledPage(text: longText, paragraphs: paragraphs)
    let chunker = TextChunker(maxTokens: 100, overlapTokens: 20)
    let chunks = chunker.chunk(pages: [page])

    #expect(chunks.count > 1)

    if chunks.count >= 2 {
        let firstChunkWords = chunks[0].content.split(whereSeparator: { $0.isWhitespace })
        let secondChunkWords = chunks[1].content.split(whereSeparator: { $0.isWhitespace })
        let lastWordsOfFirst = Set(firstChunkWords.suffix(15).map(String.init))
        let firstWordsOfSecond = Set(secondChunkWords.prefix(15).map(String.init))
        let overlap = lastWordsOfFirst.intersection(firstWordsOfSecond)
        #expect(!overlap.isEmpty, "Expected overlap between consecutive chunks")
    }
}

@Test("Multiple pages track correct page numbers")
func chunkerPageNumbers() {
    let sentence = "The patient was examined and all vital signs were within normal range for this visit. "
    let para1 = String(repeating: sentence, count: 5)
    let para2 = String(repeating: sentence, count: 5)

    let page1 = makeReconciledPage(
        pageNumber: 1,
        text: para1,
        paragraphs: [para1]
    )
    let page2 = makeReconciledPage(
        pageNumber: 2,
        text: para2,
        paragraphs: [para2]
    )

    let chunker = TextChunker(maxTokens: 50, overlapTokens: 5)
    let chunks = chunker.chunk(pages: [page1, page2])

    let page1Chunks = chunks.filter { $0.pageNumber == 1 }
    let page2Chunks = chunks.filter { $0.pageNumber == 2 }

    #expect(!page1Chunks.isEmpty, "Expected chunks from page 1")
    #expect(!page2Chunks.isEmpty, "Expected chunks from page 2")
}
