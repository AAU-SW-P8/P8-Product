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

    static func makeChartData(for mole: Mole, metric: ChartMetric, scans: [MoleScan]) -> [DataPoint] {
        scans.enumerated().compactMap { index, scan in
            guard let instance = scan.instances.first(where: { $0.mole?.id == mole.id }) else {
                return nil
            }

            let value: Double
            switch metric {
            case .area:
                value = Double(instance.area)
            case .diameter:
                value = Double(instance.diameter)
            }

            return DataPoint(
                index: index,
                date: scan.captureDate,
                value: value
            )
        }
    }

    /// Computes the data points for the chart based on the scans and the selected metric.
    private var chartData: [DataPoint] {
        Self.makeChartData(for: mole, metric: metric, scans: scans)
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
        "\(String(format: "%.1f", value))"
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
                    .interpolationMethod(.catmullRom)
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
                        .foregroundStyle(.black)
                        .symbol {
                            markerSymbol(for: markerKind)
                        }
                        .symbolSize(markerKind == .both ? 170 : 130)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.year())
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
            .chartYScale(domain: .automatic(includesZero: false))
            .padding()
        }
    }
}
