//
//  MoleInstance.swift
//  P8-Product
//
//  Created by Nicolaj Skjødt on 25/03/2026.
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
