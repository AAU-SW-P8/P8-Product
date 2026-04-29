import Testing
@testable import P8_Product

@Suite("DotPagination")
struct DotPaginationTests {

    @Test("Test less or equal five items")
    func testLessOrEqualFiveItems() {
        // Arrange & Act
        let items = ImageCarousel.calculateDotItems(count: 4, safeIndex: 0, side: .both)

        // Assert
        let expected: [ImageCarousel.DotItem] = [.index(0), .index(1), .index(2), .index(3)]
        #expect(items == expected)
    }

    @Test
    func testMoreThanFiveItems_Beginning() {
        let items = ImageCarousel.calculateDotItems(count: 10, safeIndex: 1, side: .both)
        let expected: [ImageCarousel.DotItem] = [.index(0), .index(1), .index(2), .ellipsis, .index(9)]
        #expect(items == expected)
    }

    @Test
    func testMoreThanFiveItems_Middle() {
        let items = ImageCarousel.calculateDotItems(count: 10, safeIndex: 5, side: .both)
        let expected: [ImageCarousel.DotItem] = [
            .index(0), .ellipsis, .index(4), .index(5), .index(6), .ellipsis, .index(9)
        ]
        #expect(items == expected)
    }

    @Test
    func testMoreThanFiveItems_ReversedForSideViews() {
        // Here we test that a .left side reverses the array
        let items = ImageCarousel.calculateDotItems(count: 10, safeIndex: 1, side: .left)

        // Notice the expected array is reversed compared to the Beginning test above
        let expected: [ImageCarousel.DotItem] = [.index(9), .ellipsis, .index(2), .index(1), .index(0)]
        #expect(items == expected)
    }

    @Test
    func selectedScanForMole_UsesSelectedIndexWhenMoleMatches() {
        let mole = Mole(
            name: "Arm Mole",
            bodyPart: "Arm",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil
        )

        let first = MoleScan(diameter: 4.0, area: 10.0, mole: mole)
        let second = MoleScan(diameter: 5.5, area: 12.0, mole: mole)
        let scans = [first, second]

        let selected = ImageCarousel.selectedScan(in: scans, at: 1, for: mole)
        #expect(selected?.id == second.id)
    }

    @Test
    func selectedScanWithoutMole_UsesSelectedIndex() {
        let first = MoleScan(diameter: 3.0, area: 8.0)
        let second = MoleScan(diameter: 6.0, area: 18.0)
        let scans = [first, second]

        let selected = ImageCarousel.selectedScan(in: scans, at: 1, for: nil)
        #expect(selected?.id == second.id)
    }
}
