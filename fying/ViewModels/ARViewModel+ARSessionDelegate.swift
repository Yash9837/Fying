import ARKit
import SceneKit
import Combine

// MARK: - AR Session Delegate Extension
extension ARViewModel: ARSessionDelegate {
    
    // MARK: - Session State Updates
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update lighting estimate for realistic rendering
        if let lightEstimate = frame.lightEstimate {
            roomScanModel.updateLightingEstimate(lightEstimate)
            
            // Apply lighting to scene
            if let sceneView = arSceneView {
                sceneView.scene.lightingEnvironment.intensity = lightEstimate.ambientIntensity
                sceneView.scene.lightingEnvironment.contents = nil
            }
        }
        
        // Update scan progress based on tracking state and detected surfaces
        switch frame.camera.trackingState {
        case .normal:
            if roomScanModel.scanState == .scanning {
                // Use room analyzer for better progress calculation
                let analyzerProgress = roomAnalyzer.analysisProgress
                let surfaceProgress = min(Float(roomScanModel.detectedSurfaces.count) * 0.03, 0.4)
                let totalProgress = min(analyzerProgress * 0.6 + surfaceProgress, 1.0)
                
                roomScanModel.updateScanProgress(totalProgress)
                
                // Auto-complete scan if room structure is properly understood
                if roomAnalyzer.roomStructure != nil && totalProgress >= 0.8 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self.roomScanModel.scanState == .scanning {
                            self.stopRoomScan()
                        }
                    }
                }
            }
        case .limited(let reason):
            if reason == .initializing {
                // Still initializing, continue scanning but don't update progress
                if roomScanModel.scanState == .scanning {
                    // Keep current progress, don't fail
                }
            } else {
                handleTrackingLimited(reason)
            }
        case .notAvailable:
            roomScanModel.scanState = .failed("AR tracking not available")
        @unknown default:
            break
        }
        
        // Handle scene reconstruction updates (simplified)
        // Note: Mesh anchor handling is disabled to avoid compilation issues
        // In a production app, you would implement proper mesh occlusion here
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            handleAnchorAdded(anchor)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            handleAnchorUpdated(anchor)
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            handleAnchorRemoved(anchor)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.sessionState = .error(error.localizedDescription)
            self.roomScanModel.scanState = .failed(error.localizedDescription)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.sessionState = .error("AR session was interrupted")
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.sessionState = .ready
        }
    }
    

    
    // MARK: - Private Helper Methods
    private func handleTrackingLimited(_ reason: ARCamera.TrackingState.Reason) {
        var message = ""
        var shouldRetry = false
        
        switch reason {
        case .initializing:
            message = "Initializing AR tracking..."
            // Don't fail for initializing, just wait
        case .excessiveMotion:
            message = "Too much motion detected - move slowly"
            shouldRetry = true
        case .insufficientFeatures:
            message = "Not enough features detected - improve lighting"
            shouldRetry = true
        case .relocalizing:
            message = "Relocalizing..."
            // Don't fail for relocalizing, just wait
        @unknown default:
            message = "Tracking limited"
            shouldRetry = true
        }
        
        DispatchQueue.main.async {
            if shouldRetry {
                // Update UI but don't fail the scan
                self.sessionState = .error(message)
                
                // Auto-retry after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if self.sessionState == .error(message) {
                        self.sessionState = .ready
                    }
                }
            }
        }
    }
    
    private func handleAnchorAdded(_ anchor: ARAnchor) {
        // Handle different types of anchors
        if let planeAnchor = anchor as? ARPlaneAnchor {
            handlePlaneDetected(planeAnchor)
        } else {
            // Handle furniture placement
            handleFurniturePlaced(anchor)
        }
    }
    
    private func handleAnchorUpdated(_ anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor {
            handlePlaneUpdated(planeAnchor)
        }
    }
    
    private func handleAnchorRemoved(_ anchor: ARAnchor) {
        // Handle anchor removal if needed
    }
    
    private func handlePlaneDetected(_ planeAnchor: ARPlaneAnchor) {
        // Also update the room scan model for backward compatibility
        let surfaceType: SurfaceType
        
        switch planeAnchor.alignment {
        case .horizontal:
            // Determine if it's floor or ceiling based on height
            let height = planeAnchor.transform.columns.3.y
            surfaceType = height < 0.5 ? .floor : .ceiling
        case .vertical:
            surfaceType = .wall
        @unknown default:
            surfaceType = .furniture
        }
        
        // Calculate surface area
        let area = Float(planeAnchor.planeExtent.width * planeAnchor.planeExtent.height)
        
        let detectedSurface = DetectedSurface(
            type: surfaceType,
            anchor: planeAnchor,
            bounds: CGRect(x: 0, y: 0, width: CGFloat(planeAnchor.planeExtent.width), height: CGFloat(planeAnchor.planeExtent.height)),
            confidence: 1.0,
            timestamp: Date(),
            area: area,
            isSignificant: area >= 0.5 // Only significant if area >= 0.5 square meters
        )
        
        roomScanModel.addDetectedSurface(detectedSurface)
        
        // Add visual representation to scene only for significant surfaces
        if detectedSurface.isSignificant {
            addPlaneVisualization(for: planeAnchor, type: surfaceType)
        }
        
        // Analyze all detected planes periodically
        analyzeAllDetectedPlanes()
    }
    
    private func analyzeAllDetectedPlanes() {
        guard let sceneView = arSceneView else { return }
        
        // Get all plane anchors from the session
        let allPlanes = sceneView.session.currentFrame?.anchors.compactMap { $0 as? ARPlaneAnchor } ?? []
        
        // Only analyze if we have enough planes and not already analyzing
        if allPlanes.count >= 3 && !roomAnalyzer.isAnalyzing {
            roomAnalyzer.analyzeRoom(from: allPlanes)
        }
    }
    
    private func handlePlaneUpdated(_ planeAnchor: ARPlaneAnchor) {
        // Update existing plane visualization
        updatePlaneVisualization(for: planeAnchor)
        
        // Update room dimensions
        updateRoomDimensions(with: planeAnchor)
    }
    
    private func handleFurniturePlaced(_ anchor: ARAnchor) {
        // Handle furniture placement completion
        DispatchQueue.main.async {
            self.sessionState = .ready
        }
    }
    
    private func updateRoomDimensions(with planeAnchor: ARPlaneAnchor) {
        let width = Float(planeAnchor.planeExtent.width)
        let length = Float(planeAnchor.planeExtent.height)
        
        // Calculate room dimensions based on detected planes
        let currentDimensions = roomScanModel.roomDimensions
        let newWidth = max(currentDimensions.width, width)
        let newLength = max(currentDimensions.length, length)
        let newHeight = max(currentDimensions.height, planeAnchor.transform.columns.3.y)
        
        roomScanModel.updateRoomDimensions(width: newWidth, length: newLength, height: newHeight)
    }
    
    private func addPlaneVisualization(for planeAnchor: ARPlaneAnchor, type: SurfaceType) {
        guard let sceneView = arSceneView else { return }
        
        let planeNode = SCNNode()
        let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.planeExtent.width), height: CGFloat(planeAnchor.planeExtent.height))
        
        // Create material with appropriate color and transparency
        let material = SCNMaterial()
        material.diffuse.contents = getColorForSurfaceType(type)
        material.transparency = 0.3
        material.isDoubleSided = true
        
        planeGeometry.materials = [material]
        planeNode.geometry = planeGeometry
        
        // Position the plane
        planeNode.position = SCNVector3(planeAnchor.transform.columns.3.x,
                                       planeAnchor.transform.columns.3.y,
                                       planeAnchor.transform.columns.3.z)
        
        // Rotate to match plane orientation
        planeNode.transform = SCNMatrix4(planeAnchor.transform)
        
        // Add to scene
        sceneView.scene.rootNode.addChildNode(planeNode)
        
        // Store reference for later updates
        planeNode.name = "plane_\(planeAnchor.identifier.uuidString)"
    }
    
    private func updatePlaneVisualization(for planeAnchor: ARPlaneAnchor) {
        guard let sceneView = arSceneView else { return }
        
        let planeNodeName = "plane_\(planeAnchor.identifier.uuidString)"
        if let planeNode = sceneView.scene.rootNode.childNode(withName: planeNodeName, recursively: true) {
            // Update plane geometry
            if let planeGeometry = planeNode.geometry as? SCNPlane {
                planeGeometry.width = CGFloat(planeAnchor.planeExtent.width)
                planeGeometry.height = CGFloat(planeAnchor.planeExtent.height)
            }
            
            // Update position and transform
            planeNode.position = SCNVector3(planeAnchor.transform.columns.3.x,
                                           planeAnchor.transform.columns.3.y,
                                           planeAnchor.transform.columns.3.z)
            planeNode.transform = SCNMatrix4(planeAnchor.transform)
        }
    }
    
    // MARK: - Helper Methods
    private func getColorForSurfaceType(_ type: SurfaceType) -> UIColor {
        switch type {
        case .floor:
            return UIColor.systemGreen
        case .wall:
            return UIColor.systemBlue
        case .ceiling:
            return UIColor.systemYellow
        case .furniture:
            return UIColor.systemOrange
        }
    }
    

}
