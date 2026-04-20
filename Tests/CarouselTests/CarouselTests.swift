//
//  CarouselTests.swift
//  PipelineTests
//
//  Created by Nicolaj Skjødt on 20/04/2026.
//

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
        let expected: [ImageCarousel.DotItem] = [.index(0), .index(1), .index(2), .ellipsis("right"), .index(9)]
        #expect(items == expected)
    }

    @Test
    func testMoreThanFiveItems_Middle() {
        let items = ImageCarousel.calculateDotItems(count: 10, safeIndex: 5, side: .both)
        let expected: [ImageCarousel.DotItem] = [
            .index(0), .ellipsis("left"), .index(4), .index(5), .index(6), .ellipsis("right"), .index(9)
        ]
        #expect(items == expected)
    }

    @Test
    func testMoreThanFiveItems_ReversedForSideViews() {
        // Here we test that a .left side reverses the array
        let items = ImageCarousel.calculateDotItems(count: 10, safeIndex: 1, side: .left)
        
        // Notice the expected array is reversed compared to the Beginning test above
        let expected: [ImageCarousel.DotItem] = [.index(9), .ellipsis("right"), .index(2), .index(1), .index(0)]
        #expect(items == expected)
    }
}
