//
//  ChartView.swift
//  P8-Product
//

import SwiftUI
import Charts

/**
    ChartMetric defines the types of measurements that can be visualized in the ChartView, such as area and diameter.
    It provides properties for the display title and unit of measurement for each metric.
*/
enum ChartMetric: String, CaseIterable, Identifiable {
    case area
    case diameter

    var id: Self { self }

    var title: String {
        switch self {
        case .area:
            return "Area"
        case .diameter:
            return "Diameter"
        }
    }

    var unit: String {
        switch self {
        case .area:
            return "mm²"
        case .diameter:
            return "mm"
        }
    }
}

/**
    View responsible for rendering the line chart of a mole's area or diameter over time.
    It also highlights the two scans currently selected in the evolution carousels:
    - left carousel  -> square
    - right carousel -> triangle
    - both carousels -> larger circle
*/
struct ChartView: View {
    /**
        DataPoint represents a single measurement of the mole at a specific date.
        It conforms to Identifiable for use in ForEach and Equatable for testing purposes.
    */
    struct DataPoint: Identifiable, Equatable {
        let id = UUID()
        let index: Int
        let date: Date
        let value: Double

        /// Compares two chart points by content, ignoring generated identifier values.
        static func == (lhs: DataPoint, rhs: DataPoint) -> Bool {
            lhs.index == rhs.index && lhs.date == rhs.date && lhs.value == rhs.value
        }
    }

    enum SelectedMarkerKind {
        case left
        case right
        case both
    }

    let mole: Mole
    let metric: ChartMetric
    let scans: [MoleScan]
    let topSelectedIndex: Int
    let bottomSelectedIndex: Int

    private var safeTopIndex: Int {
        ImageCarousel.safeIndex(for: scans, requested: topSelectedIndex)
    }

    private var safeBottomIndex: Int {
        ImageCarousel.safeIndex(for: scans, requested: bottomSelectedIndex)
    }

    /// Builds chart-ready data points for the requested metric using scans that belong to the supplied mole.
    /// - Parameters:
    ///   - mole: The mole whose measurements should be visualized.
    ///   - metric: The metric to extract for each scan.
    ///   - scans: Candidate scans to convert into chart points.
    /// - Returns: A list of chart points in scan order.
    static func makeChartData(for mole: Mole, metric: ChartMetric, scans: [MoleScan]) -> [DataPoint] {
        scans.enumerated().compactMap { index, scan in
            guard scan.mole?.id == mole.id else {
                return nil
            }

            let value: Double
            switch metric {
            case .area:
                value = Double(scan.area)
            case .diameter:
                value = Double(scan.diameter)
            }

            return DataPoint(
                index: index,
                date: scan.captureDate,
                value: roundedMetricValue(value)
            )
        }
    }

    /// Rounds a metric value to one decimal place for consistent chart display.
    /// - Parameter value: The raw metric value.
    /// - Returns: The rounded metric value.
    static func roundedMetricValue(_ value: Double) -> Double {
        Double(round(10 * value) / 10)
    }

    /// Computes the data points for the chart based on the scans and the selected metric.
    private var chartData: [DataPoint] {
        Self.makeChartData(for: mole, metric: metric, scans: scans)
    }

    private var yScaleDomain: ClosedRange<Double> {
        Self.yScaleDomain(for: chartData)
    }

    /// Calculates a padded y-axis domain based on the provided points.
    /// - Parameter points: Data points used to derive axis bounds.
    /// - Returns: A range suitable for chart y-axis scaling.
    static func yScaleDomain(for points: [DataPoint]) -> ClosedRange<Double> {
        let values = points.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...1
        }
        if minValue == maxValue {
            let padding = max(abs(minValue) * 0.05, 1)
            return (minValue - padding)...(maxValue + padding)
        }

        let spread = maxValue - minValue
        let padding = max(spread * 0.1, 1)
        return (minValue - padding)...(maxValue + padding)
    }

    private var dateRange: ClosedRange<Date> {
        Self.dateRange(for: chartData)
    }

    /// Calculates the x-axis date range with a one-day buffer after the newest point.
    /// - Parameter points: Data points used to derive temporal bounds.
    /// - Returns: The date range used for chart x-axis scaling.
    static func dateRange(for points: [DataPoint]) -> ClosedRange<Date> {
        let sortedDates = points.map(\.date).sorted()
        guard let first = sortedDates.first, let last = sortedDates.last else {
            let now = Date()
            return now...now
        }

        // Add a small buffer (1 day) to the end so the last point has breathing room.
        let extendedEnd = Calendar.current.date(byAdding: .day, value: 1, to: last) ?? last
        return first...extendedEnd
    }

    /// Calculates the overall change in the metric from the first to the last data point.
    private var evolution: Double {
        guard
            let oldestPoint = chartData.min(by: { $0.date < $1.date }),
            let newestPoint = chartData.max(by: { $0.date < $1.date })
        else {
            return 0
        }

        return newestPoint.value - oldestPoint.value
    }

    /// Formats the evolution value with a "+" or "-" sign and includes the unit for display in the UI.
    private var evolutionText: String {
        let deltaText = String(format: "%.1f", abs(evolution))
        if evolution > 0 {
            return "+\(deltaText) \(metric.unit)"
        } else if evolution < 0 {
            return "-\(deltaText) \(metric.unit)"
        } else {
            return "No changes"
        }
    }

    /// Helper to format the metric values for display in the chart annotations.
    private func formattedMetricValue(_ value: Double) -> String {
        "\(String(format: "%.1f", Self.roundedMetricValue(value)))"
    }

    /**
        Determines if a given data point index corresponds to the selected indices from the left and right carousels.
        It returns the appropriate marker kind to indicate which carousel(s) have selected that data point.
     */
    func markerKind(for pointIndex: Int) -> SelectedMarkerKind? {
        let isTopSelected = pointIndex == safeTopIndex
        let isBottomSelected = pointIndex == safeBottomIndex

        if isTopSelected && isBottomSelected {
            return .both
        } else if isTopSelected {
            return .left
        } else if isBottomSelected {
            return .right
        } else {
            return nil
        }
    }

    /// Determines which marker shape should be shown for a point based on selected indices.
    /// - Parameters:
    ///   - pointIndex: Index of the plotted point.
    ///   - safeTopIndex: Clamped index from the top carousel.
    ///   - safeBottomIndex: Clamped index from the bottom carousel.
    /// - Returns: The marker kind for the point, or `nil` when it is not selected.
    static func calculateMarkerKind(pointIndex: Int, safeTopIndex: Int, safeBottomIndex: Int) -> SelectedMarkerKind? {
            let isTopSelected = pointIndex == safeTopIndex
            let isBottomSelected = pointIndex == safeBottomIndex

            if isTopSelected && isBottomSelected {
                return .both
            } else if isTopSelected {
                return .left
            } else if isBottomSelected {
                return .right
            } else {
                return nil
            }
        }

    /// Returns the symbol view used to represent a selected point marker in the chart.
    /// - Parameter kind: The marker variant to render.
    /// - Returns: A marker symbol view.
    @ViewBuilder
    private func markerSymbol(for kind: SelectedMarkerKind) -> some View {
        switch kind {
        case .left:
            Image(systemName: "square.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)

        case .right:
            Image(systemName: "triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)

        case .both:
            Circle()
                .frame(width: 14, height: 14)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(metric.title + " Trend")
                Text(evolutionText)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.blue)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Chart {
                ForEach(chartData) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(45)
                    .annotation(position: .bottom) {
                        Text(formattedMetricValue(point.value))
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }

                ForEach(chartData) { point in
                    if let markerKind = markerKind(for: point.index) {
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(metric.title, point.value)
                        )
                        .foregroundStyle(.primary)
                        .symbol {
                            markerSymbol(for: markerKind)
                        }
                        .symbolSize(markerKind == .both ? 170 : 130)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let yValue = value.as(Double.self) {
                            Text("\(yValue.formatted(.number.precision(.fractionLength(1)))) \(metric.unit)")
                        }
                    }
                }
            }
            .chartYScale(domain: yScaleDomain)
            .chartXScale(domain: dateRange)
            .padding()

        }
    }
}
