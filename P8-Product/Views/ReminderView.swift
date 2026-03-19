// 
// ReminderView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

struct ReminderView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Reminder Frequency") {
                    LabeledContent("Frequency", value: "Daily")
                }

                Section("Upcoming Check-ins") {
                    LabeledContent("Image ID: 101") {
                        Text(Date(), format: .dateTime.month().day().hour().minute())
                    }
                    LabeledContent("Image ID: 102") {
                        Text(Date().addingTimeInterval(86400), format: .dateTime.month().day().hour().minute())
                    }
                }
            }
            .navigationTitle("Reminder")
        }
    }
}