//
// BodyPart.swift
// P8-Product
//

import Foundation

/// Predefined body areas used when creating or categorizing a mole.
enum BodyPart: String, CaseIterable, Codable, Identifiable {
    case unassigned = "Unassigned"
    case face = "Face"
    case neck = "Neck"
    case chest = "Chest"
    case abdomen = "Abdomen"
    case back = "Back"
    case leftArm = "Left Arm"
    case rightArm = "Right Arm"
    case leftHand = "Left Hand"
    case rightHand = "Right Hand"
    case leftLeg = "Left Leg"
    case rightLeg = "Right Leg"
    case leftFoot = "Left Foot"
    case rightFoot = "Right Foot"
    case other = "Other"

    var id: String { rawValue }
}
