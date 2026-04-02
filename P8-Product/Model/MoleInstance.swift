//
// MoleInstance.swift
// P8-Product
//

import Foundation
import SwiftData

@Model
final class MoleInstance {
    var diameter: Float
    var area: Float
    
    // The inverse relationships back to the parents
    var mole: Mole?
    var moleScan: MoleScan?
    
    /// Creates a new MoleInstance record.
    /// - Parameters:
    ///   - diameter (mm) : The diameter of the mole.
    ///   - area (mm^2): The area of the mole.
    ///   - mole: Specific mole in the moleScan.
    ///   - moleScan: Picture of the mole.
    init
    (
        diameter: Float,
        area: Float,
        mole: Mole? = nil,
        moleScan: MoleScan? = nil
    ) {
        self.diameter = diameter
        self.area = area
        self.mole = mole
        self.moleScan = moleScan
    }
}
