//
// BodyPart.swift
// P8-Product
//

import Foundation

/// Predefined body areas used when creating or categorizing a mole.
enum BodyPart: String, CaseIterable, Codable, Identifiable {
  /// No specific body part assigned.
  case unassigned = "Unassigned"
  /// The face.
  case face = "Face"
  /// The neck.
  case neck = "Neck"
  /// The chest.
  case chest = "Chest"
  /// The abdomen.
  case abdomen = "Abdomen"
  /// The back.
  case back = "Back"
  /// The left arm.
  case leftArm = "Left Arm"
  /// The right arm.
  case rightArm = "Right Arm"
  /// The left hand.
  case leftHand = "Left Hand"
  /// The right hand.
  case rightHand = "Right Hand"
  /// The left leg.
  case leftLeg = "Left Leg"
  /// The right leg.
  case rightLeg = "Right Leg"
  /// The left foot.
  case leftFoot = "Left Foot"
  /// The right foot.
  case rightFoot = "Right Foot"
  /// Any other body part not listed above.
  case other = "Other"

  /// The raw string value used as the stable identifier.
  var id: String { rawValue }
}
