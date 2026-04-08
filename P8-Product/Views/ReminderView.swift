// 
// ReminderView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

struct ReminderView: View {
    @Query(sort: \Person.createdAt) private var persons: [Person]
    @State private var selectedPerson: Person?
    @State private var reminderEnabled = true
    @State private var frequency = "Weekly"
    @State private var slideEdge: Edge = .trailing
    
    var selectedPersonMoles: [Mole] {
        guard let selectedPerson = selectedPerson else { return [] }
        return selectedPerson.moles.sorted { $0.nextDueDate ?? Date.distantFuture < $1.nextDueDate ?? Date.distantFuture }
    }
    
    var body: some View {
        NavigationStack { 
            VStack(spacing: 0) {
                personSelectorView
                Divider()
                
                List {
                    Section("Default Reminder Enabled") {
                        Toggle("Reminder Enabled", isOn: $reminderEnabled)
                            .onChange(of: reminderEnabled) { _, newValue in
                                selectedPerson?.defaultReminderEnabled = newValue
                            }
                    }

                    Section("Default Reminder Frequency") {
                        Picker("Frequency", selection: $frequency) {
                            Text("Weekly").tag("Weekly")
                            Text("Monthly").tag("Monthly")
                            Text("Quarterly").tag("Quarterly")
                        }
                        .pickerStyle(.menu)
                        .disabled(!reminderEnabled)
                        .opacity(reminderEnabled ? 1.0 : 0.4)
                        .onChange(of: frequency) { oldValue, newValue in
                            selectedPerson?.defaultReminderFrequency = newValue
                            let calendar = Calendar.current
                            for mole in selectedPersonMoles {
                                if mole.followDefault ?? true {
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
                                        mole.reminderFrequency = Frequency(rawValue: newValue.lowercased())
                                    }
                                }
                            }
                        }
                    }

                    Section("Upcoming Check-ins") {
                        if selectedPersonMoles.isEmpty {
                            Text("No moles for this person")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(selectedPersonMoles) { mole in
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
                }
                .listStyle(.plain)
            }
            .onAppear {
                if let firstPerson = persons.first, selectedPerson == nil {
                    selectedPerson = firstPerson
                    reminderEnabled = firstPerson.defaultReminderEnabled
                    frequency = displayFrequency(for: firstPerson)
                }
            }
            .onChange(of: persons) { _, newValue in
                if selectedPerson == nil, let first = newValue.first {
                    selectedPerson = first
                    reminderEnabled = first.defaultReminderEnabled
                    frequency = displayFrequency(for: first)
                }
            }
            .onChange(of: selectedPerson) { _, newValue in
                guard let person = newValue else { return }
                reminderEnabled = person.defaultReminderEnabled
                frequency = displayFrequency(for: person)
            }
            .navigationTitle("Reminder")
        }
    }
    
    // Subviews
    
    private var personSelectorView: some View {
        HStack {
            Button(action: selectPreviousPerson) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(selectedPerson == persons.first)
            .opacity(selectedPerson == persons.first ? 0.3 : 1.0)
            
            ZStack {
                if let person = selectedPerson {
                    Text(person.name)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                        .background(Color(.systemGray6))
                        .id(person)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideEdge).combined(with: .opacity),
                            removal: .move(edge: slideEdge == .leading ? .trailing : .leading).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            
            Button(action: selectNextPerson) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(selectedPerson == persons.last)
            .opacity(selectedPerson == persons.last ? 0.3 : 1.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // Helper Functions
    
    private func selectPreviousPerson() {
        guard let current = selectedPerson, let index = persons.firstIndex(of: current), index > 0 else { return }
        slideEdge = .leading
        withAnimation {
            selectedPerson = persons[index - 1]
        }
    }
    
    private func selectNextPerson() {
        guard let current = selectedPerson, let index = persons.firstIndex(of: current), index < persons.count - 1 else { return }
        slideEdge = .trailing
        withAnimation {
            selectedPerson = persons[index + 1]
        }
    }

    private func displayFrequency(for person: Person) -> String {
        switch person.defaultReminderFrequency.lowercased() {
        case "weekly":
            return "Weekly"
        case "monthly":
            return "Monthly"
        case "quarterly":
            return "Quarterly"
        default:
            return "Weekly"
        }
    }
}
