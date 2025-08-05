//
//  ContentView.swift
//  fying
//
//  Created by user@69 on 05/08/25.
//

import SwiftUI
import ARKit
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = ARViewModel()
    @State private var showFurnitureDetail = false
    @State private var selectedFurnitureItem: FurnitureItem?
    
    var body: some View {
        ZStack {
            // AR Scene View
            ARSceneView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay UI
            VStack {
                // Top overlay
                if viewModel.showScanningUI {
                    ScanningOverlayView(viewModel: viewModel)
                }
                
                Spacer()
                
                // Bottom overlay
                if viewModel.showPlacementUI {
                    VStack(spacing: 0) {
                        // Placed furniture list
                        if !viewModel.placedFurniture.isEmpty {
                            PlacedFurnitureListView(viewModel: viewModel)
                                .frame(height: 120)
                        }
                        
                        // Control panel
                        ControlPanelView(viewModel: viewModel)
                    }
                }
            }
            
            // Furniture catalog overlay
            if viewModel.showFurnitureCatalog {
                VStack {
                    Spacer()
                    
                    FurnitureCatalogView(viewModel: viewModel)
                        .frame(height: 300)
                        .transition(.move(edge: .bottom))
                }
            }
            
            // Furniture detail overlay
            if let selectedItem = selectedFurnitureItem {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                FurnitureDetailView(
                    item: selectedItem,
                    onPlace: {
                        viewModel.selectFurniture(selectedItem)
                        selectedFurnitureItem = nil
                        showFurnitureDetail = false
                    },
                    onCancel: {
                        selectedFurnitureItem = nil
                        showFurnitureDetail = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Error overlay
            if case .error(let message) = viewModel.sessionState {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("AR Error")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            viewModel.resetRoom()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding()
                }
            }
        }
        .onAppear {
            // Request camera permissions
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    DispatchQueue.main.async {
                        viewModel.sessionState = .error("Camera access is required for AR functionality")
                    }
                }
            }
        }
        .onChange(of: viewModel.currentFurnitureItem) { item in
            if let item = item {
                selectedFurnitureItem = item
                showFurnitureDetail = true
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showFurnitureCatalog)
        .animation(.easeInOut(duration: 0.3), value: showFurnitureDetail)
    }
}

#Preview {
    ContentView()
}
