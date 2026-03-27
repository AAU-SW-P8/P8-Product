//
//  ChartView.swift
//  P8-Product
//
//  Created by Peter Rahr on 26/03/2026.
//

import SwiftUI
import Charts

struct ChartView: View {
    let mole: Mole

    private var areaData: [(date: Date, area: Double)] {
        mole.instances
            .compactMap { instance in
                guard let scan = instance.moleScan else { return nil }
                return (date: scan.captureDate, area: Double(instance.area))
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        Chart {
            ForEach(areaData, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Area", point.area)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.blue)
                .symbol(Circle())
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
