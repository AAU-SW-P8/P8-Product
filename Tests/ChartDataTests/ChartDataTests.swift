//
//  ChartDataTests.swift
//  ChartDataTests
//
//  Created by Simon Thordal on 08/04/2026.
//


import Testing
import Foundation
import SwiftData
@testable import P8_Product

@MainActor
struct ChartDataTests {

    // MARK: - ChartView.makeChartData
    //
    // CompareView feeds a Mole into ChartView, which derives its plotted points
    // from the mole's instances. We can't query individual chart annotations from
    // XCUI (Swift Charts hosts them in an opaque backing layer), so we verify the
    // data flow at the source: `ChartView.makeChartData(for:metric:)`.

    /// Builds an in-memory SwiftData container so the tests can construct fully
    /// linked Mole / MoleInstance / MoleScan graphs without touching the on-disk
    /// store used by the running app.
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            Person.self,
            Mole.self,
            MoleInstance.self,
            MoleScan.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Convenience for building a bare mole inside a context.
    private func makeMole(in context: ModelContext, name: String = "Test Mole") -> Mole {
        let mole = Mole(
            name: name,
            bodyPart: "Arm",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil
        )
        context.insert(mole)
        return mole
    }

    /// Inserts a scan + instance pair linked to the given mole.
    @discardableResult
    private func attachInstance(
        to mole: Mole,
        in context: ModelContext,
        diameter: Float,
        area: Float,
        captureDate: Date
    ) -> MoleInstance {
        let scan = MoleScan(captureDate: captureDate)
        let instance = MoleInstance(
            diameter: diameter,
            area: area,
            mole: mole,
            moleScan: scan
        )
        context.insert(scan)
        context.insert(instance)
        return instance
    }

    @Test func chartDataIsSortedByCaptureDateAscending() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        // Insert in scrambled chronological order to prove sorting works.
        let day0  = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        attachInstance(to: mole, in: context, diameter: 5.0, area: 16.0, captureDate: day20)
        attachInstance(to: mole, in: context, diameter: 4.2, area: 13.8, captureDate: day0)
        attachInstance(to: mole, in: context, diameter: 4.8, area: 15.4, captureDate: day10)
        try context.save()

        let points = ChartView.makeChartData(for: mole, metric: .area)

        #expect(points.count == 3)
        #expect(points.map(\.date) == [day0, day10, day20])
    }

    @Test func chartDataReturnsAreaValuesForAreaMetric() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0  = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        attachInstance(to: mole, in: context, diameter: 4.2, area: 13.8, captureDate: day0)
        attachInstance(to: mole, in: context, diameter: 4.8, area: 15.4, captureDate: day10)
        attachInstance(to: mole, in: context, diameter: 5.0, area: 16.0, captureDate: day20)
        try context.save()

        let points = ChartView.makeChartData(for: mole, metric: .area)

        // Round-trip through Float so the comparison matches the
        // implementation's `Double(instance.area)` widening.
        let expected: [Double] = [Float(13.8), Float(15.4), Float(16.0)].map(Double.init)
        #expect(points.map(\.value) == expected)
    }

    @Test func chartDataReturnsDiameterValuesForDiameterMetric() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0  = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        attachInstance(to: mole, in: context, diameter: 4.2, area: 13.8, captureDate: day0)
        attachInstance(to: mole, in: context, diameter: 4.8, area: 15.4, captureDate: day10)
        attachInstance(to: mole, in: context, diameter: 5.0, area: 16.0, captureDate: day20)
        try context.save()

        let points = ChartView.makeChartData(for: mole, metric: .diameter)

        let expected: [Double] = [Float(4.2), Float(4.8), Float(5.0)].map(Double.init)
        #expect(points.map(\.value) == expected)
    }

    @Test func chartDataPreservesDuplicateValues() throws {
        // Two scans with the same area on different dates should produce two
        // distinct data points (this is the case the duplicate-identifier
        // discussion was about — verify it at the data layer).
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        let day1 = day0.addingTimeInterval(86_400)

        attachInstance(to: mole, in: context, diameter: 5.0, area: 16.0, captureDate: day0)
        attachInstance(to: mole, in: context, diameter: 5.0, area: 16.0, captureDate: day1)
        try context.save()

        let points = ChartView.makeChartData(for: mole, metric: .area)

        #expect(points.count == 2)
        #expect(points[0].value == points[1].value)
        #expect(points.map(\.date) == [day0, day1])
    }

    @Test func chartDataExcludesInstancesWithoutScans() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        attachInstance(to: mole, in: context, diameter: 4.0, area: 12.0, captureDate: day0)

        // Orphan instance with no scan — should be filtered out.
        let orphan = MoleInstance(diameter: 9.9, area: 99.9, mole: mole, moleScan: nil)
        context.insert(orphan)
        try context.save()

        let points = ChartView.makeChartData(for: mole, metric: .area)

        #expect(points.count == 1)
        #expect(points.first?.value == Double(Float(12.0)))
    }

    @Test func chartDataIsEmptyForMoleWithNoInstances() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)
        try context.save()

        #expect(ChartView.makeChartData(for: mole, metric: .area).isEmpty)
        #expect(ChartView.makeChartData(for: mole, metric: .diameter).isEmpty)
    }

    // MARK: - ImageCarousel selection
    //
    // The carousel renders inside a SwiftUI LazyHStack that XCUI can't query
    // for image bytes, so we test the binding between selectedIndex and the
    // returned scan/imageData at the source: ImageCarousel's static helpers.
    // Each scan gets distinct imageData so an assertion failure pinpoints
    // which scan came back wrong.

    @Test func carouselSelectionReturnsImageDataForCorrectScan() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0  = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        let bytes0 = Data([0xA0])
        let bytes1 = Data([0xA1])
        let bytes2 = Data([0xA2])

        let scan0 = MoleScan(captureDate: day0,  imageData: bytes0)
        let scan1 = MoleScan(captureDate: day10, imageData: bytes1)
        let scan2 = MoleScan(captureDate: day20, imageData: bytes2)
        [scan0, scan1, scan2].forEach(context.insert)

        context.insert(MoleInstance(diameter: 4.2, area: 13.8, mole: mole, moleScan: scan0))
        context.insert(MoleInstance(diameter: 4.8, area: 15.4, mole: mole, moleScan: scan1))
        context.insert(MoleInstance(diameter: 5.0, area: 16.0, mole: mole, moleScan: scan2))
        try context.save()

        let scans = [scan0, scan1, scan2]   // ascending order, like CompareView feeds in

        #expect(ImageCarousel.selectedScan(in: scans, at: 0)?.imageData == bytes0)
        #expect(ImageCarousel.selectedScan(in: scans, at: 1)?.imageData == bytes1)
        #expect(ImageCarousel.selectedScan(in: scans, at: 2)?.imageData == bytes2)
    }

    @Test func carouselSelectionPicksInstanceMatchingMole() throws {
        // A single scan can have multiple instances (one per mole). The
        // carousel must surface the instance whose mole matches the binding,
        // not just the first one in the array.
        let context = try makeInMemoryContext()
        let leftArm = makeMole(in: context, name: "Left Arm")
        let back    = makeMole(in: context, name: "Back")

        let scan = MoleScan(
            captureDate: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: Data([0xFF])
        )
        context.insert(scan)
        context.insert(MoleInstance(diameter: 5.0, area: 16.0, mole: leftArm, moleScan: scan))
        context.insert(MoleInstance(diameter: 3.6, area: 10.1, mole: back,    moleScan: scan))
        try context.save()

        let leftPick = ImageCarousel.selectedInstance(in: [scan], at: 0, for: leftArm)
        let backPick = ImageCarousel.selectedInstance(in: [scan], at: 0, for: back)

        #expect(leftPick?.diameter == 5.0)
        #expect(backPick?.diameter == 3.6)
    }

    @Test func carouselSelectionFallsBackToFirstInstanceWhenNoMoleFilter() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let scan = MoleScan(
            captureDate: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: Data([0x10])
        )
        context.insert(scan)
        let instance = MoleInstance(diameter: 4.0, area: 12.0, mole: mole, moleScan: scan)
        context.insert(instance)
        try context.save()

        let pick = ImageCarousel.selectedInstance(in: [scan], at: 0, for: nil)

        #expect(pick?.diameter == 4.0)
        #expect(pick?.area == 12.0)
    }

    @Test func carouselSelectionClampsOutOfBoundsIndex() throws {
        // selectedIndex can briefly out-run the scans array when CompareView
        // swaps moles. The carousel clamps to the last valid scan rather than
        // crashing or returning the wrong image.
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let scan0 = MoleScan(
            captureDate: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: Data([0x01])
        )
        let scan1 = MoleScan(
            captureDate: Date(timeIntervalSince1970: 1_700_086_400),
            imageData: Data([0x02])
        )
        [scan0, scan1].forEach(context.insert)
        context.insert(MoleInstance(diameter: 4.0, area: 12.0, mole: mole, moleScan: scan0))
        context.insert(MoleInstance(diameter: 4.5, area: 13.0, mole: mole, moleScan: scan1))
        try context.save()

        let scans = [scan0, scan1]

        #expect(ImageCarousel.safeIndex(for: scans, requested: 99) == 1)
        #expect(ImageCarousel.selectedScan(in: scans, at: 99)?.imageData == Data([0x02]))

        #expect(ImageCarousel.safeIndex(for: scans, requested: -5) == 0)
        #expect(ImageCarousel.selectedScan(in: scans, at: -5)?.imageData == Data([0x01]))
    }

    @Test func carouselSelectionReturnsNilForEmptyScans() {
        #expect(ImageCarousel.selectedScan(in: [], at: 0) == nil)
        #expect(ImageCarousel.selectedInstance(in: [], at: 0, for: nil) == nil)
        #expect(ImageCarousel.safeIndex(for: [], requested: 3) == 0)
    }

}
