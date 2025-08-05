# fying - AR Interior Design Application

A sophisticated ARKit-based iOS application that allows users to scan rooms, place virtual furniture, and visualize interior designs with realistic lighting and physics.

## Features

### 🏠 Room Scanning & Detection
- **Real-time room mapping** using ARKit's scene reconstruction
- **Surface detection** for floors, walls, ceilings, and furniture
- **Dynamic visual feedback** during scanning process
- **Room dimension calculation** with accurate measurements
- **Lighting estimation** for realistic rendering

### 🪑 3D Furniture Placement
- **USDZ model support** for high-quality 3D furniture
- **Snap-to-surface placement** for accurate positioning
- **Intuitive gesture controls**:
  - Tap to place/select furniture
  - Drag to move furniture
  - Pinch to scale furniture
  - Rotate to adjust orientation
- **Collision detection** to prevent overlapping
- **Category-based furniture catalog** (Seating, Tables, Storage, Lighting, Decor)

### 🎨 Realistic Rendering
- **Lighting estimation** for dynamic lighting effects
- **Occlusion handling** so virtual objects are blocked by real-world objects
- **Realistic shadows** and reflections
- **PBR materials** for photorealistic appearance
- **Physics integration** for natural object behavior

### 🏗️ Architecture
- **MVVM pattern** for clean separation of concerns
- **Combine framework** for reactive data flow
- **SwiftUI** for modern, declarative UI
- **ARKit integration** for advanced AR capabilities
- **SceneKit** for 3D rendering and physics

## Technical Implementation

### Core Components

#### Models
- `RoomScanModel`: Handles room scanning data and surface detection
- `FurnitureModel`: Manages furniture items and placement data
- `FurnitureCatalog`: Provides furniture catalog with categories

#### ViewModels
- `ARViewModel`: Main coordinator for AR session and furniture placement
- `ARSessionDelegate`: Handles AR session updates and plane detection

#### Views
- `ARSceneView`: SwiftUI wrapper for ARKit's ARSCNView
- `ScanningOverlayView`: Real-time scanning feedback UI
- `FurnitureCatalogView`: Furniture selection interface
- `ControlPanelView`: User controls and settings
- `PlacedFurnitureListView`: Management of placed furniture

### Key Features Implementation

#### Room Scanning
```swift
// Configure AR session with scene reconstruction
let configuration = ARWorldTrackingConfiguration()
configuration.planeDetection = [.horizontal, .vertical]
configuration.environmentTexturing = .automatic
configuration.isLightEstimationEnabled = true

if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
    configuration.sceneReconstruction = .mesh
}
```

#### Furniture Placement
```swift
// Hit testing for accurate placement
let hitTestResults = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any)
if let result = hitTestResults {
    let position = SCNVector3(result.worldTransform.columns.3.x,
                              result.worldTransform.columns.3.y,
                              result.worldTransform.columns.3.z)
    viewModel.placeFurniture(at: position)
}
```

#### Gesture Handling
```swift
// Multi-touch gesture recognition
let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
```

## Setup Instructions

### Prerequisites
- iOS 14.0 or later
- Xcode 12.0 or later
- iPhone/iPad with ARKit support (A9 processor or later)
- Camera permissions

### Installation
1. Clone the repository
2. Open `fying.xcodeproj` in Xcode
3. Add USDZ furniture models to the project (see Resources/README.md)
4. Build and run on a physical device (ARKit requires camera access)

### Required Permissions
Add the following to `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for AR functionality</string>
```

## Usage Guide

### Getting Started
1. **Launch the app** and grant camera permissions
2. **Point your camera** at the room you want to scan
3. **Tap "Scan"** to start room detection
4. **Move slowly** around the room to map surfaces
5. **Wait for completion** of the scanning process

### Furniture Placement
1. **Tap "Catalog"** to browse available furniture
2. **Select a category** (Seating, Tables, etc.)
3. **Choose furniture** from the catalog
4. **Tap on a surface** to place the furniture
5. **Use gestures** to adjust position, size, and rotation

### Gesture Controls
- **Tap**: Place or select furniture
- **Drag**: Move furniture around the room
- **Pinch**: Scale furniture size
- **Rotate**: Rotate furniture orientation

### Advanced Features
- **Lighting estimation**: Automatic adjustment to room lighting
- **Occlusion handling**: Virtual objects are blocked by real objects
- **Collision detection**: Prevents furniture overlap
- **Room dimensions**: Real-time measurement display

## Project Structure

```
fying/
├── Models/
│   ├── RoomScanModel.swift
│   └── FurnitureModel.swift
├── ViewModels/
│   ├── ARViewModel.swift
│   └── ARViewModel+ARSessionDelegate.swift
├── Views/
│   ├── ARSceneView.swift
│   ├── ScanningOverlayView.swift
│   ├── FurnitureCatalogView.swift
│   └── ControlPanelView.swift
├── Resources/
│   └── README.md
├── ContentView.swift
└── fyingApp.swift
```

## Technical Highlights

### MVVM Architecture
- **Model**: Business logic and data structures
- **View**: UI components and user interactions
- **ViewModel**: Data binding and state management

### Combine Framework
- **Reactive data flow** for real-time updates
- **Publishers and subscribers** for state management
- **Asynchronous operations** for AR session handling

### ARKit Integration
- **World tracking** for device positioning
- **Plane detection** for surface recognition
- **Scene reconstruction** for detailed room mapping
- **Lighting estimation** for realistic rendering
- **Occlusion rendering** for immersive experience

### Performance Optimizations
- **Efficient 3D model loading** with USDZ format
- **Optimized gesture recognition** for smooth interaction
- **Memory management** for large AR scenes
- **Battery optimization** for extended AR sessions

## Future Enhancements

### Planned Features
- **Multi-room support** for larger spaces
- **Furniture customization** (colors, materials)
- **Collaborative AR** for shared experiences
- **Export functionality** for design sharing
- **AI-powered furniture suggestions**
- **Integration with furniture retailers**

### Technical Improvements
- **Advanced physics simulation**
- **Real-time collaboration**
- **Cloud-based furniture catalog**
- **Machine learning for better placement**
- **Haptic feedback integration**

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Apple ARKit for the AR framework
- SceneKit for 3D rendering
- SwiftUI for modern UI development
- Combine for reactive programming

---

**fying** - Transform your space with AR-powered interior design. 
