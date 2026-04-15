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
                Section(NSLocalizedString("reminder.section.frequency", tableName: "Localizable", bundle: .main, value: "Reminder Frequency", comment: "Section title for reminder frequency")) {
                    LabeledContent(NSLocalizedString("reminder.frequency.label", tableName: "Localizable", bundle: .main, value: "Frequency", comment: "Frequency label"), value: NSLocalizedString("reminder.frequency.daily", tableName: "Localizable", bundle: .main, value: "Daily", comment: "Daily frequency value"))
                }

                Section(NSLocalizedString("reminder.section.upcoming", tableName: "Localizable", bundle: .main, value: "Upcoming Check-ins", comment: "Section title for upcoming check-ins")) {
                    LabeledContent(String(format: NSLocalizedString("reminder.imageId.format", tableName: "Localizable", bundle: .main, value: "Image ID: %d", comment: "Format for image ID label"), 101)) {
                        Text(Date(), format: .dateTime.month().day().hour().minute())
                    }
                    LabeledContent(String(format: NSLocalizedString("reminder.imageId.format", tableName: "Localizable", bundle: .main, value: "Image ID: %d", comment: "Format for image ID label"), 102)) {
                        Text(Date().addingTimeInterval(86400), format: .dateTime.month().day().hour().minute())
                    }
                }
            }
            .navigationTitle(NSLocalizedString("reminder.nav.title", tableName: "Localizable", bundle: .main, value: "Reminder", comment: "Reminder navigation title"))
        }
    }
}
