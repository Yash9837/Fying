import Foundation
import ARKit
import SceneKit
import Combine
import SwiftUI

// MARK: - AR Session State
enum ARSessionState: Equatable {
    case notReady
    case ready
    case scanning
    case placing
    case error(String)
}

// MARK: - AR View Model
class ARViewModel: NSObject, ObservableObject {
    // Published properties for UI updates
    @Published var sessionState: ARSessionState = .notReady
    @Published var placedFurniture: [PlacedFurniture] = []
    @Published var selectedFurniture: PlacedFurniture?
    @Published var currentFurnitureItem: FurnitureItem?
    @Published var showFurnitureCatalog = false
    @Published var showScanningUI = true
    @Published var showPlacementUI = false
    
    // Models
    let roomScanModel = RoomScanModel()
    let furnitureCatalog = FurnitureCatalog()
    let realityKitManager = RealityKitSessionManager()
    let roomAnalyzer = RoomAnalyzer()
    
    // AR Session
    var arSession: ARSession?
    var arSceneView: ARSCNView?
    
    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Gesture handling
    @Published var isDragging = false
    @Published var isRotating = false
    @Published var isScaling = false
    
    override init() {
        super.init()
        setupBindings()
    }
    
    // MARK: - Setup and Configuration
    private func setupBindings() {
        // Monitor room scan state changes
        roomScanModel.$scanState
            .sink { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .scanning:
                        self?.sessionState = .scanning
                        self?.showScanningUI = true
                        self?.showPlacementUI = false
                    case .completed:
                        self?.sessionState = .ready
                        self?.showScanningUI = false
                        self?.showPlacementUI = true
                    case .failed(let error):
                        self?.sessionState = .error(error)
                    default:
                        break
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor furniture selection
        $currentFurnitureItem
            .sink { [weak self] item in
                DispatchQueue.main.async {
                    self?.showFurnitureCatalog = item == nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - AR Session Management
    func configureARSession(_ sceneView: ARSCNView) {
        self.arSceneView = sceneView
        self.arSession = sceneView.session
        
            // Configure AR session for world tracking with improved room understanding
    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = [.horizontal, .vertical]
    configuration.environmentTexturing = .automatic
    configuration.isLightEstimationEnabled = true
    
    // Set higher quality for better tracking
    configuration.isAutoFocusEnabled = true
    
    // Enable advanced features for better room understanding
    if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
        configuration.sceneReconstruction = .mesh
    }
    
    // Enable people occlusion if available
    if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
        configuration.frameSemantics.insert(.personSegmentation)
    }
    
    // Set video format for better performance
    if let videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first {
        configuration.videoFormat = videoFormat
    }
        
        
        
        // Set up session delegate before starting
        sceneView.session.delegate = self
        
        // Configure scene view for realistic rendering
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        
        // Enable occlusion and realistic rendering
        sceneView.scene.isPaused = false
        sceneView.scene.background.contents = nil
        
        // Configure lighting environment
        sceneView.scene.lightingEnvironment.contents = nil
        sceneView.scene.lightingEnvironment.intensity = 1.0
        
        // Start the session with proper error handling
        startARSessionWithRetry(configuration: configuration, sceneView: sceneView)
    }
    
    private func startARSessionWithRetry(configuration: ARWorldTrackingConfiguration, sceneView: ARSCNView) {
        // First attempt with reset tracking
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Set up a timer to check tracking state and retry if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.checkTrackingStateAndRetryIfNeeded(configuration: configuration, sceneView: sceneView)
        }
        
        DispatchQueue.main.async {
            self.sessionState = .ready
            // Wait for tracking to stabilize before starting scan
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.waitForGoodTrackingThenStartScan()
            }
        }
    }
    
    private func waitForGoodTrackingThenStartScan() {
        guard let sceneView = arSceneView,
              let currentFrame = sceneView.session.currentFrame else {
            // No frame available, try again later
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.waitForGoodTrackingThenStartScan()
            }
            return
        }
        
        switch currentFrame.camera.trackingState {
        case .normal:
            // Good tracking, upgrade configuration and start scan
            upgradeConfigurationIfNeeded(sceneView: sceneView)
            self.startRoomScan()
        case .limited(let reason):
            if reason == .initializing {
                // Still initializing, wait more
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.waitForGoodTrackingThenStartScan()
                }
            } else {
                // Other limitations, show error but continue
                self.sessionState = .error("Poor tracking - try moving slowly")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.startRoomScan()
                }
            }
        case .notAvailable:
            // No tracking available, retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.waitForGoodTrackingThenStartScan()
            }
        @unknown default:
            break
        }
    }
    
    private func upgradeConfigurationIfNeeded(sceneView: ARSCNView) {
        // Only upgrade if we haven't already enabled advanced features
        let currentConfig = sceneView.session.configuration as? ARWorldTrackingConfiguration
        if currentConfig?.sceneReconstruction == nil {
            // Upgrade to advanced configuration
            let advancedConfig = ARWorldTrackingConfiguration()
            advancedConfig.planeDetection = [.horizontal, .vertical]
            advancedConfig.environmentTexturing = .automatic
            advancedConfig.isLightEstimationEnabled = true
            advancedConfig.isAutoFocusEnabled = true
            
            // Enable advanced features
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                advancedConfig.sceneReconstruction = .mesh
            }
            
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
                advancedConfig.frameSemantics.insert(.personSegmentation)
            }
            
            // Apply advanced configuration
            sceneView.session.run(advancedConfig, options: [])
        }
    }
    
    private func checkTrackingStateAndRetryIfNeeded(configuration: ARWorldTrackingConfiguration, sceneView: ARSCNView) {
        guard let currentFrame = sceneView.session.currentFrame else {
            // No frame available, retry
            retryARSession(configuration: configuration, sceneView: sceneView)
            return
        }
        
        switch currentFrame.camera.trackingState {
        case .normal:
            // Tracking is good, no need to retry
            break
        case .limited(let reason):
            // Check if it's been limited for too long
            if reason == .initializing {
                // Still initializing, give it more time
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.checkTrackingStateAndRetryIfNeeded(configuration: configuration, sceneView: sceneView)
                }
            } else {
                // Other limitations, retry
                retryARSession(configuration: configuration, sceneView: sceneView)
            }
        case .notAvailable:
            // Tracking not available, retry
            retryARSession(configuration: configuration, sceneView: sceneView)
        @unknown default:
            break
        }
    }
    
    private func retryARSession(configuration: ARWorldTrackingConfiguration, sceneView: ARSCNView) {
        print("Retrying AR session due to poor tracking...")
        
        // Pause current session
        sceneView.session.pause()
        
        // Wait a moment then restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            // Check again after restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.checkTrackingStateAndRetryIfNeeded(configuration: configuration, sceneView: sceneView)
            }
        }
    }
    
    // MARK: - Furniture Placement
    func selectFurniture(_ item: FurnitureItem) {
        currentFurnitureItem = item
        sessionState = .placing
    }
    
    func placeFurniture(at position: SCNVector3) {
        guard let furnitureItem = currentFurnitureItem,
              let sceneView = arSceneView else { return }
        
        // Create anchor for the furniture
        let transform = simd_float4x4(
            columns: (
                simd_float4(1, 0, 0, 0),
                simd_float4(0, 1, 0, 0),
                simd_float4(0, 0, 1, 0),
                simd_float4(position.x, position.y, position.z, 1)
            )
        )
        let anchor = ARAnchor(name: furnitureItem.name, transform: transform)
        
        // Create placed furniture object
        let placedFurniture = PlacedFurniture(furnitureItem: furnitureItem, anchor: anchor, position: position)
        
        // Add to scene
        DispatchQueue.main.async {
            self.placedFurniture.append(placedFurniture)
            self.selectedFurniture = placedFurniture
            self.currentFurnitureItem = nil
            self.sessionState = .ready
        }
        
        // Add anchor to session
        sceneView.session.add(anchor: anchor)
    }
    
    // MARK: - Furniture Manipulation
    func updateFurniturePosition(_ furniture: PlacedFurniture, to position: SCNVector3) {
        furniture.updatePosition(position)
        
        // Update the node's position in the scene
        if let sceneView = arSceneView {
            // Find the node associated with this furniture
            if let anchorNode = sceneView.node(for: furniture.anchor) {
                anchorNode.position = position
            }
        }
    }
    
    func updateFurnitureRotation(_ furniture: PlacedFurniture, to rotation: SCNVector4) {
        furniture.updateRotation(rotation)
        
        // Update the node's rotation in the scene
        if let sceneView = arSceneView {
            if let anchorNode = sceneView.node(for: furniture.anchor) {
                anchorNode.rotation = rotation
            }
        }
    }
    
    func updateFurnitureScale(_ furniture: PlacedFurniture, to scale: SCNVector3) {
        furniture.updateScale(scale)
        
        // Update the node's scale in the scene
        if let sceneView = arSceneView {
            if let anchorNode = sceneView.node(for: furniture.anchor) {
                anchorNode.scale = scale
            }
        }
    }
    
    func selectFurniture(_ furniture: PlacedFurniture) {
        // Deselect previously selected furniture
        placedFurniture.forEach { $0.isSelected = false }
        
        // Select new furniture
        furniture.toggleSelection()
        selectedFurniture = furniture
    }
    
    func deleteFurniture(_ furniture: PlacedFurniture) {
        // Remove from session
        if let sceneView = arSceneView {
            sceneView.session.remove(anchor: furniture.anchor)
        }
        
        // Remove from array
        DispatchQueue.main.async {
            self.placedFurniture.removeAll { $0.id == furniture.id }
            if self.selectedFurniture?.id == furniture.id {
                self.selectedFurniture = nil
            }
        }
    }
    
    // MARK: - Room Scanning
    func startRoomScan() {
        roomScanModel.scanState = .scanning
        sessionState = .scanning
        showScanningUI = true
        showPlacementUI = false
    }
    
    func stopRoomScan() {
        roomScanModel.scanState = .completed
        sessionState = .ready
        showScanningUI = false
        showPlacementUI = true
    }
    
    func resetRoom() {
        // Remove all placed furniture
        placedFurniture.forEach { furniture in
            if let sceneView = arSceneView {
                sceneView.session.remove(anchor: furniture.anchor)
            }
        }
        
        DispatchQueue.main.async {
            self.placedFurniture.removeAll()
            self.selectedFurniture = nil
            self.currentFurnitureItem = nil
        }
        
        // Reset room scan
        roomScanModel.resetScan()
        
        // Reset AR session
        if let sceneView = arSceneView {
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.environmentTexturing = .automatic
            configuration.isLightEstimationEnabled = true
            
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
            
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }
    
    // MARK: - Utility Methods
    func getLightingEstimate() -> ARLightEstimate? {
        return roomScanModel.lightingEstimate
    }
    
    func getRoomDimensions() -> (width: Float, length: Float, height: Float) {
        return roomScanModel.roomDimensions
    }
    
    func getDetectedSurfaces() -> [DetectedSurface] {
        return roomScanModel.detectedSurfaces
    }
}
