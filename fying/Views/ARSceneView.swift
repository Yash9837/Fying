import SwiftUI
import ARKit
import SceneKit
import Combine

// MARK: - AR Scene View
struct ARSceneView: UIViewRepresentable {
    @ObservedObject var viewModel: ARViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        
        // Configure the scene view
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        
        // Enable occlusion
        sceneView.scene.isPaused = false
        
        // Configure AR session
        viewModel.configureARSession(sceneView)
        
        // Add gesture recognizers
        setupGestureRecognizers(for: sceneView, context: context)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update view based on view model state
        updateSceneBasedOnState(uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARSceneView
        
        init(_ parent: ARSceneView) {
            self.parent = parent
        }
        
        // ARSCNViewDelegate methods
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            handleAnchorAdded(node, anchor: anchor)
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            handleAnchorUpdated(node, anchor: anchor)
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            handleAnchorRemoved(node, anchor: anchor)
        }
        
        // MARK: - Private Methods
        private func handleAnchorAdded(_ node: SCNNode, anchor: ARAnchor) {
            if let furnitureAnchor = anchor as? ARAnchor {
                // Handle furniture placement
                addFurnitureToScene(node, anchor: furnitureAnchor)
            }
        }
        
        private func handleAnchorUpdated(_ node: SCNNode, anchor: ARAnchor) {
            // Handle anchor updates if needed
        }
        
        private func handleAnchorRemoved(_ node: SCNNode, anchor: ARAnchor) {
            // Handle anchor removal if needed
        }
        
        private func addFurnitureToScene(_ node: SCNNode, anchor: ARAnchor) {
            guard let furnitureName = anchor.name,
                  let placedFurniture = parent.viewModel.placedFurniture.first(where: { $0.furnitureItem.name == furnitureName }) else {
                return
            }
            
            // Try to load USDZ model first
            if let modelURL = placedFurniture.furnitureItem.modelURL {
                do {
                    let scene = try SCNScene(url: modelURL, options: nil)
                    if let furnitureNode = scene.rootNode.childNodes.first {
                        setupFurnitureNode(furnitureNode, placedFurniture: placedFurniture, node: node)
                    }
                } catch {
                    print("Failed to load furniture model: \(error), using fallback geometry")
                    createFallbackFurnitureNode(placedFurniture: placedFurniture, node: node)
                }
            } else {
                // Use fallback geometry if no USDZ model is available
                createFallbackFurnitureNode(placedFurniture: placedFurniture, node: node)
            }
        }
        
        private func setupFurnitureNode(_ furnitureNode: SCNNode, placedFurniture: PlacedFurniture, node: SCNNode) {
            // Apply transformations
            furnitureNode.position = placedFurniture.position
            furnitureNode.rotation = placedFurniture.rotation
            furnitureNode.scale = placedFurniture.scale
            
            // Add physics body for collision detection
            furnitureNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            
            // Add to scene
            node.addChildNode(furnitureNode)
            
            // Store reference for manipulation
            furnitureNode.name = "furniture_\(placedFurniture.id.uuidString)"
        }
        
        private func createFallbackFurnitureNode(placedFurniture: PlacedFurniture, node: SCNNode) {
            let furnitureNode = SCNNode()
            
            // Create geometry based on furniture category
            let geometry = placedFurniture.furnitureItem.fallbackGeometry
            geometry.materials = [placedFurniture.furnitureItem.fallbackMaterial]
            
            furnitureNode.geometry = geometry
            
            // Apply transformations
            furnitureNode.position = placedFurniture.position
            furnitureNode.rotation = placedFurniture.rotation
            furnitureNode.scale = placedFurniture.scale
            
            // Add physics body for collision detection
            furnitureNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            
            // Add to scene
            node.addChildNode(furnitureNode)
            
            // Store reference for manipulation
            furnitureNode.name = "furniture_\(placedFurniture.id.uuidString)"
        }
        
        // MARK: - Gesture Handlers
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let sceneView = gesture.view as? ARSCNView else { return }
            
            let location = gesture.location(in: sceneView)
            
            // Perform hit test
            let hitTestResults = sceneView.hitTest(location, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
            
            if let result = hitTestResults.first {
                let position = SCNVector3(result.worldTransform.columns.3.x,
                                        result.worldTransform.columns.3.y,
                                        result.worldTransform.columns.3.z)
                
                if parent.viewModel.sessionState == .placing {
                    parent.viewModel.placeFurniture(at: position)
                } else if let selectedFurniture = parent.viewModel.selectedFurniture {
                    parent.viewModel.updateFurniturePosition(selectedFurniture, to: position)
                }
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let sceneView = gesture.view as? ARSCNView,
                  let selectedFurniture = parent.viewModel.selectedFurniture else { return }
            
            let location = gesture.location(in: sceneView)
            
            switch gesture.state {
            case .began:
                parent.viewModel.isDragging = true
            case .changed:
                let hitTestResults = sceneView.hitTest(location, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane])
                
                if let result = hitTestResults.first {
                    let position = SCNVector3(result.worldTransform.columns.3.x,
                                            result.worldTransform.columns.3.y,
                                            result.worldTransform.columns.3.z)
                    parent.viewModel.updateFurniturePosition(selectedFurniture, to: position)
                }
            case .ended:
                parent.viewModel.isDragging = false
            default:
                break
            }
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let selectedFurniture = parent.viewModel.selectedFurniture else { return }
            
            switch gesture.state {
            case .began:
                parent.viewModel.isScaling = true
            case .changed:
                let scale = Float(gesture.scale)
                let newScale = SCNVector3(scale, scale, scale)
                parent.viewModel.updateFurnitureScale(selectedFurniture, to: newScale)
            case .ended:
                parent.viewModel.isScaling = false
            default:
                break
            }
        }
        
        @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
            guard let selectedFurniture = parent.viewModel.selectedFurniture else { return }
            
            switch gesture.state {
            case .began:
                parent.viewModel.isRotating = true
            case .changed:
                let rotation = Float(gesture.rotation)
                let newRotation = SCNVector4(0, 1, 0, rotation)
                parent.viewModel.updateFurnitureRotation(selectedFurniture, to: newRotation)
            case .ended:
                parent.viewModel.isRotating = false
            default:
                break
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupGestureRecognizers(for sceneView: ARSCNView, context: Context) {
        // Tap gesture for furniture placement
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Pan gesture for furniture movement
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        // Pinch gesture for furniture scaling
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        sceneView.addGestureRecognizer(pinchGesture)
        
        // Rotation gesture for furniture rotation
        let rotationGesture = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation(_:)))
        sceneView.addGestureRecognizer(rotationGesture)
    }
    
    private func updateSceneBasedOnState(_ sceneView: ARSCNView) {
        // Update scene based on view model state
        switch viewModel.sessionState {
        case .scanning:
            // Show scanning feedback
            break
        case .placing:
            // Show placement feedback
            break
        case .ready:
            // Normal state
            break
        case .error(let message):
            // Show error state
            print("AR Error: \(message)")
        default:
            break
        }
    }
}
