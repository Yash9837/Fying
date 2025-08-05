import SwiftUI
import ARKit

// MARK: - Control Panel View
struct ControlPanelView: View {
    @ObservedObject var viewModel: ARViewModel
    @State private var showSettings = false
    @State private var showHelp = false
    
    var body: some View {
        VStack(spacing: 15) {
            // Top controls
            HStack {
                // Settings button
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Help button
                Button(action: { showHelp.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Bottom controls
            VStack(spacing: 12) {
                // Main action buttons
                HStack(spacing: 15) {
                    // Scan room button
                    Button(action: {
                        if viewModel.roomScanModel.scanState == .scanning {
                            viewModel.stopRoomScan()
                        } else {
                            viewModel.startRoomScan()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: viewModel.roomScanModel.scanState == .scanning ? "stop.circle" : "camera")
                                .font(.title2)
                            Text(viewModel.roomScanModel.scanState == .scanning ? "Stop" : "Scan")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(viewModel.roomScanModel.scanState == .scanning ? Color.red : Color.blue)
                        )
                    }
                    
                    // Reset room button
                    Button(action: { viewModel.resetRoom() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                            Text("Reset")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.orange)
                        )
                    }
                    
                    // Furniture catalog button
                    Button(action: { viewModel.showFurnitureCatalog.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "square.grid.2x2")
                                .font(.title2)
                            Text("Catalog")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.green)
                        )
                    }
                }
                
                // Status indicators
                HStack(spacing: 20) {
                    StatusIndicator(
                        icon: "lightbulb",
                        title: "Lighting",
                        isActive: viewModel.getLightingEstimate() != nil,
                        color: .yellow
                    )
                    
                    StatusIndicator(
                        icon: "ruler",
                        title: "Dimensions",
                        isActive: viewModel.getRoomDimensions().width > 0,
                        color: .blue
                    )
                    
                    StatusIndicator(
                        icon: "cube",
                        title: "Furniture",
                        isActive: !viewModel.placedFurniture.isEmpty,
                        color: .green
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
            )
            .padding(.horizontal)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let icon: String
    let title: String
    let isActive: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isActive ? color : .gray)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(isActive ? .white : .gray)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var viewModel: ARViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // AR Settings
                VStack(alignment: .leading, spacing: 15) {
                    Text("AR Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        SettingRow(title: "Lighting Estimation", isEnabled: true)
                        SettingRow(title: "Occlusion Rendering", isEnabled: true)
                        SettingRow(title: "Scene Reconstruction", isEnabled: ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh))
                        SettingRow(title: "Plane Detection", isEnabled: true)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                // Room Information
                VStack(alignment: .leading, spacing: 15) {
                    Text("Room Information")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    let dimensions = viewModel.getRoomDimensions()
                    VStack(spacing: 8) {
                        InfoRow(label: "Width", value: "\(String(format: "%.1f", dimensions.width))m")
                        InfoRow(label: "Length", value: "\(String(format: "%.1f", dimensions.length))m")
                        InfoRow(label: "Height", value: "\(String(format: "%.1f", dimensions.height))m")
                        InfoRow(label: "Detected Surfaces", value: "\(viewModel.getDetectedSurfaces().count)")
                        InfoRow(label: "Placed Furniture", value: "\(viewModel.placedFurniture.count)")
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Setting Row
struct SettingRow: View {
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnabled ? .green : .red)
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Help View
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Getting Started
                    HelpSection(
                        title: "Getting Started",
                        items: [
                            "1. Point your camera at the room you want to scan",
                            "2. Tap 'Scan' to start room detection",
                            "3. Move slowly around the room to map surfaces",
                            "4. Wait for the scan to complete"
                        ]
                    )
                    
                    // Furniture Placement
                    HelpSection(
                        title: "Furniture Placement",
                        items: [
                            "1. Tap 'Catalog' to browse furniture",
                            "2. Select a furniture item to place",
                            "3. Tap on a surface to place the furniture",
                            "4. Use gestures to move, rotate, and scale"
                        ]
                    )
                    
                    // Gestures
                    HelpSection(
                        title: "Gestures",
                        items: [
                            "Tap: Place or select furniture",
                            "Drag: Move furniture around",
                            "Pinch: Scale furniture size",
                            "Rotate: Rotate furniture"
                        ]
                    )
                    
                    // Tips
                    HelpSection(
                        title: "Tips for Best Results",
                        items: [
                            "Ensure good lighting in the room",
                            "Keep your device steady while scanning",
                            "Scan all walls and surfaces thoroughly",
                            "Place furniture on detected surfaces only"
                        ]
                    )
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Help Section
struct HelpSection: View {
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
} 
