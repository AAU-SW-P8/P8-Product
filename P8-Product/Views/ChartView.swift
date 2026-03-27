//
//  ChartView.swift
//  P8-Product
//
//  Created by Peter Rahr on 26/03/2026.
//

import SwiftUI
import Charts

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

struct ChartView: View {
    let mole: Mole
    let metric: ChartMetric

    private var chartData: [(date: Date, value: Double)] {
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
                return (date: scan.captureDate, value: value)
            }
            .sorted { $0.date < $1.date }
    }

    private var evolution: Double {
        let first = chartData.first?.value ?? 0
        let last = chartData.last?.value ?? first
        return last - first
    }

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

            Chart {
                ForEach(chartData.indices, id: \.self) { index in
                    let point = chartData[index]
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
                    AxisValueLabel()
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .padding()
        }
    }
}
