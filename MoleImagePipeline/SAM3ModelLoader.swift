//
//  SAM3ModelLoader.swift
//  P8-Product
//

import Combine
import CoreML
import SwiftUI

/// A singleton-like manager that handles the asynchronous loading of SAM3 models.
/// This ensures models are loaded only once and can be accessed from any view.
@MainActor
class SAM3ModelLoader: ObservableObject {
  /// The `segmentor` property.
  @Published var segmentor: MoleSegmentor?
  /// The `isLoading` property.
  @Published var isLoading = false
  /// The `error` property.
  @Published var error: Error?

  /// The `shared` property.
  static let shared = SAM3ModelLoader()

  /// Initializes a new instance.
  private init() {}

  /// The `loadModel` function.
  func loadModel() async {
    guard segmentor == nil, !isLoading else { return }

    isLoading = true
    error = nil

    let clock = ContinuousClock()
    let result = await clock.measure {
      do {
        let seg = try await MoleSegmentor()
        self.segmentor = seg
      } catch {
        self.error = error
        print("SAM3 Model Loading Failed: \(error.localizedDescription)")
      }
    }

    isLoading = false
    if error == nil {
      print("Total SAM3 loading time: \(result)")
    }
  }
}
