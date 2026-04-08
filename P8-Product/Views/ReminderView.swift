// 
// ReminderView.swift
// P8-Product
//

import SwiftUI
import SwiftData

struct ReminderView: View {
    @Query(sort: \Person.createdAt) private var persons: [Person]
    @State private var selectedPerson: Person?
    @State private var reminderEnabled = true
    @State private var defaultFrequency = "Weekly"
    @State private var slideEdge: Edge = .trailing
    
    private var selectedPersonMoles: [Mole] {
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
                        Picker("Frequency", selection: $defaultFrequency) {
                            Text("Weekly").tag("Weekly")
                            Text("Monthly").tag("Monthly")
                            Text("Quarterly").tag("Quarterly")
                        }
                        .pickerStyle(.menu)
                        .disabled(!reminderEnabled)
                        .opacity(reminderEnabled ? 1.0 : 0.4)
                        .onChange(of: defaultFrequency) { _, newValue in
                            selectedPerson?.defaultReminderFrequency = newValue
                            updateDefaultFrequencyForFollowDefaultMoles()
                        }
                    }

                    Section("Upcoming Check-ins") {
                        if selectedPersonMoles.isEmpty {
                            Text("No moles for this person")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(selectedPersonMoles) { mole in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Mole \(mole.name)")
                                        Spacer()
                                        if let dueDate = mole.nextDueDate {
                                            Text(dueDate, format: .dateTime.month().day().hour().minute())
                                        } else {
                                            Text("No date set")
                                        }
                                    }

                                    Text("Reminder")
                                        .font(.subheadline.weight(.semibold))
                                    reminderModeSelector(for: mole)

                                    Picker("Frequency", selection: frequencyBinding(for: mole)) {
                                        Text("Default").tag("Default")
                                        Text("Weekly").tag("Weekly")
                                        Text("Monthly").tag("Monthly")
                                        Text("Quarterly").tag("Quarterly")
                                    }
                                    .pickerStyle(.menu)
                                    .disabled(!effectiveReminderEnabled(for: mole))
                                    .opacity(effectiveReminderEnabled(for: mole) ? 1.0 : 0.4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .onAppear {
                if selectedPerson == nil {
                    selectedPerson = persons.first
                }
                syncSelectionState()
            }
            .onChange(of: persons) { _, newValue in
                if selectedPerson == nil, let first = newValue.first {
                    selectedPerson = first
                }
                syncSelectionState()
            }
            .onChange(of: selectedPerson) { _, newValue in
                guard newValue != nil else { return }
                syncSelectionState()
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

    private func frequencyBinding(for mole: Mole) -> Binding<String> {
        Binding(
            get: { displayFrequency(for: mole) },
            set: { newValue in
                updateReminder(for: mole, frequencyLabel: newValue)
            }
        )
    }

    private func reminderModeBinding(for mole: Mole) -> Binding<String> {
        Binding(
            get: { reminderMode(for: mole) },
            set: { newValue in
                switch newValue {
                case "Enabled":
                    mole.followDefaultReminderEnabled = false
                    mole.isReminderActive = true
                case "Disabled":
                    mole.followDefaultReminderEnabled = false
                    mole.isReminderActive = false
                default:
                    mole.followDefaultReminderEnabled = true
                }
            }
        )
    }

    private func reminderModeSelector(for mole: Mole) -> some View {
        let selection = reminderModeBinding(for: mole)
        let options = ["Follow Default", "Enabled", "Disabled"]

        return HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selection.wrappedValue == option ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reminderMode(for mole: Mole) -> String {
        if mole.followDefaultReminderEnabled ?? true {
            return "Follow Default"
        }
        return mole.isReminderActive ? "Enabled" : "Disabled"
    }

    private func effectiveReminderEnabled(for mole: Mole) -> Bool {
        if mole.followDefaultReminderEnabled ?? true {
            return reminderEnabled
        }
        return mole.isReminderActive
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

    private func displayFrequency(for mole: Mole) -> String {
        if mole.followDefault ?? true {
            return "Default"
        }

        if let reminderFrequency = mole.reminderFrequency {
            switch reminderFrequency {
            case .weekly:
                return "Weekly"
            case .monthly:
                return "Monthly"
            case .quarterly:
                return "Quarterly"
            }
        }

        return "Default"
    }

    private func updateReminder(for mole: Mole, frequencyLabel: String) {
        if frequencyLabel == "Default" {
            mole.followDefault = true
            mole.reminderFrequency = nil
        } else {
            mole.followDefault = false
            mole.reminderFrequency = Frequency(rawValue: frequencyLabel.lowercased())
        }

        let effectiveFrequencyLabel: String
        if frequencyLabel == "Default", let person = selectedPerson {
            effectiveFrequencyLabel = displayFrequency(for: person)
        } else {
            effectiveFrequencyLabel = frequencyLabel
        }

        let calendar = Calendar.current
        let lastCheckIn = mole.instances.compactMap { $0.moleScan?.captureDate }.max()
        guard let lastCheckIn else { return }

        let nextDueDate: Date?
        switch effectiveFrequencyLabel {
        case "Weekly":
            nextDueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: lastCheckIn)
        case "Monthly":
            nextDueDate = calendar.date(byAdding: .month, value: 1, to: lastCheckIn)
        case "Quarterly":
            nextDueDate = calendar.date(byAdding: .month, value: 3, to: lastCheckIn)
        default:
            nextDueDate = nil
        }

        mole.nextDueDate = max(Date(), nextDueDate ?? Date())
    }

    private func updateDefaultFrequencyForFollowDefaultMoles() {
        for mole in selectedPersonMoles where mole.followDefault ?? true {
            updateReminder(for: mole, frequencyLabel: "Default")
        }
    }

    private func syncSelectionState() {
        guard let person = selectedPerson else { return }
        reminderEnabled = person.defaultReminderEnabled
        defaultFrequency = displayFrequency(for: person)
    }
}
