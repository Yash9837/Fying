//
//  FurnitureDetailView.swift
//  fying new
//
//  Created by user@69 on 05/08/25.
//


import SwiftUI

struct FurnitureDetailView: View {
    let item: FurnitureItem
    let onPlace: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Furniture Details")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.gray)
            }
            
            // Furniture image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                
                Image(systemName: item.category.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            
            // Furniture information
            VStack(alignment: .leading, spacing: 12) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(item.description)
                    .font(.body)
                    .foregroundColor(.gray)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(item.category.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Price")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("$\(String(format: "%.2f", item.price))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default Scale")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(String(format: "%.1fx", item.defaultScale))")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Rotation")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(Int(item.defaultRotation))°")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button("Place in Room") {
                    onPlace()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
                
                Text("Tap anywhere in the AR view to place this furniture")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
        )
        .padding()
    }
}

#Preview {
    FurnitureDetailView(
        item: FurnitureItem(
            name: "Modern Chair",
            category: .seating,
            modelName: "modern_chair",
            thumbnailName: "chair_thumb",
            defaultScale: 1.0,
            defaultRotation: 0,
            price: 299.99,
            description: "Contemporary design chair with ergonomic features"
        ),
        onPlace: {},
        onCancel: {}
    )
    .background(Color.black)
}