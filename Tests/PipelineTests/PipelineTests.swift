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

@MainActor
struct PipelineTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        #expect(1+1 == 2)
    }

    @Test func performanceExample() async throws {

    }

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

}
