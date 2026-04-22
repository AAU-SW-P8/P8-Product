// 
// ReminderView.swift
// P8-Product
//

import SwiftUI
import SwiftData

struct ReminderView: View {
    
    @State private var appState = ReminderAppState()
    @Query(sort: \Person.createdAt) var people: [Person]

    /**
     The list of moles for the currently selected person, sorted by the next due date with nils at the end.
     */
    private var selectedPersonMoles: [Mole] {
        guard let selectedPerson = appState.selectedPerson else { return [] }
        return selectedPerson.moles.sorted { $0.nextDueDate ?? Date.distantFuture < $1.nextDueDate ?? Date.distantFuture }
    }
    
    var body: some View {
        NavigationStack { 
            VStack(spacing: 0) {
                personSelectorView
                Divider()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        sectionContainer(title: "Default Reminder Enabled") {
                            HStack {
                                Text("Reminder Enabled")
                                Spacer()
                                Toggle("", isOn: $appState.reminderEnabled)
                                    .labelsHidden()
                                    .accessibilityIdentifier("defaultReminderEnabledToggle")
                                    .accessibilityLabel("Default Reminder Enabled")
                            }
                            .onChange(of: appState.reminderEnabled) { _, newValue in
                                appState.setDefaultReminderEnabled(newValue)
                            }
                        }

                        sectionContainer(title: "Default Reminder Frequency") {
                            Picker("Frequency", selection: $appState.defaultFrequency) {
                                Text("Weekly").tag("Weekly")
                                Text("Monthly").tag("Monthly")
                                Text("Quarterly").tag("Quarterly")
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("defaultReminderFrequencyPicker")
                            .onChange(of: appState.defaultFrequency) { _, newValue in
                                appState.setDefaultFrequency(newValue)
                                updateFrequencyFollowDefaultMoles()
                            }
                        }

                        sectionContainer(title: "Upcoming Check-ins") {
                            if selectedPersonMoles.isEmpty {
                                Text("No moles for this person")
                                    .foregroundColor(.gray)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(selectedPersonMoles) { mole in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Mole \(mole.name)")
                                                Spacer()
                                                if let dueDate = mole.nextDueDate {
                                                    Text(dueDate, format: .dateTime.month().day().hour().minute())
                                                        .accessibilityIdentifier("moleDueDateLabel_\(mole.name)")
                                                } else {
                                                    Text("No date set")
                                                        .accessibilityIdentifier("moleDueDateLabel_\(mole.name)")
                                                }
                                            }

                                            HStack {
                                                Text("Reminder Enabled")
                                                    .font(.subheadline.weight(.semibold))
                                                Picker("Reminder Mode", selection: appState.reminderModeBinding(for: mole)) {
                                                    Text("Default").tag("Default")
                                                    Text("Enabled").tag("Enabled")
                                                    Text("Disabled").tag("Disabled")
                                                }
                                                .pickerStyle(.menu)
                                                .accessibilityIdentifier("moleReminderEnabledPicker_\(mole.name)")
                                            }

                                            HStack {
                                                Text("Reminder Frequency")
                                                    .font(.subheadline.weight(.semibold))
                                                Picker("Frequency", selection: frequencyBinding(for: mole)) {
                                                    Text("Default").tag("Default")
                                                    Text("Weekly").tag("Weekly")
                                                    Text("Monthly").tag("Monthly")
                                                    Text("Quarterly").tag("Quarterly")
                                                }
                                                .pickerStyle(.menu)
                                                .accessibilityIdentifier("moleReminderFrequencyPicker_\(mole.name)")
                                                .disabled(!effectiveReminderEnabled(for: mole))
                                                .opacity(effectiveReminderEnabled(for: mole) ? 1.0 : 0.4)
                                            }
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                if appState.selectedPerson == nil {
                    appState.setSelectedPerson(people.first)
                }
                appState.syncSelectionState()
            }
            .onChange(of: people) { _, newValue in
                if appState.selectedPerson == nil, let first = newValue.first {
                    appState.setSelectedPerson(first)
                }
                appState.syncSelectionState()
            }
            .onChange(of: appState.selectedPerson) { _, newValue in
                guard newValue != nil else { return }
                appState.syncSelectionState()
            }
        }
    }
    
    // MARK: -Subviews
    
    /**
     A custom person selector that allows navigating between different people in the database.
     It shows the name of the currently selected person and has left/right buttons to switch between them.
     */
    private var personSelectorView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reminder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            .background(Color(.systemGray6))
            
            HStack {
                Button(action: { appState.selectPreviousPerson(from: people) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .disabled(appState.selectedPerson == people.first)
                .opacity(appState.selectedPerson == people.first ? 0.3 : 1.0)

                ZStack {
                    if let person = appState.selectedPerson {
                        Text(person.name)
                            .font(.system(size: 18, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                            .background(Color(.systemGray6))
                            .id(person)
                            .transition(.asymmetric(
                                insertion: .move(edge: appState.slideEdge).combined(with: .opacity),
                                removal: .move(edge: appState.slideEdge == .leading ? .trailing : .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
                
                Button(action: { appState.selectNextPerson(from: people) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .disabled(appState.selectedPerson == people.last)
                .opacity(appState.selectedPerson == people.last ? 0.3 : 1.0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }



    private func sectionContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: -Helper Functions

    /**
     Creates a two-way binding between a mole and the frequency label used by the picker.

     - Parameter mole: The mole whose frequency setting should be read and updated.
     - Returns: A `Binding<String>` used by the per-mole frequency picker.
     */
    private func frequencyBinding(for mole: Mole) -> Binding<String> {
        Binding(
            get: { displayFrequency(for: mole) },
            set: { newValue in
                appState.updateReminder(for: mole, frequencyLabel: newValue)
            }
        )
    }

    /**
     Builds the one-line reminder mode selector for a mole.

     - Parameter mole: The mole for which the selector is rendered.
     - Returns: A view containing the three reminder mode options.
     */
    private func reminderModeSelector(for mole: Mole) -> some View {
        let selection = appState.reminderModeBinding(for: mole)
        let options = ["Default", "Enabled", "Disabled"]

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

    /**
     Calculates whether reminders are effectively enabled for a mole.

     - Parameter mole: The mole whose effective enabled state is needed.
     - Returns: `true` if reminders are enabled after applying default/override logic.
     */
    private func effectiveReminderEnabled(for mole: Mole) -> Bool {
        if mole.followDefaultReminderEnabled ?? true {
            return appState.reminderEnabled
        }
        return mole.isReminderActive
    }

    /**
     Converts a mole's reminder frequency state to the picker label.

     - Parameter mole: The mole whose frequency selection is displayed.
     - Returns: `Default`, `Weekly`, `Monthly`, or `Quarterly`.
     */
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

    /**
     Reapplies default frequency logic to all moles that follow defaults.
     */
    private func updateFrequencyFollowDefaultMoles() {
        for mole in selectedPersonMoles where mole.followDefault ?? true {
            appState.updateReminder(for: mole, frequencyLabel: "Default")
        }
    }
}
