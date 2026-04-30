import Testing

@testable import P8_Product

/// Tests for `ImageCarousel` dot-pagination logic and scan-selection helpers.
@Suite("DotPagination")
struct DotPaginationTests {

  /// Tests logic for less or equal to five items.
  @Test("Test less or equal five items")
  func testLessOrEqualFiveItems() {
    // Arrange & Act
    let items = ImageCarousel.calculateDotItems(count: 4, safeIndex: 0, side: .both)

    // Assert
    let expected: [ImageCarousel.DotItem] = [.index(0), .index(1), .index(2), .index(3)]
    #expect(items == expected)
  }

  /// Tests pagination logic for more than five items starting at the beginning.
  @Test
  func testMoreThanFiveItems_Beginning() {
    let items = ImageCarousel.calculateDotItems(count: 10, safeIndex: 1, side: .both)
    let expected: [ImageCarousel.DotItem] = [.index(0), .index(1), .index(2), .ellipsis, .index(9)]
    #expect(items == expected)
  }

  /// Tests pagination logic for more than five items in the middle.
  @Test
  func testMoreThanFiveItems_Middle() {
    let items = ImageCarousel.calculateDotItems(count: 10, safeIndex: 5, side: .both)
    let expected: [ImageCarousel.DotItem] = [
      .index(0), .ellipsis, .index(4), .index(5), .index(6), .ellipsis, .index(9),
    ]
    #expect(items == expected)
  }

  /// Tests pagination logic for more than five items reversed for side views.
  @Test
  func testMoreThanFiveItems_ReversedForSideViews() {
    // Here we test that a .left side reverses the array
    let items = ImageCarousel.calculateDotItems(count: 10, safeIndex: 1, side: .left)

    // Notice the expected array is reversed compared to the Beginning test above
    let expected: [ImageCarousel.DotItem] = [.index(9), .ellipsis, .index(2), .index(1), .index(0)]
    #expect(items == expected)
  }

  /// Tests selected scan uses selected index when mole matches.
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

  /// Tests selected scan uses selected index when without mole.
  @Test
  func selectedScanWithoutMole_UsesSelectedIndex() {
    let first = MoleScan(diameter: 3.0, area: 8.0)
    let second = MoleScan(diameter: 6.0, area: 18.0)
    let scans = [first, second]

    let selected = ImageCarousel.selectedScan(in: scans, at: 1, for: nil)
    #expect(selected?.id == second.id)
  }
}
