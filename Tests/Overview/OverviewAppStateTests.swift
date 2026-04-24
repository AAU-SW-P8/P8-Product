import Foundation
import Testing
@testable import P8_Product

@MainActor
@Suite("OverviewAppState filtering and navigation")
struct OverviewAppStateTests {

    private func makeState() -> OverviewAppState {
        OverviewAppState(dataController: .shared)
    }

    private func makeMole(
        name: String,
        bodyPart: String,
        captureDates: [Date],
        person: Person
    ) -> Mole {
        let mole = Mole(
            name: name,
            bodyPart: bodyPart,
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil,
            person: person
        )

        let scans: [MoleScan] = captureDates.map { date in
            return MoleScan(captureDate: date, diameter: 1, area: 1, mole: mole)
        }
        mole.scans = scans
        return mole
    }

    @Test("available body parts are unique and sorted")
    func availableBodyPartsAreUniqueAndSorted() {
        let state = makeState()
        let person = Person(name: "Alex")
        person.moles = [
            Mole(name: "A", bodyPart: "Back", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "B", bodyPart: "Arm", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
        ]

        let parts = state.availableBodyParts(for: person)

        #expect(parts == ["Arm", "Back"])
    }

    @Test("displayed moles filter by selected body parts")
    func displayedMolesFilterByBodyPart() {
        let state = makeState()
        let person = Person(name: "Alex")
        person.moles = [
            Mole(name: "Back One", bodyPart: "Back", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "Arm One", bodyPart: "Arm", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person)
        ]
        
        let filtered = state.displayedMoles(
            for: person,
            selectedBodyParts: ["Back"],
            sortOption: .alphabetical
        )

        #expect(filtered.map(\.name) == ["Back One"])
        #expect(filtered.map(\.name).contains("Arm One") == false)

    }

    @Test("displayed moles update as selected body-part filters change")
    func displayedMolesUpdateWhenChangingSelectedBodyParts() {
        let state = makeState()
        let person = Person(name: "Alex")
        person.moles = [
            Mole(name: "Back One", bodyPart: "Back", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "Arm One", bodyPart: "Arm", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "Leg One", bodyPart: "Leg", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person)
        ]

        var selectedBodyParts: Set<String> = []

        let initialAll = state.displayedMoles(
            for: person,
            selectedBodyParts: selectedBodyParts,
            sortOption: .alphabetical
        )
        #expect(initialAll.map(\.name) == ["Arm One", "Back One", "Leg One"])

        selectedBodyParts = ["Back"]
        let backOnly = state.displayedMoles(
            for: person,
            selectedBodyParts: selectedBodyParts,
            sortOption: .alphabetical
        )
        #expect(backOnly.map(\.name) == ["Back One"])

        selectedBodyParts.insert("Arm")
        let backAndArm = state.displayedMoles(
            for: person,
            selectedBodyParts: selectedBodyParts,
            sortOption: .alphabetical
        )
        #expect(backAndArm.map(\.name) == ["Arm One", "Back One"])

        selectedBodyParts = ["Arm"]
        let armOnly = state.displayedMoles(
            for: person,
            selectedBodyParts: selectedBodyParts,
            sortOption: .alphabetical
        )
        #expect(armOnly.map(\.name) == ["Arm One"])

        selectedBodyParts = []
        let clearedFilters = state.displayedMoles(
            for: person,
            selectedBodyParts: selectedBodyParts,
            sortOption: .alphabetical
        )
        #expect(clearedFilters.map(\.name) == ["Arm One", "Back One", "Leg One"])
    }

    @Test("displayed moles sort alphabetically regardless of case")
    func displayedMolesSortAlphabetically() {
        let state = makeState()
        let person = Person(name: "Alex")
        person.moles = [
            Mole(name: "zeta", bodyPart: "Back", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "Alpha", bodyPart: "Back", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "beta", bodyPart: "Back", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person)
        ]

        let sorted = state.displayedMoles(
            for: person,
            selectedBodyParts: [],
            sortOption: .alphabetical
        )

        #expect(sorted.map(\.name) == ["Alpha", "beta", "zeta"])
    }

    @Test("displayed moles sort by most recent scan and put no-scan moles last")
    func displayedMolesSortByRecentScan() {
        let state = makeState()
        let person = Person(name: "Alex")

        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        let oldMole = makeMole(name: "Old", bodyPart: "Back", captureDates: [day10], person: person)
        let newMole = makeMole(name: "New", bodyPart: "Back", captureDates: [day20], person: person)
        let noScanMole = makeMole(name: "No Scan", bodyPart: "Back", captureDates: [], person: person)
        let veryOldMole = makeMole(name: "Very Old", bodyPart: "Back", captureDates: [day0], person: person)

        person.moles = [oldMole, newMole, noScanMole, veryOldMole]

        let sorted = state.displayedMoles(
            for: person,
            selectedBodyParts: [],
            sortOption: .recent
        )

        #expect(sorted.map(\.name) == ["New", "Old", "Very Old", "No Scan"])
    }

    @Test("displayed moles with multi-select body parts includes all selected parts")
    func displayedMolesFilterByMultipleBodyParts() {
        let state = makeState()
        let person = Person(name: "Alex")
        person.moles = [
            Mole(name: "Back One", bodyPart: "Back", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "Arm One", bodyPart: "Arm", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "Leg One", bodyPart: "Leg", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person)
        ]

        let filtered = state.displayedMoles(
            for: person,
            selectedBodyParts: ["Back", "Leg"],
            sortOption: .alphabetical
        )

        #expect(filtered.map(\.name) == ["Back One", "Leg One"])
    }

    @Test("displayed moles returns empty when selected body part has no matches")
    func displayedMolesReturnsEmptyForNoMatchingBodyParts() {
        let state = makeState()
        let person = Person(name: "Alex")
        person.moles = [
            Mole(name: "Back One", bodyPart: "Back", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person),
            Mole(name: "Arm One", bodyPart: "Arm", isReminderActive: false, reminderFrequency: nil, nextDueDate: nil, person: person)
        ]

        let filtered = state.displayedMoles(
            for: person,
            selectedBodyParts: ["Chest"],
            sortOption: .alphabetical
        )

        #expect(filtered.isEmpty)
    }

    @Test("latestScan returns newest scan for mole")
    func latestScanReturnsNewestScan() {
        let state = makeState()
        let person = Person(name: "Alex")

        let day0 = Date(timeIntervalSince1970: 1_700_000_000)
        let day10 = day0.addingTimeInterval(10 * 86_400)
        let day20 = day0.addingTimeInterval(20 * 86_400)

        let mole = makeMole(name: "Back", bodyPart: "Back", captureDates: [day0, day20, day10], person: person)

        #expect(state.latestScan(for: mole)?.captureDate == day20)
    }

    @Test("latestScan returns nil for mole with no scans")
    func latestScanReturnsNilWhenNoScansExist() {
        let state = makeState()
        let person = Person(name: "Alex")
        let mole = makeMole(name: "Back", bodyPart: "Back", captureDates: [], person: person)

        #expect(state.latestScan(for: mole) == nil)
    }

    @Test("initialize selection picks first person when none is selected")
    func initializeSelectionPicksFirstPerson() {
        let state = makeState()
        state.selectedPerson = nil

        let first = Person(name: "First")
        let second = Person(name: "Second")

        state.initializeSelectionIfNeeded(with: [first, second])

        #expect(state.selectedPerson == first)
    }

    @Test("initialize selection does not override existing selection")
    func initializeSelectionDoesNotOverrideExistingSelection() {
        let state = makeState()
        let first = Person(name: "First")
        let second = Person(name: "Second")
        state.selectedPerson = second

        state.initializeSelectionIfNeeded(with: [first, second])

        #expect(state.selectedPerson == second)
    }

    @Test("select next and previous person updates selection")
    func selectNextAndPreviousPerson() {
        let state = makeState()
        let first = Person(name: "First")
        let second = Person(name: "Second")
        let people = [first, second]
        state.selectedPerson = first

        state.selectNextPerson(from: people)
        #expect(state.selectedPerson == second)

        state.selectPreviousPerson(from: people)
        #expect(state.selectedPerson == first)
    }

    @Test("select next at end and previous at start keep selection unchanged")
    func selectNextAndPreviousRespectBounds() {
        let state = makeState()
        let first = Person(name: "First")
        let second = Person(name: "Second")
        let people = [first, second]

        state.selectedPerson = second
        state.selectNextPerson(from: people)
        #expect(state.selectedPerson == second)

        state.selectedPerson = first
        state.selectPreviousPerson(from: people)
        #expect(state.selectedPerson == first)
    }

    @Test("selectMole updates selected mole and navigation id")
    func selectMoleUpdatesSelectionAndNavigationID() {
        let state = makeState()
        let person = Person(name: "Alex")
        let mole = Mole(
            name: "Back One",
            bodyPart: "Back",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil,
            person: person
        )

        state.selectMole(mole)
        #expect(state.selectedMole == mole)
        #expect(state.selectedMoleNavigationID == mole.id)

        state.selectMole(nil)
        #expect(state.selectedMole == nil)
        #expect(state.selectedMoleNavigationID == nil)
    }
}
