//
//  PlacedFurnitureListView.swift
//  fying new
//
//  Created by user@69 on 05/08/25.
//


import SwiftUI

struct PlacedFurnitureListView: View {
    @ObservedObject var viewModel: ARViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.placedFurniture) { furniture in
                    PlacedFurnitureItemView(
                        furniture: furniture,
                        isSelected: furniture.isSelected,
                        onSelect: {
                            viewModel.selectFurniture(furniture)
                        },
                        onDelete: {
                            viewModel.deleteFurniture(furniture)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .background(Color.black.opacity(0.7))
    }
}

struct PlacedFurnitureItemView: View {
    let furniture: PlacedFurniture
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Furniture thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                
                Image(systemName: furniture.furnitureItem.category.icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            
            // Furniture name
            Text(furniture.furnitureItem.name)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Action buttons
            HStack(spacing: 4) {
                Button(action: onSelect) {
                    Image(systemName: "hand.tap")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    PlacedFurnitureListView(viewModel: ARViewModel())
        .background(Color.black)
}