# Skin Pigment Observation & Tracker (SPOT)

[![iOS Version](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift Version](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

<p align="center">
  <b>A comprehensive iOS application for tracking, analysing, and monitoring moles over time using advanced on-device machine learning.</b>
</p>

---

## 📸 Overview
**SPOT** is designed to empower users to monitor their skin health by logging and analysing moles across different body parts. By leveraging on-device ML segmentation via SAM 3 (Segment Anything Model 3), the app can calculate mole dimensions, track visual changes over time, and persist this data locally for secure, offline access. 

---

## ✨ Features
- 🔍 **AI-Powered Segmentation:** Precise mole outline detection and isolation using a custom SAM 3 `MoleImagePipeline`.
- 📏 **Automated Measurement:** Calculates accurate projections and normalises orientations to track mole growth.
- 🗄️ **Local Data Persistence:** Seamlessly stores users, body parts, and mole scan history using the native `SwiftData` framework.
- 👤 **Profile Management:** Supports tracking data for multiple individuals within a single app instance.
- ⚡ **Offline First:** All machine learning inference and data storage happens entirely on-device, preserving user privacy.

---

## 🏗 Architecture & Tech Stack
The application is built with modern iOS development paradigms, focusing on performance, safety, and maintainability:

- **UI Framework:** [SwiftUI](https://developer.apple.com/xcode/swiftui/) for a fully declarative, responsive user interface.
- **Data Persistence:** [SwiftData](https://developer.apple.com/xcode/swiftdata/) for modern, macro-driven local caching and model relationship management.
- **Architecture Pattern:** MVVM (Model-View-ViewModel) paired with centralised view states (`States` directory) to cleanly separate business logic from UI rendering.
- **Concurrency:** Swift Concurrency (`async/await`, `Task`) is utilised heavily within the `MoleImagePipeline` to handle intensive ML model loading and image processing without blocking the main thread.
- **Machine Learning:** CoreML / Custom ML pipelines integration utilising a local SAM 3 model for semantic image segmentation.

---

## 📋 Requirements
- **iOS:** 17.0 or later (Required for `SwiftData`)
- **Xcode:** 15.0 or later
- **Swift:** 5.9 or later

---

## 🚀 Installation & Setup

1. **Clone the repository and submodules:**
   The CoreML models are hosted externally and linked as a git submodule. To clone the repository and initialise the models at the same time, run:
   ```bash
   git clone --recurse-submodules https://github.com/AAU-SW-P8/P8-Product.git
   cd P8-Product
   ```
   *If you have already cloned the repository without the submodules, you can fetch the models by running:*
   ```bash
   git submodule update --init --recursive
   ```

2. **Verify ML Models:**
   Ensure that the SAM 3 model from the [AllanVester/SAM3.1-CoreML-FP16](https://huggingface.co/AllanVester/SAM3.1-CoreML-FP16) Hugging Face repository has been successfully downloaded into the `MoleImagePipeline/models` directory. 

3. **Open the project in Xcode:**
   ```bash
   open P8-Product.xcodeproj
   ```

4. **Build and Run:**
   - Select your preferred simulator device or a connected physical device.
   - Press `Cmd + R` or click the **Play** button in Xcode.

---

## 📂 Folder Structure

```text
P8-Product/
├── P8-Product/                 # Main Application Target
│   ├── P8_Product.swift        # App Entry Point & SwiftData Container Initialisation
│   ├── Model/                  # SwiftData Models (Person, Mole, MoleScan, BodyPart)
│   ├── Views/                  # SwiftUI Views and UI Components
│   ├── States/                 # ViewModels and App State Management
│   └── Assets.xcassets         # App Icons, Colors, and Image Assets
│
├── MoleImagePipeline/          # Custom ML Image Processing Package/Module
│   ├── MoleSegmentor.swift     # Core logic for mole isolation
│   ├── SAM3ModelLoader.swift   # Loader for the Segment Anything Model
│   ├── Calculator.swift        # Measurement and dimension algorithms
│   ├── Rendering/              # Image rendering extensions
│   ├── Helper/                 # Utility functions and formatters
│   └── models/                 # On-device ML Model files (.mlmodelc / weights)
│
├── Tests/                      # Unit Tests for App Logic and Data Models
├── Alltests.xctestplan         # Xcode Test Plan configuration
└── README.md                   # Project documentation
```
