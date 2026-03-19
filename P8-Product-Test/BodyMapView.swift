//
// BodyMapView.swift
// P8-Product-Test
//

import SwiftUI
import SceneKit
import SwiftData

struct BodyMapView: View {
    @Query var people: [Person]
    @State private var selectedPerson: Person?
    @State private var moleMarkers: [MoleMarker] = []
    @State private var lastAddedMarker: MoleMarker?
    @State private var markerToDelete: MoleMarker?
    @Environment(\.modelContext) var modelContext

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Body Map")
                    .font(.headline)
                Spacer()
                Text("Tap mannequin to mark moles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))

            // 3D Mannequin
            Body3DView(
                moleMarkers: $moleMarkers,
                onAdd: { marker in
                    moleMarkers.append(marker)
                    lastAddedMarker = marker
                },
                onRemove: { marker in
                    markerToDelete = marker
                }
            )
            .frame(maxHeight: .infinity)

            // Bottom controls
            VStack {
                if lastAddedMarker != nil {
                    HStack {
                        Text("Mole added — tap marker to remove")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Button(action: undoLastMarker) {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                }

                HStack {
                    Text("Total moles marked: \(moleMarkers.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear All") {
                        moleMarkers.removeAll()
                        lastAddedMarker = nil
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding()
            }
            .background(Color(.systemBackground))
        }
        .alert(
            "Remove Mole Marker?",
            isPresented: Binding(get: { markerToDelete != nil }, set: { if !$0 { markerToDelete = nil } }),
            presenting: markerToDelete
        ) { marker in
            Button("Remove", role: .destructive) {
                removeMoleMarker(marker)
                markerToDelete = nil
            }
            Button("Cancel", role: .cancel) { markerToDelete = nil }
        } message: { marker in
            Text("Added on \(marker.timestamp.formatted(date: .abbreviated, time: .shortened))")
        }
        .onAppear {
            loadExistingMarkers()
        }
    }

    private func removeMoleMarker(_ marker: MoleMarker) {
        moleMarkers.removeAll { $0.id == marker.id }
        if lastAddedMarker?.id == marker.id {
            lastAddedMarker = moleMarkers.last
        }
    }

    private func undoLastMarker() {
        if let last = lastAddedMarker {
            removeMoleMarker(last)
            lastAddedMarker = moleMarkers.last
        }
    }

    private func loadExistingMarkers() {
        if let person = selectedPerson {
            moleMarkers = person.moles
        }
    }

    func saveMolesToPerson(_ person: Person) {
        person.moles = moleMarkers
        try? modelContext.save()
    }
}

// MARK: - 3D Mannequin View

struct Body3DView: UIViewRepresentable {
    @Binding var moleMarkers: [MoleMarker]
    let onAdd: (MoleMarker) -> Void
    let onRemove: (MoleMarker) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = UIColor.systemGray5
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.antialiasingMode = .multisampling4X

        if let scene = SCNScene(named: "Ch36_nonPBR.scn") {
            sceneView.scene = scene
        } else {
            print("⚠️ Model not found: 'Ch36_nonPBR.scn'. Using fallback.")
            let scene = SCNScene()
            
            // Create a geometric dummy human
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemGray3
            
            let rootNode = SCNNode()
            
            // Head
            let headNode = SCNNode(geometry: SCNSphere(radius: 0.12))
            headNode.geometry?.firstMaterial = material
            headNode.position = SCNVector3(0, 0.65, 0)
            rootNode.addChildNode(headNode)
            
            // Torso
            let torsoNode = SCNNode(geometry: SCNBox(width: 0.3, height: 0.6, length: 0.15, chamferRadius: 0.05))
            torsoNode.geometry?.firstMaterial = material
            torsoNode.position = SCNVector3(0, 0.2, 0)
            rootNode.addChildNode(torsoNode)
            
            // Limbs helper
            func addLimb(x: Float, y: Float, radius: CGFloat, height: CGFloat) {
                let limbNode = SCNNode(geometry: SCNCapsule(capRadius: radius, height: height))
                limbNode.geometry?.firstMaterial = material
                limbNode.position = SCNVector3(x, y, 0)
                rootNode.addChildNode(limbNode)
            }
            
            addLimb(x: -0.25, y: 0.2, radius: 0.05, height: 0.7) // Left Arm
            addLimb(x: 0.25, y: 0.2, radius: 0.05, height: 0.7)  // Right Arm
            addLimb(x: -0.1, y: -0.6, radius: 0.06, height: 0.8) // Left Leg
            addLimb(x: 0.1, y: -0.6, radius: 0.06, height: 0.8)  // Right Leg
            
            scene.rootNode.addChildNode(rootNode)
            sceneView.scene = scene
        }

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        sceneView.addGestureRecognizer(tap)

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Keep coordinator's parent reference fresh so callbacks see current state
        context.coordinator.parent = self

        guard let scene = uiView.scene else { return }

        let currentIds = Set(moleMarkers.map { $0.id.uuidString })

        // Remove sphere nodes for deleted markers
        let moleNodes = scene.rootNode.childNodes(passingTest: { node, _ in
            node.name?.hasPrefix("mole_") == true
        })
        for node in moleNodes {
            let nodeId = String(node.name!.dropFirst(5))
            if !currentIds.contains(nodeId) {
                node.removeFromParentNode()
            }
        }

        // Add sphere nodes for new markers
        let existingIds = Set(
            moleNodes.compactMap { $0.name.map { String($0.dropFirst(5)) } }
        )
        for marker in moleMarkers where !existingIds.contains(marker.id.uuidString) {
            let sphere = SCNSphere(radius: 1) // ~8 cm; increased size
            sphere.firstMaterial?.diffuse.contents = UIColor.red
            sphere.firstMaterial?.emission.contents = UIColor(red: 0.8, green: 0, blue: 0, alpha: 1)
            let node = SCNNode(geometry: sphere)
            node.name = "mole_\(marker.id.uuidString)"
            node.position = SCNVector3(marker.worldX, marker.worldY, marker.worldZ)
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: Body3DView

        init(_ parent: Body3DView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            guard let hit = hitResults.first else { return }

            // Tapped an existing mole marker — prompt to remove
            if let name = hit.node.name, name.hasPrefix("mole_") {
                let idString = String(name.dropFirst(5))
                if let marker = parent.moleMarkers.first(where: { $0.id.uuidString == idString }) {
                    parent.onRemove(marker)
                }
                return
            }

            // Tapped the mannequin mesh — place a new marker at the hit point
            let pos = hit.worldCoordinates
            let marker = MoleMarker(worldX: pos.x, worldY: pos.y, worldZ: pos.z)
            parent.onAdd(marker)
        }
    }
}

#Preview {
    BodyMapView()
        .modelContainer(for: Person.self, inMemory: true)
}
