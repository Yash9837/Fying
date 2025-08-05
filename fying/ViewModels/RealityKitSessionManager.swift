//
//  RealityKitSessionManager.swift
//  fying new
//
//  Created by user@69 on 05/08/25.
//


import Foundation
import RealityKit
import ARKit
import Combine

// MARK: - RealityKit Session Manager
class RealityKitSessionManager: NSObject, ObservableObject {
    @Published var isSessionActive = false
    @Published var roomUnderstanding: RoomUnderstanding?
    
    private var arView: ARView?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
    }
    
    // MARK: - Session Management
    func startSession() {
        guard let arView = arView else { return }
        
        // Configure RealityKit session for room understanding
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.isLightEstimationEnabled = true
        
        // Enable scene reconstruction for better room understanding
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isSessionActive = true
    }
    
    func stopSession() {
        guard let arView = arView else { return }
        arView.session.pause()
        isSessionActive = false
    }
    
    func configureARView(_ arView: ARView) {
        self.arView = arView
        arView.session.delegate = self
    }
    
    // MARK: - Room Understanding
    func analyzeRoom() {
        guard let arView = arView else { return }
        
        // Use RealityKit's built-in room understanding
        let roomUnderstanding = RoomUnderstanding()
        
        // Analyze detected planes for room structure
        let planes = arView.session.currentFrame?.anchors.compactMap { $0 as? ARPlaneAnchor } ?? []
        
        var floors: [ARPlaneAnchor] = []
        var walls: [ARPlaneAnchor] = []
        var ceilings: [ARPlaneAnchor] = []
        
        for plane in planes {
            switch plane.alignment {
            case .horizontal:
                let height = plane.transform.columns.3.y
                if height < 0.5 {
                    floors.append(plane)
                } else {
                    ceilings.append(plane)
                }
            case .vertical:
                walls.append(plane)
            @unknown default:
                break
            }
        }
        
        // Calculate room metrics
        let totalFloorArea = floors.reduce(0) { $0 + Float($1.planeExtent.width * $1.planeExtent.height) }
        let wallCount = walls.count
        let roomPerimeter = calculateRoomPerimeter(walls: walls)
        
        roomUnderstanding.update(
            floorArea: totalFloorArea,
            wallCount: wallCount,
            roomPerimeter: roomPerimeter,
            floors: floors,
            walls: walls,
            ceilings: ceilings
        )
        
        self.roomUnderstanding = roomUnderstanding
    }
    
    private func calculateRoomPerimeter(walls: [ARPlaneAnchor]) -> Float {
        // Simple perimeter calculation based on wall positions
        var perimeter: Float = 0
        
        for wall in walls {
            let width = Float(wall.planeExtent.width)
            let height = Float(wall.planeExtent.height)
            perimeter += width + height
        }
        
        return perimeter
    }
}

// MARK: - Room Understanding Model
class RoomUnderstanding: ObservableObject {
    @Published var floorArea: Float = 0
    @Published var wallCount: Int = 0
    @Published var roomPerimeter: Float = 0
    @Published var isComplete: Bool = false
    
    private var floors: [ARPlaneAnchor] = []
    private var walls: [ARPlaneAnchor] = []
    private var ceilings: [ARPlaneAnchor] = []
    
    func update(floorArea: Float, wallCount: Int, roomPerimeter: Float, floors: [ARPlaneAnchor], walls: [ARPlaneAnchor], ceilings: [ARPlaneAnchor]) {
        self.floorArea = floorArea
        self.wallCount = wallCount
        self.roomPerimeter = roomPerimeter
        self.floors = floors
        self.walls = walls
        self.ceilings = ceilings
        
        // Determine if room understanding is complete
        isComplete = floorArea >= 5.0 && wallCount >= 2 && roomPerimeter >= 8.0
    }
    
    func getSummary() -> String {
        let area = String(format: "%.1f", floorArea)
        let perimeter = String(format: "%.1f", roomPerimeter)
        return "Room: \(area)m², \(wallCount) walls, \(perimeter)m perimeter"
    }
}

// MARK: - AR Session Delegate
extension RealityKitSessionManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Analyze room periodically
        if isSessionActive && frame.timestamp.truncatingRemainder(dividingBy: 2.0) < 0.1 {
            analyzeRoom()
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Handle new anchors
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                // New plane detected
                analyzeRoom()
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Handle updated anchors
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                // Plane updated
                analyzeRoom()
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isSessionActive = false
        }
    }
}