import SwiftUI
import SwiftData
import UIKit

@MainActor
@Observable
class CompareAppState {
    // Mark: - Persistent Data Selection
    var selectedPerson: Person?
    var selectedMole: Mole?
    var selectedMetric: ChartMetric = .area
    var selectedIndexTop: Int = 0
    var selectedIndexBottom: Int = 0

    
    private let dataController: DataController

    init(dataController: DataController) {
        self.dataController = dataController
    }

    // Mark: - Logic 

    func selectPerson (_ person: Person?) {
        selectedPerson = person
    }

    func selectMole (_ mole: Mole?) {
        selectedMole = mole
    }

    func selectMetric (_ metric: ChartMetric) {
        selectedMetric = metric
    }

    func selectIndexTop (_ index: Int) {
        selectedIndexTop = index
    }

    func selectIndexBottom (_ index: Int) {
        selectedIndexBottom = index
    }



}