import Foundation
import ARKit
import Combine
import RealityKit

// MARK: - Room Surface Types
enum SurfaceType: String, CaseIterable {
    case floor = "Floor"
    case wall = "Wall"
    case ceiling = "Ceiling"
    case furniture = "Furniture"
    
    var color: UIColor {
        switch self {
        case .floor: return UIColor.systemGreen
        case .wall: return UIColor.systemBlue
        case .ceiling: return UIColor.systemYellow
        case .furniture: return UIColor.systemOrange
        }
    }
}

// MARK: - Detected Surface
struct DetectedSurface: Identifiable {
    let id = UUID()
    let type: SurfaceType
    let anchor: ARAnchor
    let bounds: CGRect
    let confidence: Float
    let timestamp: Date
    let area: Float // Surface area in square meters
    let isSignificant: Bool // Whether this surface is significant for room understanding
}

// MARK: - Room Scan State
enum RoomScanState: Equatable {
    case notStarted
    case scanning
    case completed
    case failed(String)
}

// MARK: - Room Scan Model
class RoomScanModel: ObservableObject {
    @Published var scanState: RoomScanState = .notStarted
    @Published var detectedSurfaces: [DetectedSurface] = []
    @Published var roomDimensions: (width: Float, length: Float, height: Float) = (0, 0, 0)
    @Published var scanProgress: Float = 0.0
    @Published var lightingEstimate: ARLightEstimate?
    
    // Room understanding properties
    @Published var roomArea: Float = 0.0
    @Published var wallCount: Int = 0
    @Published var floorCount: Int = 0
    @Published var ceilingCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var surfaceMergeThreshold: Float = 0.5 // Minimum distance to merge similar surfaces
    
    func updateScanProgress(_ progress: Float) {
        DispatchQueue.main.async {
            self.scanProgress = progress
        }
    }
    
    func addDetectedSurface(_ surface: DetectedSurface) {
        DispatchQueue.main.async {
            // Check if this surface is significant enough to add
            if self.isSignificantSurface(surface) {
                // Check if we should merge with existing surfaces
                if let mergedSurface = self.mergeWithExistingSurfaces(surface) {
                    // Replace the old surface with the merged one
                    if let index = self.detectedSurfaces.firstIndex(where: { $0.id == mergedSurface.id }) {
                        self.detectedSurfaces[index] = mergedSurface
                    }
                } else {
                    // Add new surface
                    self.detectedSurfaces.append(surface)
                }
                
                // Update room statistics
                self.updateRoomStatistics()
            }
        }
    }
    
    private func isSignificantSurface(_ surface: DetectedSurface) -> Bool {
        // Only consider surfaces with sufficient area
        let minArea: Float = 0.5 // Minimum 0.5 square meters
        return surface.area >= minArea
    }
    
    private func mergeWithExistingSurfaces(_ newSurface: DetectedSurface) -> DetectedSurface? {
        for existingSurface in detectedSurfaces {
            if existingSurface.type == newSurface.type {
                // Check if surfaces are close enough to merge
                let distance = calculateDistance(between: existingSurface, and: newSurface)
                if distance < surfaceMergeThreshold {
                    // Merge surfaces
                    return mergeSurfaces(existingSurface, newSurface)
                }
            }
        }
        return nil
    }
    
    private func calculateDistance(between surface1: DetectedSurface, and surface2: DetectedSurface) -> Float {
        let pos1 = surface1.anchor.transform.columns.3
        let pos2 = surface2.anchor.transform.columns.3
        let dx = pos1.x - pos2.x
        let dy = pos1.y - pos2.y
        let dz = pos1.z - pos2.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    private func mergeSurfaces(_ surface1: DetectedSurface, _ surface2: DetectedSurface) -> DetectedSurface {
        // Create a merged surface with combined area and bounds
        let mergedArea = surface1.area + surface2.area
        let mergedBounds = CGRect(
            x: min(surface1.bounds.minX, surface2.bounds.minX),
            y: min(surface1.bounds.minY, surface2.bounds.minY),
            width: max(surface1.bounds.maxX, surface2.bounds.maxX) - min(surface1.bounds.minX, surface2.bounds.minX),
            height: max(surface1.bounds.maxY, surface2.bounds.maxY) - min(surface1.bounds.minY, surface2.bounds.minY)
        )
        
        return DetectedSurface(
            type: surface1.type,
            anchor: surface1.anchor, // Keep the first anchor
            bounds: mergedBounds,
            confidence: max(surface1.confidence, surface2.confidence),
            timestamp: Date(),
            area: mergedArea,
            isSignificant: mergedArea >= 1.0 // Significant if area >= 1 square meter
        )
    }
    
    private func updateRoomStatistics() {
        let floors = detectedSurfaces.filter { $0.type == .floor }
        let walls = detectedSurfaces.filter { $0.type == .wall }
        let ceilings = detectedSurfaces.filter { $0.type == .ceiling }
        
        floorCount = floors.count
        wallCount = walls.count
        ceilingCount = ceilings.count
        
        // Calculate total room area (sum of all floor surfaces)
        roomArea = floors.reduce(0) { $0 + $1.area }
        
        // Update room dimensions based on significant surfaces
        updateRoomDimensionsFromSurfaces()
    }
    
    private func updateRoomDimensionsFromSurfaces() {
        var maxWidth: Float = 0
        var maxLength: Float = 0
        var maxHeight: Float = 0
        
        for surface in detectedSurfaces {
            let pos = surface.anchor.transform.columns.3
            let width = Float(surface.bounds.width)
            let height = Float(surface.bounds.height)
            
            switch surface.type {
            case .floor:
                maxWidth = max(maxWidth, width)
                maxLength = max(maxLength, height)
            case .wall:
                maxHeight = max(maxHeight, pos.y)
            case .ceiling:
                maxHeight = max(maxHeight, pos.y)
            case .furniture:
                break // Don't count furniture in room dimensions
            }
        }
        
        roomDimensions = (maxWidth, maxLength, maxHeight)
    }
    
    func updateLightingEstimate(_ estimate: ARLightEstimate?) {
        DispatchQueue.main.async {
            self.lightingEstimate = estimate
        }
    }
    
    func updateRoomDimensions(width: Float, length: Float, height: Float) {
        DispatchQueue.main.async {
            self.roomDimensions = (width, length, height)
        }
    }
    
    func resetScan() {
        DispatchQueue.main.async {
            self.scanState = .notStarted
            self.detectedSurfaces.removeAll()
            self.scanProgress = 0.0
            self.roomDimensions = (0, 0, 0)
            self.lightingEstimate = nil
            self.roomArea = 0.0
            self.wallCount = 0
            self.floorCount = 0
            self.ceilingCount = 0
        }
    }
    
    // MARK: - Room Understanding
    func getRoomSummary() -> String {
        let area = String(format: "%.1f", roomArea)
        return "Room: \(area)m², \(wallCount) walls, \(floorCount) floors"
    }
    
    func isRoomScanComplete() -> Bool {
        // Room scan is complete if we have:
        // - At least 1 floor surface
        // - At least 2 walls
        // - Sufficient room area (> 5 square meters)
        return floorCount >= 1 && wallCount >= 2 && roomArea >= 5.0
    }
}
