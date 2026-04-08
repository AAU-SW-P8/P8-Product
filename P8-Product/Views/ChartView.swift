//
//  ChartView.swift
//  P8-Product
//
//  Created by Peter Rahr on 26/03/2026.
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
    It extracts the relevant data points from the mole's instances and displays them, 
    along with an annotation of the overall trend.
    - Fields
        - mole: The mole whose data we want to visualize.
        - metric: The specific measurement (area or diameter) to chart.
*/
struct ChartView: View {
    /**
        DataPoint represents a single measurement of the mole at a specific date.
        It conforms to Identifiable for use in ForEach and Equatable for testing purposes.
        - Fields
            - id: A unique identifier for the data point.
            - date: The date of the measurement.
            - value: The value of the metric (area or diameter) at that date.
        - Methods
            - ==: An equality operator to compare two DataPoints based on their date and value, ignoring the id.  
    */
    struct DataPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let value: Double

        static func == (lhs: DataPoint, rhs: DataPoint) -> Bool {
            lhs.date == rhs.date && lhs.value == rhs.value
        }
    }

    let mole: Mole
    let metric: ChartMetric

    static func makeChartData(for mole: Mole, metric: ChartMetric) -> [DataPoint] {
        mole.instances
            .compactMap { instance in
                guard let scan = instance.moleScan else { return nil }
                let value: Double
                switch metric {
                case .area:
                    value = Double(instance.area)
                case .diameter:
                    value = Double(instance.diameter)
                }
                return DataPoint(date: scan.captureDate, value: value)
            }
            .sorted { $0.date < $1.date }
    }

    /// Computes the data points for the chart based on the mole's instances and the selected metric.
    private var chartData: [DataPoint] {
        Self.makeChartData(for: mole, metric: metric)
    }

    /// Calculates the overall change in the metric from the first to the last data point, indicating growth or shrinkage.
    private var evolution: Double {
        let first = chartData.first?.value ?? 0
        let last = chartData.last?.value ?? first
        return last - first
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
                    .symbol(Circle())

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(100)
                    .annotation(position: .bottom) {
                        Text(formattedMetricValue(point.value))
                            .font(.caption)
                            .foregroundStyle(.primary)
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
