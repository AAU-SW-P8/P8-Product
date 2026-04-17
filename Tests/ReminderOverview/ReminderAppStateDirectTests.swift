import Foundation
import Testing
import SwiftUI
@testable import P8_Product

@MainActor
@Suite("ReminderAppState direct behavior")
struct ReminderAppStateDirectTests {

    @Test("setDefaultReminderEnabled writes to selected person")
    func setDefaultReminderEnabledUpdatesSelectedPerson() {
        let state = ReminderAppState()
        let person = Person(name: "Alex", defaultReminderEnabled: true)
        state.setSelectedPerson(person)
        defer { state.setSelectedPerson(nil) }

        state.setDefaultReminderEnabled(false)

        #expect(person.defaultReminderEnabled == false)
    }

    @Test("enabling default reminders computes due date for follow-default mole")
    func enablingDefaultRemindersComputesDueDateForFollowDefaultMole() {
        let state = ReminderAppState()
        let person = Person(name: "Alex", defaultReminderFrequency: "Monthly", defaultReminderEnabled: false)
        state.setSelectedPerson(person)
        defer { state.setSelectedPerson(nil) }

        let scanDate = Date(timeIntervalSinceNow: -2 * 24 * 60 * 60)
        let scan = MoleScan(captureDate: scanDate)
        let mole = Mole(
            name: "Segmented Mole",
            bodyPart: "Back",
            isReminderActive: false,
            followDefaultReminderEnabled: true,
            followDefault: true,
            reminderFrequency: nil,
            nextDueDate: nil,
            person: person
        )
        let instance = MoleInstance(diameter: 1, area: 1, mole: mole, moleScan: scan)
        mole.instances = [instance]
        person.moles = [mole]

        state.setDefaultReminderEnabled(true)

        #expect(person.defaultReminderEnabled == true)
        #expect(mole.nextDueDate != nil)
    }

    @Test("setDefaultFrequency writes to selected person")
    func setDefaultFrequencyUpdatesSelectedPerson() {
        let state = ReminderAppState()
        let person = Person(name: "Alex", defaultReminderFrequency: "Weekly")
        state.setSelectedPerson(person)
        defer { state.setSelectedPerson(nil) }

        state.setDefaultFrequency("Monthly")

        #expect(person.defaultReminderFrequency == "Monthly")
    }

    @Test("reminderModeBinding applies Enabled, Disabled and Default")
    func reminderModeBindingAppliesAllModes() {
        let state = ReminderAppState()
        state.reminderEnabled = true
        let mole = Mole(
            name: "Left Arm Mole",
            bodyPart: "Left Arm",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil
        )

        let binding = state.reminderModeBinding(for: mole)

        binding.wrappedValue = "Enabled"
        #expect(mole.followDefaultReminderEnabled == false)
        #expect(mole.isReminderActive == true)

        binding.wrappedValue = "Disabled"
        #expect(mole.followDefaultReminderEnabled == false)
        #expect(mole.isReminderActive == false)

        binding.wrappedValue = "Default"
        #expect(mole.followDefaultReminderEnabled == true)
        #expect(mole.isReminderActive == true)
    }

    @Test("mole enabled override computes due date when default reminders are disabled")
    func moleEnabledOverrideComputesDueDateWhenDefaultDisabled() {
        let state = ReminderAppState()
        let person = Person(name: "Alex", defaultReminderFrequency: "Monthly", defaultReminderEnabled: false)
        state.setSelectedPerson(person)
        defer { state.setSelectedPerson(nil) }

        let scanDate = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)
        let scan = MoleScan(captureDate: scanDate)
        let mole = Mole(
            name: "Override Mole",
            bodyPart: "Back",
            isReminderActive: false,
            followDefaultReminderEnabled: true,
            followDefault: true,
            reminderFrequency: nil,
            nextDueDate: nil,
            person: person
        )
        let instance = MoleInstance(diameter: 1, area: 1, mole: mole, moleScan: scan)
        mole.instances = [instance]
        person.moles = [mole]

        let binding = state.reminderModeBinding(for: mole)
        binding.wrappedValue = "Enabled"

        #expect(mole.followDefaultReminderEnabled == false)
        #expect(mole.isReminderActive == true)
        #expect(mole.nextDueDate != nil)
    }

    @Test("updateReminder with Default uses selected person's frequency")
    func updateReminderDefaultUsesSelectedPersonFrequency() {
        let state = ReminderAppState()
        let person = Person(name: "Alex", defaultReminderFrequency: "Monthly")
        state.setSelectedPerson(person)
        defer { state.setSelectedPerson(nil) }

        let scanDate = Date(timeIntervalSinceNow: -2 * 24 * 60 * 60)
        let scan = MoleScan(captureDate: scanDate)
        let mole = Mole(
            name: "Back Mole",
            bodyPart: "Back",
            isReminderActive: true,
            reminderFrequency: .weekly,
            nextDueDate: nil,
            person: person
        )
        let instance = MoleInstance(diameter: 1, area: 1, mole: mole, moleScan: scan)
        mole.instances = [instance]

        state.updateReminder(for: mole, frequencyLabel: "Default")

        #expect(mole.followDefault == true)
        #expect(mole.reminderFrequency == nil)
        #expect(mole.nextDueDate != nil)
    }
}
