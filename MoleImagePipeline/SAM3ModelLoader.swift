//
//  SAM3ModelLoader.swift
//  P8-Product
//
//  Created by Gemini on 4/2/26.
//

import SwiftUI
import CoreML
import Combine

/// A singleton-like manager that handles the asynchronous loading of SAM3 models.
/// This ensures models are loaded only once and can be accessed from any view.
@MainActor
class SAM3ModelLoader: ObservableObject {
    @Published var segmentor: MoleSegmentor?
    @Published var isLoading = false
    @Published var error: Error?
    
    static let shared = SAM3ModelLoader()
    
    private init() {}
    
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
