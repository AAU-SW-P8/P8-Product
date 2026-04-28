//
//  PipelineTests.swift
//  PipelineTests
//
//  Created by Simon Thordal on 3/18/26.
//

import Testing
import Foundation
import SwiftData
@testable import P8_Product

@Suite("Pipeline")
@MainActor
struct PipelineTests {

    // MARK: - ChartView.makeChartData
    //
    // CompareView feeds a Mole into ChartView, which derives its plotted points
    // from the mole's instances. We can't query individual chart annotations from
    // XCUI (Swift Charts hosts them in an opaque backing layer), so we verify the
    // data flow at the source: `ChartView.makeChartData(for:metric:)`.

    /// Builds an in-memory SwiftData container so the tests can construct fully
    /// linked Mole /  MoleScan graphs without touching the on-disk
    /// store used by the running app.
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            Person.self,
            Mole.self,
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

    /// Inserts a scan linked to the given mole.
    @discardableResult
    private func attachInstance(
        to mole: Mole,
        in context: ModelContext,
        diameter: Float,
        area: Float,
        captureDate: Date
    ) -> MoleScan {
        let scan = MoleScan(
            captureDate: captureDate,
            diameter: diameter,
            area: area,
            mole: mole)
        context.insert(scan)
        return scan
    }

    @Test func chartDataFollowsProvidedScanOrder() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        // Match the newest-first scan order that MoleDetailAppState provides.
        let day0  = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        let scan0 = MoleScan(captureDate: day0, diameter: 4.2, area: 13.8, mole: mole)
        let scan10 = MoleScan(captureDate: day10, diameter: 4.8, area: 15.4, mole: mole)
        let scan20 = MoleScan(captureDate: day20, diameter: 5.0, area: 16.0, mole: mole)
        [scan0, scan10, scan20].forEach(context.insert)
        try context.save()

        let scans = [scan20, scan10, scan0]
        let points = ChartView.makeChartData(for: mole, metric: .area, scans: scans)

        #expect(points.count == 3)
        #expect(points.map { $0.date } == [day20, day10, day0])
    }

    @Test func chartDataReturnsAreaValuesForAreaMetric() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0  = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        let scan0 = MoleScan(captureDate: day0, diameter: 4.2, area: 13.8, mole: mole)
        let scan10 = MoleScan(captureDate: day10, diameter: 4.8, area: 15.4, mole: mole)
        let scan20 = MoleScan(captureDate: day20, diameter: 5.0, area: 16.0, mole: mole)
        [scan0, scan10, scan20].forEach(context.insert)
        try context.save()

        let scans = [scan20, scan10, scan0]
        let points = ChartView.makeChartData(for: mole, metric: .area, scans: scans)

        // Round-trip through Float so the comparison matches the
        // implementation's `Double(instance.area)` widening.
        let expected: [Double] = [16.0, 15.4, 13.8]
        #expect(points.map { $0.value } == expected)
    }

    @Test func chartDataReturnsDiameterValuesForDiameterMetric() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0  = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        let scan0 = MoleScan(captureDate: day0, diameter: 4.2, area: 13.8, mole: mole)
        let scan10 = MoleScan(captureDate: day10, diameter: 4.8, area: 15.4, mole: mole)
        let scan20 = MoleScan(captureDate: day20, diameter: 5.0, area: 16.0, mole: mole)
        [scan0, scan10, scan20].forEach(context.insert)
        try context.save()

        let scans = [scan20, scan10, scan0]
        let points = ChartView.makeChartData(for: mole, metric: .diameter, scans: scans)

        let expected: [Double] = [5.0, 4.8, 4.2]
        #expect(points.map { $0.value } == expected)
    }

    @Test func chartDataPreservesDuplicateValues() throws {
        // Two scans with the same area on different dates should produce two
        // distinct data points (this is the case the duplicate-identifier
        // discussion was about — verify it at the data layer).
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        let day1 = day0.addingTimeInterval(86_400)

        let scan0 = MoleScan(captureDate: day0, diameter: 5.0, area: 16.0, mole: mole)
        let scan1 = MoleScan(captureDate: day1, diameter: 5.0, area: 16.0, mole: mole)
        [scan0, scan1].forEach(context.insert)
        try context.save()

        let points = ChartView.makeChartData(for: mole, metric: .area, scans: [scan1, scan0])

        #expect(points.count == 2)
        #expect(points[0].value == points[1].value)
        #expect(points.map { $0.date } == [day1, day0])
    }

    @Test func chartDataExcludesScansWithoutMole() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        let attachedScan = attachInstance(to: mole, in: context, diameter: 4.0, area: 12.0, captureDate: day0)

        // Orphan scan with no mole should be filtered out.
        let orphanScan = MoleScan(
            captureDate: day0.addingTimeInterval(86_400),
            diameter: 9.9,
            area: 99.9,
            mole: nil
        )
        context.insert(orphanScan)
        try context.save()

        let points = ChartView.makeChartData(for: mole, metric: .area, scans: [attachedScan, orphanScan])

        #expect(points.count == 1)
        #expect(points.first?.value == Double(Float(12.0)))
    }

    @Test func chartDataIsEmptyForMoleWithNoScans() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)
        try context.save()

        #expect(ChartView.makeChartData(for: mole, metric: .area, scans: []).isEmpty)
        #expect(ChartView.makeChartData(for: mole, metric: .diameter, scans: []).isEmpty)
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

        let scan0 = MoleScan(captureDate: day0,  imageData: bytes0, diameter: 4.2, area: 13.8, mole: mole)
        let scan1 = MoleScan(captureDate: day10, imageData: bytes1, diameter: 4.8, area: 15.4, mole: mole)
        let scan2 = MoleScan(captureDate: day20, imageData: bytes2, diameter: 5.0, area: 16.0, mole: mole)
        [scan0, scan1, scan2].forEach(context.insert)
        try context.save()

        let scans = [scan0, scan1, scan2]   // ascending order, like CompareView feeds in

        #expect(ImageCarousel.selectedScan(in: scans, at: 0)?.imageData == bytes0)
        #expect(ImageCarousel.selectedScan(in: scans, at: 1)?.imageData == bytes1)
        #expect(ImageCarousel.selectedScan(in: scans, at: 2)?.imageData == bytes2)
    }

    @Test func carouselSelectionPicksScanMatchingMole() throws {
        // Each scan now carries its own mole and measurement values.
        // The carousel should surface the scan whose mole matches the binding.
        let context = try makeInMemoryContext()
        let leftArm = makeMole(in: context, name: "Left Arm")
        let back    = makeMole(in: context, name: "Back")

        let leftScan = MoleScan(
            captureDate: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: Data([0xFF]),
            diameter: 5.0,
            area: 16.0,
            mole: leftArm
        )
        let backScan = MoleScan(
            captureDate: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: Data([0xFF]),
            diameter: 3.6,
            area: 10.1,
            mole: back
        )
        context.insert(leftScan)
        context.insert(backScan)
        try context.save()

        let leftPick = ImageCarousel.selectedScan(in: [leftScan], at: 0, for: leftArm)
        let backPick = ImageCarousel.selectedScan(in: [backScan], at: 0, for: back)

        #expect(leftPick?.diameter == 5.0)
        #expect(backPick?.diameter == 3.6)
    }

    @Test func carouselSelectionFallsBackToFirstScanWhenNoMoleFilter() throws {
        let context = try makeInMemoryContext()
        let mole = makeMole(in: context)

        let scan = MoleScan(
            captureDate: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: Data([0x10]),
            diameter: 4.0,
            area: 12.0,
            mole: mole
        )
        context.insert(scan)
        try context.save()

        let pick = ImageCarousel.selectedScan(in: [scan], at: 0, for: nil)

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
            imageData: Data([0x01]),
            diameter: 4.0,
            area: 12.0,
            mole: mole
        )
        let scan1 = MoleScan(
            captureDate: Date(timeIntervalSince1970: 1_700_086_400),
            imageData: Data([0x02]),
            diameter: 4.5,
            area: 13.0,
            mole: mole
        )
        [scan0, scan1].forEach(context.insert)
        try context.save()

        let scans = [scan0, scan1]

        #expect(ImageCarousel.safeIndex(for: scans, requested: 99) == 1)
        #expect(ImageCarousel.selectedScan(in: scans, at: 99)?.imageData == Data([0x02]))

        #expect(ImageCarousel.safeIndex(for: scans, requested: -5) == 0)
        #expect(ImageCarousel.selectedScan(in: scans, at: -5)?.imageData == Data([0x01]))
    }

    @Test func carouselSelectionReturnsNilForEmptyScans() {
        #expect(ImageCarousel.selectedScan(in: [], at: 0) == nil)
        #expect(ImageCarousel.selectedScan(in: [], at: 0, for: nil) == nil)
        #expect(ImageCarousel.safeIndex(for: [], requested: 3) == 0)
    }

}
