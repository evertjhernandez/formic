enum WorkspaceRibbonTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case annotate = "Annotate"
    case view = "View"
    case find = "Find"

    var id: Self { self }
}
