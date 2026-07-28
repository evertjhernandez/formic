enum SidebarMode: String, CaseIterable, Identifiable {
    case thumbnails = "Pages"
    case outline = "Outline"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .thumbnails:
            return "rectangle.stack"
        case .outline:
            return "list.bullet.indent"
        }
    }
}
