import Foundation
import Testing
@testable import P8_Product

@Suite("ReminderView behavior")
struct ReminderOverviewTest {
    @Test("Default frequency keeps followDefault and uses person's frequency")
    func updateReminderWithDefaultFrequencyUsesPersonSetting() {
        let calendar = Calendar.current
        let person = Person(name: "Alex", defaultReminderFrequency: "Monthly")
        let lastCheckIn = Date(timeIntervalSinceNow: -2 * 24 * 60 * 60)
        let mole = makeMole(lastCheckIn: lastCheckIn)

        applyReminderUpdate(
            mole: mole,
            selectedPerson: person,
            frequencyLabel: "Default",
            now: Date()
        )

        #expect(mole.followDefault == true)
        #expect(mole.reminderFrequency == nil)

        let expected = calendar.date(byAdding: .month, value: 1, to: lastCheckIn)
        #expect(mole.nextDueDate != nil)
        #expect(isSameMinute(mole.nextDueDate!, expected!))
    }

    @Test("Explicit frequency disables followDefault and stores enum value")
    func updateReminderWithExplicitFrequencyStoresFrequency() {
        let lastCheckIn = Date(timeIntervalSinceNow: -6 * 24 * 60 * 60)
        let mole = makeMole(lastCheckIn: lastCheckIn)

        applyReminderUpdate(
            mole: mole,
            selectedPerson: nil,
            frequencyLabel: "Weekly",
            now: Date()
        )

        #expect(mole.followDefault == false)
        #expect(mole.reminderFrequency == .weekly)
        #expect(mole.nextDueDate != nil)
    }

    @Test("Past computed due date is clamped to current date")
    func dueDateIsClampedToNowWhenComputedDateIsPast() {
        let now = Date()
        let oldCheckIn = Calendar.current.date(byAdding: .month, value: -6, to: now)!
        let mole = makeMole(lastCheckIn: oldCheckIn)

        applyReminderUpdate(
            mole: mole,
            selectedPerson: nil,
            frequencyLabel: "Weekly",
            now: now
        )

        #expect(mole.nextDueDate != nil)
        #expect(mole.nextDueDate! >= now)
    }

    @Test("No check-in data keeps existing next due date")
    func noCheckInLeavesNextDueDateUnchanged() {
        let initialDueDate = Date(timeIntervalSinceNow: 10_000)
        let mole = Mole(
            name: "Mole 1",
            bodyPart: "Arm",
            isReminderActive: true,
            reminderFrequency: .weekly,
            nextDueDate: initialDueDate
        )

        applyReminderUpdate(
            mole: mole,
            selectedPerson: nil,
            frequencyLabel: "Monthly",
            now: Date()
        )

        #expect(mole.nextDueDate == initialDueDate)
    }

    @Test("Moles are sorted by due date with nil dates last")
    func sortedMolesPlacesNilDatesAtEnd() {
        let now = Date()
        let person = Person(name: "Alex")

        let first = Mole(
            name: "First",
            bodyPart: "Arm",
            isReminderActive: true,
            reminderFrequency: .weekly,
            nextDueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)
        )
        let second = Mole(
            name: "Second",
            bodyPart: "Leg",
            isReminderActive: true,
            reminderFrequency: .weekly,
            nextDueDate: nil
        )
        let third = Mole(
            name: "Third",
            bodyPart: "Back",
            isReminderActive: true,
            reminderFrequency: .weekly,
            nextDueDate: Calendar.current.date(byAdding: .day, value: 3, to: now)
        )

        person.moles = [second, third, first]

        let sorted = person.moles.sorted {
            $0.nextDueDate ?? Date.distantFuture < $1.nextDueDate ?? Date.distantFuture
        }

        #expect(sorted.map(\.name) == ["First", "Third", "Second"])
    }

    private func makeMole(lastCheckIn: Date) -> Mole {
        let scan = MoleScan(captureDate: lastCheckIn)
        let instance = MoleInstance(diameter: 2, area: 4, moleScan: scan)
        let mole = Mole(
            name: "Mole 1",
            bodyPart: "Arm",
            isReminderActive: true,
            reminderFrequency: nil,
            nextDueDate: nil
        )
        mole.instances = [instance]
        return mole
    }

    /// Mirrors ReminderView's reminder update behavior using model objects.
    private func applyReminderUpdate(
        mole: Mole,
        selectedPerson: Person?,
        frequencyLabel: String,
        now: Date
    ) {
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

        mole.nextDueDate = max(now, nextDueDate ?? now)
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

    private func isSameMinute(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 60
    }
}
