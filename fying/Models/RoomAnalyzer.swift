//
//  RoomAnalyzer.swift
//  fying new
//
//  Created by user@69 on 05/08/25.
//


import Foundation
import ARKit
import SceneKit
import Combine

// MARK: - Room Analyzer
class RoomAnalyzer: NSObject, ObservableObject {
    @Published var roomStructure: RoomStructure?
    @Published var isAnalyzing = false
    @Published var analysisProgress: Float = 0.0
    
    private var detectedPlanes: [ARPlaneAnchor] = []
    private var planeClusters: [PlaneCluster] = []
    private var roomBounds: RoomBounds?
    
    // Analysis parameters
    private let minWallHeight: Float = 2.0 // Minimum wall height in meters
    private let minFloorArea: Float = 1.0 // Minimum floor area in square meters
    private let clusterThreshold: Float = 0.5 // Distance threshold for clustering planes
    private let analysisTimeout: TimeInterval = 30.0 // Analysis timeout in seconds
    
    override init() {
        super.init()
    }
    
    // MARK: - Room Analysis
    func analyzeRoom(from planes: [ARPlaneAnchor]) {
        isAnalyzing = true
        analysisProgress = 0.0
        
        // Clear previous analysis
        detectedPlanes = planes
        planeClusters = []
        roomBounds = nil
        
        // Start analysis
        performRoomAnalysis()
    }
    
    private func performRoomAnalysis() {
        // Step 1: Classify planes by type and position
        let classifiedPlanes = classifyPlanes(detectedPlanes)
        analysisProgress = 0.2
        
        // Step 2: Cluster similar planes
        planeClusters = clusterPlanes(classifiedPlanes)
        analysisProgress = 0.4
        
        // Step 3: Determine room bounds
        roomBounds = calculateRoomBounds(from: planeClusters)
        analysisProgress = 0.6
        
        // Step 4: Validate room structure
        let isValidRoom = validateRoomStructure()
        analysisProgress = 0.8
        
        // Step 5: Create room structure
        if isValidRoom {
            roomStructure = createRoomStructure()
        }
        analysisProgress = 1.0
        
        isAnalyzing = false
    }
    
    private func classifyPlanes(_ planes: [ARPlaneAnchor]) -> [ClassifiedPlane] {
        var classifiedPlanes: [ClassifiedPlane] = []
        
        for plane in planes {
            let classification = classifyPlane(plane)
            classifiedPlanes.append(ClassifiedPlane(plane: plane, classification: classification))
        }
        
        return classifiedPlanes
    }
    
    private func classifyPlane(_ plane: ARPlaneAnchor) -> PlaneClassification {
        let height = plane.transform.columns.3.y
        let area = Float(plane.planeExtent.width * plane.planeExtent.height)
        
        switch plane.alignment {
        case .horizontal:
            if height < 0.5 {
                // Floor - should be at or near ground level
                return .floor(area: area, height: height)
            } else if height > 2.0 {
                // Ceiling - should be above typical room height
                return .ceiling(area: area, height: height)
            } else {
                // Intermediate horizontal surface (table, etc.)
                return .horizontalSurface(area: area, height: height)
            }
        case .vertical:
            if area >= minWallHeight * 1.0 { // Minimum wall area
                return .wall(area: area, height: height)
            } else {
                return .verticalSurface(area: area, height: height)
            }
        @unknown default:
            return .unknown(area: area, height: height)
        }
    }
    
    private func clusterPlanes(_ classifiedPlanes: [ClassifiedPlane]) -> [PlaneCluster] {
        var clusters: [PlaneCluster] = []
        
        // Group by classification type
        let floors = classifiedPlanes.filter { $0.classification.isFloor }
        let walls = classifiedPlanes.filter { $0.classification.isWall }
        let ceilings = classifiedPlanes.filter { $0.classification.isCeiling }
        
        // Create clusters
        if !floors.isEmpty {
            clusters.append(PlaneCluster(type: .floor, planes: floors))
        }
        
        if !walls.isEmpty {
            clusters.append(PlaneCluster(type: .wall, planes: walls))
        }
        
        if !ceilings.isEmpty {
            clusters.append(PlaneCluster(type: .ceiling, planes: ceilings))
        }
        
        return clusters
    }
    
    private func calculateRoomBounds(from clusters: [PlaneCluster]) -> RoomBounds {
        var minX: Float = Float.infinity
        var maxX: Float = -Float.infinity
        var minY: Float = Float.infinity
        var maxY: Float = -Float.infinity
        var minZ: Float = Float.infinity
        var maxZ: Float = -Float.infinity
        
        for cluster in clusters {
            for classifiedPlane in cluster.planes {
                let plane = classifiedPlane.plane
                let position = plane.transform.columns.3
                let width = Float(plane.planeExtent.width)
                let height = Float(plane.planeExtent.height)
                
                // Calculate bounds
                minX = min(minX, position.x - width/2)
                maxX = max(maxX, position.x + width/2)
                minY = min(minY, position.y)
                maxY = max(maxY, position.y + height)
                minZ = min(minZ, position.z - height/2)
                maxZ = max(maxZ, position.z + height/2)
            }
        }
        
        return RoomBounds(
            width: maxX - minX,
            height: maxY - minY,
            length: maxZ - minZ,
            center: SCNVector3((minX + maxX)/2, (minY + maxY)/2, (minZ + maxZ)/2)
        )
    }
    
    private func validateRoomStructure() -> Bool {
        guard let bounds = roomBounds else { return false }
        
        // Check if we have sufficient room structure
        let hasFloors = planeClusters.contains { $0.type == .floor }
        let hasWalls = planeClusters.contains { $0.type == .wall }
        let hasCeilings = planeClusters.contains { $0.type == .ceiling }
        
        // Room should have at least floors and walls
        let hasBasicStructure = hasFloors && hasWalls
        
        // Room should have reasonable dimensions
        let hasReasonableSize = bounds.width >= 2.0 && bounds.length >= 2.0 && bounds.height >= 2.0
        
        // Room should have sufficient area
        let roomArea = bounds.width * bounds.length
        let hasSufficientArea = roomArea >= 4.0 // At least 4 square meters
        
        return hasBasicStructure && hasReasonableSize && hasSufficientArea
    }
    
    private func createRoomStructure() -> RoomStructure {
        guard let bounds = roomBounds else {
            return RoomStructure(bounds: RoomBounds(width: 0, height: 0, length: 0, center: SCNVector3Zero), walls: [], floors: [], ceilings: [])
        }
        
        let walls = planeClusters.first { $0.type == .wall }?.planes ?? []
        let floors = planeClusters.first { $0.type == .floor }?.planes ?? []
        let ceilings = planeClusters.first { $0.type == .ceiling }?.planes ?? []
        
        return RoomStructure(
            bounds: bounds,
            walls: walls.map { $0.plane },
            floors: floors.map { $0.plane },
            ceilings: ceilings.map { $0.plane }
        )
    }
}

// MARK: - Supporting Types
struct ClassifiedPlane {
    let plane: ARPlaneAnchor
    let classification: PlaneClassification
}

enum PlaneClassification {
    case floor(area: Float, height: Float)
    case wall(area: Float, height: Float)
    case ceiling(area: Float, height: Float)
    case horizontalSurface(area: Float, height: Float)
    case verticalSurface(area: Float, height: Float)
    case unknown(area: Float, height: Float)
    
    var isFloor: Bool {
        if case .floor = self { return true }
        return false
    }
    
    var isWall: Bool {
        if case .wall = self { return true }
        return false
    }
    
    var isCeiling: Bool {
        if case .ceiling = self { return true }
        return false
    }
}

struct PlaneCluster {
    let type: ClusterType
    let planes: [ClassifiedPlane]
}

enum ClusterType {
    case floor
    case wall
    case ceiling
}

struct RoomBounds {
    let width: Float
    let height: Float
    let length: Float
    let center: SCNVector3
    
    var area: Float {
        return width * length
    }
    
    var volume: Float {
        return width * length * height
    }
}

struct RoomStructure {
    let bounds: RoomBounds
    let walls: [ARPlaneAnchor]
    let floors: [ARPlaneAnchor]
    let ceilings: [ARPlaneAnchor]
    
    var wallCount: Int { walls.count }
    var floorCount: Int { floors.count }
    var ceilingCount: Int { ceilings.count }
    
    var totalWallArea: Float {
        walls.reduce(0) { $0 + Float($1.planeExtent.width * $1.planeExtent.height) }
    }
    
    var totalFloorArea: Float {
        floors.reduce(0) { $0 + Float($1.planeExtent.width * $1.planeExtent.height) }
    }
    
    var totalCeilingArea: Float {
        ceilings.reduce(0) { $0 + Float($1.planeExtent.width * $1.planeExtent.height) }
    }
    
    func getSummary() -> String {
        let area = String(format: "%.1f", bounds.area)
        let height = String(format: "%.1f", bounds.height)
        return "Room: \(area)m², \(wallCount) walls, \(height)m height"
    }
}
