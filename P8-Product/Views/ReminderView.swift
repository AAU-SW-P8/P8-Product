// 
// ReminderView.swift
// P8-Product
//

import SwiftUI
import SwiftData

struct ReminderView: View {
    
    @State private var appState = ReminderAppState(dataController: .shared)
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
                            Toggle("Reminder Enabled", isOn: $appState.reminderEnabled)
                                .onChange(of: appState.reminderEnabled) { _, newValue in
                                    appState.selectedPerson?.defaultReminderEnabled = newValue
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
                            .disabled(!appState.reminderEnabled)
                            .opacity(appState.reminderEnabled ? 1.0 : 0.4)
                            .onChange(of: appState.defaultFrequency) { _, newValue in
                                appState.selectedPerson?.defaultReminderFrequency = newValue
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
                                                } else {
                                                    Text("No date set")
                                                }
                                            }

                                            Text("Reminder Enabled")
                                                .font(.subheadline.weight(.semibold))
                                            reminderModeSelector(for: mole)

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
                    appState.selectedPerson = people.first
                }
                appState.syncSelectionState()
            }
            .onChange(of: people) { _, newValue in
                if appState.selectedPerson == nil, let first = newValue.first {
                    appState.selectedPerson = first
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
            .padding(.bottom, 4)
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
                updateReminder(for: mole, frequencyLabel: newValue)
            }
        )
    }
    /**
     Creates a two-way binding for the reminder mode segmented options.

     - Parameter mole: The mole whose reminder mode should be read and updated.
     - Returns: A `Binding<String>` for `Follow Default`, `Enabled`, or `Disabled`.
     */
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

    /**
     Builds the one-line reminder mode selector for a mole.

     - Parameter mole: The mole for which the selector is rendered.
     - Returns: A view containing the three reminder mode options.
     */
    private func reminderModeSelector(for mole: Mole) -> some View {
        let selection = reminderModeBinding(for: mole)
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
     Resolves the current reminder mode label for a mole.

     - Parameter mole: The mole whose reminder mode should be evaluated.
     - Returns: `Follow Default`, `Enabled`, or `Disabled`.
     */
    private func reminderMode(for mole: Mole) -> String {
        if mole.followDefaultReminderEnabled ?? true {
            return "Follow Default"
        }
        return mole.isReminderActive ? "Enabled" : "Disabled"
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
         Updates a mole's reminder configuration and recalculates next due date.

         - Parameters:
             - mole: The mole being updated.
             - frequencyLabel: The selected frequency label (`Default`, `Weekly`, `Monthly`, or `Quarterly`).
         */
    private func updateReminder(for mole: Mole, frequencyLabel: String) {
        if frequencyLabel == "Default" {
            mole.followDefault = true
            mole.reminderFrequency = nil
        } else {
            mole.followDefault = false
            mole.reminderFrequency = Frequency(rawValue: frequencyLabel.lowercased())
        }

        let effectiveFrequencyLabel: String
        if frequencyLabel == "Default", let person = appState.selectedPerson {
            effectiveFrequencyLabel = appState.displayFrequency(for: person)
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

    /**
     Reapplies default frequency logic to all moles that follow defaults.
     */
    private func updateFrequencyFollowDefaultMoles() {
        for mole in selectedPersonMoles where mole.followDefault ?? true {
            updateReminder(for: mole, frequencyLabel: "Default")
        }
    }
}
