import Testing
@testable import P8_Product // Ensure this matches your Product Module Name

@Suite("Chart Marker Visual Logic")
struct ChartViewTests {

    @Test("Shows Square (.left) when only the top carousel matches the chart point")
    func leftCarouselSelection() {
        // Act
        let result = ChartView.calculateMarkerKind(
            pointIndex: 2,
            safeTopIndex: 2,
            safeBottomIndex: 5
        )
        
        // Assert
        #expect(result == .left)
    }

    @Test("Shows Triangle (.right) when only the bottom carousel matches the chart point")
    func rightCarouselSelection() {
        let result = ChartView.calculateMarkerKind(
            pointIndex: 5,
            safeTopIndex: 2,
            safeBottomIndex: 5
        )
        
        #expect(result == .right)
    }

    @Test("Shows Large Circle (.both) when both carousels are on the exact same scan")
    func bothCarouselsSelection() {
        let result = ChartView.calculateMarkerKind(
            pointIndex: 3,
            safeTopIndex: 3,
            safeBottomIndex: 3
        )
        
        #expect(result == .both)
    }

    @Test("Shows no marker (nil) when the data point is not selected by either carousel")
    func neitherCarouselSelection() {
        let result = ChartView.calculateMarkerKind(
            pointIndex: 1,
            safeTopIndex: 2,
            safeBottomIndex: 5
        )
        
        #expect(result == nil)
    }
}
