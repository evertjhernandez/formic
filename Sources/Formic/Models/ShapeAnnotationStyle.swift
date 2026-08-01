import PDFKit

enum ShapeAnnotationStyle: CaseIterable, Identifiable, Hashable {
    case rectangle
    case oval

    var id: Self { self }

    var displayName: String {
        switch self {
        case .rectangle:
            return "Rectangle"
        case .oval:
            return "Oval"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle:
            return "rectangle"
        case .oval:
            return "circle"
        }
    }

    var annotationSubtype: PDFAnnotationSubtype {
        switch self {
        case .rectangle:
            return .square
        case .oval:
            return .circle
        }
    }
}
