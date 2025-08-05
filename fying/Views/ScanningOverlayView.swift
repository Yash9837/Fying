import SwiftUI
import ARKit

struct ScanningOverlayView: View {
    @ObservedObject var viewModel: ARViewModel
    
    var body: some View {
        VStack {
            // Top status bar
            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                    Text("Room Scanning")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    // Show tracking status
                    switch viewModel.sessionState {
                    case .scanning:
                        if let roomStructure = viewModel.roomAnalyzer.roomStructure {
                            Text(roomStructure.getSummary())
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else if viewModel.roomAnalyzer.isAnalyzing {
                            Text("Analyzing room structure... \(Int(viewModel.roomAnalyzer.analysisProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Text("Detecting surfaces...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    case .error(let message):
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.orange)
                    default:
                        Text("Initializing AR...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.roomScanModel.scanProgress))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(viewModel.roomScanModel.scanProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            
            Spacer()
            
            // Scanning instructions
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    ScanningInstructionView(
                        icon: "move.3d",
                        title: "Move Slowly",
                        description: "Pan around the room"
                    )
                    
                    ScanningInstructionView(
                        icon: "light.max",
                        title: "Good Lighting",
                        description: "Ensure proper lighting"
                    )
                }
                
                HStack(spacing: 20) {
                    ScanningInstructionView(
                        icon: "camera.fill",
                        title: "Keep Steady",
                        description: "Avoid rapid movements"
                    )
                    
                    ScanningInstructionView(
                        icon: "eye.fill",
                        title: "Scan Surfaces",
                        description: "Focus on walls and floors"
                    )
                }
                
                // Additional guidance for tracking issues
                if case .error = viewModel.sessionState {
                    VStack(spacing: 8) {
                        Text("Tracking Tips:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text("• Move device slowly and steadily")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text("• Ensure good lighting in the room")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text("• Point camera at textured surfaces")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            
            Spacer()
            
            // Bottom controls
            HStack {
                Button("Cancel") {
                    viewModel.resetRoom()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Spacer()
                
                Button("Complete Scan") {
                    viewModel.stopRoomScan()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.roomScanModel.scanProgress < 0.8)
            }
            .padding()
        }
        .padding()
    }
}

struct ScanningInstructionView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ScanningOverlayView(viewModel: ARViewModel())
        .background(Color.black)
}
