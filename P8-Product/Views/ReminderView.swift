// 
// ReminderView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

struct ReminderView: View {
    @Query(sort: \Mole.nextDueDate) private var moles: [Mole]
    @State private var frequency = "Weekly"
    
    var body: some View {
        NavigationStack { 
            List {
                Section("Reminder Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        Text("Weekly").tag("Weekly")
                        Text("Monthly").tag("Monthly")
                        Text("Quarterly").tag("Quarterly")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: frequency) { oldValue, newValue in
                        let calendar = Calendar.current
                        for mole in moles {
                            if mole.followDefault == true {
                                let lastCheckIn = mole.instances.compactMap { $0.moleScan?.captureDate }.max()
                                if let lastCheckIn = lastCheckIn {
                                    var nextDueDate: Date?
                                    switch newValue {
                                    case "Weekly":
                                        nextDueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: lastCheckIn)
                                    case "Monthly":
                                        nextDueDate = calendar.date(byAdding: .month, value: 1, to: lastCheckIn)
                                    case "Quarterly":
                                        nextDueDate = calendar.date(byAdding: .month, value: 3, to: lastCheckIn)
                                    default:
                                        break
                                    }
                                    nextDueDate = max(Date(), nextDueDate ?? Date())
                                    mole.nextDueDate = nextDueDate
                                    mole.reminderFrequency = newValue
                                }
                            }
                        }
                    }
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