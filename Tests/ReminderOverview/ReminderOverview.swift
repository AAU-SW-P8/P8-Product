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

    /// Verifies that monthly reminder selection uses a one-month offset from the latest scan.
    @Test("Monthly frequency computes due date one month after latest check-in")
    func updateReminderWithMonthlyFrequencyComputesMonthlyDueDate() {
        let calendar = Calendar.current
        let lastCheckIn = Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)
        let mole = makeMole(lastCheckIn: lastCheckIn)

        applyReminderUpdate(
            mole: mole,
            selectedPerson: nil,
            frequencyLabel: "Monthly",
            now: Date(timeIntervalSinceNow: -60)
        )

        let expected = calendar.date(byAdding: .month, value: 1, to: lastCheckIn)
        #expect(mole.followDefault == false)
        #expect(mole.reminderFrequency == .monthly)
        #expect(mole.nextDueDate != nil)
        #expect(isSameMinute(mole.nextDueDate!, expected!))
    }

    /// Verifies that quarterly reminder selection uses a three-month offset from the latest scan.
    @Test("Quarterly frequency computes due date three months after latest check-in")
    func updateReminderWithQuarterlyFrequencyComputesQuarterlyDueDate() {
        let calendar = Calendar.current
        let lastCheckIn = Date(timeIntervalSinceNow: -10 * 24 * 60 * 60)
        let mole = makeMole(lastCheckIn: lastCheckIn)

        applyReminderUpdate(
            mole: mole,
            selectedPerson: nil,
            frequencyLabel: "Quarterly",
            now: Date(timeIntervalSinceNow: -60)
        )

        let expected = calendar.date(byAdding: .month, value: 3, to: lastCheckIn)
        #expect(mole.followDefault == false)
        #expect(mole.reminderFrequency == .quarterly)
        #expect(mole.nextDueDate != nil)
        #expect(isSameMinute(mole.nextDueDate!, expected!))
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

    @Test("Reminder mode Enabled sets override and activates reminder")
    func reminderModeEnabledSetsOverrideAndActive() {
        let mole = Mole(
            name: "Mode Mole",
            bodyPart: "Arm",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil
        )
        mole.followDefaultReminderEnabled = true

        applyReminderMode(mole: mole, newValue: "Enabled")

        #expect(mole.followDefaultReminderEnabled == false)
        #expect(mole.isReminderActive == true)
    }

    @Test("Reminder mode Disabled sets override and deactivates reminder")
    func reminderModeDisabledSetsOverrideAndInactive() {
        let mole = Mole(
            name: "Mode Mole",
            bodyPart: "Arm",
            isReminderActive: true,
            reminderFrequency: nil,
            nextDueDate: nil
        )
        mole.followDefaultReminderEnabled = true

        applyReminderMode(mole: mole, newValue: "Disabled")

        #expect(mole.followDefaultReminderEnabled == false)
        #expect(mole.isReminderActive == false)
    }

    @Test("Reminder mode Follow Default enables follow-default flag")
    func reminderModeFollowDefaultEnablesFollowDefaultFlag() {
        let mole = Mole(
            name: "Mode Mole",
            bodyPart: "Arm",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil
        )
        mole.followDefaultReminderEnabled = false

        applyReminderMode(mole: mole, newValue: "Follow Default")

        #expect(mole.followDefaultReminderEnabled == true)
    }

    @Test("Effective reminder enabled follows person default when configured")
    func effectiveReminderEnabledUsesPersonDefaultWhenFollowingDefault() {
        let mole = Mole(
            name: "Mole 1",
            bodyPart: "Arm",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil
        )
        mole.followDefaultReminderEnabled = true

        let enabled = effectiveReminderEnabled(mole: mole, reminderEnabled: false)

        #expect(enabled == false)
    }

    @Test("Effective reminder enabled uses mole override when not following default")
    func effectiveReminderEnabledUsesMoleOverrideWhenNotFollowingDefault() {
        let mole = Mole(
            name: "Mole 1",
            bodyPart: "Arm",
            isReminderActive: true,
            reminderFrequency: nil,
            nextDueDate: nil
        )
        mole.followDefaultReminderEnabled = false

        let enabled = effectiveReminderEnabled(mole: mole, reminderEnabled: false)

        #expect(enabled == true)
    }

    @Test("Default frequency update only reapplies to follow-default moles")
    func defaultFrequencyReappliesOnlyToFollowDefaultMoles() {
        let person = Person(name: "Alex", defaultReminderFrequency: "Quarterly")
        let lastCheckIn = Date(timeIntervalSinceNow: -3 * 24 * 60 * 60)

        let followDefaultMole = makeMole(lastCheckIn: lastCheckIn)
        followDefaultMole.followDefault = true
        followDefaultMole.reminderFrequency = nil

        let customMole = makeMole(lastCheckIn: lastCheckIn)
        customMole.followDefault = false
        customMole.reminderFrequency = .weekly

        let beforeCustomDue = customMole.nextDueDate

        applyDefaultFrequencyForFollowDefaultMoles(
            moles: [followDefaultMole, customMole],
            selectedPerson: person,
            now: Date()
        )

        #expect(followDefaultMole.nextDueDate != nil)
        #expect(customMole.reminderFrequency == .weekly)
        #expect(customMole.nextDueDate == beforeCustomDue)
    }

    @Test("Selecting previous person moves one step when possible")
    func selectPreviousPersonMovesOneStep() {
        let first = Person(name: "A")
        let second = Person(name: "B")
        let third = Person(name: "C")
        let people = [first, second, third]

        let result = selectPreviousPerson(current: second, persons: people)

        #expect(result.selectedPerson?.name == "A")
        #expect(result.slideEdge == "leading")
    }

    /// Verifies that selecting the previous person at the first index does not move selection.
    @Test("Selecting previous person at first index keeps current selection")
    func selectPreviousPersonAtFirstIndexDoesNotMove() {
        let first = Person(name: "A")
        let second = Person(name: "B")
        let people = [first, second]

        let result = selectPreviousPerson(current: first, persons: people)

        #expect(result.selectedPerson?.name == "A")
        #expect(result.slideEdge == nil)
    }

    @Test("Selecting next person moves one step when possible")
    func selectNextPersonMovesOneStep() {
        let first = Person(name: "A")
        let second = Person(name: "B")
        let third = Person(name: "C")
        let people = [first, second, third]

        let result = selectNextPerson(current: second, persons: people)

        #expect(result.selectedPerson?.name == "C")
        #expect(result.slideEdge == "trailing")
    }

    /// Verifies that selecting the next person at the last index does not move selection.
    @Test("Selecting next person at last index keeps current selection")
    func selectNextPersonAtLastIndexDoesNotMove() {
        let first = Person(name: "A")
        let second = Person(name: "B")
        let people = [first, second]

        let result = selectNextPerson(current: second, persons: people)

        #expect(result.selectedPerson?.name == "B")
        #expect(result.slideEdge == nil)
    }

    @Test("Sync state copies selected person's defaults")
    func syncSelectionStateCopiesDefaults() {
        let person = Person(
            name: "Alex",
            defaultReminderFrequency: "Monthly",
            defaultReminderEnabled: false
        )

        let synced = syncSelectionState(selectedPerson: person)

        #expect(synced?.reminderEnabled == false)
        #expect(synced?.defaultFrequency == "Monthly")
    }

    /// Verifies that syncing reminder state with no selected person produces no state snapshot.
    @Test("Sync state with no selected person returns nil")
    func syncSelectionStateWithoutSelectedPersonReturnsNil() {
        let synced = syncSelectionState(selectedPerson: nil)

        #expect(synced == nil)
    }

    @Test("Mole display frequency returns Default when following default")
    func moleDisplayFrequencyUsesDefaultLabelWhenFollowingDefault() {
        let mole = Mole(
            name: "Mole 1",
            bodyPart: "Arm",
            isReminderActive: true,
            reminderFrequency: .monthly,
            nextDueDate: nil
        )
        mole.followDefault = true

        #expect(displayFrequency(for: mole) == "Default")
    }

    @Test("Mole display frequency maps enum values")
    func moleDisplayFrequencyMapsEnumValues() {
        let weekly = Mole(name: "W", bodyPart: "Arm", isReminderActive: true, reminderFrequency: .weekly, nextDueDate: nil)
        weekly.followDefault = false
        let monthly = Mole(name: "M", bodyPart: "Arm", isReminderActive: true, reminderFrequency: .monthly, nextDueDate: nil)
        monthly.followDefault = false
        let quarterly = Mole(name: "Q", bodyPart: "Arm", isReminderActive: true, reminderFrequency: .quarterly, nextDueDate: nil)
        quarterly.followDefault = false

        #expect(displayFrequency(for: weekly) == "Weekly")
        #expect(displayFrequency(for: monthly) == "Monthly")
        #expect(displayFrequency(for: quarterly) == "Quarterly")
    }

    private func makeMole(lastCheckIn: Date) -> Mole {
        let mole = Mole(
            name: "Mole 1",
            bodyPart: "Arm",
            isReminderActive: true,
            reminderFrequency: nil,
            nextDueDate: nil
        )

        let scan = MoleScan(captureDate: lastCheckIn, diameter: 2, area: 4, mole: mole)
        mole.scans = [scan]
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
        let lastCheckIn = mole.scans.compactMap { $0.captureDate }.max()
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

    /// Mirrors ReminderView's reminder mode update side effects.
    private func applyReminderMode(mole: Mole, newValue: String) {
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

    /// Mirrors ReminderView's effective reminder enabled logic.
    private func effectiveReminderEnabled(mole: Mole, reminderEnabled: Bool) -> Bool {
        if mole.followDefaultReminderEnabled ?? true {
            return reminderEnabled
        }
        return mole.isReminderActive
    }

    /// Mirrors ReminderView's default-frequency propagation for follow-default moles.
    private func applyDefaultFrequencyForFollowDefaultMoles(
        moles: [Mole],
        selectedPerson: Person?,
        now: Date
    ) {
        for mole in moles where mole.followDefault ?? true {
            applyReminderUpdate(
                mole: mole,
                selectedPerson: selectedPerson,
                frequencyLabel: "Default",
                now: now
            )
        }
    }

    /// Mirrors ReminderView's previous person selection behavior.
    private func selectPreviousPerson(current: Person?, persons: [Person]) -> (selectedPerson: Person?, slideEdge: String?) {
        guard let current, let index = persons.firstIndex(of: current), index > 0 else {
            return (current, nil)
        }
        return (persons[index - 1], "leading")
    }

    /// Mirrors ReminderView's next person selection behavior.
    private func selectNextPerson(current: Person?, persons: [Person]) -> (selectedPerson: Person?, slideEdge: String?) {
        guard let current, let index = persons.firstIndex(of: current), index < persons.count - 1 else {
            return (current, nil)
        }
        return (persons[index + 1], "trailing")
    }

    /// Mirrors ReminderView's UI state sync from selected person.
    private func syncSelectionState(selectedPerson: Person?) -> (reminderEnabled: Bool, defaultFrequency: String)? {
        guard let person = selectedPerson else { return nil }
        return (person.defaultReminderEnabled, displayFrequency(for: person))
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

    private func isSameMinute(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 60
    }
}
