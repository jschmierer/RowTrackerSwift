import Testing

@Suite("Phase 1 scaffold")
struct ScaffoldTests {
    @Test("project builds") func projectBuilds() {
        #expect(2 + 2 == 4)
    }
}
