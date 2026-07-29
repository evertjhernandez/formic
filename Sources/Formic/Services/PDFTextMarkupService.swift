import PDFKit

struct PDFMarkupRecord {
    let page: PDFPage
    let annotation: PDFAnnotation
}

struct PDFTextMarkupService {
    func records(for selection: PDFSelection, style: TextMarkupStyle) -> [PDFMarkupRecord] {
        selection.selectionsByLine().flatMap { lineSelection in
            lineSelection.pages.compactMap { page in
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 0, bounds.height > 0 else { return nil }

                let annotation = PDFAnnotation(
                    bounds: bounds,
                    forType: style.annotationSubtype,
                    withProperties: nil
                )
                annotation.color = style.color
                return PDFMarkupRecord(page: page, annotation: annotation)
            }
        }
    }
}
