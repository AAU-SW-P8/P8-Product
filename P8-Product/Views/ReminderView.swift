// 
// ReminderView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

struct ReminderView: View {
    @Query(sort: \Mole.nextDueDate) private var moles: [Mole]
    var body: some View {
        NavigationStack {
            @State var frequency = "Weekly"
            
            List {
                Section("Reminder Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        Text("Weekly").tag("Weekly")
                        Text("Monthly").tag("Monthly")
                        Text("Quarterly").tag("Quarterly")
                    }
                    .pickerStyle(.menu)
                }

                Section("Upcoming Check-ins") {
                    ForEach(moles) { mole in
                        HStack {
                            Text("Mole \(mole.name)")
                            Spacer()
                            if let dueDate = mole.nextDueDate {
                                Text(dueDate, format: .dateTime.month().day().hour().minute())
                            } else {
                                Text("No date set")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminder")
        }
    }
}